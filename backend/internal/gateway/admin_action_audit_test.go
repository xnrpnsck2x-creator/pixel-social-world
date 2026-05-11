package gateway

import (
	"fmt"
	"net/http"
	"strings"
	"testing"

	"pixel-social-world/backend/internal/utility"
)

func TestAdminActionAuditRecordsHighRiskActions(t *testing.T) {
	deps := DefaultMemoryDependencies()
	deps.AdminToken = "viewer:view-token,moderator:mod-token,owner:owner-token"
	server := NewServerWithDependencies(deps)
	session := testGuestLogin(t, server, "Audit Owner")
	playerID := session["player_id"].(string)

	testGetJSON(t, server, "/admin/action-audit", "", http.StatusForbidden)

	testPostJSON(t, server, "/admin/chat-moderation/actions", "mod-token", map[string]any{
		"target_player_id": playerID,
		"target_name":      "Audit Owner",
		"action":           "mute",
		"scope":            "room",
		"room_id":          "world_town_square",
		"duration_seconds": 600,
		"reason":           "audit fixture",
	}, http.StatusAccepted)

	testPostJSON(t, server, "/admin/players/maps/discovered", "owner-token", map[string]any{
		"player_id": playerID,
		"map_id":    "social_trade_market_v1",
		"confirm":   true,
		"note":      "grant for audit",
	}, http.StatusOK)

	panels := utility.DefaultPanels()
	panels.Notice.Notices = append(panels.Notice.Notices, utility.Message{
		ID:         "audit_notice",
		SubjectKey: "world.notice.audit.title",
		BodyKey:    "world.notice.audit.body",
		IconID:     "notice",
		ActionID:   "trade",
		ActionKey:  "world.panel.action.trade",
	})
	testPutUtilityPanels(t, server, panels, "owner-token", http.StatusOK)

	audit := testGetJSON(t, server, "/admin/action-audit?limit=10", "view-token", http.StatusOK)
	if int(audit["count"].(float64)) != 3 {
		t.Fatalf("expected three audit events, got %#v", audit)
	}
	assertAuditContains(t, audit, "chat_moderation.apply", "moderator", playerID)
	assertAuditContains(t, audit, "player_map.discover", "owner", playerID+":social_trade_market_v1")
	assertAuditContains(t, audit, "utility_panels.update", "owner", "global")
	if strings.Contains(fmt.Sprint(audit), "owner-token") || strings.Contains(fmt.Sprint(audit), "mod-token") {
		t.Fatalf("audit leaked raw admin token: %#v", audit)
	}

	mapAudit := testGetJSON(t, server, "/admin/action-audit?action=player_map.discover", "view-token", http.StatusOK)
	items := mapAudit["items"].([]any)
	if len(items) != 1 {
		t.Fatalf("expected one map audit event, got %#v", mapAudit)
	}
	event := items[0].(map[string]any)
	if event["confirmed"] != true || event["note"] != "grant for audit" {
		t.Fatalf("map audit event lost safety fields: %#v", event)
	}

	debug := testGetJSON(t, server, "/debug/ops", "view-token", http.StatusOK)
	stats := debug["admin_action_audit"].(map[string]any)
	if int(stats["count"].(float64)) != 3 || int(stats["max_events"].(float64)) != adminActionAuditMaxEvents {
		t.Fatalf("debug ops did not expose audit stats: %#v", stats)
	}
}

func TestAdminActionAuditRecordsReviewAndCreatorSettlement(t *testing.T) {
	deps := DefaultMemoryDependencies()
	deps.AdminToken = "viewer:view-token,reviewer:review-token,owner:owner-token"
	server := NewServerWithDependencies(deps)
	creator := testGuestLogin(t, server, "Audit Creator")
	player := testGuestLogin(t, server, "Audit Player")
	creatorID := creator["player_id"].(string)
	playerID := player["player_id"].(string)

	payload := creatorPackagePayload(creatorID, "creator_role_guard", safePackageScript())
	testPostJSON(t, server, "/creator-submissions/package", creator["access_token"].(string), payload, http.StatusAccepted)
	postReviewRoleJSON(t, server, "review-token", `{"action":"approve"}`, http.StatusAccepted)
	postReviewRoleJSON(t, server, "owner-token", `{"action":"publish"}`, http.StatusAccepted)
	testPostJSON(t, server, "/economy/creator-share", "owner-token", map[string]any{
		"player_id":     playerID,
		"creator_id":    creatorID,
		"game_id":       "creator_role_guard",
		"source_id":     "audit_session_001",
		"player_amount": 10,
	}, http.StatusOK)

	audit := testGetJSON(t, server, "/admin/action-audit?limit=10", "view-token", http.StatusOK)
	assertAuditContains(t, audit, "minigame.review", "reviewer", "creator_role_guard")
	assertAuditContains(t, audit, "minigame.review", "owner", "creator_role_guard")
	assertAuditContains(t, audit, "economy.creator_share.grant", "owner", creatorID+":creator_role_guard")
}

func assertAuditContains(t *testing.T, response map[string]any, action string, role string, targetID string) {
	t.Helper()
	items := response["items"].([]any)
	for _, raw := range items {
		event := raw.(map[string]any)
		if event["action"] == action && event["role"] == role && event["target_id"] == targetID {
			if !strings.HasPrefix(event["actor_id"].(string), "admin:") {
				t.Fatalf("audit actor was not anonymized: %#v", event)
			}
			return
		}
	}
	t.Fatalf("missing audit action %s/%s/%s in %#v", action, role, targetID, response)
}
