package room

import "sync/atomic"

const maxTrackedRoomMetrics = 256
const overflowRoomMetricsID = "_overflow"

type roomMetricCounters struct {
	localBroadcasts     atomic.Int64
	localDeliveryTarget atomic.Int64
	localDelivered      atomic.Int64
	writeFailed         atomic.Int64
	slowWrites          atomic.Int64
}

type writeResult struct {
	delivered bool
	failed    bool
	slow      bool
}

func (h *Hub) recordRoomBroadcast(roomID string, targets int) {
	counters := h.roomCounters(roomID)
	counters.localBroadcasts.Add(1)
	counters.localDeliveryTarget.Add(int64(targets))
}

func (h *Hub) recordRoomWrite(roomID string, result writeResult) {
	counters := h.roomCounters(roomID)
	if result.delivered {
		counters.localDelivered.Add(1)
	}
	if result.failed {
		counters.writeFailed.Add(1)
	}
	if result.slow {
		counters.slowWrites.Add(1)
	}
}

func (h *Hub) roomCounters(roomID string) *roomMetricCounters {
	roomID = normalizedMetricRoomID(roomID)
	h.roomMetricsMu.RLock()
	counters := h.roomMetrics[roomID]
	h.roomMetricsMu.RUnlock()
	if counters != nil {
		return counters
	}

	h.roomMetricsMu.Lock()
	defer h.roomMetricsMu.Unlock()
	if counters = h.roomMetrics[roomID]; counters != nil {
		return counters
	}
	if len(h.roomMetrics) >= maxTrackedRoomMetrics {
		roomID = overflowRoomMetricsID
		if counters = h.roomMetrics[roomID]; counters != nil {
			return counters
		}
	}
	counters = &roomMetricCounters{}
	h.roomMetrics[roomID] = counters
	return counters
}

func (h *Hub) roomMetricsSnapshot() map[string]map[string]int64 {
	h.roomMetricsMu.RLock()
	defer h.roomMetricsMu.RUnlock()
	snapshot := make(map[string]map[string]int64, len(h.roomMetrics))
	for roomID, counters := range h.roomMetrics {
		snapshot[roomID] = counters.snapshot()
	}
	return snapshot
}

func (c *roomMetricCounters) snapshot() map[string]int64 {
	return map[string]int64{
		"local_broadcasts":      c.localBroadcasts.Load(),
		"local_delivery_target": c.localDeliveryTarget.Load(),
		"local_delivered":       c.localDelivered.Load(),
		"write_failed":          c.writeFailed.Load(),
		"slow_writes":           c.slowWrites.Load(),
	}
}

func normalizedMetricRoomID(roomID string) string {
	if roomID == "" {
		return defaultRoomID
	}
	return roomID
}
