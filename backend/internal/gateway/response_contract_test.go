package gateway

import (
	"net/http"
	"testing"
)

func TestHighRiskResponseContractsTradeEconomyInventoryLiveOps(t *testing.T) {
	deps := DefaultMemoryDependencies()
	deps.AdminToken = "viewer:view-token,owner:owner-token"
	server := NewServerWithDependencies(deps)
	seller := testGuestLogin(t, server, "Contract Seller")
	buyer := testGuestLogin(t, server, "Contract Buyer")
	creator := testGuestLogin(t, server, "Contract Creator")
	sellerID := seller["player_id"].(string)
	sellerToken := seller["access_token"].(string)
	buyerID := buyer["player_id"].(string)
	buyerToken := buyer["access_token"].(string)
	creatorID := creator["player_id"].(string)

	created := testPostJSON(t, server, "/trade/listings", sellerToken, map[string]any{
		"seller_id": sellerID,
		"item_id":   "simple_chair",
		"title_key": "facility.trade.listing.simple_chair.title",
		"body_key":  "facility.trade.listing.simple_chair.body",
		"icon_id":   "icon.home",
		"price":     7,
	}, http.StatusCreated)
	contractFields(t, "trade create response", created, "listing")
	listing := contractMap(t, "created listing", created["listing"])
	contractFields(t, "created listing", listing,
		"id", "seller_id", "item_id", "title_key", "body_key", "icon_id",
		"price", "status", "escrow_status", "created_unix", "updated_unix",
	)
	listingID := contractString(t, "listing id", listing["id"])

	market := testGetJSON(t, server, "/trade/listings?player_id="+buyerID, buyerToken, http.StatusOK)
	contractFields(t, "trade listing board", market, "server_time", "items")
	contractFields(t, "trade listing row", contractFirstItem(t, "trade listing rows", market["items"]),
		"id", "seller_id", "item_id", "title_key", "body_key", "icon_id",
		"price", "status", "escrow_status", "created_unix", "updated_unix",
	)

	inventory := testGetJSON(t, server, "/trade/inventory?player_id="+sellerID, sellerToken, http.StatusOK)
	contractFields(t, "trade inventory", inventory, "server_time", "items")
	contractFields(t, "trade inventory row", contractFirstItem(t, "trade inventory items", inventory["items"]),
		"player_id", "item_id", "owned", "locked", "available",
	)

	audit := testGetJSON(t, server, "/admin/inventory/audit?player_id="+sellerID, "view-token", http.StatusOK)
	contractFields(t, "inventory audit", audit, "flags", "items", "player_id", "server_time", "totals")
	contractFields(t, "inventory audit totals", contractMap(t, "inventory audit totals", audit["totals"]),
		"items", "owned", "locked", "available", "reservation_count",
		"housing_reservations", "trade_reservations", "legacy_reservations",
		"other_reservations", "locked_without_reservation",
	)

	purchase := testPostJSON(t, server, "/trade/listings/"+listingID+"/buy", buyerToken, map[string]any{
		"buyer_id": buyerID,
	}, http.StatusOK)
	contractFields(t, "trade purchase", purchase, "listing", "transfer", "item_transfer")
	contractFields(t, "trade purchase listing", contractMap(t, "trade purchase listing", purchase["listing"]),
		"id", "seller_id", "buyer_id", "item_id", "price", "status", "escrow_status", "updated_unix",
	)
	transfer := contractMap(t, "trade transfer", purchase["transfer"])
	contractFields(t, "trade transfer", transfer, "from", "to", "amount")
	contractFields(t, "trade transfer from", contractMap(t, "trade transfer from", transfer["from"]),
		"player_id", "balance", "delta",
	)
	contractFields(t, "trade transfer to", contractMap(t, "trade transfer to", transfer["to"]),
		"player_id", "balance", "delta",
	)
	contractFields(t, "trade item transfer", contractMap(t, "trade item transfer", purchase["item_transfer"]),
		"item_id", "quantity", "from", "to",
	)

	history := testGetJSON(t, server, "/trade/history?player_id="+buyerID, buyerToken, http.StatusOK)
	contractFields(t, "trade history", history, "server_time", "items")
	contractFields(t, "trade history row", contractFirstItem(t, "trade history rows", history["items"]),
		"id", "type", "listing_id", "seller_id", "buyer_id", "item_id", "title_key", "icon_id", "price", "created_unix",
	)
	adminHistory := testGetJSON(t, server, "/admin/trade/history?type=sold", "view-token", http.StatusOK)
	contractFields(t, "admin trade history", adminHistory, "server_time", "count", "matched", "limit", "offset", "items")

	firstSession := testPostJSON(t, server, "/economy/first-session/claim", buyerToken, map[string]any{
		"player_id": buyerID,
		"completed_step_ids": []string{
			"npc_met", "map_opened", "trade_opened", "games_opened", "chat_sent",
		},
	}, http.StatusOK)
	contractFields(t, "first-session reward", firstSession, "player_id", "balance", "delta", "source_id", "claimed")

	creatorShare := testPostJSON(t, server, "/economy/creator-share", "owner-token", map[string]any{
		"player_id":     buyerID,
		"creator_id":    creatorID,
		"game_id":       "contract_creator_game",
		"source_id":     "contract.creator.play.1",
		"player_amount": 15,
	}, http.StatusOK)
	contractFields(t, "creator share", creatorShare, "player", "creator", "creator_amount", "creator_share_bps")
	contractFields(t, "creator share player", contractMap(t, "creator share player", creatorShare["player"]),
		"player_id", "balance", "delta",
	)
	contractFields(t, "creator share creator", contractMap(t, "creator share creator", creatorShare["creator"]),
		"player_id", "balance", "delta",
	)

	policy := testGetJSON(t, server, "/economy/policy", "view-token", http.StatusOK)
	contractFields(t, "economy policy", policy, "creator_share_bps", "daily_soft_cap")
	ledger := testGetJSON(t, server, "/economy/ledger/"+buyerID, buyerToken, http.StatusOK)
	contractFields(t, "economy ledger", ledger, "events")
	contractFields(t, "economy ledger row", contractFirstItem(t, "economy ledger events", ledger["events"]),
		"id", "player_id", "type", "delta", "balance_after", "created_at", "previous_checksum", "checksum",
	)
	payouts := testGetJSON(t, server, "/admin/economy/creator-payouts", "view-token", http.StatusOK)
	contractFields(t, "creator payouts", payouts,
		"request_id", "server_time", "items", "count", "matched", "limit",
		"total_creators", "total_revenue_events", "total_revenue_coins",
	)
	contractFields(t, "creator payout row", contractFirstItem(t, "creator payout rows", payouts["items"]),
		"creator_id", "game_id", "revenue_events", "revenue_coins", "last_revenue_at",
	)

	ops := testGetJSON(t, server, "/debug/ops", "view-token", http.StatusOK)
	contractFields(t, "debug ops", ops,
		"request_id", "rooms", "realtime", "chat", "fishing_rewards", "economy",
		"creator_payouts", "economy_policy", "admin_action_audit",
		"retention_policy", "retention_cleanup_plan", "alerts",
	)
	alerts := contractMap(t, "debug ops alerts", ops["alerts"])
	contractFields(t, "debug ops alerts", alerts,
		"generated_at", "thresholds_version", "highest_severity", "count",
		"open_reports", "admin_missing_notes", "movement_culled_rate", "trade", "items",
	)
	alertEndpoint := testGetJSON(t, server, "/debug/ops/alerts?emit_log=1", "view-token", http.StatusOK)
	contractFields(t, "debug ops alerts endpoint", alertEndpoint, "request_id", "alerts")
}

func TestHighRiskResponseContractsCreatorReviewPipeline(t *testing.T) {
	deps := DefaultMemoryDependencies()
	deps.AdminToken = "viewer:view-token,reviewer:review-token,owner:owner-token"
	server := NewServerWithDependencies(deps)
	owner := testGuestLogin(t, server, "Contract Package Owner")
	ownerID := owner["player_id"].(string)
	ownerToken := owner["access_token"].(string)

	payload := creatorPackagePayload(t, ownerID, "contract_creator_package", safePackageScript())
	submitted := testPostJSON(t, server, "/creator-submissions/package", ownerToken, payload, http.StatusAccepted)
	contractFields(t, "creator package submit", submitted,
		"game_id", "version", "author", "mode_id", "name", "min_players",
		"max_players", "tags", "requires_network", "runtime_contract",
		"entry_scene", "main_script", "asset_budget_bytes", "status", "package",
	)

	status := waitCreatorStatus(
		t,
		server,
		"/creator-submissions/contract_creator_package/status?player_id="+ownerID,
		ownerToken,
		"needs_review",
	)
	contractFields(t, "creator status", status, "game_id", "mode_id", "version", "status", "package")
	pkg := contractMap(t, "creator status package", status["package"])
	contractFields(t, "creator status package", pkg,
		"storage_key", "sha256", "file_count", "total_bytes", "submitted_at",
		"scanned_at", "scan_report", "ai_review", "review_job",
	)
	contractFields(t, "creator scan report", contractMap(t, "creator scan report", pkg["scan_report"]),
		"status", "stages", "issues", "files", "required", "script_count", "asset_count",
	)
	contractFields(t, "creator AI review", contractMap(t, "creator AI review", pkg["ai_review"]),
		"status", "approved", "reviewer", "reviewed_at", "notes",
	)
	contractFields(t, "creator review job", contractMap(t, "creator review job", pkg["review_job"]),
		"id", "game_id", "storage_key", "status", "attempts", "run_after_unix", "created_unix", "updated_unix",
	)

	history := testGetJSON(t, server, "/creator-submissions/contract_creator_package/history?player_id="+ownerID, ownerToken, http.StatusOK)
	contractFields(t, "creator history", history, "game_id", "items")
	contractFields(t, "creator history row", contractFirstItem(t, "creator history items", history["items"]),
		"game_id", "version", "author", "status", "created_unix", "updated_unix", "record",
	)

	dashboard := testGetJSON(t, server, "/admin/reviewer-dashboard", "view-token", http.StatusOK)
	contractFields(t, "reviewer dashboard", dashboard, "generated_at", "items")
	dashboardItem := contractFirstItem(t, "reviewer dashboard items", dashboard["items"])
	contractFields(t, "reviewer dashboard item", dashboardItem,
		"game_id", "version", "author", "mode_id", "status", "name",
		"min_players", "max_players", "tags", "requires_network",
		"runtime_contract", "scan", "ai", "job", "install",
	)
	contractFields(t, "reviewer dashboard scan", contractMap(t, "reviewer dashboard scan", dashboardItem["scan"]),
		"status", "issue_count", "issues", "stages", "file_count", "total_bytes",
		"script_count", "asset_count", "submitted_at", "scanned_at", "storage_key",
	)
	contractFields(t, "reviewer dashboard ai", contractMap(t, "reviewer dashboard ai", dashboardItem["ai"]),
		"status", "approved", "reviewer", "reviewed_at", "note_count", "notes",
	)
	contractFields(t, "reviewer dashboard job", contractMap(t, "reviewer dashboard job", dashboardItem["job"]),
		"id", "status", "attempts", "run_after_unix", "created_unix", "updated_unix",
	)

	approved := testPostJSON(t, server, "/minigames/contract_creator_package/review", "review-token", map[string]any{
		"action": "approve",
		"note":   "contract smoke approve",
	}, http.StatusAccepted)
	contractFields(t, "review approval", approved, "game_id", "version", "author", "mode_id", "status", "package")
	published := testPostJSON(t, server, "/minigames/contract_creator_package/review", "owner-token", map[string]any{
		"action": "publish",
		"note":   "contract smoke publish",
	}, http.StatusAccepted)
	contractFields(t, "review publish", published, "game_id", "version", "author", "mode_id", "status", "package")
	publishedPackage := contractMap(t, "published package", published["package"])
	contractFields(t, "published package", publishedPackage, "install")
	contractFields(t, "published install", contractMap(t, "published install", publishedPackage["install"]),
		"status", "game_id", "version", "author", "mode_id", "name",
		"min_players", "max_players", "tags", "requires_network",
		"runtime_contract", "entry_scene", "main_script", "install_key",
		"install_uri", "manifest_uri", "source_storage_key", "source_sha256",
		"file_count", "total_bytes", "published_at",
	)

	catalog := testGetJSON(t, server, "/minigames/catalog", "", http.StatusOK)
	contractFields(t, "minigame catalog", catalog, "items")
	catalogRow := contractFirstItem(t, "minigame catalog items", catalog["items"])
	contractFields(t, "minigame catalog row", catalogRow,
		"status", "game_id", "version", "author", "mode_id", "name",
		"min_players", "max_players", "tags", "requires_network",
		"runtime_contract", "source_sha256", "published_at",
	)
	for _, privateField := range []string{
		"entry_scene", "main_script", "install_key", "install_uri",
		"manifest_uri", "source_storage_key",
	} {
		if _, exposed := catalogRow[privateField]; exposed {
			t.Fatalf("public minigame catalog exposed private field %q: %#v", privateField, catalogRow)
		}
	}

	runtime := testGetJSON(t, server, "/minigames/contract_creator_package/runtime", "", http.StatusOK)
	contractFields(t, "published runtime", runtime,
		"schema_version", "game_id", "version", "author", "mode_id", "name",
		"min_players", "max_players", "requires_network", "runtime_contract",
		"manifest", "definition", "source_sha256", "published_at",
	)

	audit := getAdminJSON(t, server, "/admin/reviewer-audit/contract_creator_package", "view-token", http.StatusOK)
	contractFields(t, "review audit", audit, "game_id", "items")
	contractFields(t, "review audit row", contractFirstItem(t, "review audit items", audit["items"]),
		"id", "game_id", "action", "status", "reviewer", "source", "created_unix",
	)
}

func contractFields(t *testing.T, label string, data map[string]any, fields ...string) {
	t.Helper()
	for _, field := range fields {
		if _, ok := data[field]; !ok {
			t.Fatalf("%s missing field %q in %#v", label, field, data)
		}
	}
}

func contractMap(t *testing.T, label string, value any) map[string]any {
	t.Helper()
	data, ok := value.(map[string]any)
	if !ok {
		t.Fatalf("%s should be object, got %#v", label, value)
	}
	return data
}

func contractArray(t *testing.T, label string, value any) []any {
	t.Helper()
	items, ok := value.([]any)
	if !ok {
		t.Fatalf("%s should be array, got %#v", label, value)
	}
	return items
}

func contractFirstItem(t *testing.T, label string, value any) map[string]any {
	t.Helper()
	items := contractArray(t, label, value)
	if len(items) == 0 {
		t.Fatalf("%s should not be empty", label)
	}
	return contractMap(t, label+"[0]", items[0])
}

func contractString(t *testing.T, label string, value any) string {
	t.Helper()
	text, ok := value.(string)
	if !ok || text == "" {
		t.Fatalf("%s should be non-empty string, got %#v", label, value)
	}
	return text
}
