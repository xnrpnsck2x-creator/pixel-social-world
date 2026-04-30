package minigame

import (
	"context"
	"encoding/json"
	"errors"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

type SubmissionRecord struct {
	GameID              string `gorm:"primaryKey;size:120"`
	Version             string `gorm:"size:40"`
	Author              string `gorm:"index;size:120"`
	ModeID              string `gorm:"index;size:80"`
	NameJSON            string
	MinPlayers          int
	MaxPlayers          int
	TagsJSON            string
	RequiresNetwork     bool
	RuntimeContractJSON string
	EntryScene          string
	MainScript          string
	AssetBudget         int
	Status              string `gorm:"index;size:40"`
	PackageJSON         string
	CreatedUnix         int64
	UpdatedUnix         int64
}

type GormSubmissionService struct {
	db              *gorm.DB
	sessions        Service
	artifactStore   PackageArtifactStore
	packageReviewer PackageAIReviewer
	installStore    PackageInstallStore
}

type GormSubmissionOption func(*GormSubmissionService)

func WithPackageArtifactStore(store PackageArtifactStore) GormSubmissionOption {
	return func(service *GormSubmissionService) {
		if store != nil {
			service.artifactStore = store
		}
	}
}

func WithPackageAIReviewer(reviewer PackageAIReviewer) GormSubmissionOption {
	return func(service *GormSubmissionService) {
		if reviewer != nil {
			service.packageReviewer = reviewer
		}
	}
}

func WithPackageInstallStore(store PackageInstallStore) GormSubmissionOption {
	return func(service *GormSubmissionService) {
		if store != nil {
			service.installStore = store
		}
	}
}

func NewGormSubmissionService(db *gorm.DB, sessions Service, opts ...GormSubmissionOption) Service {
	if sessions == nil {
		sessions = NewMemoryService()
	}
	service := &GormSubmissionService{
		db:              db,
		sessions:        sessions,
		artifactStore:   NewMemoryPackageArtifactStore(),
		packageReviewer: NewDefaultPackageAIReviewer(),
		installStore:    NewMemoryPackageInstallStore(),
	}
	for _, opt := range opts {
		opt(service)
	}
	go service.recoverPackageReviewJobs()
	return service
}

func (s *GormSubmissionService) Submit(ctx context.Context, request SubmitRequest) (Record, error) {
	if err := validateSubmitRequest(request); err != nil {
		return Record{}, err
	}
	record := Record{SubmitRequest: request, Status: "pending_review"}
	return record, s.saveRecord(ctx, record)
}

func (s *GormSubmissionService) SubmitPackage(ctx context.Context, request PackageSubmitRequest) (Record, error) {
	record, err := buildPackageRecord(request)
	if record.GameID == "" {
		return Record{}, err
	}
	if saveErr := s.saveRecord(ctx, record); saveErr != nil {
		return Record{}, saveErr
	}
	return record, err
}

func (s *GormSubmissionService) Get(ctx context.Context, id string) (Record, bool) {
	var row SubmissionRecord
	if err := s.db.WithContext(ctx).First(&row, "game_id = ?", id).Error; err != nil {
		return Record{}, false
	}
	record, err := row.toRecord()
	return record, err == nil
}

func (s *GormSubmissionService) QueueReview(ctx context.Context, id string) Record {
	record, _ := s.SetReviewStatus(ctx, id, "review_queued")
	return record
}

func (s *GormSubmissionService) SetReviewStatus(ctx context.Context, id string, status string) (Record, error) {
	if !allowedReviewStatus(status) {
		return Record{}, errors.New("unsupported_review_status")
	}
	if status == "published" {
		return s.PublishPackage(ctx, id)
	}
	var result Record
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var row SubmissionRecord
		err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).
			First(&row, "game_id = ?", id).Error
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return errors.New("minigame_not_found")
		}
		if err != nil {
			return err
		}
		row.Status = status
		row.UpdatedUnix = time.Now().Unix()
		if err := tx.Save(&row).Error; err != nil {
			return err
		}
		record, err := row.toRecord()
		if err != nil {
			return err
		}
		result = record
		return saveSubmissionVersionTx(tx, record)
	})
	return result, err
}

func (s *GormSubmissionService) saveRecord(ctx context.Context, record Record) error {
	return s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		row, err := submissionRowFromRecord(record)
		if err != nil {
			return err
		}
		if err := tx.Clauses(clause.OnConflict{
			Columns:   []clause.Column{{Name: "game_id"}},
			UpdateAll: true,
		}).Create(&row).Error; err != nil {
			return err
		}
		return saveSubmissionVersionTx(tx, record)
	})
}

func (s *GormSubmissionService) saveScanRecord(ctx context.Context, record Record) error {
	return s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var row SubmissionRecord
		err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).
			First(&row, "game_id = ?", record.GameID).Error
		if errors.Is(err, gorm.ErrRecordNotFound) {
			next, err := submissionRowFromRecord(record)
			if err != nil {
				return err
			}
			if err := tx.Create(&next).Error; err != nil {
				return err
			}
			return saveSubmissionVersionTx(tx, record)
		}
		if err != nil {
			return err
		}
		if !packageScanMutableStatus(row.Status) {
			return nil
		}
		next, err := submissionRowFromRecord(record)
		if err != nil {
			return err
		}
		next.CreatedUnix = row.CreatedUnix
		if err := tx.Save(&next).Error; err != nil {
			return err
		}
		return saveSubmissionVersionTx(tx, record)
	})
}

func submissionRowFromRecord(record Record) (SubmissionRecord, error) {
	nameJSON, err := marshalString(record.Name)
	if err != nil {
		return SubmissionRecord{}, err
	}
	tagsJSON, err := marshalString(record.Tags)
	if err != nil {
		return SubmissionRecord{}, err
	}
	runtimeJSON, err := marshalString(record.RuntimeContract)
	if err != nil {
		return SubmissionRecord{}, err
	}
	packageJSON, err := marshalString(record.Package)
	if err != nil {
		return SubmissionRecord{}, err
	}
	now := time.Now().Unix()
	return SubmissionRecord{
		GameID:              record.GameID,
		Version:             record.Version,
		Author:              record.Author,
		ModeID:              record.ModeID,
		NameJSON:            nameJSON,
		MinPlayers:          record.MinPlayers,
		MaxPlayers:          record.MaxPlayers,
		TagsJSON:            tagsJSON,
		RequiresNetwork:     record.RequiresNetwork,
		RuntimeContractJSON: runtimeJSON,
		EntryScene:          record.EntryScene,
		MainScript:          record.MainScript,
		AssetBudget:         record.AssetBudget,
		Status:              record.Status,
		PackageJSON:         packageJSON,
		CreatedUnix:         now,
		UpdatedUnix:         now,
	}, nil
}

func (r SubmissionRecord) toRecord() (Record, error) {
	name := map[string]string{}
	if err := unmarshalString(r.NameJSON, &name); err != nil {
		return Record{}, err
	}
	tags := []string{}
	if err := unmarshalString(r.TagsJSON, &tags); err != nil {
		return Record{}, err
	}
	runtimeContract := map[string]any{}
	if err := unmarshalString(r.RuntimeContractJSON, &runtimeContract); err != nil {
		return Record{}, err
	}
	var snapshot *PackageSnapshot
	if r.PackageJSON != "" && r.PackageJSON != "null" {
		var parsed PackageSnapshot
		if err := unmarshalString(r.PackageJSON, &parsed); err != nil {
			return Record{}, err
		}
		snapshot = &parsed
	}
	return Record{
		SubmitRequest: SubmitRequest{
			GameID:          r.GameID,
			Version:         r.Version,
			Author:          r.Author,
			ModeID:          r.ModeID,
			Name:            name,
			MinPlayers:      r.MinPlayers,
			MaxPlayers:      r.MaxPlayers,
			Tags:            tags,
			RequiresNetwork: r.RequiresNetwork,
			RuntimeContract: runtimeContract,
			EntryScene:      r.EntryScene,
			MainScript:      r.MainScript,
			AssetBudget:     r.AssetBudget,
		},
		Status:  r.Status,
		Package: snapshot,
	}, nil
}

func marshalString(value any) (string, error) {
	encoded, err := json.Marshal(value)
	if err != nil {
		return "", err
	}
	return string(encoded), nil
}

func unmarshalString(raw string, target any) error {
	if raw == "" {
		return nil
	}
	return json.Unmarshal([]byte(raw), target)
}
