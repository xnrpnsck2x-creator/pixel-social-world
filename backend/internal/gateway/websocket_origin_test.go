package gateway

import (
	"net/http/httptest"
	"testing"
)

func TestWebSocketOriginCheckerAllowsNativeAndConfiguredOriginsOnly(t *testing.T) {
	check := websocketOriginChecker([]string{"https://play.example.com"})

	native := httptest.NewRequest("GET", "/ws/city", nil)
	if !check(native) {
		t.Fatal("native client without Origin should be allowed")
	}

	allowed := httptest.NewRequest("GET", "/ws/city", nil)
	allowed.Header.Set("Origin", "https://play.example.com")
	if !check(allowed) {
		t.Fatal("configured browser origin should be allowed")
	}

	denied := httptest.NewRequest("GET", "/ws/city", nil)
	denied.Header.Set("Origin", "https://attacker.example")
	if check(denied) {
		t.Fatal("unconfigured browser origin should be rejected")
	}
}
