package auth

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	goredis "github.com/redis/go-redis/v9"
)

func (s *RedisService) UpgradeGuest(ctx context.Context, request UpgradeGuestRequest) (UpgradeGuestResponse, error) {
	normalized, err := verifyUpgradeRequest(ctx, s.verifier, request)
	if err != nil {
		return UpgradeGuestResponse{}, err
	}

	key := redisLinkedAccountKey(normalized.Provider, normalized.ProviderSubject)
	var account LinkedAccount
	var session Session
	err = s.client.Watch(ctx, func(tx *goredis.Tx) error {
		raw, loadErr := tx.Get(ctx, key).Result()
		if loadErr != nil && loadErr != goredis.Nil {
			return loadErr
		}
		if loadErr == nil {
			if err := json.Unmarshal([]byte(raw), &account); err != nil {
				return err
			}
			if account.PlayerID != normalized.PlayerID {
				return fmt.Errorf("account_already_linked")
			}
		} else {
			account = LinkedAccount{
				PlayerID:        normalized.PlayerID,
				Provider:        normalized.Provider,
				Platform:        normalized.Platform,
				ProviderSubject: normalized.ProviderSubject,
				Email:           normalized.Email,
				DisplayName:     normalized.DisplayName,
				LinkedAt:        time.Now().UnixMilli(),
			}
		}

		session = newSession(normalized.PlayerID, s.accessTTL, s.refreshTTL)
		_, txErr := tx.TxPipelined(ctx, func(pipe goredis.Pipeliner) error {
			if loadErr == goredis.Nil {
				encoded, _ := json.Marshal(account)
				pipe.Set(ctx, key, encoded, 0)
			}
			s.queueSave(ctx, pipe, session)
			return nil
		})
		return txErr
	}, key)
	if err != nil {
		return UpgradeGuestResponse{}, err
	}
	return UpgradeGuestResponse{Session: session, LinkedAccount: account}, nil
}

func redisLinkedAccountKey(provider string, subject string) string {
	return "auth:linked:" + linkedAccountMapKey(provider, subject)
}
