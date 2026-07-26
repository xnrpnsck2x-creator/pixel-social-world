package room

import (
	"context"
	"time"

	"github.com/gorilla/websocket"
)

const defaultWriteTimeout = 500 * time.Millisecond
const slowWriteThreshold = 40 * time.Millisecond

func (h *Hub) writeDirect(client *clientState, envelope Envelope) bool {
	state := client.snapshot()
	return h.enqueueClient(client, outboundMessage{
		envelope: envelope,
		roomID:   state.roomID,
		direct:   true,
	})
}

func (h *Hub) ensureClientWriter(client *clientState) {
	client.writerOnce.Do(func() {
		client.ensureQueue()
		go h.runClientWriter(client)
	})
}

func (h *Hub) enqueueClient(client *clientState, message outboundMessage) bool {
	h.ensureClientWriter(client)
	queued, coalesced := client.enqueue(message, h.sendQueueLimit)
	if coalesced {
		h.metrics.movementCoalesced.Add(1)
	}
	if queued {
		return true
	}
	h.metrics.sendQueueOverflow.Add(1)
	_ = client.close()
	return false
}

func (h *Hub) runClientWriter(client *clientState) {
	notify, done := client.queueSignals()
	ticker := time.NewTicker(h.pingPeriod)
	defer ticker.Stop()

	for {
		for {
			message, ok := client.dequeue()
			if !ok {
				break
			}
			result := h.writeClient(client, message.envelope)
			h.recordRoomWrite(message.roomID, result)
			if result.delivered {
				if message.direct {
					h.metrics.directDelivered.Add(1)
				} else {
					h.metrics.localDelivered.Add(1)
				}
			}
			if result.failed {
				return
			}
		}

		select {
		case <-notify:
		case <-ticker.C:
			if !h.writePing(client) {
				return
			}
		case <-done:
			return
		}
	}
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
		h.metrics.writeFailureClosed.Add(1)
		_ = client.close()
	}
	return result
}

func (h *Hub) writePing(client *clientState) bool {
	state := client.snapshot()
	if h.sessionLease != nil &&
		state.playerID != "" &&
		!h.sessionLease.IsCurrent(
			context.Background(),
			state.playerID,
			state.sessionToken,
			h.sessionLeaseTTL(),
		) {
		_ = client.close()
		return false
	}
	if client.conn == nil {
		return true
	}
	client.writeMu.Lock()
	err := client.conn.WriteControl(
		websocket.PingMessage,
		nil,
		time.Now().Add(defaultWriteTimeout),
	)
	client.writeMu.Unlock()
	if err == nil {
		return true
	}
	h.metrics.writeFailed.Add(1)
	h.metrics.writeFailureClosed.Add(1)
	_ = client.close()
	return false
}

func (c *clientState) write(envelope Envelope) error {
	c.writeMu.Lock()
	defer c.writeMu.Unlock()
	if c.writeFn != nil {
		return c.writeFn(envelope)
	}
	if c.conn == nil {
		return nil
	}
	_ = c.conn.SetWriteDeadline(time.Now().Add(defaultWriteTimeout))
	err := c.conn.WriteJSON(envelope)
	_ = c.conn.SetWriteDeadline(time.Time{})
	return err
}

func (c *clientState) close() error {
	var err error
	c.closeOnce.Do(func() {
		c.ensureQueue()
		c.queueMu.Lock()
		c.queueClosed = true
		close(c.done)
		c.signalWriterLocked()
		c.queueMu.Unlock()
		if c.closeFn != nil {
			err = c.closeFn()
			return
		}
		if c.conn != nil {
			err = c.conn.Close()
		}
	})
	return err
}
