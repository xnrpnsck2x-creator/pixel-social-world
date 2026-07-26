package room

import (
	"context"
	"testing"
	"time"

	miniredis "github.com/alicebob/miniredis/v2"
	goredis "github.com/redis/go-redis/v9"
)

func TestRedisSessionLeaseFencesOlderTokenAcrossInstances(t *testing.T) {
	redisServer := miniredis.RunT(t)
	client := goredis.NewClient(&goredis.Options{Addr: redisServer.Addr()})
	first := NewRedisSessionLease(client)
	second := NewRedisSessionLease(client)
	ctx := context.Background()

	if err := first.Claim(ctx, "player_a", "token-a", time.Minute); err != nil {
		t.Fatal(err)
	}
	if !first.IsCurrent(ctx, "player_a", "token-a", time.Minute) {
		t.Fatal("first token was not current")
	}
	if err := second.Claim(ctx, "player_a", "token-b", time.Minute); err != nil {
		t.Fatal(err)
	}
	if first.IsCurrent(ctx, "player_a", "token-a", time.Minute) {
		t.Fatal("older token remained current after replacement")
	}
	if !second.IsCurrent(ctx, "player_a", "token-b", time.Minute) {
		t.Fatal("replacement token was not current")
	}
	if err := first.Release(ctx, "player_a", "token-a"); err != nil {
		t.Fatal(err)
	}
	if !second.IsCurrent(ctx, "player_a", "token-b", time.Minute) {
		t.Fatal("older token released the replacement lease")
	}
}

func TestRedisSessionLeaseFencesEventsFromOlderHub(t *testing.T) {
	redisServer := miniredis.RunT(t)
	client := goredis.NewClient(&goredis.Options{Addr: redisServer.Addr()})
	oldHub := NewHub(WithSessionLease(NewRedisSessionLease(client)))
	defer oldHub.Close()
	newHub := NewHub(WithSessionLease(NewRedisSessionLease(client)))
	defer newHub.Close()
	oldClient := newClientState(nil, time.Now().Unix())
	newClient := newClientState(nil, time.Now().Unix())
	defer oldClient.close()
	defer newClient.close()

	oldHub.reserveJoin(oldClient, "player_a", "Old", "room_a")
	newHub.reserveJoin(newClient, "player_a", "New", "room_a")
	oldHub.handle(oldClient, Envelope{
		SchemaVersion: 1,
		Type:          "player.move",
		Payload: map[string]interface{}{
			"position": map[string]interface{}{"x": 10.0, "y": 20.0},
		},
	})
	if _, ok := oldHub.lastPlayerPoint("room_a", "player_a"); ok {
		t.Fatal("older hub accepted a fenced movement event")
	}
}
