package minigame

import "context"

func (s *RedisSessionService) SubmissionHistory(
	ctx context.Context,
	id string,
) (SubmissionHistorySnapshot, error) {
	return s.records.SubmissionHistory(ctx, id)
}
