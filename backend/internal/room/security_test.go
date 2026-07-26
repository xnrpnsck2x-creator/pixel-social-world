package room

import (
	"encoding/json"
	"strings"
	"testing"
	"time"

	"github.com/gorilla/websocket"
)

func TestHubNeverBroadcastsJoinAccessToken(t *testing.T) {
	hub := NewHub(WithSessionValidator(testValidator{
		"player_a": "secret-token-a",
		"player_b": "secret-token-b",
	}))
	server := newHubTestServer(t, hub)
	defer server.Close()

	observer := dialTestSocket(t, server.URL)
	defer observer.Close()
	writeEnvelope(t, observer, authenticatedJoinEnvelope("player_b", "secret-token-b", "room_a"))
	drainJoinHandshake(t, observer)

	sender := dialTestSocket(t, server.URL)
	defer sender.Close()
	writeEnvelope(t, sender, authenticatedJoinEnvelope("player_a", "secret-token-a", "room_a"))
	joined := readUntilType(t, observer, "world.join")
	encoded, err := json.Marshal(joined)
	if err != nil {
		t.Fatalf("marshal join event: %v", err)
	}
	if strings.Contains(string(encoded), "secret-token-a") {
		t.Fatalf("join event leaked access token: %s", encoded)
	}
	payload := joined.Payload.(map[string]interface{})
	if _, leaked := payload["access_token"]; leaked {
		t.Fatalf("join payload exposed access_token: %#v", payload)
	}
}

func TestHubRejectsUnsupportedAndPreAuthEvents(t *testing.T) {
	hub := NewHub()
	server := newHubTestServer(t, hub)
	defer server.Close()

	unauthenticated := dialTestSocket(t, server.URL)
	defer unauthenticated.Close()
	writeEnvelope(t, unauthenticated, Envelope{
		SchemaVersion: 1,
		Type:          "player.move",
		RequestID:     "preauth-move",
	})
	rejected := readUntilType(t, unauthenticated, "protocol.error")
	if rejected.RequestID != "preauth-move" ||
		rejected.Payload.(map[string]interface{})["error"] != "authentication_required" {
		t.Fatalf("unexpected pre-auth rejection: %#v", rejected)
	}

	sender := dialTestSocket(t, server.URL)
	defer sender.Close()
	observer := dialTestSocket(t, server.URL)
	defer observer.Close()
	writeEnvelope(t, sender, joinEnvelope("player_a", "room_a"))
	writeEnvelope(t, observer, joinEnvelope("player_b", "room_a"))
	drainJoinHandshake(t, sender)
	drainJoinHandshake(t, observer)

	writeEnvelope(t, sender, Envelope{
		SchemaVersion: 1,
		Type:          "admin.injected",
		RequestID:     "unsupported-event",
		Payload:       map[string]interface{}{"access_token": "must-not-broadcast"},
	})
	rejected = readUntilType(t, sender, "protocol.error")
	if rejected.Payload.(map[string]interface{})["error"] != "unsupported_client_event" {
		t.Fatalf("unexpected unsupported-event rejection: %#v", rejected)
	}
	assertNoType(t, observer, "admin.injected", 80*time.Millisecond)
}

func TestClientQueueBoundsReliableMessagesAndCoalescesMovement(t *testing.T) {
	client := newClientState(nil, time.Now().Unix())
	reliable := outboundMessage{envelope: Envelope{SchemaVersion: 1, Type: "chat.message"}}
	if queued, _ := client.enqueue(reliable, 1); !queued {
		t.Fatal("first reliable message was not queued")
	}
	if queued, _ := client.enqueue(reliable, 1); queued {
		t.Fatal("reliable queue exceeded its configured bound")
	}

	firstMove := outboundMessage{
		envelope: Envelope{SchemaVersion: 1, Type: "player.move", Payload: map[string]interface{}{"sequence": 1}},
	}
	secondMove := outboundMessage{
		envelope: Envelope{SchemaVersion: 1, Type: "player.move", Payload: map[string]interface{}{"sequence": 2}},
	}
	if queued, coalesced := client.enqueue(firstMove, 1); !queued || coalesced {
		t.Fatalf("unexpected first movement enqueue: queued=%v coalesced=%v", queued, coalesced)
	}
	if queued, coalesced := client.enqueue(secondMove, 1); !queued || !coalesced {
		t.Fatalf("movement was not coalesced: queued=%v coalesced=%v", queued, coalesced)
	}
	_, _ = client.dequeue()
	latest, ok := client.dequeue()
	if !ok || latest.envelope.Payload.(map[string]interface{})["sequence"] != 2 {
		t.Fatalf("movement queue did not preserve latest state: %#v", latest)
	}
}

func TestRapidRoomSwitchIsRateLimited(t *testing.T) {
	now := time.Unix(100, 0)
	hub := NewHub(WithClock(func() time.Time { return now }))
	defer hub.Close()
	client := newClientState(nil, now.Unix())

	hub.handle(client, joinEnvelope("player_a", "room_a"))
	hub.handle(client, joinEnvelope("player_a", "room_b"))

	if state := client.snapshot(); state.roomID != "room_a" {
		t.Fatalf("rapid room switch bypassed join rate limit: %#v", state)
	}
}

func TestSupersededSessionCannotPublishMovement(t *testing.T) {
	hub := NewHub()
	defer hub.Close()
	oldClient := newClientState(nil, time.Now().Unix())
	newClient := newClientState(nil, time.Now().Unix())
	defer oldClient.close()
	defer newClient.close()
	hub.reserveJoin(oldClient, "player_a", "Old", "room_a")
	hub.reserveJoin(newClient, "player_a", "New", "room_a")

	hub.handle(oldClient, Envelope{
		SchemaVersion: 1,
		Type:          "player.move",
		RequestID:     "stale-move",
		Payload: map[string]interface{}{
			"position": map[string]interface{}{"x": 10.0, "y": 20.0},
		},
	})
	if _, ok := hub.lastPlayerPoint("room_a", "player_a"); ok {
		t.Fatal("superseded session published movement")
	}
}

func authenticatedJoinEnvelope(playerID string, token string, roomID string) Envelope {
	envelope := joinEnvelope(playerID, roomID)
	envelope.Payload.(map[string]interface{})["access_token"] = token
	return envelope
}

func drainJoinHandshake(t *testing.T, conn *websocket.Conn) {
	t.Helper()
	_ = readUntilType(t, conn, "world.join")
	_ = readUntilType(t, conn, "world.snapshot")
}
