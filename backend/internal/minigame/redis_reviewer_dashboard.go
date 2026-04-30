package minigame

import "context"

func (s *RedisSessionService) ReviewDashboard(ctx context.Context) (ReviewDashboardSnapshot, error) {
	return s.records.ReviewDashboard(ctx)
}
