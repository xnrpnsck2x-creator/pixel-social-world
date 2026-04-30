package minigame

import (
	"context"
	"sync"
	"testing"
	"time"

	miniredis "github.com/alicebob/miniredis/v2"
	goredis "github.com/redis/go-redis/v9"
)

func TestRedisSessionServiceConcurrentJoinDoesNotOverfill(t *testing.T) {
	redisServer := miniredis.RunT(t)
	client := goredis.NewClient(&goredis.Options{Addr: redisServer.Addr()})
	service := NewRedisSessionService(client, time.Minute)
	ctx := context.Background()

	session, err := service.CreateSession(ctx, CreateSessionRequest{
		GameID:       "fishing",
		RoomID:       "world_town_square",
		HostPlayerID: "host",
		MaxPlayers:   2,
	})
	if err != nil {
		t.Fatalf("CreateSession returned error: %v", err)
	}

	var waitGroup sync.WaitGroup
	for index := 0; index < 12; index++ {
		waitGroup.Add(1)
		go func(index int) {
			defer waitGroup.Done()
			_, _ = service.JoinSession(ctx, JoinSessionRequest{
				SessionID: session.ID,
				PlayerID:  "redis_player_" + string(rune('a'+index)),
			})
		}(index)
	}
	waitGroup.Wait()

	sessions := service.ListSessions(ctx, "world_town_square")
	if len(sessions) != 1 {
		t.Fatalf("expected one session, got %d", len(sessions))
	}
	if len(sessions[0].Players) > 2 {
		t.Fatalf("session overfilled: %#v", sessions[0])
	}
}

func TestRedisSessionServiceTTLRemovesSessionFromList(t *testing.T) {
	redisServer := miniredis.RunT(t)
	client := goredis.NewClient(&goredis.Options{Addr: redisServer.Addr()})
	service := NewRedisSessionService(client, time.Second)
	ctx := context.Background()

	if _, err := service.CreateSession(ctx, CreateSessionRequest{
		GameID:       "fishing",
		RoomID:       "world_town_square",
		HostPlayerID: "host",
		MaxPlayers:   2,
	}); err != nil {
		t.Fatalf("CreateSession returned error: %v", err)
	}
	redisServer.FastForward(2 * time.Second)
	sessions := service.ListSessions(ctx, "world_town_square")
	if len(sessions) != 0 {
		t.Fatalf("expected ttl to remove session, got %#v", sessions)
	}
}
