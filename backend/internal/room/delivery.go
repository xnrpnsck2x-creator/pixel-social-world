package room

import "context"

func (h *Hub) startFanout() {
	if h.fanout == nil {
		return
	}
	ctx, cancel := context.WithCancel(context.Background())
	h.fanoutCancel = cancel
	go func() {
		_ = h.fanout.Subscribe(ctx, h.receiveFanout)
	}()
}

func (h *Hub) receiveFanout(roomID string, envelope Envelope) {
	h.metrics.fanoutReceived.Add(1)
	h.applyFanoutState(roomID, envelope)
	h.broadcastLocal(roomID, envelope)
}

func (h *Hub) applyFanoutState(roomID string, envelope Envelope) {
	payload := payloadMap(envelope.Payload)
	playerID := stringValue(payload, "player_id", "")
	switch envelope.Type {
	case "player.move":
		h.rememberMove(roomID, playerID, payload)
	case "world.leave":
		h.forgetMove(roomID, playerID)
	}
}

func (h *Hub) emitToRoom(roomID string, envelope Envelope) {
	if h.fanout != nil {
		if err := h.fanout.Publish(context.Background(), roomID, envelope); err != nil {
			h.metrics.fanoutPublishFailed.Add(1)
			h.broadcastLocal(roomID, envelope)
			return
		}
		h.metrics.fanoutPublished.Add(1)
		return
	}
	h.broadcastLocal(roomID, envelope)
}

func (h *Hub) broadcastLocal(roomID string, envelope Envelope) {
	clients := h.snapshotClients(roomID)
	h.metrics.localBroadcasts.Add(1)
	h.metrics.localDeliveryTarget.Add(int64(len(clients)))
	if roomID != "" {
		h.recordRoomBroadcast(roomID, len(clients))
	} else {
		targetsByRoom := map[string]int{}
		for _, client := range clients {
			targetsByRoom[normalizedMetricRoomID(client.roomID)]++
		}
		for targetRoomID, targets := range targetsByRoom {
			h.recordRoomBroadcast(targetRoomID, targets)
		}
	}
	for _, client := range clients {
		result := h.writeClient(client, envelope)
		h.recordRoomWrite(client.roomID, result)
		if result.delivered {
			h.metrics.localDelivered.Add(1)
		}
	}
}
