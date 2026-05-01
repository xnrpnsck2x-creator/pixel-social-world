package minigame

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strconv"
	"time"

	goredis "github.com/redis/go-redis/v9"

	"pixel-social-world/backend/internal/economy"
)

type RedisFishingRewardService struct {
	client   *goredis.Client
	sessions Service
	economy  economy.Service
	rules    FishingRewardRules
	ttl      time.Duration
	metrics  fishingRewardMetrics
}

func NewRedisFishingRewardService(
	client *goredis.Client,
	sessions Service,
	economyService economy.Service,
	rules FishingRewardRules,
	ttl time.Duration,
) *RedisFishingRewardService {
	if ttl <= 0 {
		ttl = 24 * time.Hour
	}
	return &RedisFishingRewardService{
		client:   client,
		sessions: sessions,
		economy:  economyService,
		rules:    normalizeFishingRules(rules),
		ttl:      ttl,
	}
}

func (s *RedisFishingRewardService) ClaimCatch(
	ctx context.Context,
	request FishingCatchRequest,
) (FishingCatchResponse, error) {
	session, ok := s.sessions.GetSession(ctx, request.SessionID)
	if !ok || session.GameID != "fishing" {
		s.metrics.errors.Add(1)
		return FishingCatchResponse{}, ErrInvalidFishingSession
	}
	if !fishingSessionHasPlayer(session.Players, request.PlayerID) {
		s.metrics.errors.Add(1)
		return FishingCatchResponse{}, ErrFishingSessionForbidden
	}
	requestKey := fishingRequestKey(session.ID, request.PlayerID, request.RequestID)
	if response, claimed, err := s.claimRequest(ctx, requestKey); err != nil || !claimed {
		if err != nil {
			s.countRedisError(err)
		} else {
			s.metrics.replayed.Add(1)
		}
		return response, err
	}
	catchNumber, err := s.nextCatch(ctx, session.ID, request.PlayerID)
	if err != nil {
		s.releaseRequest(ctx, requestKey)
		s.countRedisError(err)
		return FishingCatchResponse{}, err
	}
	response := s.grant(ctx, session.ID, request, catchNumber)
	if requestKey != "" {
		if err := s.saveResponse(ctx, requestKey, response); err != nil {
			return FishingCatchResponse{}, err
		}
	}
	s.metrics.granted.Add(1)
	return response, nil
}

func (s *RedisFishingRewardService) Stats(ctx context.Context) FishingRewardStats {
	return FishingRewardStats{
		Backend:        "redis",
		Granted:        s.metrics.granted.Load(),
		Replayed:       s.metrics.replayed.Load(),
		Capped:         s.metrics.capped.Load(),
		Pending:        s.metrics.pending.Load(),
		Errors:         s.metrics.errors.Load(),
		ActiveCounters: s.countKeys(ctx, "minigame:fishing:count:*"),
		StoredRequests: s.countKeys(ctx, "minigame:fishing:request:*"),
	}
}

func (s *RedisFishingRewardService) claimRequest(
	ctx context.Context,
	key string,
) (FishingCatchResponse, bool, error) {
	if key == "" {
		return FishingCatchResponse{}, true, nil
	}
	response, err := s.loadResponse(ctx, key)
	if err == nil {
		return response, false, nil
	}
	ok, err := s.client.SetNX(ctx, key, "pending", s.ttl).Result()
	if err != nil {
		return FishingCatchResponse{}, false, err
	}
	if ok {
		return FishingCatchResponse{}, true, nil
	}
	response, err = s.loadResponse(ctx, key)
	if err == nil {
		return response, false, nil
	}
	return FishingCatchResponse{}, false, ErrFishingRequestPending
}

func (s *RedisFishingRewardService) grant(
	ctx context.Context,
	sessionID string,
	request FishingCatchRequest,
	catchNumber int,
) FishingCatchResponse {
	reward := pickFishingReward(s.rules.Rewards)
	balance := s.economy.Grant(ctx, economy.GrantRequest{
		PlayerID: request.PlayerID,
		SourceID: fmt.Sprintf("minigame.fishing.%s.%s.%02d", sessionID, request.PlayerID, catchNumber),
		Amount:   reward.RewardCoin,
	})
	return FishingCatchResponse{
		PlayerID:    request.PlayerID,
		SessionID:   sessionID,
		RequestID:   request.RequestID,
		CatchNumber: catchNumber,
		FishID:      reward.FishID,
		FishNameKey: reward.NameKey,
		Rarity:      reward.Rarity,
		RewardCoin:  balance.Delta,
		Balance:     balance.Balance,
	}
}

func (s *RedisFishingRewardService) nextCatch(
	ctx context.Context,
	sessionID string,
	playerID string,
) (int, error) {
	key := fishingCountKey(sessionID, playerID)
	var catchNumber int
	for attempt := 0; attempt < 8; attempt++ {
		err := s.client.Watch(ctx, func(tx *goredis.Tx) error {
			count, err := s.loadCatchCount(ctx, tx, key)
			if err != nil {
				return err
			}
			if count >= s.rules.RewardLimit {
				return ErrFishingRewardCap
			}
			catchNumber = count + 1
			_, err = tx.TxPipelined(ctx, func(pipe goredis.Pipeliner) error {
				pipe.Set(ctx, key, strconv.Itoa(catchNumber), s.ttl)
				return nil
			})
			return err
		}, key)
		if err == goredis.TxFailedErr {
			continue
		}
		return catchNumber, err
	}
	return 0, errors.New("fishing_reward_conflict")
}

func (s *RedisFishingRewardService) loadCatchCount(
	ctx context.Context,
	tx *goredis.Tx,
	key string,
) (int, error) {
	raw, err := tx.Get(ctx, key).Result()
	if err == goredis.Nil {
		return 0, nil
	}
	if err != nil {
		return 0, err
	}
	return strconv.Atoi(raw)
}

func (s *RedisFishingRewardService) loadResponse(
	ctx context.Context,
	key string,
) (FishingCatchResponse, error) {
	raw, err := s.client.Get(ctx, key).Result()
	if err != nil {
		return FishingCatchResponse{}, err
	}
	if raw == "pending" {
		return FishingCatchResponse{}, ErrFishingRequestPending
	}
	var response FishingCatchResponse
	if err := json.Unmarshal([]byte(raw), &response); err != nil {
		return FishingCatchResponse{}, err
	}
	return response, nil
}

func (s *RedisFishingRewardService) saveResponse(
	ctx context.Context,
	key string,
	response FishingCatchResponse,
) error {
	encoded, err := json.Marshal(response)
	if err != nil {
		return err
	}
	return s.client.Set(ctx, key, encoded, s.ttl).Err()
}

func (s *RedisFishingRewardService) releaseRequest(ctx context.Context, key string) {
	if key != "" {
		_ = s.client.Del(ctx, key).Err()
	}
}

func (s *RedisFishingRewardService) countRedisError(err error) {
	if err == ErrFishingRewardCap {
		s.metrics.capped.Add(1)
	} else if err == ErrFishingRequestPending {
		s.metrics.pending.Add(1)
	} else if err != nil {
		s.metrics.errors.Add(1)
	}
}

func (s *RedisFishingRewardService) countKeys(ctx context.Context, pattern string) int {
	iter := s.client.Scan(ctx, 0, pattern, 100).Iterator()
	count := 0
	for iter.Next(ctx) {
		count++
	}
	return count
}
