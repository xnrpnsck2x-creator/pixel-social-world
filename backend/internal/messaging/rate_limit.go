package messaging

import (
	"sync"
	"time"
)

const privateRateLimitWindow = 10 * time.Second
const privateRateLimitMaxMessages = 6

type privateRateLimiter struct {
	mu   sync.Mutex
	hits map[string][]time.Time
}

func newPrivateRateLimiter() *privateRateLimiter {
	return &privateRateLimiter{hits: map[string][]time.Time{}}
}

func (r *privateRateLimiter) allow(playerID string, now time.Time) bool {
	r.mu.Lock()
	defer r.mu.Unlock()
	windowStart := now.Add(-privateRateLimitWindow)
	recent := []time.Time{}
	for _, hit := range r.hits[playerID] {
		if hit.After(windowStart) {
			recent = append(recent, hit)
		}
	}
	if len(recent) >= privateRateLimitMaxMessages {
		r.hits[playerID] = recent
		return false
	}
	recent = append(recent, now)
	r.hits[playerID] = recent
	return true
}
