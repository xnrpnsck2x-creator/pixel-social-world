package gateway

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestCORSAllowsConfiguredOrigin(t *testing.T) {
	deps := DefaultMemoryDependencies()
	deps.CORSAllowedOrigins = []string{"http://127.0.0.1:18888"}
	server := NewServerWithDependencies(deps)

	request := httptest.NewRequest(http.MethodOptions, "/auth/guest", nil)
	request.Header.Set("Origin", "http://127.0.0.1:18888")
	request.Header.Set("Access-Control-Request-Method", http.MethodPost)
	recorder := httptest.NewRecorder()

	server.router.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusNoContent {
		t.Fatalf("expected no-content preflight, got %d", recorder.Code)
	}
	if recorder.Header().Get("Access-Control-Allow-Origin") != "http://127.0.0.1:18888" {
		t.Fatalf("expected allowed origin header, got %q", recorder.Header().Get("Access-Control-Allow-Origin"))
	}
	if recorder.Header().Get("Access-Control-Allow-Credentials") != "true" {
		t.Fatalf("expected credentials to be allowed")
	}
}

func TestCORSRejectsUnknownPreflightOrigin(t *testing.T) {
	deps := DefaultMemoryDependencies()
	deps.CORSAllowedOrigins = []string{"http://127.0.0.1:18888"}
	server := NewServerWithDependencies(deps)

	request := httptest.NewRequest(http.MethodOptions, "/auth/guest", nil)
	request.Header.Set("Origin", "https://example.com")
	request.Header.Set("Access-Control-Request-Method", http.MethodPost)
	recorder := httptest.NewRecorder()

	server.router.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusForbidden {
		t.Fatalf("expected forbidden preflight, got %d", recorder.Code)
	}
	if recorder.Header().Get("Access-Control-Allow-Origin") != "" {
		t.Fatalf("expected no CORS origin header for rejected origin")
	}
}
