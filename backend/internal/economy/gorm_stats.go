package economy

import (
	"context"

	"gorm.io/gorm"
)

func (s *GormService) Stats(ctx context.Context) Stats {
	return Stats{
		TotalLedgerEvents:    countLedgerRecords(ctx, s.db, ""),
		GrantEvents:          countLedgerRecords(ctx, s.db, "type = ?", "grant"),
		SpendEvents:          countLedgerRecords(ctx, s.db, "type = ?", "spend"),
		RewardCapHits:        countLedgerRecords(ctx, s.db, "type IN ? AND delta = 0", []string{"grant", creatorPlayRewardType}),
		CreatorPlayRewards:   countLedgerRecords(ctx, s.db, "type = ?", creatorPlayRewardType),
		CreatorRevenueShares: countLedgerRecords(ctx, s.db, "type = ?", creatorRevenueShareType),
		CreatorRevenueCoins:  sumLedgerDelta(ctx, s.db, "type = ?", creatorRevenueShareType),
	}
}

func countLedgerRecords(ctx context.Context, db *gorm.DB, condition string, args ...any) int {
	var count int64
	query := db.WithContext(ctx).Model(&LedgerRecord{})
	if condition != "" {
		query = query.Where(condition, args...)
	}
	_ = query.Count(&count).Error
	return int(count)
}

func sumLedgerDelta(ctx context.Context, db *gorm.DB, condition string, args ...any) int {
	var sum int
	query := db.WithContext(ctx).Model(&LedgerRecord{}).Select("COALESCE(SUM(delta), 0)")
	if condition != "" {
		query = query.Where(condition, args...)
	}
	_ = query.Scan(&sum).Error
	return sum
}
