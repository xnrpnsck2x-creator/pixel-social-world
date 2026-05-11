package economy

import "context"

func (s *GormService) CreatorPayouts(ctx context.Context, limit int) CreatorPayoutSnapshot {
	limit = normalizePayoutLimit(limit)
	type payoutGroup struct {
		CreatorID     string
		GameID        string
		RevenueEvents int
		RevenueCoins  int
		LastRevenueAt int64
	}
	groups := []payoutGroup{}
	_ = s.db.WithContext(ctx).
		Model(&LedgerRecord{}).
		Select("player_id AS creator_id, game_id, COUNT(*) AS revenue_events, COALESCE(SUM(delta), 0) AS revenue_coins, COALESCE(MAX(created_unix), 0) AS last_revenue_at").
		Where("type = ?", creatorRevenueShareType).
		Group("player_id, game_id").
		Order("revenue_coins DESC, last_revenue_at DESC, creator_id ASC, game_id ASC").
		Find(&groups).Error

	snapshot := CreatorPayoutSnapshot{Limit: limit, Matched: len(groups)}
	creators := map[string]bool{}
	rows := make([]CreatorPayoutRow, 0, len(groups))
	for _, group := range groups {
		row := CreatorPayoutRow{
			CreatorID:     normalizePlayerID(group.CreatorID),
			GameID:        payoutGameID(group.GameID),
			RevenueEvents: group.RevenueEvents,
			RevenueCoins:  group.RevenueCoins,
			LastRevenueAt: group.LastRevenueAt,
		}
		row.RecentSourceID = s.recentCreatorPayoutSource(ctx, row.CreatorID, group.GameID)
		rows = append(rows, row)
		creators[row.CreatorID] = true
		snapshot.TotalRevenueEvents += row.RevenueEvents
		snapshot.TotalRevenueCoins += row.RevenueCoins
	}
	snapshot.TotalCreators = len(creators)
	if len(rows) > limit {
		rows = rows[:limit]
	}
	snapshot.Items = rows
	snapshot.Count = len(rows)
	return snapshot
}

func (s *GormService) recentCreatorPayoutSource(ctx context.Context, creatorID string, gameID string) string {
	var record LedgerRecord
	err := s.db.WithContext(ctx).
		Where("player_id = ? AND game_id = ? AND type = ?", creatorID, gameID, creatorRevenueShareType).
		Order("created_unix DESC, id DESC").
		First(&record).Error
	if err != nil {
		return ""
	}
	return record.SourceID
}
