package utility

import "testing"

func TestPanelRecordRoundTripStripsRuntimeScope(t *testing.T) {
	panels := DefaultPanels()
	panels.PlayerID = "player_1"
	panels.ServerTime = 12345
	record, err := NewPanelRecord(panels)
	if err != nil {
		t.Fatalf("NewPanelRecord returned error: %v", err)
	}
	if record.ID != activePanelRecordID || record.PanelsJSON == "" || record.UpdatedAt == 0 {
		t.Fatalf("record missing persistence fields: %#v", record)
	}
	restored, err := record.ToPanels()
	if err != nil {
		t.Fatalf("ToPanels returned error: %v", err)
	}
	if restored.PlayerID != "" || restored.ServerTime != 0 {
		t.Fatalf("runtime scope leaked into stored panels: %#v", restored)
	}
	if len(restored.Shop.Items) != len(panels.Shop.Items) {
		t.Fatalf("shop items changed after round trip: %#v", restored.Shop)
	}
}

func TestPanelRecordRejectsInvalidPanels(t *testing.T) {
	panels := DefaultPanels()
	panels.Shop.Items[0].ActionID = ""
	if _, err := NewPanelRecord(panels); err == nil {
		t.Fatal("expected invalid shop offer to fail")
	}
}

func TestPanelRecordRejectsInvalidJSON(t *testing.T) {
	record := PanelRecord{ID: activePanelRecordID, PanelsJSON: "{", UpdatedAt: 1}
	if _, err := record.ToPanels(); err == nil {
		t.Fatal("expected invalid JSON to fail")
	}
}
