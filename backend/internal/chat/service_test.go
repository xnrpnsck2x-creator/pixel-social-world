package chat

import (
	"context"
	"strings"
	"testing"
)

func TestMemoryServicePrivateHistory(t *testing.T) {
	service := NewMemoryService()
	ctx := context.Background()

	first, err := service.Send(ctx, SendRequest{
		RoomID:     "dm:player_1:player_2",
		ChannelID:  "private",
		SenderID:   "player_1",
		SenderName: "Ari",
		Body:       "hello",
		Action: Action{
			"type":       "join_minigame",
			"game_id":    "fishing",
			"session_id": "session_1",
		},
	})
	if err != nil {
		t.Fatalf("Send returned error: %v", err)
	}
	if first.ID == "" || first.CreatedAt == 0 {
		t.Fatalf("message metadata was not populated: %#v", first)
	}
	if first.Action["type"] != "join_minigame" || first.Action["session_id"] != "session_1" {
		t.Fatalf("message action was not preserved: %#v", first.Action)
	}

	_, err = service.Send(ctx, SendRequest{
		RoomID:     "dm:player_1:player_2",
		ChannelID:  "private",
		SenderID:   "player_2",
		SenderName: "Bea",
		Body:       "hi",
	})
	if err != nil {
		t.Fatalf("second Send returned error: %v", err)
	}

	history, err := service.History(ctx, HistoryRequest{
		RoomID:    "dm:player_1:player_2",
		ChannelID: "private",
		Limit:     1,
	})
	if err != nil {
		t.Fatalf("History returned error: %v", err)
	}
	if len(history) != 1 || history[0].SenderID != "player_2" {
		t.Fatalf("History did not return most recent message: %#v", history)
	}

	fullHistory, err := service.History(ctx, HistoryRequest{
		RoomID:    "dm:player_1:player_2",
		ChannelID: "private",
		Limit:     2,
	})
	if err != nil {
		t.Fatalf("full History returned error: %v", err)
	}
	if len(fullHistory) != 2 || fullHistory[0].Action["game_id"] != "fishing" {
		t.Fatalf("History did not preserve message action: %#v", fullHistory)
	}
}

func TestMemoryServiceRoomHistoryIsEphemeralButReportable(t *testing.T) {
	service := NewMemoryService()
	ctx := context.Background()
	message, err := service.Send(ctx, SendRequest{
		RoomID:     "world_town_square",
		ChannelID:  "global",
		SenderID:   "player_1",
		SenderName: "Ari",
		Body:       "room invite",
		Action: Action{
			"type":       "join_minigame",
			"game_id":    "fishing",
			"session_id": "session_1",
		},
	})
	if err != nil {
		t.Fatalf("Send returned error: %v", err)
	}
	history, err := service.History(ctx, HistoryRequest{
		RoomID:    "world_town_square",
		ChannelID: "global",
		Limit:     10,
	})
	if err != nil {
		t.Fatalf("History returned error: %v", err)
	}
	if len(history) != 0 {
		t.Fatalf("room chat history should be ephemeral, got %#v", history)
	}
	report, err := service.Report(ctx, ReportRequest{
		MessageID:  message.ID,
		RoomID:     message.RoomID,
		ChannelID:  message.ChannelID,
		ReporterID: "player_2",
		Reason:     "spam",
	})
	if err != nil {
		t.Fatalf("ephemeral room message should remain reportable while online: %v", err)
	}
	if report.MessageBody != "room invite" {
		t.Fatalf("report did not snapshot ephemeral room message: %#v", report)
	}
}

func TestMemoryServiceDropsUnsupportedAction(t *testing.T) {
	service := NewMemoryService()
	message, err := service.Send(context.Background(), SendRequest{
		RoomID:     "world_town_square",
		ChannelID:  "global",
		SenderID:   "player_1",
		SenderName: "Ari",
		Body:       "hello",
		Action: Action{
			"type":   "unknown",
			"secret": "ignored",
		},
	})
	if err != nil {
		t.Fatalf("Send returned error: %v", err)
	}
	if len(message.Action) != 0 {
		t.Fatalf("unsupported action should be dropped: %#v", message.Action)
	}
}

func TestMemoryServiceRejectsLongBody(t *testing.T) {
	service := NewMemoryService()
	_, err := service.Send(context.Background(), SendRequest{
		Body: strings.Repeat("x", maxBodyLength+1),
	})
	if err == nil {
		t.Fatal("expected long body to be rejected")
	}
}

func TestMemoryServiceRateLimitsBurst(t *testing.T) {
	service := NewMemoryService()
	ctx := context.Background()
	for index := 0; index < rateLimitMaxMessages; index++ {
		_, err := service.Send(ctx, SendRequest{
			RoomID:     "world_town_square",
			ChannelID:  "global",
			SenderID:   "player_spam",
			SenderName: "Spam",
			Body:       "burst",
		})
		if err != nil {
			t.Fatalf("Send %d returned error: %v", index, err)
		}
	}
	_, err := service.Send(ctx, SendRequest{
		RoomID:     "world_town_square",
		ChannelID:  "global",
		SenderID:   "player_spam",
		SenderName: "Spam",
		Body:       "burst again",
	})
	if err == nil || err.Error() != "rate_limited" {
		t.Fatalf("expected rate_limited, got %v", err)
	}
	stats := service.Stats(ctx)
	if stats.RejectedRateLimited != 1 {
		t.Fatalf("rate limit stats not updated: %#v", stats)
	}
}

func TestMemoryServiceReportsExistingMessage(t *testing.T) {
	service := NewMemoryService()
	ctx := context.Background()
	message, err := service.Send(ctx, SendRequest{
		RoomID:     "world_town_square",
		ChannelID:  "global",
		SenderID:   "player_1",
		SenderName: "Ari",
		Body:       "please review this",
	})
	if err != nil {
		t.Fatalf("Send returned error: %v", err)
	}

	report, err := service.Report(ctx, ReportRequest{
		MessageID:  message.ID,
		RoomID:     message.RoomID,
		ChannelID:  message.ChannelID,
		ReporterID: "player_2",
		Reason:     "spam",
	})
	if err != nil {
		t.Fatalf("Report returned error: %v", err)
	}
	if report.ID == "" || report.CreatedAt == 0 || report.MessageID != message.ID {
		t.Fatalf("report metadata was not populated: %#v", report)
	}
	stats := service.Stats(ctx)
	if stats.TotalReports != 1 || stats.ReportsByRoom["world_town_square"] != 1 {
		t.Fatalf("report stats were not updated: %#v", stats)
	}
	snapshot, err := service.Reports(ctx, ReportListRequest{Status: ReportStatusOpen})
	if err != nil {
		t.Fatalf("Reports returned error: %v", err)
	}
	if len(snapshot.Items) != 1 || snapshot.Items[0].MessageBody != "please review this" {
		t.Fatalf("report dashboard did not include message snapshot: %#v", snapshot)
	}
	reviewed, err := service.ReviewReport(ctx, ReportReviewRequest{
		ReportID:   report.ID,
		Status:     ReportStatusReviewed,
		ReviewerID: "admin:test",
		ReviewNote: "handled",
	})
	if err != nil {
		t.Fatalf("ReviewReport returned error: %v", err)
	}
	if reviewed.Status != ReportStatusReviewed || reviewed.ReviewerID != "admin:test" || reviewed.ReviewedAt == 0 {
		t.Fatalf("report review metadata not updated: %#v", reviewed)
	}
}

func TestMemoryServiceModerationMuteAndRestore(t *testing.T) {
	service := NewMemoryService()
	ctx := context.Background()
	action, err := service.ApplyModeration(ctx, ModerationActionRequest{
		TargetPlayerID:  "player_muted",
		TargetName:      "Muted",
		Action:          ModerationActionMute,
		Scope:           ModerationScopeRoom,
		RoomID:          "world_town_square",
		DurationSeconds: 3600,
		Reason:          "spam",
		ModeratorID:     "admin:test",
	})
	if err != nil {
		t.Fatalf("ApplyModeration returned error: %v", err)
	}
	if action.ExpiresAt == 0 || action.TargetPlayerID != "player_muted" {
		t.Fatalf("mute action metadata not populated: %#v", action)
	}
	_, err = service.Send(ctx, SendRequest{
		RoomID:     "world_town_square",
		ChannelID:  "global",
		SenderID:   "player_muted",
		SenderName: "Muted",
		Body:       "still talking",
	})
	if err == nil || err.Error() != "chat_muted" {
		t.Fatalf("expected muted sender to be blocked, got %v", err)
	}
	_, err = service.ApplyModeration(ctx, ModerationActionRequest{
		TargetPlayerID: "player_muted",
		Action:         ModerationActionRestore,
		Scope:          ModerationScopeRoom,
		RoomID:         "world_town_square",
		Reason:         "appeal accepted",
		ModeratorID:    "admin:test",
	})
	if err != nil {
		t.Fatalf("restore returned error: %v", err)
	}
	_, err = service.Send(ctx, SendRequest{
		RoomID:     "world_town_square",
		ChannelID:  "global",
		SenderID:   "player_muted",
		SenderName: "Muted",
		Body:       "thanks",
	})
	if err != nil {
		t.Fatalf("restored sender should be allowed, got %v", err)
	}
	stats := service.Stats(ctx)
	if stats.ModerationActions != 2 || stats.ActiveModeration != 0 {
		t.Fatalf("moderation stats not updated: %#v", stats)
	}
}

func TestMemoryServiceRejectsMissingReportTarget(t *testing.T) {
	service := NewMemoryService()
	_, err := service.Report(context.Background(), ReportRequest{
		MessageID:  "missing",
		ReporterID: "player_2",
	})
	if err == nil {
		t.Fatal("expected missing message report to be rejected")
	}
}
