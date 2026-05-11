package gateway

import (
	"net/http"
	"testing"
)

func TestSocialFacilitiesRequirePlayerAuthAndReturnTradeGuild(t *testing.T) {
	server := NewServerWithDependencies(DefaultMemoryDependencies())
	session := testGuestLogin(t, server, "Facility Owner")
	playerID := session["player_id"].(string)
	token := session["access_token"].(string)

	testGetJSON(t, server, "/social/facilities?player_id="+playerID, "", http.StatusUnauthorized)

	catalog := testGetJSON(t, server, "/social/facilities?player_id="+playerID, token, http.StatusOK)
	if catalog["player_id"] != playerID {
		t.Fatalf("facilities did not return player scope: %#v", catalog)
	}
	facilities := catalog["facilities"].(map[string]any)
	trade := facilities["trade"].(map[string]any)
	if trade["map_id"] != "social_trade_market_v1" {
		t.Fatalf("trade facility returned wrong map: %#v", trade)
	}
	rows := trade["rows"].([]any)
	if len(rows) == 0 || rows[0].(map[string]any)["title_key"] != "facility.trade.board.title" {
		t.Fatalf("trade facility missing configured rows: %#v", trade)
	}

	guild := testGetJSON(t, server, "/social/facilities/guild?player_id="+playerID, token, http.StatusOK)
	if guild["map_id"] != "social_guild_garden_v1" {
		t.Fatalf("guild facility returned wrong map: %#v", guild)
	}
}
