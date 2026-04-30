package auth

import (
	"context"
	"testing"
	"time"

	miniredis "github.com/alicebob/miniredis/v2"
	goredis "github.com/redis/go-redis/v9"
)

func TestRedisServiceRefreshAndTTL(t *testing.T) {
	redisServer := miniredis.RunT(t)
	client := goredis.NewClient(&goredis.Options{Addr: redisServer.Addr()})
	service := NewRedisService(client, time.Second, time.Hour)
	ctx := context.Background()
	session, err := service.GuestLogin(ctx, GuestLoginRequest{DisplayName: "Redis Tester"})
	if err != nil {
		t.Fatalf("GuestLogin returned error: %v", err)
	}
	if !service.ValidateAccessToken(ctx, session.PlayerID, session.AccessToken) {
		t.Fatal("initial access token was not valid")
	}
	next, err := service.RefreshAccessToken(ctx, RefreshRequest{
		PlayerID:     session.PlayerID,
		RefreshToken: session.RefreshToken,
	})
	if err != nil {
		t.Fatalf("RefreshAccessToken returned error: %v", err)
	}
	if service.ValidateAccessToken(ctx, session.PlayerID, session.AccessToken) {
		t.Fatal("old redis access token remained valid after refresh")
	}
	if !service.ValidateAccessToken(ctx, next.PlayerID, next.AccessToken) {
		t.Fatal("new redis access token was not valid")
	}
	redisServer.FastForward(2 * time.Second)
	if service.ValidateAccessToken(ctx, next.PlayerID, next.AccessToken) {
		t.Fatal("redis access token survived ttl")
	}
}

func TestRedisServiceUpgradeGuestLinksProvider(t *testing.T) {
	redisServer := miniredis.RunT(t)
	client := goredis.NewClient(&goredis.Options{Addr: redisServer.Addr()})
	service := NewRedisService(client, time.Second, time.Hour)
	ctx := context.Background()
	session, _ := service.GuestLogin(ctx, GuestLoginRequest{DisplayName: "Redis Tester"})
	upgraded, err := service.UpgradeGuest(ctx, UpgradeGuestRequest{
		PlayerID:        session.PlayerID,
		Provider:        "apple",
		Platform:        "h5",
		ProviderSubject: "apple-subject-1",
		IdentityToken:   "dummy-token",
	})
	if err != nil {
		t.Fatalf("UpgradeGuest returned error: %v", err)
	}
	if upgraded.Session.PlayerID != session.PlayerID {
		t.Fatal("redis upgrade changed player id")
	}
	if !service.ValidateAccessToken(ctx, upgraded.Session.PlayerID, upgraded.Session.AccessToken) {
		t.Fatal("upgraded redis session token was not valid")
	}
}
