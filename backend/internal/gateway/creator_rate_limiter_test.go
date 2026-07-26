package gateway

import (
	"testing"
	"time"
)

func TestCreatorSubmissionLimiterEnforcesPlayerAndResetsWindow(t *testing.T) {
	limiter := newCreatorSubmissionLimiter()
	now := time.Unix(100, 0)
	limiter.now = func() time.Time { return now }

	for attempt := 0; attempt < creatorPlayerSubmissionsPerWindow; attempt++ {
		if !limiter.allow("player-a", "127.0.0.1") {
			t.Fatalf("submission %d was unexpectedly limited", attempt)
		}
	}
	if limiter.allow("player-a", "127.0.0.1") {
		t.Fatal("player submission limit was not enforced")
	}

	now = now.Add(creatorSubmissionWindow + time.Second)
	if !limiter.allow("player-a", "127.0.0.1") {
		t.Fatal("submission window did not reset")
	}
}
