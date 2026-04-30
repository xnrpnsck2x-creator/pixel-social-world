package utility

import (
	"context"
	"encoding/json"
	"errors"
	"os"
	"sync"
	"time"
)

type ShopOffer struct {
	ID        string `json:"id"`
	ItemID    string `json:"item_id"`
	ActionID  string `json:"action_id"`
	ActionKey string `json:"action_key"`
}

type Message struct {
	ID         string `json:"id"`
	SenderKey  string `json:"sender_key,omitempty"`
	SubjectKey string `json:"subject_key"`
	BodyKey    string `json:"body_key"`
	IconID     string `json:"icon_id"`
	ActionID   string `json:"action_id"`
	ActionKey  string `json:"action_key"`
	CreatedAt  int64  `json:"created_at,omitempty"`
}

type ShopPanel struct {
	Items []ShopOffer `json:"items"`
}

type MailPanel struct {
	Messages []Message `json:"messages"`
}

type NoticePanel struct {
	Notices []Message `json:"notices"`
}

type Panels struct {
	SchemaVersion int         `json:"schema_version"`
	Shop          ShopPanel   `json:"shop"`
	Mail          MailPanel   `json:"mail"`
	Notice        NoticePanel `json:"notice"`
	PlayerID      string      `json:"player_id,omitempty"`
	ServerTime    int64       `json:"server_time,omitempty"`
}

type Service interface {
	Panels(ctx context.Context, playerID string) (Panels, error)
	Shop(ctx context.Context, playerID string) (ShopPanel, error)
	Mail(ctx context.Context, playerID string) (MailPanel, error)
	Notices(ctx context.Context, playerID string) (NoticePanel, error)
	UpdatePanels(ctx context.Context, panels Panels) (Panels, error)
}

type StaticService struct {
	mu     sync.RWMutex
	panels Panels
}

func NewStaticService(panels Panels) *StaticService {
	if panels.SchemaVersion <= 0 {
		panels = DefaultPanels()
	}
	return &StaticService{panels: clonePanels(panels)}
}

func NewDefaultService() *StaticService {
	panels, err := LoadPanels("")
	if err != nil {
		panels = DefaultPanels()
	}
	return NewStaticService(panels)
}

func LoadPanels(path string) (Panels, error) {
	bytes, err := readPanelsConfig(path)
	if err != nil {
		return Panels{}, err
	}
	var panels Panels
	if err := json.Unmarshal(bytes, &panels); err != nil {
		return Panels{}, err
	}
	if err := validatePanels(panels); err != nil {
		return Panels{}, err
	}
	return panels, nil
}

func (s *StaticService) Panels(ctx context.Context, playerID string) (Panels, error) {
	if err := ctx.Err(); err != nil {
		return Panels{}, err
	}
	if playerID == "" {
		return Panels{}, errors.New("player_required")
	}
	s.mu.RLock()
	panels := clonePanels(s.panels)
	s.mu.RUnlock()
	panels.PlayerID = playerID
	panels.ServerTime = time.Now().Unix()
	return panels, nil
}

func (s *StaticService) Shop(ctx context.Context, playerID string) (ShopPanel, error) {
	panels, err := s.Panels(ctx, playerID)
	return panels.Shop, err
}

func (s *StaticService) Mail(ctx context.Context, playerID string) (MailPanel, error) {
	panels, err := s.Panels(ctx, playerID)
	return panels.Mail, err
}

func (s *StaticService) Notices(ctx context.Context, playerID string) (NoticePanel, error) {
	panels, err := s.Panels(ctx, playerID)
	return panels.Notice, err
}

func (s *StaticService) UpdatePanels(ctx context.Context, panels Panels) (Panels, error) {
	if err := ctx.Err(); err != nil {
		return Panels{}, err
	}
	if err := validatePanels(panels); err != nil {
		return Panels{}, err
	}
	updated := clonePanels(panels)
	s.mu.Lock()
	s.panels = updated
	s.mu.Unlock()
	updated.ServerTime = time.Now().Unix()
	return updated, nil
}

func DefaultPanels() Panels {
	return Panels{
		SchemaVersion: 1,
		Shop: ShopPanel{Items: []ShopOffer{
			{ID: "starter_wallpaper_offer", ItemID: "starter_wallpaper", ActionID: "home", ActionKey: "world.panel.action.home"},
			{ID: "wooden_floor_offer", ItemID: "wooden_floor", ActionID: "home", ActionKey: "world.panel.action.home"},
			{ID: "simple_chair_offer", ItemID: "simple_chair", ActionID: "home", ActionKey: "world.panel.action.home"},
		}},
		Mail: MailPanel{Messages: []Message{
			{
				ID:         "welcome_home",
				SenderKey:  "mail.sender.town_office",
				SubjectKey: "mail.welcome.subject",
				BodyKey:    "mail.welcome.body",
				IconID:     "icon.mail",
				ActionID:   "home",
				ActionKey:  "world.panel.action.home",
			},
		}},
		Notice: NoticePanel{Notices: []Message{
			{
				ID:         "creator_alpha_call",
				SubjectKey: "notice.creator_alpha.subject",
				BodyKey:    "notice.creator_alpha.body",
				IconID:     "icon.quest",
				ActionID:   "creator",
				ActionKey:  "world.panel.action.creator",
			},
		}},
	}
}

func readPanelsConfig(path string) ([]byte, error) {
	paths := []string{}
	if path != "" {
		paths = append(paths, path)
	}
	paths = append(paths,
		"configs/utility_panels.json",
		"../configs/utility_panels.json",
		"../../configs/utility_panels.json",
		"../../../configs/utility_panels.json",
	)
	var firstErr error
	for _, candidate := range paths {
		bytes, err := os.ReadFile(candidate)
		if err == nil {
			return bytes, nil
		}
		if firstErr == nil {
			firstErr = err
		}
	}
	return nil, firstErr
}

func validatePanels(panels Panels) error {
	if panels.SchemaVersion <= 0 {
		return errors.New("utility_schema_version_required")
	}
	for _, offer := range panels.Shop.Items {
		if offer.ID == "" || offer.ItemID == "" || offer.ActionID == "" || offer.ActionKey == "" {
			return errors.New("invalid_shop_offer")
		}
	}
	for _, message := range panels.Mail.Messages {
		if err := validateMessage(message, true); err != nil {
			return err
		}
	}
	for _, notice := range panels.Notice.Notices {
		if err := validateMessage(notice, false); err != nil {
			return err
		}
	}
	return nil
}

func validateMessage(message Message, requireSender bool) error {
	if message.ID == "" || message.SubjectKey == "" || message.BodyKey == "" || message.IconID == "" ||
		message.ActionID == "" || message.ActionKey == "" {
		return errors.New("invalid_utility_message")
	}
	if requireSender && message.SenderKey == "" {
		return errors.New("invalid_utility_message")
	}
	return nil
}

func clonePanels(panels Panels) Panels {
	panels.Shop.Items = append([]ShopOffer{}, panels.Shop.Items...)
	panels.Mail.Messages = append([]Message{}, panels.Mail.Messages...)
	panels.Notice.Notices = append([]Message{}, panels.Notice.Notices...)
	return panels
}
