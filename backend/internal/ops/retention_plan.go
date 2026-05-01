package ops

import "fmt"

type RetentionCleanupTask struct {
	Name          string `json:"name"`
	Storage       string `json:"storage"`
	Table         string `json:"table,omitempty"`
	Column        string `json:"column,omitempty"`
	RetentionDays int    `json:"retention_days"`
	Ephemeral     bool   `json:"ephemeral"`
	SQL           string `json:"sql,omitempty"`
}

func BuildRetentionCleanupPlan(policy RetentionPolicy) []RetentionCleanupTask {
	policy = NormalizeRetentionPolicy(policy)
	return []RetentionCleanupTask{
		{
			Name:          "room_chat_history",
			Storage:       "memory_only",
			RetentionDays: policy.RoomChatHistoryDays,
			Ephemeral:     true,
		},
		sqlCleanupTask("private_messages", "private_message_records", "created_unix", policy.PrivateMessageDays),
		sqlCleanupTask("mailbox_messages", "mail_message_records", "created_unix", policy.MailboxDays),
		sqlCleanupTask("chat_reports", "report_records", "created_at", policy.ReportDays),
		sqlCleanupTask("private_reports", "private_report_records", "created_unix", policy.ReportDays),
		sqlCleanupTask("economy_ledger", "ledger_records", "created_unix", policy.LedgerDays),
		sqlCleanupTask("creator_submissions", "submission_records", "updated_unix", policy.CreatorAuditDays),
		sqlCleanupTask("creator_review_audit", "review_audit_records", "created_unix", policy.CreatorAuditDays),
		sqlCleanupTask("creator_review_jobs", "package_review_job_records", "updated_unix", policy.CreatorAuditDays),
		{
			Name:          "creator_artifact_staging",
			Storage:       "filesystem",
			RetentionDays: policy.CreatorArtifactStagingDays,
		},
	}
}

func sqlCleanupTask(name string, table string, column string, days int) RetentionCleanupTask {
	return RetentionCleanupTask{
		Name:          name,
		Storage:       "postgres",
		Table:         table,
		Column:        column,
		RetentionDays: days,
		SQL:           fmt.Sprintf("DELETE FROM %s WHERE %s < $1", table, column),
	}
}
