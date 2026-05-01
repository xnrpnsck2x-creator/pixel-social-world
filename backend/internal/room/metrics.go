package room

import "sync/atomic"

type hubMetrics struct {
	connectionsOpened   atomic.Int64
	connectionsClosed   atomic.Int64
	localBroadcasts     atomic.Int64
	localDeliveryTarget atomic.Int64
	fanoutPublished     atomic.Int64
	fanoutPublishFailed atomic.Int64
	fanoutReceived      atomic.Int64
	directDelivered     atomic.Int64
	localDelivered      atomic.Int64
	writeFailed         atomic.Int64
	writeFailureClosed  atomic.Int64
	slowWrites          atomic.Int64
	moveRateLimited     atomic.Int64
	emoteRateLimited    atomic.Int64
	leaveEvents         atomic.Int64
}

func (m *hubMetrics) Snapshot() map[string]int64 {
	return map[string]int64{
		"connections_opened":    m.connectionsOpened.Load(),
		"connections_closed":    m.connectionsClosed.Load(),
		"local_broadcasts":      m.localBroadcasts.Load(),
		"local_delivery_target": m.localDeliveryTarget.Load(),
		"fanout_published":      m.fanoutPublished.Load(),
		"fanout_publish_failed": m.fanoutPublishFailed.Load(),
		"fanout_received":       m.fanoutReceived.Load(),
		"direct_delivered":      m.directDelivered.Load(),
		"local_delivered":       m.localDelivered.Load(),
		"write_failed":          m.writeFailed.Load(),
		"write_failure_closed":  m.writeFailureClosed.Load(),
		"slow_writes":           m.slowWrites.Load(),
		"move_rate_limited":     m.moveRateLimited.Load(),
		"emote_rate_limited":    m.emoteRateLimited.Load(),
		"leave_events":          m.leaveEvents.Load(),
	}
}
