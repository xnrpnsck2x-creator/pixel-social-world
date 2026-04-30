package minigame

import "context"

func (s *RedisSessionService) RecordReviewAudit(
	ctx context.Context,
	event ReviewAuditEvent,
) error {
	return s.records.RecordReviewAudit(ctx, event)
}

func (s *RedisSessionService) ReviewAudit(
	ctx context.Context,
	gameID string,
) (ReviewAuditSnapshot, error) {
	return s.records.ReviewAudit(ctx, gameID)
}
