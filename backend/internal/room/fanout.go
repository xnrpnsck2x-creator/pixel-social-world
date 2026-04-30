package room

import "context"

type FanoutHandler func(roomID string, envelope Envelope)

type Fanout interface {
	Publish(ctx context.Context, roomID string, envelope Envelope) error
	Subscribe(ctx context.Context, handler FanoutHandler) error
	Close() error
}

func WithFanout(fanout Fanout) Option {
	return func(h *Hub) {
		h.fanout = fanout
	}
}
