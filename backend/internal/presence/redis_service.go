package presence

import (
	"context"
	"encoding/json"
	"time"

	goredis "github.com/redis/go-redis/v9"
)

type RedisService struct {
	client *goredis.Client
	ttl    time.Duration
}

func NewRedisService(client *goredis.Client, ttl time.Duration) Service {
	if ttl <= 0 {
		ttl = 30 * time.Second
	}
	return &RedisService{client: client, ttl: ttl}
}

func (s *RedisService) Heartbeat(ctx context.Context, request HeartbeatRequest) (Presence, error) {
	request.RoomID = normalize(request.RoomID, defaultRoomID)
	request.PlayerID = normalize(request.PlayerID, defaultPlayerID)
	now := time.Now()
	record := Presence{
		PlayerID:    request.PlayerID,
		RoomID:      request.RoomID,
		DisplayName: normalize(request.DisplayName, "Guest"),
		LastSeenAt:  now.UnixMilli(),
		ExpiresAt:   now.Add(s.ttl).UnixMilli(),
	}
	encoded, err := json.Marshal(record)
	if err != nil {
		return Presence{}, err
	}
	pipe := s.client.TxPipeline()
	pipe.Set(ctx, presenceKey(request.RoomID, request.PlayerID), encoded, s.ttl)
	pipe.SAdd(ctx, roomMembersKey(request.RoomID), request.PlayerID)
	pipe.Expire(ctx, roomMembersKey(request.RoomID), s.ttl*2)
	_, err = pipe.Exec(ctx)
	return record, err
}

func (s *RedisService) RoomMembers(ctx context.Context, roomID string) ([]Presence, error) {
	roomID = normalize(roomID, defaultRoomID)
	playerIDs, err := s.client.SMembers(ctx, roomMembersKey(roomID)).Result()
	if err != nil {
		return nil, err
	}
	members := []Presence{}
	for _, playerID := range playerIDs {
		raw, err := s.client.Get(ctx, presenceKey(roomID, playerID)).Result()
		if err == goredis.Nil {
			_ = s.client.SRem(ctx, roomMembersKey(roomID), playerID).Err()
			continue
		}
		if err != nil {
			return nil, err
		}
		var record Presence
		if err := json.Unmarshal([]byte(raw), &record); err != nil {
			return nil, err
		}
		members = append(members, record)
	}
	return members, nil
}

func (s *RedisService) Remove(ctx context.Context, roomID string, playerID string) error {
	roomID = normalize(roomID, defaultRoomID)
	playerID = normalize(playerID, defaultPlayerID)
	pipe := s.client.TxPipeline()
	pipe.Del(ctx, presenceKey(roomID, playerID))
	pipe.SRem(ctx, roomMembersKey(roomID), playerID)
	_, err := pipe.Exec(ctx)
	return err
}

func presenceKey(roomID string, playerID string) string {
	return "presence:" + roomID + ":" + playerID
}

func roomMembersKey(roomID string) string {
	return "room:" + roomID + ":members"
}
