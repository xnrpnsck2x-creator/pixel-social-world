package room

import (
	"context"
	"fmt"
	"time"

	goredis "github.com/redis/go-redis/v9"
)

type SessionLease interface {
	Claim(ctx context.Context, playerID string, token string, ttl time.Duration) error
	IsCurrent(ctx context.Context, playerID string, token string, ttl time.Duration) bool
	Release(ctx context.Context, playerID string, token string) error
	Close() error
}

type RedisSessionLease struct {
	client *goredis.Client
}

var refreshSessionLeaseScript = goredis.NewScript(`
if redis.call("GET", KEYS[1]) == ARGV[1] then
  redis.call("PEXPIRE", KEYS[1], ARGV[2])
  return 1
end
return 0
`)

var releaseSessionLeaseScript = goredis.NewScript(`
if redis.call("GET", KEYS[1]) == ARGV[1] then
  return redis.call("DEL", KEYS[1])
end
return 0
`)

func NewRedisSessionLease(client *goredis.Client) *RedisSessionLease {
	return &RedisSessionLease{client: client}
}

func WithSessionLease(lease SessionLease) Option {
	return func(h *Hub) {
		h.sessionLease = lease
	}
}

func (l *RedisSessionLease) Claim(
	ctx context.Context,
	playerID string,
	token string,
	ttl time.Duration,
) error {
	return l.client.Set(ctx, sessionLeaseKey(playerID), token, ttl).Err()
}

func (l *RedisSessionLease) IsCurrent(
	ctx context.Context,
	playerID string,
	token string,
	ttl time.Duration,
) bool {
	result, err := refreshSessionLeaseScript.Run(
		ctx,
		l.client,
		[]string{sessionLeaseKey(playerID)},
		token,
		ttl.Milliseconds(),
	).Int()
	return err == nil && result == 1
}

func (l *RedisSessionLease) Release(
	ctx context.Context,
	playerID string,
	token string,
) error {
	return releaseSessionLeaseScript.Run(
		ctx,
		l.client,
		[]string{sessionLeaseKey(playerID)},
		token,
	).Err()
}

func (l *RedisSessionLease) Close() error {
	return nil
}

func sessionLeaseKey(playerID string) string {
	return fmt.Sprintf("room:session:%s", playerID)
}
