package minigame

import "context"

func (s *GormSubmissionService) CreateSession(ctx context.Context, request CreateSessionRequest) (Session, error) {
	return s.sessions.CreateSession(ctx, request)
}

func (s *GormSubmissionService) JoinSession(ctx context.Context, request JoinSessionRequest) (Session, error) {
	return s.sessions.JoinSession(ctx, request)
}

func (s *GormSubmissionService) LeaveSession(ctx context.Context, request LeaveSessionRequest) (Session, error) {
	return s.sessions.LeaveSession(ctx, request)
}

func (s *GormSubmissionService) EndSession(ctx context.Context, sessionID string) (Session, error) {
	return s.sessions.EndSession(ctx, sessionID)
}

func (s *GormSubmissionService) GetSession(ctx context.Context, sessionID string) (Session, bool) {
	return s.sessions.GetSession(ctx, sessionID)
}

func (s *GormSubmissionService) ListSessions(ctx context.Context, roomID string) []Session {
	return s.sessions.ListSessions(ctx, roomID)
}
