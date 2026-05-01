package gateway

import (
	"net/http"
	"testing"
)

func TestSocialRelationshipsAndBlockPrivateMessages(t *testing.T) {
	server := NewServer()
	alice := testGuestLogin(t, server, "Social Alice")
	bob := testGuestLogin(t, server, "Social Bob")
	aliceToken := alice["access_token"].(string)
	bobToken := bob["access_token"].(string)
	aliceID := alice["player_id"].(string)
	bobID := bob["player_id"].(string)

	follow := testPostJSON(t, server, "/social/follow", aliceToken, map[string]any{
		"player_id":        aliceID,
		"target_player_id": bobID,
	}, http.StatusOK)
	if follow["following"] != true || follow["target_player_id"] != bobID {
		t.Fatalf("follow did not return relationship state: %#v", follow)
	}
	state := testGetJSON(
		t,
		server,
		"/social/state/"+aliceID+"?player_id="+bobID,
		bobToken,
		http.StatusOK,
	)
	if state["followed_by"] != true {
		t.Fatalf("reverse state did not expose followed_by: %#v", state)
	}
	list := testGetJSON(
		t,
		server,
		"/social/following?player_id="+aliceID+"&limit=10",
		aliceToken,
		http.StatusOK,
	)
	rows := list["relationships"].([]any)
	if len(rows) != 1 || rows[0].(map[string]any)["target_player_id"] != bobID {
		t.Fatalf("following list did not include target: %#v", list)
	}

	block := testPostJSON(t, server, "/social/block", bobToken, map[string]any{
		"player_id":        bobID,
		"target_player_id": aliceID,
	}, http.StatusOK)
	if block["blocked"] != true {
		t.Fatalf("block did not set blocked state: %#v", block)
	}
	blocked := testPostJSON(t, server, "/private-messages", aliceToken, map[string]any{
		"sender_id":    aliceID,
		"recipient_id": bobID,
		"body":         "blocked hello",
	}, http.StatusForbidden)
	if blocked["error"] != "private_message_blocked" {
		t.Fatalf("expected private_message_blocked, got %#v", blocked)
	}

	testPostJSON(t, server, "/social/unblock", bobToken, map[string]any{
		"player_id":        bobID,
		"target_player_id": aliceID,
	}, http.StatusOK)
	message := testPostJSON(t, server, "/private-messages", aliceToken, map[string]any{
		"sender_id":    aliceID,
		"recipient_id": bobID,
		"body":         "unblocked hello",
	}, http.StatusCreated)
	if message["body"] != "unblocked hello" {
		t.Fatalf("private message did not recover after unblock: %#v", message)
	}
}

func TestSocialSelfRelationshipIsRejected(t *testing.T) {
	server := NewServer()
	alice := testGuestLogin(t, server, "Self Social")
	playerID := alice["player_id"].(string)
	response := testPostJSON(t, server, "/social/follow", alice["access_token"].(string), map[string]any{
		"player_id":        playerID,
		"target_player_id": playerID,
	}, http.StatusConflict)
	if response["error"] != "self_relationship_forbidden" {
		t.Fatalf("expected self_relationship_forbidden, got %#v", response)
	}
}
