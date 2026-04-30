package room

import (
	"context"
	"testing"
)

func TestHubDeniesUnauthorizedRoomJoin(t *testing.T) {
	hub := NewHub(WithRoomAuthorizer(testRoomAuthorizer{allowed: map[string]bool{
		"player_a:world_town_square": true,
	}}))
	server := newHubTestServer(t, hub)
	defer server.Close()

	conn := dialTestSocket(t, server.URL)
	defer conn.Close()

	writeEnvelope(t, conn, joinEnvelope("player_a", "home:other_player"))
	response := readUntilType(t, conn, "room.denied")
	payload := response.Payload.(map[string]interface{})
	if payload["room_id"] != "home:other_player" || payload["error"] != "room_access_denied" {
		t.Fatalf("unexpected room denied payload: %#v", payload)
	}
}

type testRoomAuthorizer struct {
	allowed map[string]bool
}

func (a testRoomAuthorizer) CanJoinRoom(_ context.Context, playerID string, roomID string) bool {
	return a.allowed[playerID+":"+roomID]
}
