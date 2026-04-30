package redis

import (
	"context"
	"time"

	goredis "github.com/redis/go-redis/v9"
)

type Config struct {
	Addr                string
	Password            string
	DB                  int
	PoolSize            int
	MinIdleConns        int
	DialTimeoutSeconds  int
	ReadTimeoutSeconds  int
	WriteTimeoutSeconds int
}

func Open(config Config) *goredis.Client {
	return goredis.NewClient(&goredis.Options{
		Addr:         config.Addr,
		Password:     config.Password,
		DB:           config.DB,
		PoolSize:     config.PoolSize,
		MinIdleConns: config.MinIdleConns,
		DialTimeout:  secondsDuration(config.DialTimeoutSeconds),
		ReadTimeout:  secondsDuration(config.ReadTimeoutSeconds),
		WriteTimeout: secondsDuration(config.WriteTimeoutSeconds),
	})
}

func Ping(ctx context.Context, client *goredis.Client) error {
	if ctx == nil {
		ctx = context.Background()
	}
	return client.Ping(ctx).Err()
}

func secondsDuration(seconds int) time.Duration {
	if seconds <= 0 {
		return 0
	}
	return time.Duration(seconds) * time.Second
}
