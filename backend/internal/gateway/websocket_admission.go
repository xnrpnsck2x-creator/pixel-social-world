package gateway

import (
	"net"
	"net/http"
	"strings"
	"sync"
	"time"
)

const defaultWebsocketGlobalLimit = 2048
const defaultWebsocketPerIPLimit = 32
const defaultWebsocketAttemptsPerMinute = 60
const maxTrackedWebsocketIPs = 10000

type websocketAttemptWindow struct {
	startedAt time.Time
	attempts  int
}

type websocketAdmissionLimiter struct {
	mu             sync.Mutex
	globalLimit    int
	perIPLimit     int
	attemptLimit   int
	windowDuration time.Duration
	activeTotal    int
	activeByIP     map[string]int
	attemptsByIP   map[string]websocketAttemptWindow
	lastCleanup    time.Time
}

func newWebsocketAdmissionLimiter(
	globalLimit int,
	perIPLimit int,
	attemptLimit int,
	windowDuration time.Duration,
) *websocketAdmissionLimiter {
	return &websocketAdmissionLimiter{
		globalLimit:    globalLimit,
		perIPLimit:     perIPLimit,
		attemptLimit:   attemptLimit,
		windowDuration: windowDuration,
		activeByIP:     map[string]int{},
		attemptsByIP:   map[string]websocketAttemptWindow{},
	}
}

func defaultWebsocketAdmissionLimiter() *websocketAdmissionLimiter {
	return newWebsocketAdmissionLimiter(
		defaultWebsocketGlobalLimit,
		defaultWebsocketPerIPLimit,
		defaultWebsocketAttemptsPerMinute,
		time.Minute,
	)
}

func (l *websocketAdmissionLimiter) acquire(ip string, now time.Time) (func(), string) {
	ip = strings.TrimSpace(ip)
	if ip == "" {
		ip = "unknown"
	}
	l.mu.Lock()
	defer l.mu.Unlock()
	l.cleanupLocked(now)
	if _, tracked := l.attemptsByIP[ip]; !tracked &&
		len(l.attemptsByIP) >= maxTrackedWebsocketIPs {
		return nil, "websocket_rate_limited"
	}
	if l.globalLimit > 0 && l.activeTotal >= l.globalLimit {
		return nil, "websocket_capacity_full"
	}
	if l.perIPLimit > 0 && l.activeByIP[ip] >= l.perIPLimit {
		return nil, "websocket_ip_capacity_full"
	}
	window := l.attemptsByIP[ip]
	if window.startedAt.IsZero() || now.Sub(window.startedAt) >= l.windowDuration {
		window = websocketAttemptWindow{startedAt: now}
	}
	if l.attemptLimit > 0 && window.attempts >= l.attemptLimit {
		l.attemptsByIP[ip] = window
		return nil, "websocket_rate_limited"
	}
	window.attempts++
	l.attemptsByIP[ip] = window
	l.activeTotal++
	l.activeByIP[ip]++

	var once sync.Once
	return func() {
		once.Do(func() {
			l.release(ip)
		})
	}, ""
}

func (l *websocketAdmissionLimiter) release(ip string) {
	l.mu.Lock()
	defer l.mu.Unlock()
	if l.activeByIP[ip] > 1 {
		l.activeByIP[ip]--
	} else {
		delete(l.activeByIP, ip)
	}
	if l.activeTotal > 0 {
		l.activeTotal--
	}
}

func (l *websocketAdmissionLimiter) cleanupLocked(now time.Time) {
	if !l.lastCleanup.IsZero() && now.Sub(l.lastCleanup) < l.windowDuration {
		return
	}
	l.lastCleanup = now
	for ip, window := range l.attemptsByIP {
		if l.activeByIP[ip] == 0 && now.Sub(window.startedAt) >= l.windowDuration {
			delete(l.attemptsByIP, ip)
		}
	}
}

func websocketRemoteIP(request *http.Request) string {
	host, _, err := net.SplitHostPort(strings.TrimSpace(request.RemoteAddr))
	if err == nil {
		return host
	}
	return strings.TrimSpace(request.RemoteAddr)
}
