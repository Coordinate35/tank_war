local helper = loadfile(ngx.var.root .. "/v1/helper/global_helper.lua")()
local json = loadfile(ngx.var.root .. "/v1/core/json.lua")()
local const = loadfile(ngx.var.root .. "/v1/config/constants.lua")()
local random = require("resty.random")
local redis = require "resty.redis"

local game_loop = {}

game_loop._current_time = 0;
game_loop._object_type = {"tank", "bullet", "blast"}
game_loop._tank = {}
game_loop._bullet = {}
game_loop._blast = {}
game_loop._command_queue = {}

function game_loop:_get_command_from_redis()
	local command, err
	self._red_subcriber = redis:new()
	local ok, err = self._red_subcriber:connect(ngx.var.redis_host, ngx.var.redis_port)
	if not ok then
		print("subscriber connect to redis failed: " .. err)
	end
	while not command do 
		command, err = self._red_subcriber:subscribe("command")
		if not command then
			print("subcribe failed " .. err)
		end
	end
	while true do 
		command, err = self._red_subcriber:read_reply()
		if not command then
			print("failed to read command reply " .. err)
		else
			table.insert(self._command_queue, command[3])
		end
	end
end

function game_loop:_connect_redis()
	local ok, err = self._red:connect(ngx.var.redis_host, ngx.var.redis_port)
	if not ok then
		return false, err
	end
	return true, nil
end

function game_loop:execute_start(command)
	local tank = {}
	tank.x = random.number(0, const.world_width)
	tank.y = random.number(0, const.world_height)
	tank.speed = const.tank_speed
	tank.dir = math.pi / 2
	tank.nickname = command.nickname
	self._tank[command.player_id] = tank
end

function game_loop:execute_move(command)
	self._tank[command.player_id].dir = command.dir
end

function game_loop:execute_fire(command)
	local tank = self._tank[command.player_id]
	local bullet = {
		x = tank.x,
		y = tank.y,
		speed = const.bullet_speed,
		dir = tank.dir,
		owner = command.player_id
	}
	local id = helper.generate_id()
	self._bullet[id] = bullet
end

function game_loop:execute_command()
	while 0 ~= table.getn(self._command_queue) do
		local command = json.decode(self._command_queue[1])
		table.remove(self._command_queue, 1)
		self["execute_" .. command.cmd](self, command)
	end
end

function game_loop:detect_blast_event()
	local tank_bullet_distance
	local event = {}
	if not self._blast then 
		print(err)
		return
	end
	for tank_id, tank in pairs(self._tank) do
		local min_distance = const.blast_distance
		for bullet_id, bullet in pairs(self._bullet) do
			if bullet.owner == tank_id then
				tank_bullet_distance = const.blast_distance + 1
			else
				tank_bullet_distance = helper.calculate_distance(tank.x, tank.y, bullet.x, bullet.y)
			end
			if min_distance >= tank_bullet_distance then
				min_distance = tank_bullet_distance
				event.tank_id = tank_id
				event.bullet_id = bullet_id
				event.x = tank.x
				event.y = tank.y
			end
		end
		if min_distance < const.blast_distance then
			self._tank[event.tank_id] = nil
			self._bullet[event.bullet_id] = nil
			event.time = self._current_time
			table.insert(self._blast, event)
		end
	end
end

function game_loop:detect_bullet_edge_event()
	for bullet_id, bullet in pairs(self._bullet) do 
		if 0 == self._bullet.x or 0 == self._bullet.y then
			self._bullet[bullet_id] = nil
		end
	end
end

function game_loop:detect_event()
	self:detect_blast_event()
	self:detect_bullet_edge_event()
end

function game_loop:update_tank(time)
	self:update_position(time, "tank")
end

function game_loop:update_bullet(time)
	self:update_position(time, "bullet")
end

function game_loop:update_blast(time)
	if ngx.null == self._blast or 0 == #self._blast then
		return
	end
	for key, _ in pairs(self._blast) do
		self._blast[key].progress = self._current_time - self._blast[key].time
	end
end

function game_loop:update(time)
	for _, value in pairs(self._object_type) do 
		self["update_" .. value](self, time)
	end

	-- for _, value in pairs(self._object_type) do
	-- 	self["update_position"](self, time, value)
	-- end
end

function game_loop:update_position(time, object_type)
	local object_var = "_" .. object_type
	if ngx.null == self[object_var] or {} == self[object_var] then
		return
	end
	for key, object in pairs(self[object_var]) do 
		local distance = object.speed * time
		local angle = helper.rad_to_angle(object.dir)
		self[object_var][key].x = self[object_var][key].x + distance * math.cos(angle)
		self[object_var][key].y = self[object_var][key].y + distance * math.sin(angle)
		if self[object_var][key].x > const.world_width then
			self[object_var][key].x = const.world_width
		end
		if self[object_var][key].y > const.world_height then
			self[object_var][key].y = const.world_height
		end
		if self[object_var][key].x < 0 then
			self[object_var][key] = 0
		end
		if self[object_var][key].y < 0 then
			self[object_var][key] = 0
		end
	end
end

function game_loop:start_getting_command()
	ngx.thread.spawn(self._get_command_from_redis, self)
end

function game_loop:start_game_loop()
	self:start_getting_command()
	local err, ok
	while true do
		self._last_time = self._current_time
		self._current_time = helper.get_13bit_time()
		self._tank, err = self._red:get("tank")
		self._bullet, err = self._red:get("bullet")
		self._blast = self._red:get("blast")
		for _, value in pairs(self._object_type) do
			if ngx.null == self["_" .. value] or false == self["_" .. value] then
				self["_" .. value] = {}
			else
				self["_" .. value] = json.decode(self["_" .. value])
			end
		end
		self:update(self._current_time - self._last_time)
		self:execute_command()
		self:detect_event()
		ok, err = self._red:set("tank", json.encode_empty_as_object(self._tank))
		ok, err = self._red:set("bullet", json.encode_empty_as_object(self._bullet))
		ok, err = self._red:set("blast", json.encode_empty_as_object(self._blast))
		ngx.sleep(0.015)
	end
end

function game_loop:new()
	local is_success, err
	self._red = redis:new()
	is_success, err = self:_connect_redis()
	if false == is_success then
		self:response_error("", err)
	end
	return setmetatable({}, {__index = self})
end

return game_loop