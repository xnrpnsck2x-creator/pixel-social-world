package social

import (
	"context"
	"errors"
	"sort"
	"time"

	"gorm.io/gorm"
)

type RelationshipRecord struct {
	PlayerID       string `gorm:"primaryKey;size:80"`
	TargetPlayerID string `gorm:"primaryKey;size:80"`
	Following      bool
	Blocked        bool
	UpdatedUnix    int64
	CreatedAt      time.Time
	UpdatedAt      time.Time
}

type GormService struct {
	db *gorm.DB
}

func AutoMigrate(db *gorm.DB) error {
	return db.AutoMigrate(&RelationshipRecord{})
}

func NewGormService(db *gorm.DB) Service {
	return &GormService{db: db}
}

func (s *GormService) Follow(ctx context.Context, request RelationshipRequest) (RelationshipState, error) {
	request, err := normalizeRequest(request)
	if err != nil {
		return RelationshipState{}, err
	}
	if s.Blocked(ctx, request.PlayerID, request.TargetPlayerID) {
		return s.State(ctx, request)
	}
	return s.save(ctx, request, func(record *RelationshipRecord) {
		record.Following = true
	})
}

func (s *GormService) Unfollow(ctx context.Context, request RelationshipRequest) (RelationshipState, error) {
	request, err := normalizeRequest(request)
	if err != nil {
		return RelationshipState{}, err
	}
	return s.save(ctx, request, func(record *RelationshipRecord) {
		record.Following = false
	})
}

func (s *GormService) Block(ctx context.Context, request RelationshipRequest) (RelationshipState, error) {
	request, err := normalizeRequest(request)
	if err != nil {
		return RelationshipState{}, err
	}
	err = s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		now := time.Now().Unix()
		record, err := relationRecord(tx, request.PlayerID, request.TargetPlayerID)
		if err != nil {
			return err
		}
		record.Blocked = true
		record.Following = false
		record.UpdatedUnix = now
		if err := tx.Save(&record).Error; err != nil {
			return err
		}
		reverse, err := relationRecord(tx, request.TargetPlayerID, request.PlayerID)
		if err != nil {
			return err
		}
		reverse.Following = false
		reverse.UpdatedUnix = now
		return tx.Save(&reverse).Error
	})
	if err != nil {
		return RelationshipState{}, err
	}
	return s.State(ctx, request)
}

func (s *GormService) Unblock(ctx context.Context, request RelationshipRequest) (RelationshipState, error) {
	request, err := normalizeRequest(request)
	if err != nil {
		return RelationshipState{}, err
	}
	return s.save(ctx, request, func(record *RelationshipRecord) {
		record.Blocked = false
	})
}

func (s *GormService) State(ctx context.Context, request RelationshipRequest) (RelationshipState, error) {
	request, err := normalizeRequest(request)
	if err != nil {
		return RelationshipState{}, err
	}
	direct, err := s.load(ctx, request.PlayerID, request.TargetPlayerID)
	if err != nil {
		return RelationshipState{}, err
	}
	reverse, err := s.load(ctx, request.TargetPlayerID, request.PlayerID)
	if err != nil {
		return RelationshipState{}, err
	}
	return stateFromRecords(request, direct, reverse), nil
}

func (s *GormService) Following(ctx context.Context, request ListRequest) ([]RelationshipState, error) {
	request, err := normalizeListRequest(request)
	if err != nil {
		return nil, err
	}
	records := []RelationshipRecord{}
	err = s.db.WithContext(ctx).
		Where("player_id = ? AND following = ?", request.PlayerID, true).
		Order("target_player_id asc").
		Limit(request.Limit).
		Find(&records).Error
	if err != nil {
		return nil, err
	}
	sort.Slice(records, func(i int, j int) bool {
		return records[i].TargetPlayerID < records[j].TargetPlayerID
	})
	states := make([]RelationshipState, 0, len(records))
	for _, record := range records {
		state, err := s.State(ctx, RelationshipRequest{
			PlayerID: request.PlayerID, TargetPlayerID: record.TargetPlayerID,
		})
		if err != nil {
			return nil, err
		}
		states = append(states, state)
	}
	return states, nil
}

func (s *GormService) Blocked(ctx context.Context, playerID string, targetPlayerID string) bool {
	state, err := s.State(ctx, RelationshipRequest{PlayerID: playerID, TargetPlayerID: targetPlayerID})
	return err == nil && (state.Blocked || state.BlockedBy)
}

func (s *GormService) save(
	ctx context.Context,
	request RelationshipRequest,
	mutate func(*RelationshipRecord),
) (RelationshipState, error) {
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		record, err := relationRecord(tx, request.PlayerID, request.TargetPlayerID)
		if err != nil {
			return err
		}
		mutate(&record)
		record.UpdatedUnix = time.Now().Unix()
		return tx.Save(&record).Error
	})
	if err != nil {
		return RelationshipState{}, err
	}
	return s.State(ctx, request)
}

func (s *GormService) load(ctx context.Context, playerID string, targetPlayerID string) (RelationshipRecord, error) {
	var record RelationshipRecord
	err := s.db.WithContext(ctx).
		First(&record, "player_id = ? AND target_player_id = ?", playerID, targetPlayerID).
		Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return RelationshipRecord{PlayerID: playerID, TargetPlayerID: targetPlayerID}, nil
	}
	return record, err
}

func relationRecord(tx *gorm.DB, playerID string, targetPlayerID string) (RelationshipRecord, error) {
	var record RelationshipRecord
	err := tx.First(&record, "player_id = ? AND target_player_id = ?", playerID, targetPlayerID).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return RelationshipRecord{PlayerID: playerID, TargetPlayerID: targetPlayerID}, nil
	}
	return record, err
}

func stateFromRecords(
	request RelationshipRequest,
	direct RelationshipRecord,
	reverse RelationshipRecord,
) RelationshipState {
	updated := direct.UpdatedUnix
	if reverse.UpdatedUnix > updated {
		updated = reverse.UpdatedUnix
	}
	return RelationshipState{
		PlayerID:       request.PlayerID,
		TargetPlayerID: request.TargetPlayerID,
		Following:      direct.Following,
		FollowedBy:     reverse.Following,
		Blocked:        direct.Blocked,
		BlockedBy:      reverse.Blocked,
		UpdatedAt:      updated,
	}
}
