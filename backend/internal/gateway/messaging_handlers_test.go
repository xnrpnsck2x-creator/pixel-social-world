package gateway

import (
	"net/http"
	"testing"
)

func TestMessagingPrivateAndMailboxAreDurableAndScoped(t *testing.T) {
	server := NewServer()
	alice := testGuestLogin(t, server, "Alice Messaging")
	bob := testGuestLogin(t, server, "Bob Messaging")
	aliceToken := alice["access_token"].(string)
	bobToken := bob["access_token"].(string)
	aliceID := alice["player_id"].(string)
	bobID := bob["player_id"].(string)

	private := testPostJSON(t, server, "/private-messages", aliceToken, map[string]any{
		"sender_id":    aliceID,
		"recipient_id": bobID,
		"body":         "persistent private hello",
	}, http.StatusCreated)
	if private["conversation_id"] == "" || private["body"] != "persistent private hello" {
		t.Fatalf("private message response was incomplete: %#v", private)
	}

	conversation := testGetJSON(
		t,
		server,
		"/private-messages/"+aliceID+"?player_id="+bobID+"&limit=10",
		bobToken,
		http.StatusOK,
	)
	messages := conversation["messages"].([]any)
	if len(messages) != 1 {
		t.Fatalf("expected one private message, got %#v", conversation)
	}
	first := messages[0].(map[string]any)
	if first["sender_id"] != aliceID || first["recipient_id"] != bobID {
		t.Fatalf("private message was not sender/recipient scoped: %#v", first)
	}
	conversations := testGetJSON(
		t,
		server,
		"/private-messages?player_id="+bobID+"&limit=10",
		bobToken,
		http.StatusOK,
	)
	conversationRows := conversations["conversations"].([]any)
	if len(conversationRows) != 1 {
		t.Fatalf("expected one private conversation summary, got %#v", conversations)
	}
	summary := conversationRows[0].(map[string]any)
	if summary["peer_id"] != aliceID || int(summary["unread_count"].(float64)) != 1 {
		t.Fatalf("private conversation summary did not expose unread state: %#v", summary)
	}
	readPrivate := testPostJSON(t, server, "/private-messages/read/"+aliceID, bobToken, map[string]any{
		"player_id": bobID,
	}, http.StatusOK)
	if int(readPrivate["unread_count"].(float64)) != 0 {
		t.Fatalf("private read did not clear unread count: %#v", readPrivate)
	}
	report := testPostJSON(t, server, "/private-messages/report", bobToken, map[string]any{
		"message_id":  private["id"],
		"reporter_id": bobID,
		"reason":      "player_report",
	}, http.StatusAccepted)
	if report["message_id"] != private["id"] || report["message_body"] != private["body"] {
		t.Fatalf("private report did not snapshot message: %#v", report)
	}

	mail := testPostJSON(t, server, "/mailbox/send", aliceToken, map[string]any{
		"sender_id":    aliceID,
		"recipient_id": bobID,
		"subject":      "Welcome",
		"body":         "persistent mailbox hello",
	}, http.StatusCreated)
	mailID := mail["id"].(string)
	if mail["recipient_id"] != bobID || mailID == "" {
		t.Fatalf("mail response was incomplete: %#v", mail)
	}

	inbox := testGetJSON(t, server, "/mailbox/inbox?player_id="+bobID+"&limit=10", bobToken, http.StatusOK)
	inboxMessages := inbox["messages"].([]any)
	if len(inboxMessages) != 1 {
		t.Fatalf("expected one mailbox message, got %#v", inbox)
	}

	testPostJSON(t, server, "/mailbox/"+mailID+"/read", aliceToken, map[string]any{
		"player_id": aliceID,
	}, http.StatusForbidden)
	read := testPostJSON(t, server, "/mailbox/"+mailID+"/read", bobToken, map[string]any{
		"player_id": bobID,
	}, http.StatusOK)
	if int(read["read_at"].(float64)) <= 0 {
		t.Fatalf("mail read did not set read_at: %#v", read)
	}
}

func TestPrivateMessagesAreRateLimited(t *testing.T) {
	server := NewServer()
	alice := testGuestLogin(t, server, "Private Rate Alice")
	bob := testGuestLogin(t, server, "Private Rate Bob")
	aliceToken := alice["access_token"].(string)
	aliceID := alice["player_id"].(string)
	bobID := bob["player_id"].(string)

	for index := 0; index < 6; index++ {
		testPostJSON(t, server, "/private-messages", aliceToken, map[string]any{
			"sender_id":    aliceID,
			"recipient_id": bobID,
			"body":         "burst",
		}, http.StatusCreated)
	}
	blocked := testPostJSON(t, server, "/private-messages", aliceToken, map[string]any{
		"sender_id":    aliceID,
		"recipient_id": bobID,
		"body":         "blocked",
	}, http.StatusTooManyRequests)
	if blocked["error"] != "private_rate_limited" {
		t.Fatalf("expected private_rate_limited, got %#v", blocked)
	}
}

func TestMessagingPrivateAndMailboxPagination(t *testing.T) {
	server := NewServer()
	alice := testGuestLogin(t, server, "Page Alice")
	bob := testGuestLogin(t, server, "Page Bob")
	aliceToken := alice["access_token"].(string)
	bobToken := bob["access_token"].(string)
	aliceID := alice["player_id"].(string)
	bobID := bob["player_id"].(string)

	for _, body := range []string{"pm-1", "pm-2", "pm-3"} {
		testPostJSON(t, server, "/private-messages", aliceToken, map[string]any{
			"sender_id":    aliceID,
			"recipient_id": bobID,
			"body":         body,
		}, http.StatusCreated)
	}
	firstPage := testGetJSON(t, server, "/private-messages/"+aliceID+"?player_id="+bobID+"&limit=2", bobToken, http.StatusOK)
	firstMessages := firstPage["messages"].([]any)
	if len(firstMessages) != 2 || firstMessages[0].(map[string]any)["body"] != "pm-2" || firstMessages[1].(map[string]any)["body"] != "pm-3" {
		t.Fatalf("unexpected first private page: %#v", firstPage)
	}
	secondPage := testGetJSON(t, server, "/private-messages/"+aliceID+"?player_id="+bobID+"&limit=2&offset=2", bobToken, http.StatusOK)
	secondMessages := secondPage["messages"].([]any)
	if len(secondMessages) != 1 || secondMessages[0].(map[string]any)["body"] != "pm-1" {
		t.Fatalf("unexpected second private page: %#v", secondPage)
	}
	pagination := secondPage["pagination"].(map[string]any)
	if int(pagination["offset"].(float64)) != 2 || int(pagination["count"].(float64)) != 1 {
		t.Fatalf("private pagination metadata missing: %#v", pagination)
	}

	for _, subject := range []string{"mail-1", "mail-2", "mail-3"} {
		testPostJSON(t, server, "/mailbox/send", aliceToken, map[string]any{
			"sender_id":    aliceID,
			"recipient_id": bobID,
			"subject":      subject,
			"body":         "mail body",
		}, http.StatusCreated)
	}
	mailPage := testGetJSON(t, server, "/mailbox/inbox?player_id="+bobID+"&limit=2", bobToken, http.StatusOK)
	mailMessages := mailPage["messages"].([]any)
	if len(mailMessages) != 2 || mailMessages[0].(map[string]any)["subject"] != "mail-3" || mailMessages[1].(map[string]any)["subject"] != "mail-2" {
		t.Fatalf("unexpected first mail page: %#v", mailPage)
	}
	mailTail := testGetJSON(t, server, "/mailbox/inbox?player_id="+bobID+"&limit=2&offset=2", bobToken, http.StatusOK)
	tailMessages := mailTail["messages"].([]any)
	if len(tailMessages) != 1 || tailMessages[0].(map[string]any)["subject"] != "mail-1" {
		t.Fatalf("unexpected second mail page: %#v", mailTail)
	}
}
