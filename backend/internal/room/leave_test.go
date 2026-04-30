package room

import "testing"

func TestHubBroadcastsLeaveOnDisconnect(t *testing.T) {
	hub := NewHub()
	server := newHubTestServer(t, hub)
	defer server.Close()

	roomA1 := dialTestSocket(t, server.URL)
	roomA2 := dialTestSocket(t, server.URL)
	defer roomA2.Close()

	writeEnvelope(t, roomA1, joinEnvelope("player_a1", "room_a"))
	writeEnvelope(t, roomA2, joinEnvelope("player_a2", "room_a"))
	waitForRoomCounts(t, hub, map[string]int{"room_a": 2})

	_ = roomA1.Close()
	leave := readUntilType(t, roomA2, "world.leave")
	payload := leave.Payload.(map[string]interface{})
	if payload["player_id"] != "player_a1" || payload["room_id"] != "room_a" {
		t.Fatalf("unexpected leave payload: %#v", payload)
	}
}

func TestHubBroadcastsLeaveOnRoomSwitch(t *testing.T) {
	hub := NewHub()
	server := newHubTestServer(t, hub)
	defer server.Close()

	roomA1 := dialTestSocket(t, server.URL)
	defer roomA1.Close()
	roomA2 := dialTestSocket(t, server.URL)
	defer roomA2.Close()

	writeEnvelope(t, roomA1, joinEnvelope("player_a1", "room_a"))
	writeEnvelope(t, roomA2, joinEnvelope("player_a2", "room_a"))
	waitForRoomCounts(t, hub, map[string]int{"room_a": 2})

	writeEnvelope(t, roomA1, joinEnvelope("player_a1", "room_b"))
	leave := readUntilType(t, roomA2, "world.leave")
	payload := leave.Payload.(map[string]interface{})
	if payload["player_id"] != "player_a1" || payload["room_id"] != "room_a" {
		t.Fatalf("unexpected room switch leave payload: %#v", payload)
	}
}
