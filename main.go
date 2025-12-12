package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"strings"

	"github.com/redis/go-redis/v9"
	"github.com/tidwall/redcon"
)

func main() {
	var addr = flag.String("addr", ":6379", "proxy address")
	var kvAddr = flag.String("kvaddr", "127.0.0.1:6666", "kvrocks server address")
	flag.Parse()

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

	// SELECT db -> AUTH nsdb
	if cmdName == "SELECT" {
		if len(cmd.Args) < 2 {
			conn.WriteError("wrong number of arguments for 'select' command")
			return
		}
		db := string(cmd.Args[1])
		namespace := "ns" + db

		result := kvClient.Do(context.Background(), "AUTH", namespace)
		if result.Err() != nil {
			conn.WriteError(result.Err().Error())
		} else {
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
		conn.WriteError(result.Err().Error())
		return
	}

	switch v := result.Val().(type) {
	case string:
		conn.WriteBulkString(v)
	case int64:
		conn.WriteInt(int(v))
	case nil:
		conn.WriteNull()
	default:
		conn.WriteBulkString(fmt.Sprint(v))
	}
}
