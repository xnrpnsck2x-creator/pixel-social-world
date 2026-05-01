package gateway

import (
	"context"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"strconv"
	"strings"
	"testing"
	"time"

	miniredis "github.com/alicebob/miniredis/v2"
	"github.com/gorilla/websocket"
	goredis "github.com/redis/go-redis/v9"

	"pixel-social-world/backend/internal/auth"
	"pixel-social-world/backend/internal/room"
)

const redisFanoutLoadSmokeClients = 16
const redisFanoutLoadSmokeMaxClients = 80

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

func TestRedisRealtimeFanoutMultiClientLoadProfile(t *testing.T) {
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

	clientCount := redisFanoutLoadClientCount(t)
	clients := make([]wsLoadClient, 0, clientCount)
	defer func() { closeLoadClients(clients) }()
	for i := 0; i < clientCount; i++ {
		server := serverA
		serverURL := httpA.URL
		if i%2 == 1 {
			server = serverB
			serverURL = httpB.URL
		}
		session := testGuestLogin(t, server, fmt.Sprintf("Redis Load %02d", i))
		conn := dialGatewaySocket(t, serverURL)
		client := wsLoadClient{
			conn:     conn,
			playerID: session["player_id"].(string),
			token:    session["access_token"].(string),
		}
		clients = append(clients, client)
		writeLoadEnvelope(t, conn, "world.join", map[string]any{
			"player_id":    client.playerID,
			"access_token": client.token,
			"room_id":      "redis_load_room",
			"display_name": fmt.Sprintf("Redis Load %02d", i),
		})
	}
	drainLoadClients(clients, 200*time.Millisecond)

	for round := 0; round < 2; round++ {
		for index, client := range clients {
			writeLoadEnvelope(t, client.conn, "player.move", map[string]any{
				"position": loadSmokePosition(index, round),
				"velocity": map[string]any{"x": 1, "y": 0},
				"facing":   "right",
			})
		}
		time.Sleep(80 * time.Millisecond)
	}
	testPostJSON(t, serverA, "/chat/send", clients[0].token, map[string]any{
		"room_id":     "redis_load_room",
		"channel_id":  "global",
		"sender_id":   clients[0].playerID,
		"sender_name": "Redis Load 00",
		"body":        "redis fanout load chat",
	}, http.StatusOK)
	drainLoadClients(clients, 400*time.Millisecond)

	opsA := fetchLoadOps(t, serverA)
	opsB := fetchLoadOps(t, serverB)
	roomsA := opsA["rooms"].(map[string]any)
	roomsB := opsB["rooms"].(map[string]any)
	if int(roomsA["online_count"].(float64))+int(roomsB["online_count"].(float64)) != clientCount {
		t.Fatalf("expected %d redis clients across gateways, got A=%#v B=%#v", clientCount, roomsA, roomsB)
	}
	assertRedisRealtimeMetricAtLeast(t, serverA, "fanout_published", 1)
	assertRedisRealtimeMetricAtLeast(t, serverB, "fanout_published", 1)
	assertRedisRealtimeMetricAtLeast(t, serverA, "fanout_received", 1)
	assertRedisRealtimeMetricAtLeast(t, serverB, "fanout_received", 1)
	assertRedisRealtimeMetricEquals(t, serverA, "write_failed", 0)
	assertRedisRealtimeMetricEquals(t, serverB, "write_failed", 0)
	assertRedisRealtimeMetricEquals(t, serverA, "fanout_publish_failed", 0)
	assertRedisRealtimeMetricEquals(t, serverB, "fanout_publish_failed", 0)
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

func redisFanoutLoadClientCount(t *testing.T) int {
	t.Helper()
	value := strings.TrimSpace(os.Getenv("PSW_WS_REDIS_LOAD_SMOKE_CLIENTS"))
	if value == "" {
		return redisFanoutLoadSmokeClients
	}
	parsed, err := strconv.Atoi(value)
	if err != nil || parsed < 2 || parsed > redisFanoutLoadSmokeMaxClients {
		t.Fatalf("PSW_WS_REDIS_LOAD_SMOKE_CLIENTS must be 2-%d, got %q", redisFanoutLoadSmokeMaxClients, value)
	}
	return parsed
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
