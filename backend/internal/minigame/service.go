package minigame

import (
	"context"
	"errors"
	"sync"
)

type SubmitRequest struct {
	GameID          string            `json:"game_id"`
	Version         string            `json:"version"`
	Author          string            `json:"author"`
	ModeID          string            `json:"mode_id"`
	Name            map[string]string `json:"name"`
	MinPlayers      int               `json:"min_players"`
	MaxPlayers      int               `json:"max_players"`
	Tags            []string          `json:"tags"`
	RequiresNetwork bool              `json:"requires_network"`
	RuntimeContract map[string]any    `json:"runtime_contract"`
	EntryScene      string            `json:"entry_scene"`
	MainScript      string            `json:"main_script"`
	AssetBudget     int               `json:"asset_budget_bytes"`
}

type Record struct {
	SubmitRequest
	Status  string           `json:"status"`
	Package *PackageSnapshot `json:"package,omitempty"`
}

type CreateSessionRequest struct {
	GameID       string `json:"game_id"`
	RoomID       string `json:"room_id"`
	HostPlayerID string `json:"host_player_id"`
	MaxPlayers   int    `json:"max_players"`
}

type JoinSessionRequest struct {
	SessionID string `json:"session_id"`
	PlayerID  string `json:"player_id"`
}

type LeaveSessionRequest struct {
	SessionID string `json:"session_id"`
	PlayerID  string `json:"player_id"`
}

type Session struct {
	ID           string   `json:"id"`
	GameID       string   `json:"game_id"`
	RoomID       string   `json:"room_id"`
	HostPlayerID string   `json:"host_player_id"`
	Status       string   `json:"status"`
	Players      []string `json:"players"`
	MaxPlayers   int      `json:"max_players"`
	Version      int      `json:"version"`
	CreatedAt    int64    `json:"created_at"`
	UpdatedAt    int64    `json:"updated_at"`
	ExpiresAt    int64    `json:"expires_at"`
}

type Service interface {
	Submit(ctx context.Context, request SubmitRequest) (Record, error)
	SubmitPackage(ctx context.Context, request PackageSubmitRequest) (Record, error)
	SubmitPackageAsync(ctx context.Context, request PackageSubmitRequest) (Record, error)
	Get(ctx context.Context, id string) (Record, bool)
	SubmissionHistory(ctx context.Context, id string) (SubmissionHistorySnapshot, error)
	QueueReview(ctx context.Context, id string) Record
	SetReviewStatus(ctx context.Context, id string, status string) (Record, error)
	PublishPackage(ctx context.Context, id string) (Record, error)
	RollbackPackage(ctx context.Context, id string) (Record, error)
	UnpublishPackage(ctx context.Context, id string) (Record, error)
	ListPublishedPackages(ctx context.Context) ([]PackageInstallSnapshot, error)
	ReviewDashboard(ctx context.Context) (ReviewDashboardSnapshot, error)
	RecordReviewAudit(ctx context.Context, event ReviewAuditEvent) error
	ReviewAudit(ctx context.Context, id string) (ReviewAuditSnapshot, error)
	CreateSession(ctx context.Context, request CreateSessionRequest) (Session, error)
	JoinSession(ctx context.Context, request JoinSessionRequest) (Session, error)
	LeaveSession(ctx context.Context, request LeaveSessionRequest) (Session, error)
	EndSession(ctx context.Context, sessionID string) (Session, error)
	GetSession(ctx context.Context, sessionID string) (Session, bool)
	ListSessions(ctx context.Context, roomID string) []Session
}

type MemoryService struct {
	mu              sync.RWMutex
	records         map[string]Record
	versionRecords  map[string]map[string]SubmissionVersionSnapshot
	reviewJobs      map[string]PackageReviewJobSnapshot
	sessions        map[string]Session
	sessionSequence int
	artifactStore   PackageArtifactStore
	packageReviewer PackageAIReviewer
	installStore    PackageInstallStore
	reviewAudit     []ReviewAuditEvent
}

var creatorModePlayerCaps = map[string]int{
	"casual_activity":  4,
	"side_scroller_2d": 4,
	"2d_fighting":      4,
	"strategy_war":     4,
	"rpg_adventure":    4,
	"tower_defense":    4,
	"battle_royale":    16,
}

func NewMemoryService() Service {
	return NewMemoryServiceConcrete()
}

func NewMemoryServiceConcrete() *MemoryService {
	return &MemoryService{
		records:         make(map[string]Record),
		versionRecords:  map[string]map[string]SubmissionVersionSnapshot{},
		reviewJobs:      map[string]PackageReviewJobSnapshot{},
		sessions:        map[string]Session{},
		artifactStore:   NewMemoryPackageArtifactStore(),
		packageReviewer: NewDefaultPackageAIReviewer(),
		installStore:    NewMemoryPackageInstallStore(),
	}
}

func NewMemoryServiceWithPackageStore(store PackageArtifactStore) *MemoryService {
	return NewMemoryServiceWithPackageStores(store, nil)
}

func NewMemoryServiceWithPackageStores(
	store PackageArtifactStore,
	installStore PackageInstallStore,
) *MemoryService {
	service := NewMemoryServiceConcrete()
	if store != nil {
		service.artifactStore = store
	}
	if installStore != nil {
		service.installStore = installStore
	}
	return service
}

func NewMemoryServiceWithReviewDeps(
	store PackageArtifactStore,
	reviewer PackageAIReviewer,
) *MemoryService {
	service := NewMemoryServiceWithPackageStore(store)
	if reviewer != nil {
		service.packageReviewer = reviewer
	}
	return service
}

func NewMemoryServiceWithPackageDeps(
	store PackageArtifactStore,
	installStore PackageInstallStore,
	reviewer PackageAIReviewer,
) *MemoryService {
	service := NewMemoryServiceWithPackageStores(store, installStore)
	if reviewer != nil {
		service.packageReviewer = reviewer
	}
	return service
}

func (s *MemoryService) Submit(_ context.Context, request SubmitRequest) (Record, error) {
	if err := validateSubmitRequest(request); err != nil {
		return Record{}, err
	}

	record := Record{SubmitRequest: request, Status: "pending_review"}
	s.mu.Lock()
	s.records[request.GameID] = record
	s.storeSubmissionVersionLocked(record)
	s.mu.Unlock()
	return record, nil
}

func (s *MemoryService) Get(_ context.Context, id string) (Record, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	record, ok := s.records[id]
	return record, ok
}

func (s *MemoryService) QueueReview(_ context.Context, id string) Record {
	s.mu.Lock()
	defer s.mu.Unlock()
	record := s.records[id]
	record.Status = "review_queued"
	s.records[id] = record
	s.storeSubmissionVersionLocked(record)
	return record
}

func (s *MemoryService) SetReviewStatus(ctx context.Context, id string, status string) (Record, error) {
	if !allowedReviewStatus(status) {
		return Record{}, errors.New("unsupported_review_status")
	}
	if status == "published" {
		return s.PublishPackage(ctx, id)
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	record, ok := s.records[id]
	if !ok {
		return Record{}, errors.New("minigame_not_found")
	}
	record.Status = status
	s.records[id] = record
	s.storeSubmissionVersionLocked(record)
	return record, nil
}
