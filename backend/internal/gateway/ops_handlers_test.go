package gateway

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"

	"pixel-social-world/backend/internal/chat"
	"pixel-social-world/backend/internal/trade"
)

func TestHealthReadyAndRequestID(t *testing.T) {
	deps := DefaultMemoryDependencies()
	deps.AdminToken = "ops-admin"
	server := NewServerWithDependencies(deps)

	request := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	request.Header.Set("X-Request-ID", "ops-smoke-1")
	recorder := httptest.NewRecorder()
	server.router.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusOK || recorder.Header().Get("X-Request-ID") != "ops-smoke-1" {
		t.Fatalf("health did not preserve request id: %d %#v", recorder.Code, recorder.Header())
	}
	health := decodeJSONBody(t, recorder.Body.Bytes())
	if health["request_id"] != "ops-smoke-1" || health["server_time"] == nil {
		t.Fatalf("health response missing ops metadata: %#v", health)
	}

	readyRequest := httptest.NewRequest(http.MethodGet, "/readyz", nil)
	readyRecorder := httptest.NewRecorder()
	server.router.ServeHTTP(readyRecorder, readyRequest)
	if readyRecorder.Code != http.StatusOK || readyRecorder.Header().Get("X-Request-ID") == "" {
		t.Fatalf("ready did not emit request id: %d %#v", readyRecorder.Code, readyRecorder.Header())
	}
	ready := decodeJSONBody(t, readyRecorder.Body.Bytes())
	services := ready["services"].(map[string]any)
	if services["chat"] != true || services["realtime"] != true || services["fishing_rewards"] != true {
		t.Fatalf("ready response missing service probes: %#v", ready)
	}
	opsRequest := httptest.NewRequest(http.MethodGet, "/debug/ops", nil)
	opsRequest.Header.Set("X-Admin-Token", "ops-admin")
	opsRecorder := httptest.NewRecorder()
	server.router.ServeHTTP(opsRecorder, opsRequest)
	if opsRecorder.Code != http.StatusOK {
		t.Fatalf("debug ops failed: %d %s", opsRecorder.Code, opsRecorder.Body.String())
	}
	ops := decodeJSONBody(t, opsRecorder.Body.Bytes())
	retention := ops["retention_policy"].(map[string]any)
	if int(retention["room_chat_history_days"].(float64)) != 0 ||
		int(retention["private_message_days"].(float64)) <= 0 {
		t.Fatalf("debug ops missing retention policy: %#v", retention)
	}
	cleanupPlan := ops["retention_cleanup_plan"].([]any)
	if len(cleanupPlan) == 0 || cleanupPlan[0].(map[string]any)["name"] != "room_chat_history" {
		t.Fatalf("debug ops missing retention cleanup plan: %#v", cleanupPlan)
	}
}

func TestStructuredAccessLogIncludesRequestID(t *testing.T) {
	var logs bytes.Buffer
	originalWriter := gin.DefaultWriter
	gin.DefaultWriter = &logs
	t.Cleanup(func() { gin.DefaultWriter = originalWriter })
	server := NewServerWithDependencies(DefaultMemoryDependencies())
	request := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	request.Header.Set("X-Request-ID", "log-smoke-1")
	recorder := httptest.NewRecorder()
	server.router.ServeHTTP(recorder, request)
	var line map[string]any
	logLine := lastJSONLine(logs.Bytes())
	if err := json.Unmarshal(logLine, &line); err != nil {
		t.Fatalf("decode access log: %v\n%s", err, logs.String())
	}
	if line["event"] != "http_request" || line["request_id"] != "log-smoke-1" || line["path"] != "/healthz" {
		t.Fatalf("structured access log missing request fields: %#v", line)
	}
}

func TestDebugOpsAlertsEndpointForwardsLogAndMetrics(t *testing.T) {
	var logs bytes.Buffer
	originalWriter := gin.DefaultWriter
	gin.DefaultWriter = &logs
	t.Cleanup(func() { gin.DefaultWriter = originalWriter })

	deps := DefaultMemoryDependencies()
	deps.AdminToken = "viewer:view-token"
	server := NewServerWithDependencies(deps)
	for index := 0; index < 3; index++ {
		server.recordTradeRiskError(tradeRiskOperationBuy, trade.ErrListingInactive)
	}

	request := httptest.NewRequest(http.MethodGet, "/debug/ops/alerts", nil)
	request.Header.Set("X-Admin-Token", "view-token")
	request.Header.Set("X-Request-ID", "alerts-forward-1")
	recorder := httptest.NewRecorder()
	server.router.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusOK {
		t.Fatalf("debug ops alerts failed: %d %s", recorder.Code, recorder.Body.String())
	}
	body := decodeJSONBody(t, recorder.Body.Bytes())
	alerts := body["alerts"].(map[string]any)
	if body["request_id"] != "alerts-forward-1" ||
		alerts["highest_severity"] != "warning" ||
		int(alerts["count"].(float64)) != 1 {
		t.Fatalf("alerts endpoint did not return forwarding snapshot: %#v", body)
	}

	alertLine := findJSONLineByEvent(t, logs.Bytes(), "liveops_alert_snapshot")
	if alertLine["request_id"] != "alerts-forward-1" ||
		alertLine["level"] != "warn" ||
		alertLine["highest_severity"] != "warning" {
		t.Fatalf("alert forwarding log missing expected fields: %#v\n%s", alertLine, logs.String())
	}

	metricsRequest := httptest.NewRequest(http.MethodGet, "/debug/ops/alerts?format=prometheus", nil)
	metricsRequest.Header.Set("X-Admin-Token", "view-token")
	metricsRecorder := httptest.NewRecorder()
	server.router.ServeHTTP(metricsRecorder, metricsRequest)
	metrics := metricsRecorder.Body.String()
	if metricsRecorder.Code != http.StatusOK ||
		!strings.Contains(metrics, "psw_liveops_alerts_active 1") ||
		!strings.Contains(metrics, "psw_liveops_trade_buy_inactive_total 3") ||
		!strings.Contains(metrics, `psw_liveops_alert_item{`) {
		t.Fatalf("prometheus alert metrics missing expected values: %d\n%s", metricsRecorder.Code, metrics)
	}
}

func TestDebugOpsExposesLiveOpsAlerts(t *testing.T) {
	deps := DefaultMemoryDependencies()
	deps.AdminToken = "viewer:view-token,owner:owner-token"
	server := NewServerWithDependencies(deps)
	session := testGuestLogin(t, server, "Alert Target")
	playerID := session["player_id"].(string)

	for index := 0; index < 21; index++ {
		message, err := deps.ChatService.Send(context.Background(), chat.SendRequest{
			RoomID:     "world_town_square",
			ChannelID:  "global",
			SenderID:   fmt.Sprintf("sender_%02d", index),
			SenderName: "Alert Sender",
			Body:       "reported for alert smoke",
		})
		if err != nil {
			t.Fatalf("seed chat message %d: %v", index, err)
		}
		_, err = deps.ChatService.Report(context.Background(), chat.ReportRequest{
			MessageID:  message.ID,
			RoomID:     message.RoomID,
			ChannelID:  message.ChannelID,
			ReporterID: fmt.Sprintf("reporter_%02d", index),
			Reason:     "spam",
		})
		if err != nil {
			t.Fatalf("seed chat report %d: %v", index, err)
		}
	}
	testPostJSON(t, server, "/admin/players/maps/discovered", "owner-token", map[string]any{
		"player_id": playerID,
		"map_id":    "social_trade_market_v1",
		"confirm":   true,
	}, http.StatusOK)

	ops := testGetJSON(t, server, "/debug/ops", "view-token", http.StatusOK)
	alerts := ops["alerts"].(map[string]any)
	if alerts["highest_severity"] != "critical" ||
		int(alerts["open_reports"].(float64)) != 21 ||
		int(alerts["admin_missing_notes"].(float64)) != 1 {
		t.Fatalf("debug ops alerts did not summarize risk state: %#v", alerts)
	}
	assertAlertContains(t, alerts, "open_chat_reports", "warning")
	assertAlertContains(t, alerts, "admin_missing_notes", "critical")
}

func TestDebugOpsExposesTradeRiskAlerts(t *testing.T) {
	deps := DefaultMemoryDependencies()
	deps.AdminToken = "viewer:view-token"
	server := NewServerWithDependencies(deps)
	buyer := testGuestLogin(t, server, "Trade Risk Buyer")
	buyerID := buyer["player_id"].(string)
	buyerToken := buyer["access_token"].(string)

	for index := 0; index < 5; index++ {
		seller := testGuestLogin(t, server, fmt.Sprintf("Trade Cancel Seller %02d", index))
		sellerID := seller["player_id"].(string)
		sellerToken := seller["access_token"].(string)
		created := testPostJSON(t, server, "/trade/listings", sellerToken, map[string]any{
			"seller_id": sellerID,
			"item_id":   "simple_chair",
			"price":     7,
		}, http.StatusCreated)
		listingID := created["listing"].(map[string]any)["id"].(string)
		testPostJSON(t, server, "/trade/listings/"+listingID+"/cancel", sellerToken, map[string]any{
			"seller_id": sellerID,
		}, http.StatusOK)
	}
	for index := 0; index < 2; index++ {
		seller := testGuestLogin(t, server, fmt.Sprintf("Trade High Seller %02d", index))
		sellerID := seller["player_id"].(string)
		sellerToken := seller["access_token"].(string)
		testPostJSON(t, server, "/trade/listings", sellerToken, map[string]any{
			"seller_id": sellerID,
			"item_id":   "arcade_cabinet",
			"price":     9000,
		}, http.StatusCreated)
	}
	seller := testGuestLogin(t, server, "Trade Race Seller")
	sellerID := seller["player_id"].(string)
	sellerToken := seller["access_token"].(string)
	created := testPostJSON(t, server, "/trade/listings", sellerToken, map[string]any{
		"seller_id": sellerID,
		"item_id":   "potted_plant",
		"price":     7,
	}, http.StatusCreated)
	listingID := created["listing"].(map[string]any)["id"].(string)
	testPostJSON(t, server, "/trade/listings/"+listingID+"/buy", buyerToken, map[string]any{
		"buyer_id": buyerID,
	}, http.StatusOK)
	for index := 0; index < 3; index++ {
		testPostJSON(t, server, "/trade/listings/"+listingID+"/buy", buyerToken, map[string]any{
			"buyer_id": buyerID,
		}, http.StatusConflict)
	}
	server.recordTradeRiskError(tradeRiskOperationBuy, errors.New("escrow_commit_failed"))

	ops := testGetJSON(t, server, "/debug/ops", "view-token", http.StatusOK)
	alerts := ops["alerts"].(map[string]any)
	tradeState := alerts["trade"].(map[string]any)
	counters := tradeState["counters"].(map[string]any)
	events := tradeState["events"].(map[string]any)
	if alerts["highest_severity"] != "critical" ||
		int(counters["buy_inactive"].(float64)) != 3 ||
		int(counters["settlement_failures"].(float64)) != 1 ||
		int(events["high_price_active_listings"].(float64)) != 2 ||
		int(events["cancel_rate"].(float64)) < 70 {
		t.Fatalf("debug ops trade alerts did not summarize trade risk: %#v", alerts)
	}
	assertAlertContains(t, alerts, "listing_race_or_inactive", "warning")
	assertAlertContains(t, alerts, "cancel_rate", "critical")
	assertAlertContains(t, alerts, "high_price_active_listings", "warning")
	assertAlertContains(t, alerts, "settlement_failures", "warning")
}

func assertAlertContains(t *testing.T, alerts map[string]any, code string, severity string) {
	t.Helper()
	for _, raw := range alerts["items"].([]any) {
		item := raw.(map[string]any)
		if item["code"] == code && item["severity"] == severity {
			return
		}
	}
	t.Fatalf("missing alert %s/%s in %#v", code, severity, alerts)
}

func decodeJSONBody(t *testing.T, body []byte) map[string]any {
	t.Helper()
	var decoded map[string]any
	if err := json.Unmarshal(body, &decoded); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	return decoded
}

func lastJSONLine(data []byte) []byte {
	lines := bytes.Split(bytes.TrimSpace(data), []byte("\n"))
	for index := len(lines) - 1; index >= 0; index-- {
		line := bytes.TrimSpace(lines[index])
		if bytes.HasPrefix(line, []byte("{")) {
			return line
		}
	}
	return nil
}

func findJSONLineByEvent(t *testing.T, data []byte, event string) map[string]any {
	t.Helper()
	lines := bytes.Split(bytes.TrimSpace(data), []byte("\n"))
	for _, line := range lines {
		line = bytes.TrimSpace(line)
		if len(line) == 0 || !bytes.HasPrefix(line, []byte("{")) {
			continue
		}
		var decoded map[string]any
		if err := json.Unmarshal(line, &decoded); err != nil {
			continue
		}
		if decoded["event"] == event {
			return decoded
		}
	}
	t.Fatalf("missing structured log event %s in %s", event, string(data))
	return nil
}
