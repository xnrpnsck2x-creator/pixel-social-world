package minigame

import (
	"errors"
	"fmt"
)

type modeRuntimeContract struct {
	Camera         string
	InputProfile   string
	NetworkProfile string
}

var creatorModeRuntimeContracts = map[string]modeRuntimeContract{
	"casual_activity":  {Camera: "contained", InputProfile: "tap_timing", NetworkProfile: "offline_optional"},
	"side_scroller_2d": {Camera: "side_view", InputProfile: "action_platformer", NetworkProfile: "session_sync"},
	"2d_fighting":      {Camera: "side_view", InputProfile: "fighting_action", NetworkProfile: "authoritative_realtime"},
	"strategy_war":     {Camera: "isometric", InputProfile: "strategy_pointer", NetworkProfile: "turn_or_lockstep"},
	"rpg_adventure":    {Camera: "top_down", InputProfile: "rpg_move_confirm", NetworkProfile: "session_sync"},
	"tower_defense":    {Camera: "lane_grid", InputProfile: "tower_place_upgrade", NetworkProfile: "session_sync"},
	"battle_royale":    {Camera: "top_down", InputProfile: "survival_action", NetworkProfile: "authoritative_realtime"},
}

func validateModeRuntimeContract(modeID string, contract map[string]any) error {
	expected, ok := creatorModeRuntimeContracts[modeID]
	if !ok {
		return errors.New("unsupported_mode_id")
	}
	if err := requireRuntimeContractValue(contract, "camera", expected.Camera); err != nil {
		return err
	}
	if err := requireRuntimeContractValue(contract, "input_profile", expected.InputProfile); err != nil {
		return err
	}
	return requireRuntimeContractValue(contract, "network_profile", expected.NetworkProfile)
}

func requireRuntimeContractValue(contract map[string]any, field string, expected string) error {
	if fmt.Sprint(contract[field]) != expected {
		return fmt.Errorf("runtime_contract_%s_mismatch", field)
	}
	return nil
}
