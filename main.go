package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"reflect"
	"strings"

	"github.com/redis/go-redis/v9"
	"github.com/tidwall/redcon"
)

var debug bool

func main() {
	var addr = flag.String("addr", ":6379", "proxy address")
	var kvAddr = flag.String("kvaddr", "127.0.0.1:6666", "kvrocks server address")
	flag.BoolVar(&debug, "debug", false, "enable debug mode")
	flag.Parse()

	if debug {
		log.Println("调试模式已启用")
		log.Printf("代理地址: %s", *addr)
		log.Printf("Kvrocks 服务器地址: %s", *kvAddr)
	}

	err := redcon.ListenAndServe(*addr,
		func(conn redcon.Conn, cmd redcon.Command) {
			kvClient := getKVClient(conn)
			handleCommand(conn, cmd, kvClient)
		},
		func(conn redcon.Conn) bool {
			kvClient := redis.NewClient(&redis.Options{
				Addr: *kvAddr,
			})
			conn.SetContext(kvClient)
			log.Printf("新客户端连接: %s", conn.RemoteAddr())
			return true
		},
		func(conn redcon.Conn, err error) {
			if kvClient := getKVClient(conn); kvClient != nil {
				kvClient.Close()
				log.Printf("客户端断开: %s", conn.RemoteAddr())
			}
		},
	)
	log.Fatal(err)
}

func getKVClient(conn redcon.Conn) *redis.Client {
	if kvClient, ok := conn.Context().(*redis.Client); ok {
		return kvClient
	}
	return nil
}

func handleCommand(conn redcon.Conn, cmd redcon.Command, kvClient *redis.Client) {
	if kvClient == nil {
		conn.WriteError("internal error: no kvrocks client")
		return
	}

	cmdName := strings.ToUpper(string(cmd.Args[0]))

	if debug {
		args := make([]string, len(cmd.Args))
		for i, arg := range cmd.Args {
			args[i] = string(arg)
		}
		log.Printf("[DEBUG] 收到命令: %s, 参数: %v, 客户端: %s", cmdName, args, conn.RemoteAddr())
	}

	// SELECT db -> AUTH nsdb
	if cmdName == "SELECT" {
		if len(cmd.Args) < 2 {
			conn.WriteError("wrong number of arguments for 'select' command")
			return
		}
		db := string(cmd.Args[1])
		if debug {
			log.Printf("[DEBUG] SELECT 命令转换为 AUTH %s", db)
		}
		result := kvClient.Do(context.Background(), "AUTH", db)
		if result.Err() != nil {
			if debug {
				log.Printf("[DEBUG] AUTH 命令失败: %v", result.Err())
			}
			conn.WriteError(result.Err().Error())
		} else {
			if debug {
				log.Printf("[DEBUG] AUTH 命令成功")
			}
			conn.WriteString("OK")
		}
		return
	}

	// 其他命令直接转发
	args := make([]interface{}, len(cmd.Args))
	for i, arg := range cmd.Args {
		args[i] = string(arg)
	}

	result := kvClient.Do(context.Background(), args...)

	if result.Err() != nil {
		if debug {
			log.Printf("[DEBUG] 命令执行失败: %v", result.Err())
		}
		conn.WriteError(result.Err().Error())
		return
	}

	if debug {
		log.Printf("[DEBUG] 命令执行成功, 返回类型: %T", result.Val())
	}

	switch v := result.Val().(type) {
	case string:
		conn.WriteBulkString(v)
	case int64:
		conn.WriteInt(int(v))
	case []interface{}:
		// 处理数组类型（如 KEYS 命令返回的结果）
		conn.WriteArray(len(v))
		for _, item := range v {
			if str, ok := item.(string); ok {
				conn.WriteBulkString(str)
			} else {
				conn.WriteBulkString(fmt.Sprint(item))
			}
		}
	case map[string]string:
		// 处理哈希表类型（如 HGETALL 命令返回的结果）
		conn.WriteArray(len(v) * 2) // 键值对，所以长度是 map 长度的 2 倍
		for key, value := range v {
			conn.WriteBulkString(key)
			conn.WriteBulkString(value)
		}
	case map[interface{}]interface{}:
		// 处理 interface{} 类型的哈希表（Kvrocks 返回的实际类型）
		conn.WriteArray(len(v) * 2) // 键值对，所以长度是 map 长度的 2 倍
		for key, value := range v {
			conn.WriteBulkString(fmt.Sprint(key))
			conn.WriteBulkString(fmt.Sprint(value))
		}
	case []string:
		// 处理字符串数组
		conn.WriteArray(len(v))
		for _, str := range v {
			conn.WriteBulkString(str)
		}
	case nil:
		conn.WriteNull()
	default:
		// 对于未知类型，尝试使用反射处理
		rv := reflect.ValueOf(v)
		if rv.Kind() == reflect.Slice {
			conn.WriteArray(rv.Len())
			for i := 0; i < rv.Len(); i++ {
				item := rv.Index(i).Interface()
				conn.WriteBulkString(fmt.Sprint(item))
			}
		} else {
			conn.WriteBulkString(fmt.Sprint(v))
		}
	}
}
