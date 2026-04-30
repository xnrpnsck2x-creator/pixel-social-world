package messaging

import "context"

func (s *GormService) privateReadAtByConversation(
	ctx context.Context,
	playerID string,
) (map[string]int64, error) {
	records := []PrivateReadStateRecord{}
	err := s.db.WithContext(ctx).
		Where("player_id = ?", playerID).
		Find(&records).Error
	if err != nil {
		return nil, err
	}
	readAt := map[string]int64{}
	for _, record := range records {
		readAt[record.ConversationID] = record.LastReadUnix
	}
	return readAt, nil
}
