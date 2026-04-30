package minigame

import (
	"crypto/rand"
	"encoding/json"
	"fmt"
	"math/big"
	"os"
	"time"
)

func DefaultFishingRewardRules() FishingRewardRules {
	return FishingRewardRules{
		RewardLimit: DefaultFishingSessionCatchLimit,
		Rewards: []FishingReward{
			{FishID: "pond_minnow", NameKey: "fishing.fish.pond_minnow.name", Rarity: "common", Weight: 60, RewardCoin: 3},
			{FishID: "leaf_carp", NameKey: "fishing.fish.leaf_carp.name", Rarity: "uncommon", Weight: 30, RewardCoin: 8},
			{FishID: "moon_koi", NameKey: "fishing.fish.moon_koi.name", Rarity: "rare", Weight: 10, RewardCoin: 25},
		},
	}
}

func LoadFishingRewardRules(path string) (FishingRewardRules, error) {
	if path == "" {
		return DefaultFishingRewardRules(), nil
	}
	bytes, err := readFishingConfig(path)
	if err != nil {
		return FishingRewardRules{}, err
	}
	var config struct {
		RewardLimit int `json:"daily_full_reward_count"`
		Fish        []struct {
			ID        string `json:"id"`
			NameKey   string `json:"name_key"`
			Rarity    string `json:"rarity"`
			Weight    int    `json:"weight"`
			SellValue int    `json:"sell_value"`
		} `json:"fish"`
	}
	if err := json.Unmarshal(bytes, &config); err != nil {
		return FishingRewardRules{}, err
	}
	rules := FishingRewardRules{RewardLimit: config.RewardLimit}
	for _, fish := range config.Fish {
		rules.Rewards = append(rules.Rewards, FishingReward{
			FishID:     fish.ID,
			NameKey:    fish.NameKey,
			Rarity:     fish.Rarity,
			Weight:     fish.Weight,
			RewardCoin: fish.SellValue,
		})
	}
	return normalizeFishingRules(rules), nil
}

func readFishingConfig(path string) ([]byte, error) {
	bytes, err := os.ReadFile(path)
	if err == nil || os.IsNotExist(err) == false {
		return bytes, err
	}
	for _, fallback := range []string{"configs/fishing.json", "../configs/fishing.json"} {
		if fallback == path {
			continue
		}
		bytes, fallbackErr := os.ReadFile(fallback)
		if fallbackErr == nil {
			return bytes, nil
		}
	}
	return nil, err
}

func normalizeFishingRules(rules FishingRewardRules) FishingRewardRules {
	if rules.RewardLimit <= 0 {
		rules.RewardLimit = DefaultFishingSessionCatchLimit
	}
	if len(rules.Rewards) == 0 {
		return DefaultFishingRewardRules()
	}
	return rules
}

func fishingRequestKey(sessionID string, playerID string, requestID string) string {
	if requestID == "" {
		return ""
	}
	return fmt.Sprintf("minigame:fishing:request:%s:%s:%s", sessionID, playerID, requestID)
}

func fishingCountKey(sessionID string, playerID string) string {
	return fmt.Sprintf("minigame:fishing:count:%s:%s", sessionID, playerID)
}

func pickFishingReward(rewards []FishingReward) FishingReward {
	totalWeight := 0
	for _, reward := range rewards {
		totalWeight += max(1, reward.Weight)
	}
	roll := secureRandomRange(totalWeight)
	cursor := 0
	for _, reward := range rewards {
		cursor += max(1, reward.Weight)
		if roll <= cursor {
			return reward
		}
	}
	return rewards[0]
}

func secureRandomRange(maxValue int) int {
	if maxValue <= 1 {
		return 1
	}
	value, err := rand.Int(rand.Reader, big.NewInt(int64(maxValue)))
	if err != nil {
		return time.Now().Nanosecond()%maxValue + 1
	}
	return int(value.Int64()) + 1
}

func fishingSessionHasPlayer(players []string, playerID string) bool {
	for _, id := range players {
		if id == playerID {
			return true
		}
	}
	return false
}
