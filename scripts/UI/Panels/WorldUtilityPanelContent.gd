class_name WorldUtilityPanelContent
extends RefCounted

func panel_record(panel_id: String) -> Dictionary:
	match panel_id:
		"shop":
			return {"title_key": "world.panel.shop.title", "icon_id": "icon.shop"}
		"mail":
			return {"title_key": "world.panel.mail.title", "icon_id": "icon.mail"}
		"notice":
			return {"title_key": "world.panel.notice.title", "icon_id": "icon.quest"}
		"creator":
			return {"title_key": "world.panel.creator.title", "icon_id": "icon.check"}
		"map":
			return {"title_key": "world.panel.map.title", "icon_id": "icon.map"}
		"map_atlas":
			return {"title_key": "world.panel.map.atlas_title", "icon_id": "icon.map"}
		_:
			return {"title_key": "world.panel.inventory.title", "icon_id": "icon.backpack"}

func panel_body(panel_id: String) -> String:
	match panel_id:
		"shop":
			return App.t_key("world.panel.shop.body")
		"mail":
			return App.t_key("world.panel.mail.body")
		"notice":
			return App.t_key("world.panel.notice.body")
		"creator":
			return App.t_key("world.panel.creator.body")
		"map":
			return App.t_key("world.panel.map.body")
		"map_atlas":
			return App.t_key("world.panel.map.atlas_body")
		_:
			return App.t_key("world.panel.inventory.body")

func panel_detail(panel_id: String) -> String:
	match panel_id:
		"shop":
			return App.format_key("world.panel.shop.wallet_format", {"coins": SaveSystem.get_coin_balance()})
		"inventory":
			return App.format_key("world.panel.inventory.wallet_format", {"coins": SaveSystem.get_coin_balance()})
		"creator":
			return App.t_key("world.panel.creator.detail")
		"map":
			return ""
		"map_atlas":
			return App.t_key("world.panel.map.atlas_detail")
	return ""
