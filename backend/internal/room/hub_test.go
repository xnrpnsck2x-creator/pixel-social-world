package room

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gorilla/websocket"
)

func TestHubBroadcastsPlayerMoveOnlyInsideRoom(t *testing.T) {
	hub := NewHub()
	upgrader := websocket.Upgrader{}
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		conn, err := upgrader.Upgrade(writer, request, nil)
		if err != nil {
			t.Errorf("upgrade failed: %v", err)
			return
		}
		hub.Attach(conn)
	}))
	defer server.Close()

	roomA1 := dialTestSocket(t, server.URL)
	defer roomA1.Close()
	roomA2 := dialTestSocket(t, server.URL)
	defer roomA2.Close()
	roomB := dialTestSocket(t, server.URL)
	defer roomB.Close()

	writeEnvelope(t, roomA1, joinEnvelope("player_a1", "room_a"))
	writeEnvelope(t, roomA2, joinEnvelope("player_a2", "room_a"))
	writeEnvelope(t, roomB, joinEnvelope("player_b", "room_b"))
	waitForRoomCounts(t, hub, map[string]int{"room_a": 2, "room_b": 1})

	move := Envelope{
		SchemaVersion: 1,
		Type:          "player.move",
		Payload: map[string]interface{}{
			"player_id": "player_a1",
			"room_id":   "room_a",
			"position":  map[string]interface{}{"x": 9000, "y": -9000},
		},
	}
	writeEnvelope(t, roomA1, move)

	receivedMove := readUntilType(t, roomA2, "player.move")
	movePayload := receivedMove.Payload.(map[string]interface{})
	if movePayload["player_id"] != "player_a1" || movePayload["room_id"] != "room_a" {
		t.Fatalf("move payload was not normalized: %#v", movePayload)
	}
	position := movePayload["position"].(map[string]interface{})
	if position["x"] != float64(480) || position["y"] != float64(-300) {
		t.Fatalf("move position was not clamped: %#v", position)
	}
	assertNoType(t, roomB, "player.move", 80*time.Millisecond)

	writeEnvelope(t, roomA2, Envelope{SchemaVersion: 1, Type: "world.snapshot"})
	snapshot := readUntilType(t, roomA2, "world.snapshot")
	snapshotPayload := snapshot.Payload.(map[string]interface{})
	players := snapshotPayload["players"].([]interface{})
	if len(players) != 1 {
		t.Fatalf("expected one player in snapshot, got %#v", players)
	}

	writeEnvelope(t, roomA2, Envelope{
		SchemaVersion: 1,
		Type:          "emote.send",
		Payload: map[string]interface{}{
			"player_id": "player_a2",
			"room_id":   "room_a",
			"emote_id":  "emote.exclamation",
		},
	})
	emote := readUntilType(t, roomA1, "emote.event")
	payload := emote.Payload.(map[string]interface{})
	if payload["emote_id"] != "emote.exclamation" {
		t.Fatalf("unexpected emote payload: %#v", payload)
	}
	assertNoType(t, roomB, "emote.event", 80*time.Millisecond)
}

func TestHubRejectsInvalidJoinToken(t *testing.T) {
	hub := NewHub(WithSessionValidator(testValidator{"player_a": "token_a"}))
	server := newHubTestServer(t, hub)
	defer server.Close()

	conn := dialTestSocket(t, server.URL)
	defer conn.Close()

	writeEnvelope(t, conn, Envelope{
		SchemaVersion: 1,
		Type:          "world.join",
		Payload: map[string]interface{}{
			"player_id":    "player_a",
			"access_token": "wrong",
			"room_id":      "room_a",
		},
	})
	response := readUntilType(t, conn, "auth.failed")
	payload := response.Payload.(map[string]interface{})
	if payload["error"] != "invalid_access_token" {
		t.Fatalf("unexpected auth failure payload: %#v", payload)
	}
}

func TestHubRateLimitsPlayerMove(t *testing.T) {
	hub := NewHub(WithRateLimits(time.Hour, 0))
	server := newHubTestServer(t, hub)
	defer server.Close()

	roomA1 := dialTestSocket(t, server.URL)
	defer roomA1.Close()
	roomA2 := dialTestSocket(t, server.URL)
	defer roomA2.Close()

	writeEnvelope(t, roomA1, joinEnvelope("player_a1", "room_a"))
	writeEnvelope(t, roomA2, joinEnvelope("player_a2", "room_a"))
	waitForRoomCounts(t, hub, map[string]int{"room_a": 2})

	move := Envelope{
		SchemaVersion: 1,
		Type:          "player.move",
		Payload:       map[string]interface{}{"position": map[string]interface{}{"x": 1, "y": 1}},
	}
	writeEnvelope(t, roomA1, move)
	writeEnvelope(t, roomA1, move)

	_ = readUntilType(t, roomA2, "player.move")
	assertNoType(t, roomA2, "player.move", 80*time.Millisecond)
}

func TestHubRejectsRoomWhenCapacityFull(t *testing.T) {
	hub := NewHub(WithRoomCapacityPolicy(RoomCapacityPolicy{
		MainCity: 2,
		Housing:  1,
		Minigame: 1,
		Custom:   1,
	}))
	server := newHubTestServer(t, hub)
	defer server.Close()

	first := dialTestSocket(t, server.URL)
	defer first.Close()
	second := dialTestSocket(t, server.URL)
	defer second.Close()

	writeEnvelope(t, first, joinEnvelope("player_a", "room_full"))
	waitForRoomCounts(t, hub, map[string]int{"room_full": 1})
	writeEnvelope(t, second, joinEnvelope("player_b", "room_full"))

	response := readUntilType(t, second, "room.denied")
	payload := response.Payload.(map[string]interface{})
	if payload["error"] != "room_capacity_full" || payload["limit"] != float64(1) {
		t.Fatalf("unexpected room capacity denial: %#v", payload)
	}
	waitForRoomCounts(t, hub, map[string]int{"room_full": 1})
}

func TestHubTracksSlowWritesAndClosesFailedWrites(t *testing.T) {
	now := time.Unix(1777560000, 0)
	hub := NewHub(WithClock(func() time.Time { return now }))
	defer hub.Close()

	closed := false
	slowClient := &clientState{
		roomID: "room_a",
		writeFn: func(Envelope) error {
			now = now.Add(slowWriteThreshold + time.Millisecond)
			return nil
		},
	}
	result := hub.writeClient(slowClient, Envelope{SchemaVersion: 1, Type: "slow.test"})
	hub.recordRoomWrite(slowClient.roomID, result)
	if !result.delivered || !result.slow {
		t.Fatalf("expected delivered slow write, got %#v", result)
	}

	failedClient := &clientState{
		roomID: "room_a",
		writeFn: func(Envelope) error {
			return errors.New("socket blocked")
		},
		closeFn: func() error {
			closed = true
			return nil
		},
	}
	result = hub.writeClient(failedClient, Envelope{SchemaVersion: 1, Type: "fail.test"})
	hub.recordRoomWrite(failedClient.roomID, result)
	if !result.failed || !closed {
		t.Fatalf("expected failed write to close client, result=%#v closed=%v", result, closed)
	}

	realtime := hub.metrics.Snapshot()
	if realtime["slow_writes"] != 1 || realtime["write_failed"] != 1 || realtime["write_failure_closed"] != 1 {
		t.Fatalf("unexpected realtime write metrics: %#v", realtime)
	}
	rooms := hub.DebugSnapshot()["rooms"].(map[string]map[string]interface{})
	roomState := rooms["room_a"]
	if roomState["slow_writes"] != int64(1) || roomState["write_failed"] != int64(1) {
		t.Fatalf("unexpected room write metrics: %#v", roomState)
	}
}

func newHubTestServer(t *testing.T, hub *Hub) *httptest.Server {
	t.Helper()
	upgrader := websocket.Upgrader{}
	return httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		conn, err := upgrader.Upgrade(writer, request, nil)
		if err != nil {
			t.Errorf("upgrade failed: %v", err)
			return
		}
		hub.Attach(conn)
	}))
}

func dialTestSocket(t *testing.T, serverURL string) *websocket.Conn {
	t.Helper()
	url := "ws" + strings.TrimPrefix(serverURL, "http")
	conn, _, err := websocket.DefaultDialer.Dial(url, nil)
	if err != nil {
		t.Fatalf("dial failed: %v", err)
	}
	return conn
}

func joinEnvelope(playerID string, roomID string) Envelope {
	return Envelope{
		SchemaVersion: 1,
		Type:          "world.join",
		Payload: map[string]interface{}{
			"player_id":    playerID,
			"room_id":      roomID,
			"display_name": playerID,
		},
	}
}

func writeEnvelope(t *testing.T, conn *websocket.Conn, envelope Envelope) {
	t.Helper()
	if err := conn.WriteJSON(envelope); err != nil {
		t.Fatalf("write failed: %v", err)
	}
}

func readUntilType(t *testing.T, conn *websocket.Conn, messageType string) Envelope {
	t.Helper()
	_ = conn.SetReadDeadline(time.Now().Add(time.Second))
	for {
		var envelope Envelope
		if err := conn.ReadJSON(&envelope); err != nil {
			t.Fatalf("read timed out waiting for %s: %v", messageType, err)
		}
		if envelope.Type == messageType {
			return envelope
		}
	}
}

func assertNoType(t *testing.T, conn *websocket.Conn, messageType string, timeout time.Duration) {
	t.Helper()
	_ = conn.SetReadDeadline(time.Now().Add(timeout))
	for {
		var envelope Envelope
		if err := conn.ReadJSON(&envelope); err != nil {
			return
		}
		if envelope.Type == messageType {
			t.Fatalf("unexpected %s received", messageType)
		}
	}
}

func waitForRoomCounts(t *testing.T, hub *Hub, expected map[string]int) {
	t.Helper()
	deadline := time.Now().Add(time.Second)
	for time.Now().Before(deadline) {
		snapshot := hub.Snapshot()
		rooms := snapshot["rooms"].(map[string]int)
		matches := true
		for roomID, count := range expected {
			if rooms[roomID] != count {
				matches = false
				break
			}
		}
		if matches {
			return
		}
		time.Sleep(10 * time.Millisecond)
	}
	t.Fatalf("room counts did not reach %#v; snapshot=%#v", expected, hub.Snapshot())
}

type testValidator map[string]string

func (v testValidator) ValidateAccessToken(_ context.Context, playerID string, accessToken string) bool {
	return v[playerID] == accessToken
}
