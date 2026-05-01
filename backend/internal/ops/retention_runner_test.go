package ops

import (
	"context"
	"testing"
	"time"
)

func TestSafeSQLIdent(t *testing.T) {
	valid := []string{"private_message_records", "created_unix", "report_records_2"}
	for _, value := range valid {
		if !safeSQLIdent(value) {
			t.Fatalf("expected %q to be safe", value)
		}
	}
	invalid := []string{"", "_hidden", "ReportRecords", "records;drop", "records-name"}
	for _, value := range invalid {
		if safeSQLIdent(value) {
			t.Fatalf("expected %q to be unsafe", value)
		}
	}
}

func TestRunPostgresRetentionCleanupSkipsNonPostgresTasks(t *testing.T) {
	policy := DefaultRetentionPolicy()
	policy.PrivateMessageDays = 0
	policy.MailboxDays = 0
	policy.ReportDays = 0
	policy.LedgerDays = 0
	policy.CreatorAuditDays = 0
	results, err := RunPostgresRetentionCleanup(context.Background(), nil, policy, time.Unix(2000, 0), true)
	if err != nil {
		t.Fatal(err)
	}
	if len(results) == 0 {
		t.Fatal("expected retention cleanup results")
	}
	if !results[0].Skipped || results[0].Name != "room_chat_history" {
		t.Fatalf("expected room chat to be skipped: %#v", results[0])
	}
}
