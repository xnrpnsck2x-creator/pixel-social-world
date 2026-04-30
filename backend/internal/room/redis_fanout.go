package room

import (
	"context"
	"encoding/json"
	"strings"

	goredis "github.com/redis/go-redis/v9"
)

const fanoutPrefix = "room:"
const fanoutSuffix = ":fanout"

type RedisFanout struct {
	client *goredis.Client
}

func NewRedisFanout(client *goredis.Client) *RedisFanout {
	return &RedisFanout{client: client}
}

func (f *RedisFanout) Publish(ctx context.Context, roomID string, envelope Envelope) error {
	if ctx == nil {
		ctx = context.Background()
	}
	bytes, err := json.Marshal(envelope)
	if err != nil {
		return err
	}
	return f.client.Publish(ctx, channelForRoom(roomID), string(bytes)).Err()
}

func (f *RedisFanout) Subscribe(ctx context.Context, handler FanoutHandler) error {
	pubsub := f.client.PSubscribe(ctx, channelForRoom("*"))
	defer pubsub.Close()
	channel := pubsub.Channel()
	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		case message, ok := <-channel:
			if !ok {
				return nil
			}
			var envelope Envelope
			if err := json.Unmarshal([]byte(message.Payload), &envelope); err != nil {
				continue
			}
			handler(roomFromChannel(message.Channel), envelope)
		}
	}
}

func (f *RedisFanout) Close() error {
	return nil
}

func channelForRoom(roomID string) string {
	return fanoutPrefix + roomID + fanoutSuffix
}

func roomFromChannel(channel string) string {
	roomID := strings.TrimPrefix(channel, fanoutPrefix)
	return strings.TrimSuffix(roomID, fanoutSuffix)
}
