package room

import (
	"context"
	"fmt"
	"time"

	goredis "github.com/redis/go-redis/v9"
)

type RateLimiter interface {
	Allow(ctx context.Context, key string, interval time.Duration) bool
	Close() error
}

type RedisRateLimiter struct {
	client *goredis.Client
}

func NewRedisRateLimiter(client *goredis.Client) *RedisRateLimiter {
	return &RedisRateLimiter{client: client}
}

func WithRateLimiter(rateLimiter RateLimiter) Option {
	return func(h *Hub) {
		h.rateLimiter = rateLimiter
	}
}

func (l *RedisRateLimiter) Allow(ctx context.Context, key string, interval time.Duration) bool {
	if interval <= 0 {
		return true
	}
	if ctx == nil {
		ctx = context.Background()
	}
	ok, err := l.client.SetNX(ctx, key, "1", interval).Result()
	return err == nil && ok
}

func (l *RedisRateLimiter) Close() error {
	return nil
}

func rateKey(playerID string, action string) string {
	return fmt.Sprintf("rate:%s:%s", playerID, action)
}

func (h *Hub) allowAction(
	client *clientState,
	action string,
	interval time.Duration,
	last *time.Time,
) bool {
	if h.rateLimiter != nil {
		return h.rateLimiter.Allow(context.Background(), rateKey(client.playerID, action), interval)
	}
	if h.tooSoon(*last, interval) {
		return false
	}
	*last = h.now()
	return true
}
