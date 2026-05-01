package gateway

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	miniredis "github.com/alicebob/miniredis/v2"
	"github.com/gorilla/websocket"
	goredis "github.com/redis/go-redis/v9"

	"pixel-social-world/backend/internal/auth"
	"pixel-social-world/backend/internal/room"
)

func TestRedisRealtimeFanoutCrossesGatewayInstances(t *testing.T) {
	redisServer := miniredis.RunT(t)
	redisClient := goredis.NewClient(&goredis.Options{Addr: redisServer.Addr()})
	defer redisClient.Close()

	authService := auth.NewRedisService(redisClient, time.Minute, time.Hour)
	serverA := newRedisRealtimeTestServer(t, redisClient, authService)
	defer serverA.roomHub.Close()
	serverB := newRedisRealtimeTestServer(t, redisClient, authService)
	defer serverB.roomHub.Close()

	httpA := httptest.NewServer(serverA.router)
	defer httpA.Close()
	httpB := httptest.NewServer(serverB.router)
	defer httpB.Close()
	waitForRedisFanoutSubscribers(t, redisClient, 2)

	sessionA := testGuestLogin(t, serverA, "Redis A")
	sessionB := testGuestLogin(t, serverB, "Redis B")
	connA := dialGatewaySocket(t, httpA.URL)
	defer connA.Close()
	connB := dialGatewaySocket(t, httpB.URL)
	defer connB.Close()

	writeLoadEnvelope(t, connA, "world.join", map[string]any{
		"player_id":    sessionA["player_id"],
		"access_token": sessionA["access_token"],
		"room_id":      "redis_room",
		"display_name": "Redis A",
	})
	writeLoadEnvelope(t, connB, "world.join", map[string]any{
		"player_id":    sessionB["player_id"],
		"access_token": sessionB["access_token"],
		"room_id":      "redis_room",
		"display_name": "Redis B",
	})
	_ = readGatewayEnvelope(t, connA, "world.snapshot")
	_ = readGatewayEnvelope(t, connB, "world.snapshot")

	writeLoadEnvelope(t, connA, "player.move", map[string]any{
		"position": map[string]any{"x": 64, "y": -32},
		"velocity": map[string]any{"x": 1, "y": 0},
		"facing":   "right",
	})
	move := readGatewayEnvelope(t, connB, "player.move")
	movePayload := move.Payload.(map[string]interface{})
	if movePayload["player_id"] != sessionA["player_id"] || movePayload["room_id"] != "redis_room" {
		t.Fatalf("redis fanout move did not preserve sender room: %#v", movePayload)
	}

	testPostJSON(t, serverA, "/chat/send", sessionA["access_token"].(string), map[string]any{
		"room_id":     "redis_room",
		"channel_id":  "global",
		"sender_id":   sessionA["player_id"],
		"sender_name": "Redis A",
		"body":        "redis fanout chat",
	}, http.StatusOK)
	chat := readGatewayEnvelope(t, connB, "chat.message")
	chatPayload := chat.Payload.(map[string]interface{})
	if chatPayload["room_id"] != "redis_room" {
		t.Fatalf("redis fanout chat did not preserve room: %#v", chatPayload)
	}

	assertRedisRealtimeMetricAtLeast(t, serverA, "fanout_published", 1)
	assertRedisRealtimeMetricAtLeast(t, serverB, "fanout_received", 1)
	assertRedisRealtimeMetricEquals(t, serverA, "write_failed", 0)
	assertRedisRealtimeMetricEquals(t, serverB, "write_failed", 0)
}

func newRedisRealtimeTestServer(
	t *testing.T,
	redisClient *goredis.Client,
	authService auth.Service,
) *Server {
	t.Helper()
	deps := DefaultMemoryDependencies()
	deps.AdminToken = "test-admin"
	deps.AuthService = authService
	deps.RoomHub = room.NewHub(
		room.WithSessionValidator(authService),
		room.WithRoomAuthorizer(NewRoomAuthorizer(deps.MinigameService)),
		room.WithFanout(room.NewRedisFanout(redisClient)),
		room.WithRateLimiter(room.NewRedisRateLimiter(redisClient)),
	)
	return NewServerWithDependencies(deps)
}

func waitForRedisFanoutSubscribers(t *testing.T, redisClient *goredis.Client, expected int64) {
	t.Helper()
	deadline := time.Now().Add(time.Second)
	var lastCount int64
	var lastErr error
	for time.Now().Before(deadline) {
		count, err := redisClient.PubSubNumPat(context.Background()).Result()
		if err == nil && count >= expected {
			return
		}
		lastCount = count
		lastErr = err
		time.Sleep(10 * time.Millisecond)
	}
	t.Fatalf("redis fanout subscribers did not reach %d; count=%d err=%v", expected, lastCount, lastErr)
}

func dialGatewaySocket(t *testing.T, serverURL string) *websocket.Conn {
	t.Helper()
	url := "ws" + strings.TrimPrefix(serverURL, "http") + "/ws/city"
	conn, _, err := websocket.DefaultDialer.Dial(url, nil)
	if err != nil {
		t.Fatalf("dial gateway websocket: %v", err)
	}
	return conn
}

func readGatewayEnvelope(t *testing.T, conn *websocket.Conn, messageType string) room.Envelope {
	t.Helper()
	_ = conn.SetReadDeadline(time.Now().Add(time.Second))
	for {
		var envelope room.Envelope
		if err := conn.ReadJSON(&envelope); err != nil {
			t.Fatalf("read timed out waiting for %s: %v", messageType, err)
		}
		if envelope.Type == messageType {
			return envelope
		}
	}
}

func assertRedisRealtimeMetricAtLeast(t *testing.T, server *Server, key string, minimum int) {
	t.Helper()
	realtime := fetchLoadOps(t, server)["realtime"].(map[string]any)
	value := int(realtime[key].(float64))
	if value < minimum {
		t.Fatalf("expected redis realtime metric %s >= %d, got %d in %#v", key, minimum, value, realtime)
	}
}

func assertRedisRealtimeMetricEquals(t *testing.T, server *Server, key string, expected int) {
	t.Helper()
	realtime := fetchLoadOps(t, server)["realtime"].(map[string]any)
	value := int(realtime[key].(float64))
	if value != expected {
		t.Fatalf("expected redis realtime metric %s == %d, got %d in %#v", key, expected, value, realtime)
	}
}
