package ops

import "testing"

func TestBuildRetentionCleanupPlanKeepsRoomChatEphemeral(t *testing.T) {
	plan := BuildRetentionCleanupPlan(DefaultRetentionPolicy())
	if len(plan) == 0 {
		t.Fatal("expected retention cleanup tasks")
	}
	roomChat := plan[0]
	if !roomChat.Ephemeral || roomChat.RetentionDays != 0 || roomChat.SQL != "" {
		t.Fatalf("room chat cleanup task must stay memory-only and ephemeral: %#v", roomChat)
	}
	if !containsCleanupTask(plan, "private_messages", "private_message_records") {
		t.Fatalf("cleanup plan missing private messages task: %#v", plan)
	}
	if !containsCleanupTask(plan, "economy_ledger", "ledger_records") {
		t.Fatalf("cleanup plan missing ledger task: %#v", plan)
	}
}

func containsCleanupTask(plan []RetentionCleanupTask, name string, table string) bool {
	for _, task := range plan {
		if task.Name == name && task.Table == table && task.SQL != "" {
			return true
		}
	}
	return false
}
