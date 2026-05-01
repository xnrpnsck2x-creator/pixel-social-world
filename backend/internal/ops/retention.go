package ops

type RetentionPolicy struct {
	RoomChatHistoryDays        int `json:"room_chat_history_days"`
	PrivateMessageDays         int `json:"private_message_days"`
	MailboxDays                int `json:"mailbox_days"`
	ReportDays                 int `json:"report_days"`
	LedgerDays                 int `json:"ledger_days"`
	CreatorAuditDays           int `json:"creator_audit_days"`
	CreatorArtifactStagingDays int `json:"creator_artifact_staging_days"`
}

func DefaultRetentionPolicy() RetentionPolicy {
	return RetentionPolicy{
		RoomChatHistoryDays:        0,
		PrivateMessageDays:         365,
		MailboxDays:                365,
		ReportDays:                 730,
		LedgerDays:                 2555,
		CreatorAuditDays:           730,
		CreatorArtifactStagingDays: 30,
	}
}

func NormalizeRetentionPolicy(policy RetentionPolicy) RetentionPolicy {
	if IsZeroRetentionPolicy(policy) {
		return DefaultRetentionPolicy()
	}
	if policy.RoomChatHistoryDays < 0 {
		policy.RoomChatHistoryDays = 0
	}
	if policy.PrivateMessageDays < 0 {
		policy.PrivateMessageDays = 0
	}
	if policy.MailboxDays < 0 {
		policy.MailboxDays = 0
	}
	if policy.ReportDays < 0 {
		policy.ReportDays = 0
	}
	if policy.LedgerDays < 0 {
		policy.LedgerDays = 0
	}
	if policy.CreatorAuditDays < 0 {
		policy.CreatorAuditDays = 0
	}
	if policy.CreatorArtifactStagingDays < 0 {
		policy.CreatorArtifactStagingDays = 0
	}
	return policy
}

func IsZeroRetentionPolicy(policy RetentionPolicy) bool {
	return policy.RoomChatHistoryDays == 0 &&
		policy.PrivateMessageDays == 0 &&
		policy.MailboxDays == 0 &&
		policy.ReportDays == 0 &&
		policy.LedgerDays == 0 &&
		policy.CreatorAuditDays == 0 &&
		policy.CreatorArtifactStagingDays == 0
}
