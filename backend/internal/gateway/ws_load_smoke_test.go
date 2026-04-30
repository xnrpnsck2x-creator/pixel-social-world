package gateway

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/gorilla/websocket"

	"pixel-social-world/backend/internal/room"
)

const wsLoadSmokeClients = 24
const wsLoadSmokeMaxClients = 100

type wsLoadClient struct {
	conn     *websocket.Conn
	playerID string
	token    string
}

func TestWebSocketLoadSmokeUpdatesRealtimeMetrics(t *testing.T) {
	clientCount := wsLoadSmokeClientCount(t)
	deps := DefaultMemoryDependencies()
	deps.AdminToken = "test-admin"
	server := NewServerWithDependencies(deps)
	httpServer := httptest.NewServer(server.router)
	defer httpServer.Close()
	wsURL := "ws" + strings.TrimPrefix(httpServer.URL, "http") + "/ws/city"

	clients := make([]wsLoadClient, 0, clientCount)
	defer func() { closeLoadClients(clients) }()
	for i := 0; i < clientCount; i++ {
		session := testGuestLogin(t, server, fmt.Sprintf("Load %02d", i))
		conn, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
		if err != nil {
			t.Fatalf("dial websocket %d: %v", i, err)
		}
		client := wsLoadClient{
			conn:     conn,
			playerID: session["player_id"].(string),
			token:    session["access_token"].(string),
		}
		clients = append(clients, client)
		writeLoadEnvelope(t, conn, "world.join", map[string]any{
			"player_id":     client.playerID,
			"access_token":  client.token,
			"room_id":       "load_room",
			"display_name":  fmt.Sprintf("Load %02d", i),
			"load_smoke_id": i,
		})
	}
	drainLoadClients(clients, 150*time.Millisecond)

	for round := 0; round < 3; round++ {
		for index, client := range clients {
			writeLoadEnvelope(t, client.conn, "player.move", map[string]any{
				"position": map[string]any{"x": index * 4, "y": round * 8},
				"velocity": map[string]any{"x": 1, "y": 0},
				"facing":   "right",
			})
		}
		time.Sleep(60 * time.Millisecond)
	}
	for i := 0; i < 4; i++ {
		writeLoadEnvelope(t, clients[0].conn, "player.move", map[string]any{
			"position": map[string]any{"x": i, "y": i},
			"facing":   "down",
		})
	}
	testPostJSON(t, server, "/chat/send", clients[0].token, map[string]any{
		"room_id":     "load_room",
		"channel_id":  "global",
		"sender_id":   clients[0].playerID,
		"sender_name": "Load 00",
		"body":        "load smoke chat",
	}, http.StatusOK)
	drainLoadClients(clients, 300*time.Millisecond)

	ops := fetchLoadOps(t, server)
	rooms := ops["rooms"].(map[string]any)
	if int(rooms["online_count"].(float64)) != clientCount {
		t.Fatalf("expected %d online clients, got %#v", clientCount, rooms)
	}
	realtime := ops["realtime"].(map[string]any)
	assertLoadMetricAtLeast(t, realtime, "connections_opened", clientCount)
	assertLoadMetricAtLeast(t, realtime, "local_broadcasts", clientCount)
	assertLoadMetricAtLeast(t, realtime, "local_delivery_target", clientCount*clientCount)
	assertLoadMetricAtLeast(t, realtime, "local_delivered", clientCount*clientCount)
	assertLoadMetricAtLeast(t, realtime, "move_rate_limited", 1)
	if int(realtime["write_failed"].(float64)) != 0 {
		t.Fatalf("load smoke should not produce write failures: %#v", realtime)
	}

	debugRooms := fetchLoadRooms(t, server)
	roomState := debugRooms["rooms"].(map[string]any)["load_room"].(map[string]any)
	assertLoadMetricAtLeast(t, roomState, "local_delivery_target", clientCount*clientCount)
	assertLoadMetricAtLeast(t, roomState, "local_delivered", clientCount*clientCount)
	if int(roomState["write_failed"].(float64)) != 0 {
		t.Fatalf("load room should not produce write failures: %#v", roomState)
	}
}

func wsLoadSmokeClientCount(t *testing.T) int {
	t.Helper()
	value := strings.TrimSpace(os.Getenv("PSW_WS_LOAD_SMOKE_CLIENTS"))
	if value == "" {
		return wsLoadSmokeClients
	}
	parsed, err := strconv.Atoi(value)
	if err != nil || parsed < 1 || parsed > wsLoadSmokeMaxClients {
		t.Fatalf("PSW_WS_LOAD_SMOKE_CLIENTS must be 1-%d, got %q", wsLoadSmokeMaxClients, value)
	}
	return parsed
}

func writeLoadEnvelope(t *testing.T, conn *websocket.Conn, messageType string, payload map[string]any) {
	t.Helper()
	if err := conn.WriteJSON(room.Envelope{
		SchemaVersion: 1,
		Type:          messageType,
		SentAt:        time.Now().Unix(),
		Payload:       payload,
	}); err != nil {
		t.Fatalf("write %s: %v", messageType, err)
	}
}

func drainLoadClients(clients []wsLoadClient, duration time.Duration) {
	deadline := time.Now().Add(duration)
	for time.Now().Before(deadline) {
		for _, client := range clients {
			_ = client.conn.SetReadDeadline(time.Now().Add(2 * time.Millisecond))
			for {
				if _, _, err := client.conn.ReadMessage(); err != nil {
					break
				}
			}
		}
		time.Sleep(5 * time.Millisecond)
	}
}

func closeLoadClients(clients []wsLoadClient) {
	for _, client := range clients {
		_ = client.conn.Close()
	}
}

func fetchLoadOps(t *testing.T, server *Server) map[string]any {
	t.Helper()
	return fetchLoadAdminJSON(t, server, "/debug/ops")
}

func fetchLoadRooms(t *testing.T, server *Server) map[string]any {
	t.Helper()
	return fetchLoadAdminJSON(t, server, "/debug/rooms")
}

func fetchLoadAdminJSON(t *testing.T, server *Server, path string) map[string]any {
	t.Helper()
	request := httptest.NewRequest(http.MethodGet, path, nil)
	request.Header.Set("X-Admin-Token", "test-admin")
	recorder := httptest.NewRecorder()
	server.router.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusOK {
		t.Fatalf("%s failed: %d %s", path, recorder.Code, recorder.Body.String())
	}
	var decoded map[string]any
	if err := json.Unmarshal(recorder.Body.Bytes(), &decoded); err != nil {
		t.Fatalf("decode %s: %v", path, err)
	}
	return decoded
}

func assertLoadMetricAtLeast(t *testing.T, metrics map[string]any, key string, minimum int) {
	t.Helper()
	value := int(metrics[key].(float64))
	if value < minimum {
		t.Fatalf("expected %s >= %d, got %d in %#v", key, minimum, value, metrics)
	}
}
