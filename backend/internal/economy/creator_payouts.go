package economy

import (
	"context"
	"sort"
)

func (s *MemoryService) CreatorPayouts(_ context.Context, limit int) CreatorPayoutSnapshot {
	limit = normalizePayoutLimit(limit)
	s.mu.Lock()
	defer s.mu.Unlock()

	rowsByKey := map[string]*CreatorPayoutRow{}
	creators := map[string]bool{}
	snapshot := CreatorPayoutSnapshot{Limit: limit}
	for playerID, events := range s.ledger {
		for _, event := range events {
			if event.Type != creatorRevenueShareType {
				continue
			}
			creatorID := normalizePlayerID(event.PlayerID)
			if creatorID == "offline-player" {
				creatorID = playerID
			}
			gameID := payoutGameID(event.GameID)
			key := creatorID + "\x00" + gameID
			row := rowsByKey[key]
			if row == nil {
				row = &CreatorPayoutRow{CreatorID: creatorID, GameID: gameID}
				rowsByKey[key] = row
			}
			row.RevenueEvents++
			row.RevenueCoins += maxInt(event.Delta, 0)
			if event.CreatedAt >= row.LastRevenueAt {
				row.LastRevenueAt = event.CreatedAt
				row.RecentSourceID = event.SourceID
			}
			creators[creatorID] = true
			snapshot.TotalRevenueEvents++
			snapshot.TotalRevenueCoins += maxInt(event.Delta, 0)
		}
	}
	rows := make([]CreatorPayoutRow, 0, len(rowsByKey))
	for _, row := range rowsByKey {
		rows = append(rows, *row)
	}
	sortPayoutRows(rows)
	snapshot.Matched = len(rows)
	snapshot.TotalCreators = len(creators)
	if len(rows) > limit {
		rows = rows[:limit]
	}
	snapshot.Items = rows
	snapshot.Count = len(rows)
	return snapshot
}

func normalizePayoutLimit(limit int) int {
	if limit <= 0 {
		return 8
	}
	if limit > 50 {
		return 50
	}
	return limit
}

func payoutGameID(gameID string) string {
	if gameID == "" {
		return "unknown"
	}
	return gameID
}

func sortPayoutRows(rows []CreatorPayoutRow) {
	sort.Slice(rows, func(i, j int) bool {
		if rows[i].RevenueCoins != rows[j].RevenueCoins {
			return rows[i].RevenueCoins > rows[j].RevenueCoins
		}
		if rows[i].LastRevenueAt != rows[j].LastRevenueAt {
			return rows[i].LastRevenueAt > rows[j].LastRevenueAt
		}
		if rows[i].CreatorID != rows[j].CreatorID {
			return rows[i].CreatorID < rows[j].CreatorID
		}
		return rows[i].GameID < rows[j].GameID
	})
}
