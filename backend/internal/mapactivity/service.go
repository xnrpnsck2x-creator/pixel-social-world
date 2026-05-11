package mapactivity

import (
	"context"
	"errors"
	"fmt"
	"hash/fnv"
	"regexp"
	"strings"
	"sync"
	"time"

	"pixel-social-world/backend/internal/economy"
)

var (
	ErrPlayerRequired = errors.New("player_required")
	ErrMapRequired    = errors.New("map_required")
	ErrActionRequired = errors.New("action_required")
	ErrUnknownAction  = errors.New("unknown_activity")
	ErrActivityNotMap = errors.New("activity_not_on_map")
	ErrCooldown       = errors.New("activity_cooldown")
	ErrDailyLimit     = errors.New("activity_daily_limit")
)

type ClaimRequest struct {
	PlayerID string `json:"player_id"`
	MapID    string `json:"map_id"`
	ActionID string `json:"action_id"`
}

type ActivityRule struct {
	ActionID         string
	RewardCoins      int
	CooldownSeconds  int64
	DailyRewardLimit int
	SkillID          string
	SkillXP          int
	Drops            []ActivityDrop
	RareEvent        ActivityRareEvent
	SourceID         string
}

type ActivityDrop struct {
	ItemID string `json:"item_id"`
	Amount int    `json:"amount"`
	Rarity string `json:"rarity"`
}

type ActivityRareEvent struct {
	EventID   string `json:"event_id"`
	TitleKey  string `json:"title_key"`
	ChanceBps int    `json:"chance_bps"`
}

type ActivityRareEventResult struct {
	EventID  string `json:"event_id"`
	TitleKey string `json:"title_key"`
}

type ClaimResponse struct {
	PlayerID         string                   `json:"player_id"`
	MapID            string                   `json:"map_id"`
	ActionID         string                   `json:"action_id"`
	RewardCoins      int                      `json:"reward_coins"`
	SkillID          string                   `json:"skill_id,omitempty"`
	SkillXP          int                      `json:"skill_xp,omitempty"`
	Drops            []ActivityDrop           `json:"drops"`
	RareEvent        *ActivityRareEventResult `json:"rare_event,omitempty"`
	CooldownSeconds  int64                    `json:"cooldown_seconds"`
	DailyRewardLimit int                      `json:"daily_reward_limit"`
	DailyRewardCount int                      `json:"daily_reward_count"`
	ReadyAt          int64                    `json:"ready_at"`
	ReadyInSeconds   int64                    `json:"ready_in_seconds"`
	ServerTime       int64                    `json:"server_time"`
	Claimed          bool                     `json:"claimed"`
	Wallet           economy.GrantResponse    `json:"wallet"`
}

type Service interface {
	Claim(ctx context.Context, request ClaimRequest) (ClaimResponse, error)
}

type MemoryService struct {
	mu              sync.Mutex
	economyService  economy.Service
	startingBalance int
	ruleset         Ruleset
	cooldowns       map[string]int64
	dailyRewards    map[string]int
}

func NewMemoryService(economyService economy.Service, startingBalance int) Service {
	return NewMemoryServiceWithRuleset(economyService, startingBalance, DefaultRuleset())
}

func NewMemoryServiceWithRuleset(economyService economy.Service, startingBalance int, ruleset Ruleset) Service {
	if economyService == nil {
		economyService = economy.NewMemoryService()
	}
	if startingBalance < 0 {
		startingBalance = 0
	}
	ruleset = NormalizeRuleset(ruleset)
	return &MemoryService{
		economyService:  economyService,
		startingBalance: startingBalance,
		ruleset:         ruleset,
		cooldowns:       map[string]int64{},
		dailyRewards:    map[string]int{},
	}
}

func (s *MemoryService) Claim(ctx context.Context, request ClaimRequest) (ClaimResponse, error) {
	request = normalizeRequest(request)
	rule, err := validateRequest(s.ruleset, request)
	now := time.Now().Unix()
	if err != nil {
		return baseResponse(request, rule, now, economy.GrantResponse{PlayerID: request.PlayerID}), err
	}

	key := cooldownKey(request)
	dailyKey := dailyRewardKey(request, now)
	s.mu.Lock()
	readyAt := s.cooldowns[key]
	if readyAt > now {
		dailyCount := s.dailyRewards[dailyKey]
		s.mu.Unlock()
		wallet := s.economyService.EnsurePlayer(ctx, request.PlayerID, s.startingBalance)
		return cooldownResponse(request, rule, now, readyAt, dailyCount, wallet), ErrCooldown
	}
	dailyCount := s.dailyRewards[dailyKey]
	if dailyLimitReached(rule, dailyCount) {
		s.mu.Unlock()
		wallet := s.economyService.EnsurePlayer(ctx, request.PlayerID, s.startingBalance)
		return dailyLimitResponse(request, rule, now, dailyCount, wallet), ErrDailyLimit
	}
	readyAt = now + rule.CooldownSeconds
	s.cooldowns[key] = readyAt
	if tracksDailyReward(rule) {
		dailyCount++
		s.dailyRewards[dailyKey] = dailyCount
	}
	s.mu.Unlock()

	wallet := s.economyService.EnsurePlayer(ctx, request.PlayerID, s.startingBalance)
	if rule.RewardCoins > 0 {
		wallet = s.economyService.Grant(ctx, economy.GrantRequest{
			PlayerID: request.PlayerID,
			SourceID: sourceID(rule, request),
			Amount:   rule.RewardCoins,
		})
	}
	return ClaimResponse{
		PlayerID:         request.PlayerID,
		MapID:            request.MapID,
		ActionID:         request.ActionID,
		RewardCoins:      wallet.Delta,
		SkillID:          rule.SkillID,
		SkillXP:          rule.SkillXP,
		Drops:            copyDrops(rule.Drops),
		RareEvent:        rareEventResult(rule, request, now, dailyCount),
		CooldownSeconds:  rule.CooldownSeconds,
		DailyRewardLimit: dailyLimit(rule),
		DailyRewardCount: dailyCount,
		ReadyAt:          readyAt,
		ReadyInSeconds:   maxInt64(0, readyAt-now),
		ServerTime:       now,
		Claimed:          true,
		Wallet:           wallet,
	}, nil
}

func validateRequest(ruleset Ruleset, request ClaimRequest) (ActivityRule, error) {
	ruleset = NormalizeRuleset(ruleset)
	if request.PlayerID == "" {
		return ActivityRule{}, ErrPlayerRequired
	}
	if request.MapID == "" {
		return ActivityRule{}, ErrMapRequired
	}
	if request.ActionID == "" {
		return ActivityRule{}, ErrActionRequired
	}
	rule, ok := ruleset.Rules[request.ActionID]
	if !ok {
		return ActivityRule{}, ErrUnknownAction
	}
	if !ruleset.Allows(request.MapID, request.ActionID) {
		return rule, ErrActivityNotMap
	}
	return rule, nil
}

func baseResponse(request ClaimRequest, rule ActivityRule, now int64, wallet economy.GrantResponse) ClaimResponse {
	return ClaimResponse{
		PlayerID:         request.PlayerID,
		MapID:            request.MapID,
		ActionID:         request.ActionID,
		RewardCoins:      0,
		Drops:            []ActivityDrop{},
		CooldownSeconds:  rule.CooldownSeconds,
		DailyRewardLimit: dailyLimit(rule),
		ServerTime:       now,
		Wallet:           wallet,
	}
}

func cooldownResponse(
	request ClaimRequest,
	rule ActivityRule,
	now int64,
	readyAt int64,
	dailyCount int,
	wallet economy.GrantResponse,
) ClaimResponse {
	response := baseResponse(request, rule, now, wallet)
	response.ReadyAt = readyAt
	response.ReadyInSeconds = maxInt64(0, readyAt-now)
	response.DailyRewardCount = dailyCount
	return response
}

func dailyLimitResponse(
	request ClaimRequest,
	rule ActivityRule,
	now int64,
	dailyCount int,
	wallet economy.GrantResponse,
) ClaimResponse {
	response := baseResponse(request, rule, now, wallet)
	response.DailyRewardCount = dailyCount
	return response
}

func sourceID(rule ActivityRule, request ClaimRequest) string {
	if rule.SourceID == "" {
		return fmt.Sprintf("map_activity.%s.%s.%s", request.ActionID, request.MapID, request.ActionID)
	}
	return fmt.Sprintf("%s.%s.%s", rule.SourceID, request.MapID, request.ActionID)
}

var idPattern = regexp.MustCompile(`^[a-zA-Z0-9_-]{1,96}$`)

func normalizeRequest(request ClaimRequest) ClaimRequest {
	return ClaimRequest{
		PlayerID: sanitizeID(request.PlayerID),
		MapID:    sanitizeID(request.MapID),
		ActionID: sanitizeID(request.ActionID),
	}
}

func sanitizeID(value string) string {
	value = strings.TrimSpace(value)
	if !idPattern.MatchString(value) {
		return ""
	}
	return value
}

func cooldownKey(request ClaimRequest) string {
	return request.PlayerID + ":" + request.MapID + ":" + request.ActionID
}

func dailyRewardKey(request ClaimRequest, unixTime int64) string {
	return request.PlayerID + ":" + dayKey(unixTime) + ":" + request.ActionID
}

func dayKey(unixTime int64) string {
	return time.Unix(unixTime, 0).UTC().Format("2006-01-02")
}

func tracksDailyReward(rule ActivityRule) bool {
	return rule.RewardCoins > 0 && rule.DailyRewardLimit > 0
}

func dailyLimitReached(rule ActivityRule, count int) bool {
	return tracksDailyReward(rule) && count >= rule.DailyRewardLimit
}

func dailyLimit(rule ActivityRule) int {
	if !tracksDailyReward(rule) {
		return 0
	}
	return rule.DailyRewardLimit
}

func copyDrops(drops []ActivityDrop) []ActivityDrop {
	if len(drops) == 0 {
		return []ActivityDrop{}
	}
	result := make([]ActivityDrop, len(drops))
	copy(result, drops)
	return result
}

func rareEventResult(
	rule ActivityRule,
	request ClaimRequest,
	now int64,
	dailyCount int,
) *ActivityRareEventResult {
	if rule.RareEvent.EventID == "" || rule.RareEvent.ChanceBps <= 0 {
		return nil
	}
	if stableRoll(request, now, dailyCount) >= rule.RareEvent.ChanceBps {
		return nil
	}
	return &ActivityRareEventResult{
		EventID:  rule.RareEvent.EventID,
		TitleKey: rule.RareEvent.TitleKey,
	}
}

func stableRoll(request ClaimRequest, now int64, dailyCount int) int {
	hash := fnv.New32a()
	_, _ = hash.Write([]byte(fmt.Sprintf(
		"%s:%s:%s:%s:%d",
		request.PlayerID,
		request.MapID,
		request.ActionID,
		dayKey(now),
		dailyCount,
	)))
	return int(hash.Sum32() % 10000)
}

func maxInt64(a int64, b int64) int64 {
	if a > b {
		return a
	}
	return b
}
