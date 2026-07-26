package gateway

import (
	"sync"
	"time"
)

const creatorPlayerSubmissionsPerWindow = 4
const creatorIPSubmissionsPerWindow = 12
const creatorSubmissionWindow = time.Minute
const maxCreatorLimiterKeys = 10000
const creatorLimiterCleanupInterval = 256

type creatorSubmissionLimiter struct {
	mu     sync.Mutex
	events map[string][]time.Time
	now    func() time.Time
	window time.Duration
	player int
	ip     int
	calls  int
}

func newCreatorSubmissionLimiter() *creatorSubmissionLimiter {
	return &creatorSubmissionLimiter{
		events: make(map[string][]time.Time),
		now:    time.Now,
		window: creatorSubmissionWindow,
		player: creatorPlayerSubmissionsPerWindow,
		ip:     creatorIPSubmissionsPerWindow,
	}
}

func (l *creatorSubmissionLimiter) allow(playerID string, clientIP string) bool {
	now := l.now()
	l.mu.Lock()
	defer l.mu.Unlock()
	l.calls++
	if l.calls%creatorLimiterCleanupInterval == 0 {
		l.removeExpired(now)
	}
	if !l.allowKey("player:"+playerID, l.player, now) {
		return false
	}
	if !l.allowKey("ip:"+clientIP, l.ip, now) {
		l.removeLatest("player:" + playerID)
		return false
	}
	return true
}

func (l *creatorSubmissionLimiter) allowKey(key string, limit int, now time.Time) bool {
	cutoff := now.Add(-l.window)
	events := l.events[key]
	first := 0
	for first < len(events) && events[first].Before(cutoff) {
		first++
	}
	events = append([]time.Time{}, events[first:]...)
	if len(events) == 0 {
		delete(l.events, key)
		if len(l.events) >= maxCreatorLimiterKeys {
			return false
		}
	}
	if len(events) >= limit {
		l.events[key] = events
		return false
	}
	l.events[key] = append(events, now)
	return true
}

func (l *creatorSubmissionLimiter) removeExpired(now time.Time) {
	cutoff := now.Add(-l.window)
	for key, events := range l.events {
		last := len(events) - 1
		if last < 0 || events[last].Before(cutoff) {
			delete(l.events, key)
		}
	}
}

func (l *creatorSubmissionLimiter) removeLatest(key string) {
	events := l.events[key]
	if len(events) <= 1 {
		delete(l.events, key)
		return
	}
	l.events[key] = events[:len(events)-1]
}
