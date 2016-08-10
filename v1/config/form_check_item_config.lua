local form_check_item_config = {}

form_check_item_config.frame_id = {
	["field"] = "id",
	["label"] = "报文id",
	["rules"] = "required|is_number"
}

form_check_item_config.command = {
	["field"] = "cmd",
	["label"] = "动作指令",
	["rules"] = "required|is_command"
}

form_check_item_config.timestamp = {
	["field"] = "ts",
	["label"] = "时间戳",
	["rules"] = "required|is_number"
}

form_check_item_config.screen = {
	["field"] = "screen",
	["label"] = "屏幕参数",
	["rules"] = "required|is_screen"
}

form_check_item_config.nickname = {
	["field"] = "nickname",
	["label"] = "用户昵称",
	["rules"] = "required|min_length[1]|max_length[30]"
}

form_check_item_config.direction = {
	["field"] = "dir",
	["label"] = "移动方向",
	["rules"] = "required|is_number"
}

return form_check_item_config