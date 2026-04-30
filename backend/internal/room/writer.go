package room

import "time"

const defaultWriteTimeout = 2 * time.Second
const slowWriteThreshold = 40 * time.Millisecond

func (h *Hub) writeDirect(client *clientState, envelope Envelope) bool {
	result := h.writeClient(client, envelope)
	if result.delivered {
		h.metrics.directDelivered.Add(1)
		return true
	}
	return false
}

func (h *Hub) writeClient(client *clientState, envelope Envelope) writeResult {
	startedAt := h.now()
	err := client.write(envelope)
	result := writeResult{delivered: err == nil, failed: err != nil}
	if h.now().Sub(startedAt) > slowWriteThreshold {
		result.slow = true
		h.metrics.slowWrites.Add(1)
	}
	if err != nil {
		h.metrics.writeFailed.Add(1)
	}
	return result
}

func (c *clientState) write(envelope Envelope) error {
	c.writeMu.Lock()
	defer c.writeMu.Unlock()
	_ = c.conn.SetWriteDeadline(time.Now().Add(defaultWriteTimeout))
	err := c.conn.WriteJSON(envelope)
	_ = c.conn.SetWriteDeadline(time.Time{})
	return err
}
