package gateway

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
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
