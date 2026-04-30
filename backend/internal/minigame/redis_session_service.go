package minigame

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	goredis "github.com/redis/go-redis/v9"
)

type RedisSessionService struct {
	records *MemoryService
	client  *goredis.Client
	ttl     time.Duration
}

func NewRedisSessionService(client *goredis.Client, ttl time.Duration) Service {
	return NewRedisSessionServiceWithPackageStore(client, ttl, nil)
}

func NewRedisSessionServiceWithPackageStore(
	client *goredis.Client,
	ttl time.Duration,
	store PackageArtifactStore,
) Service {
	return NewRedisSessionServiceWithPackageStores(client, ttl, store, nil)
}

func NewRedisSessionServiceWithPackageStores(
	client *goredis.Client,
	ttl time.Duration,
	store PackageArtifactStore,
	installStore PackageInstallStore,
) Service {
	return NewRedisSessionServiceWithPackageDeps(client, ttl, store, installStore, nil)
}

func NewRedisSessionServiceWithPackageDeps(
	client *goredis.Client,
	ttl time.Duration,
	store PackageArtifactStore,
	installStore PackageInstallStore,
	reviewer PackageAIReviewer,
) Service {
	if ttl <= 0 {
		ttl = 15 * time.Minute
	}
	records := NewMemoryServiceConcrete()
	if store != nil {
		records.artifactStore = store
	}
	if installStore != nil {
		records.installStore = installStore
	}
	if reviewer != nil {
		records.packageReviewer = reviewer
	}
	return &RedisSessionService{
		records: records,
		client:  client,
		ttl:     ttl,
	}
}

func (s *RedisSessionService) Submit(ctx context.Context, request SubmitRequest) (Record, error) {
	return s.records.Submit(ctx, request)
}

func (s *RedisSessionService) SubmitPackage(ctx context.Context, request PackageSubmitRequest) (Record, error) {
	return s.records.SubmitPackage(ctx, request)
}

func (s *RedisSessionService) SubmitPackageAsync(ctx context.Context, request PackageSubmitRequest) (Record, error) {
	return s.records.SubmitPackageAsync(ctx, request)
}

func (s *RedisSessionService) Get(ctx context.Context, id string) (Record, bool) {
	return s.records.Get(ctx, id)
}

func (s *RedisSessionService) QueueReview(ctx context.Context, id string) Record {
	return s.records.QueueReview(ctx, id)
}

func (s *RedisSessionService) SetReviewStatus(ctx context.Context, id string, status string) (Record, error) {
	return s.records.SetReviewStatus(ctx, id, status)
}

func (s *RedisSessionService) PublishPackage(ctx context.Context, id string) (Record, error) {
	return s.records.PublishPackage(ctx, id)
}

func (s *RedisSessionService) RollbackPackage(ctx context.Context, id string) (Record, error) {
	return s.records.RollbackPackage(ctx, id)
}

func (s *RedisSessionService) UnpublishPackage(ctx context.Context, id string) (Record, error) {
	return s.records.UnpublishPackage(ctx, id)
}

func (s *RedisSessionService) ListPublishedPackages(ctx context.Context) ([]PackageInstallSnapshot, error) {
	return s.records.ListPublishedPackages(ctx)
}

func (s *RedisSessionService) CreateSession(ctx context.Context, request CreateSessionRequest) (Session, error) {
	if request.GameID == "" {
		return Session{}, errors.New("game_id_required")
	}
	request.RoomID = normalize(request.RoomID, "world_town_square")
	request.HostPlayerID = normalize(request.HostPlayerID, "offline-player")
	if request.MaxPlayers <= 0 {
		request.MaxPlayers = s.records.maxPlayersForGame(request.GameID)
	}
	status := "waiting"
	if request.MaxPlayers <= 1 {
		status = "active"
	}
	sequence, err := s.client.Incr(ctx, "minigame_session:counter").Result()
	if err != nil {
		return Session{}, err
	}
	now := time.Now().Unix()
	session := Session{
		ID:           fmt.Sprintf("session_%06d", sequence),
		GameID:       request.GameID,
		RoomID:       request.RoomID,
		HostPlayerID: request.HostPlayerID,
		Status:       status,
		Players:      []string{request.HostPlayerID},
		MaxPlayers:   request.MaxPlayers,
		Version:      1,
		CreatedAt:    now,
		UpdatedAt:    now,
		ExpiresAt:    time.Now().Add(s.ttl).Unix(),
	}
	if err := s.saveSession(ctx, session); err != nil {
		return Session{}, err
	}
	return session, nil
}

func (s *RedisSessionService) JoinSession(ctx context.Context, request JoinSessionRequest) (Session, error) {
	request.PlayerID = normalize(request.PlayerID, "offline-player")
	return s.mutateSession(ctx, request.SessionID, func(session Session) (Session, error) {
		if session.Status == "ended" {
			return Session{}, errors.New("session_ended")
		}
		if containsPlayer(session.Players, request.PlayerID) {
			return session, nil
		}
		if len(session.Players) >= session.MaxPlayers {
			return Session{}, errors.New("session_full")
		}
		session.Players = append(session.Players, request.PlayerID)
		if len(session.Players) >= session.MaxPlayers {
			session.Status = "active"
		}
		session.Version++
		session.UpdatedAt = time.Now().Unix()
		return session, nil
	})
}

func (s *RedisSessionService) LeaveSession(ctx context.Context, request LeaveSessionRequest) (Session, error) {
	request.PlayerID = normalize(request.PlayerID, "offline-player")
	session, err := s.mutateSession(ctx, request.SessionID, func(session Session) (Session, error) {
		session.Players = removePlayer(session.Players, request.PlayerID)
		if len(session.Players) == 0 {
			session.Status = "ended"
		} else if session.HostPlayerID == request.PlayerID {
			session.HostPlayerID = session.Players[0]
		}
		session.Version++
		session.UpdatedAt = time.Now().Unix()
		return session, nil
	})
	if err == nil && session.Status == "ended" {
		_ = s.client.SRem(ctx, roomSessionsKey(session.RoomID), session.ID).Err()
	}
	return session, err
}

func (s *RedisSessionService) EndSession(ctx context.Context, sessionID string) (Session, error) {
	session, err := s.mutateSession(ctx, sessionID, func(session Session) (Session, error) {
		session.Status = "ended"
		session.Version++
		session.UpdatedAt = time.Now().Unix()
		return session, nil
	})
	if err == nil {
		_ = s.client.SRem(ctx, roomSessionsKey(session.RoomID), session.ID).Err()
	}
	return session, err
}

func (s *RedisSessionService) GetSession(ctx context.Context, sessionID string) (Session, bool) {
	session, err := s.loadSession(ctx, sessionID)
	return session, err == nil && session.Status != "ended"
}

func (s *RedisSessionService) ListSessions(ctx context.Context, roomID string) []Session {
	roomID = normalize(roomID, "world_town_square")
	ids, err := s.client.SMembers(ctx, roomSessionsKey(roomID)).Result()
	if err != nil {
		return []Session{}
	}
	sessions := []Session{}
	for _, id := range ids {
		session, err := s.loadSession(ctx, id)
		if err == goredis.Nil {
			_ = s.client.SRem(ctx, roomSessionsKey(roomID), id).Err()
			continue
		}
		if err == nil && session.Status != "ended" {
			sessions = append(sessions, session)
		}
	}
	return sessions
}

func (s *RedisSessionService) mutateSession(
	ctx context.Context,
	sessionID string,
	mutator func(Session) (Session, error),
) (Session, error) {
	key := sessionKey(sessionID)
	var result Session
	for attempt := 0; attempt < 8; attempt++ {
		err := s.client.Watch(ctx, func(tx *goredis.Tx) error {
			raw, err := tx.Get(ctx, key).Result()
			if err != nil {
				return err
			}
			var session Session
			if err := json.Unmarshal([]byte(raw), &session); err != nil {
				return err
			}
			session, err = mutator(session)
			if err != nil {
				return err
			}
			session.ExpiresAt = time.Now().Add(s.ttl).Unix()
			encoded, err := json.Marshal(session)
			if err != nil {
				return err
			}
			_, err = tx.TxPipelined(ctx, func(pipe goredis.Pipeliner) error {
				pipe.Set(ctx, key, encoded, s.ttl)
				pipe.SAdd(ctx, roomSessionsKey(session.RoomID), session.ID)
				pipe.Expire(ctx, roomSessionsKey(session.RoomID), s.ttl*2)
				return nil
			})
			result = session
			return err
		}, key)
		if err == goredis.TxFailedErr {
			continue
		}
		if err == goredis.Nil {
			return Session{}, errors.New("session_not_found")
		}
		return result, err
	}
	return Session{}, errors.New("session_conflict")
}

func (s *RedisSessionService) saveSession(ctx context.Context, session Session) error {
	encoded, err := json.Marshal(session)
	if err != nil {
		return err
	}
	pipe := s.client.TxPipeline()
	pipe.Set(ctx, sessionKey(session.ID), encoded, s.ttl)
	pipe.SAdd(ctx, roomSessionsKey(session.RoomID), session.ID)
	pipe.Expire(ctx, roomSessionsKey(session.RoomID), s.ttl*2)
	_, err = pipe.Exec(ctx)
	return err
}

func (s *RedisSessionService) loadSession(ctx context.Context, sessionID string) (Session, error) {
	raw, err := s.client.Get(ctx, sessionKey(sessionID)).Result()
	if err != nil {
		return Session{}, err
	}
	var session Session
	if err := json.Unmarshal([]byte(raw), &session); err != nil {
		return Session{}, err
	}
	return session, nil
}
