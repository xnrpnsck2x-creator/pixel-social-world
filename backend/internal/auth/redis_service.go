package auth

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	goredis "github.com/redis/go-redis/v9"
)

type RedisService struct {
	client     *goredis.Client
	accessTTL  time.Duration
	refreshTTL time.Duration
	verifier   ProviderVerifier
}

func NewRedisService(client *goredis.Client, accessTTL time.Duration, refreshTTL time.Duration) Service {
	return NewRedisServiceWithProviderVerifier(client, accessTTL, refreshTTL, nil)
}

func NewRedisServiceWithProviderVerifier(
	client *goredis.Client,
	accessTTL time.Duration,
	refreshTTL time.Duration,
	verifier ProviderVerifier,
) Service {
	if accessTTL <= 0 {
		accessTTL = defaultAccessTTL
	}
	if refreshTTL <= 0 {
		refreshTTL = defaultRefreshTTL
	}
	if verifier == nil {
		verifier = NewClaimedProviderVerifier()
	}
	return &RedisService{
		client:     client,
		accessTTL:  accessTTL,
		refreshTTL: refreshTTL,
		verifier:   verifier,
	}
}

func (s *RedisService) GuestLogin(ctx context.Context, request GuestLoginRequest) (Session, error) {
	if request.DisplayName == "" {
		request.DisplayName = "Guest"
	}
	session := newSession(fmt.Sprintf("guest_%d", time.Now().UnixNano()), s.accessTTL, s.refreshTTL)
	return session, s.saveSession(ctx, session)
}

func (s *RedisService) RefreshAccessToken(ctx context.Context, request RefreshRequest) (Session, error) {
	if request.PlayerID == "" || request.RefreshToken == "" {
		return Session{}, fmt.Errorf("invalid_refresh")
	}
	old, err := s.loadSession(ctx, refreshKey(request.RefreshToken))
	if err != nil || old.PlayerID != request.PlayerID || old.RefreshExpiresAt <= time.Now().UnixMilli() {
		return Session{}, fmt.Errorf("invalid_refresh")
	}
	next := newSession(old.PlayerID, s.accessTTL, s.refreshTTL)
	pipe := s.client.TxPipeline()
	pipe.Del(ctx, accessKey(old.AccessToken), refreshKey(old.RefreshToken))
	s.queueSave(ctx, pipe, next)
	_, err = pipe.Exec(ctx)
	return next, err
}

func (s *RedisService) ValidateAccessToken(ctx context.Context, playerID string, accessToken string) bool {
	if playerID == "" || accessToken == "" {
		return false
	}
	session, err := s.loadSession(ctx, accessKey(accessToken))
	return err == nil && session.PlayerID == playerID && session.AccessExpiresAt > time.Now().UnixMilli()
}

func (s *RedisService) saveSession(ctx context.Context, session Session) error {
	pipe := s.client.TxPipeline()
	s.queueSave(ctx, pipe, session)
	_, err := pipe.Exec(ctx)
	return err
}

func (s *RedisService) queueSave(ctx context.Context, pipe goredis.Pipeliner, session Session) {
	encoded, _ := json.Marshal(session)
	pipe.Set(ctx, accessKey(session.AccessToken), encoded, s.accessTTL)
	pipe.Set(ctx, refreshKey(session.RefreshToken), encoded, s.refreshTTL)
}

func (s *RedisService) loadSession(ctx context.Context, key string) (Session, error) {
	raw, err := s.client.Get(ctx, key).Result()
	if err != nil {
		return Session{}, err
	}
	var session Session
	if err := json.Unmarshal([]byte(raw), &session); err != nil {
		return Session{}, err
	}
	return session, nil
}

func accessKey(token string) string {
	return "auth:access:" + token
}

func refreshKey(token string) string {
	return "auth:refresh:" + token
}
