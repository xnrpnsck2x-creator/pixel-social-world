package economy

import "context"

func (s *MemoryService) Stats(_ context.Context) Stats {
	s.mu.Lock()
	defer s.mu.Unlock()
	stats := Stats{}
	for _, events := range s.ledger {
		for _, event := range events {
			stats.TotalLedgerEvents++
			switch event.Type {
			case "grant":
				stats.GrantEvents++
			case "spend":
				stats.SpendEvents++
			case creatorPlayRewardType:
				stats.CreatorPlayRewards++
			case creatorRevenueShareType:
				stats.CreatorRevenueShares++
				stats.CreatorRevenueCoins += maxInt(event.Delta, 0)
			}
			if countsTowardDailyCap(event.Type) && event.Delta == 0 {
				stats.RewardCapHits++
			}
		}
	}
	return stats
}
