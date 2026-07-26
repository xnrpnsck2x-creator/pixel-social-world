package gateway

import (
	"net/http/httptest"
	"testing"
	"time"
)

func TestWebsocketAdmissionBoundsConnectionsAndAttempts(t *testing.T) {
	now := time.Unix(100, 0)
	limiter := newWebsocketAdmissionLimiter(2, 1, 3, time.Minute)
	releaseA, rejection := limiter.acquire("192.0.2.1", now)
	if rejection != "" {
		t.Fatalf("first connection rejected: %s", rejection)
	}
	if _, rejection := limiter.acquire("192.0.2.1", now); rejection != "websocket_ip_capacity_full" {
		t.Fatalf("per-IP capacity was not enforced: %s", rejection)
	}
	releaseB, rejection := limiter.acquire("192.0.2.2", now)
	if rejection != "" {
		t.Fatalf("second IP connection rejected: %s", rejection)
	}
	if _, rejection := limiter.acquire("192.0.2.3", now); rejection != "websocket_capacity_full" {
		t.Fatalf("global capacity was not enforced: %s", rejection)
	}
	releaseA()
	releaseB()

	rateLimiter := newWebsocketAdmissionLimiter(10, 10, 2, time.Minute)
	for attempt := 0; attempt < 2; attempt++ {
		release, rejection := rateLimiter.acquire("198.51.100.1", now)
		if rejection != "" {
			t.Fatalf("attempt %d rejected: %s", attempt, rejection)
		}
		release()
	}
	if _, rejection := rateLimiter.acquire(
		"198.51.100.1",
		now,
	); rejection != "websocket_rate_limited" {
		t.Fatalf("attempt rate was not enforced: %s", rejection)
	}
}

func TestWebsocketRemoteIPIgnoresForwardedHeader(t *testing.T) {
	request := httptest.NewRequest("GET", "/ws", nil)
	request.RemoteAddr = "203.0.113.7:4567"
	request.Header.Set("X-Forwarded-For", "127.0.0.1")
	if ip := websocketRemoteIP(request); ip != "203.0.113.7" {
		t.Fatalf("untrusted forwarded IP changed admission key: %q", ip)
	}
}
