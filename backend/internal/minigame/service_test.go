package minigame

import (
	"context"
	"sync"
	"testing"
	"time"
)

func TestMemoryServiceConcurrentJoinDoesNotOverfill(t *testing.T) {
	service := NewMemoryService()
	ctx := context.Background()
	session, err := service.CreateSession(ctx, CreateSessionRequest{
		GameID:       "fishing",
		RoomID:       "world_town_square",
		HostPlayerID: "host",
		MaxPlayers:   2,
	})
	if err != nil {
		t.Fatalf("CreateSession returned error: %v", err)
	}

	var waitGroup sync.WaitGroup
	for index := 0; index < 12; index++ {
		waitGroup.Add(1)
		go func(index int) {
			defer waitGroup.Done()
			_, _ = service.JoinSession(ctx, JoinSessionRequest{
				SessionID: session.ID,
				PlayerID:  "player_" + string(rune('a'+index)),
			})
		}(index)
	}
	waitGroup.Wait()

	sessions := service.ListSessions(ctx, "world_town_square")
	if len(sessions) != 1 {
		t.Fatalf("expected one active/waiting session, got %d", len(sessions))
	}
	if len(sessions[0].Players) > 2 {
		t.Fatalf("session overfilled: %#v", sessions[0])
	}
	if sessions[0].Status != "active" {
		t.Fatalf("expected full session to become active, got %s", sessions[0].Status)
	}
}

func TestMemoryServiceLeaveMigratesHostAndEndsEmptySession(t *testing.T) {
	service := NewMemoryService()
	ctx := context.Background()
	session, err := service.CreateSession(ctx, CreateSessionRequest{
		GameID:       "fishing",
		HostPlayerID: "host",
		MaxPlayers:   3,
	})
	if err != nil {
		t.Fatalf("CreateSession returned error: %v", err)
	}
	session, err = service.JoinSession(ctx, JoinSessionRequest{
		SessionID: session.ID,
		PlayerID:  "guest",
	})
	if err != nil {
		t.Fatalf("JoinSession returned error: %v", err)
	}
	session, err = service.LeaveSession(ctx, LeaveSessionRequest{
		SessionID: session.ID,
		PlayerID:  "host",
	})
	if err != nil {
		t.Fatalf("LeaveSession returned error: %v", err)
	}
	if session.HostPlayerID != "guest" {
		t.Fatalf("expected host migration to guest, got %s", session.HostPlayerID)
	}
	session, err = service.LeaveSession(ctx, LeaveSessionRequest{
		SessionID: session.ID,
		PlayerID:  "guest",
	})
	if err != nil {
		t.Fatalf("LeaveSession returned error: %v", err)
	}
	if session.Status != "ended" {
		t.Fatalf("expected empty session to end, got %s", session.Status)
	}
}

func TestMemoryServiceListSessionsDropsExpiredSession(t *testing.T) {
	service := NewMemoryServiceConcrete()
	ctx := context.Background()
	session, err := service.CreateSession(ctx, CreateSessionRequest{
		GameID:       "fishing",
		HostPlayerID: "host",
		MaxPlayers:   2,
	})
	if err != nil {
		t.Fatalf("CreateSession returned error: %v", err)
	}

	service.mu.Lock()
	session.ExpiresAt = time.Now().Unix() - 1
	service.sessions[session.ID] = session
	service.mu.Unlock()

	if sessions := service.ListSessions(ctx, "world_town_square"); len(sessions) != 0 {
		t.Fatalf("expected expired sessions to be dropped, got %#v", sessions)
	}
	if _, ok := service.GetSession(ctx, session.ID); ok {
		t.Fatal("expected expired session lookup to fail")
	}
}

func TestMemoryServiceSubmitRequiresSupportedCreatorMode(t *testing.T) {
	service := NewMemoryService()
	ctx := context.Background()
	_, err := service.Submit(ctx, SubmitRequest{
		GameID:     "creator_platformer",
		Version:    "1.0.0",
		Author:     "creator",
		ModeID:     "side_scroller_2d",
		Name:       map[string]string{"en": "Run", "ja": "走る", "zh": "奔跑"},
		MinPlayers: 1,
		MaxPlayers: 4,
		Tags:       []string{"action"},
		RuntimeContract: map[string]any{
			"camera":          "side_view",
			"input_profile":   "action_platformer",
			"network_profile": "session_sync",
		},
		EntryScene:  "res://creator/creator_platformer/main.tscn",
		MainScript:  "res://creator/creator_platformer/game.gd",
		AssetBudget: 5242880,
	})
	if err != nil {
		t.Fatalf("supported mode submit returned error: %v", err)
	}
	_, err = service.Submit(ctx, SubmitRequest{
		GameID:     "creator_duel",
		Version:    "1.0.0",
		Author:     "creator",
		ModeID:     "2d_fighting",
		Name:       map[string]string{"en": "Duel", "ja": "決闘", "zh": "对决"},
		MinPlayers: 1,
		MaxPlayers: 4,
		Tags:       []string{"fighting"},
		RuntimeContract: map[string]any{
			"camera":          "side_view",
			"input_profile":   "fighting_action",
			"network_profile": "authoritative_realtime",
		},
		EntryScene:  "res://creator/creator_duel/main.tscn",
		MainScript:  "res://creator/creator_duel/game.gd",
		AssetBudget: 5242880,
	})
	if err != nil {
		t.Fatalf("2d_fighting submit returned error: %v", err)
	}

	_, err = service.Submit(ctx, SubmitRequest{
		GameID:     "creator_unknown",
		Version:    "1.0.0",
		Author:     "creator",
		ModeID:     "unknown_mode",
		Name:       map[string]string{"en": "Bad", "ja": "悪い", "zh": "坏"},
		MinPlayers: 1,
		MaxPlayers: 1,
		RuntimeContract: map[string]any{
			"camera": "contained",
		},
		EntryScene:  "res://creator/creator_unknown/main.tscn",
		MainScript:  "res://creator/creator_unknown/game.gd",
		AssetBudget: 5242880,
	})
	if err == nil {
		t.Fatal("expected unsupported mode submit to fail")
	}
}

func TestMemoryServiceSubmitRejectsModePlayerCapOverflow(t *testing.T) {
	service := NewMemoryService()
	_, err := service.Submit(context.Background(), SubmitRequest{
		GameID:     "creator_too_large",
		Version:    "1.0.0",
		Author:     "creator",
		ModeID:     "tower_defense",
		Name:       map[string]string{"en": "Wave", "ja": "波", "zh": "波次"},
		MinPlayers: 1,
		MaxPlayers: 8,
		RuntimeContract: map[string]any{
			"camera": "lane_grid",
		},
		EntryScene:  "res://creator/creator_too_large/main.tscn",
		MainScript:  "res://creator/creator_too_large/game.gd",
		AssetBudget: 5242880,
	})
	if err == nil {
		t.Fatal("expected player cap overflow to fail")
	}
}
