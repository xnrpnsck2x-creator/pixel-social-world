package utility

import (
	"context"
	"testing"
)

func TestStaticServiceReturnsPlayerScopedPanels(t *testing.T) {
	service := NewStaticService(Panels{
		SchemaVersion: 1,
		Shop: ShopPanel{Items: []ShopOffer{
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
	})
	panels, err := service.Panels(context.Background(), "player_1")
	if err != nil {
		t.Fatalf("Panels returned error: %v", err)
	}
	if panels.PlayerID != "player_1" || panels.ServerTime == 0 {
		t.Fatalf("panels did not include player scope and server time: %#v", panels)
	}
	if len(panels.Shop.Items) != 1 || panels.Shop.Items[0].ItemID != "simple_chair" {
		t.Fatalf("shop panel changed: %#v", panels.Shop)
	}
	if len(panels.Mail.Messages) != 1 || panels.Mail.Messages[0].SenderKey == "" {
		t.Fatalf("mail panel changed: %#v", panels.Mail)
	}
}

func TestStaticServiceRequiresPlayer(t *testing.T) {
	service := NewStaticService(DefaultPanels())
	if _, err := service.Panels(context.Background(), ""); err == nil {
		t.Fatal("expected empty player id to fail")
	}
}

func TestValidatePanelsRejectsBadMessages(t *testing.T) {
	panels := DefaultPanels()
	panels.Mail.Messages[0].SenderKey = ""
	if err := validatePanels(panels); err == nil {
		t.Fatal("expected missing mail sender to fail")
	}
}
