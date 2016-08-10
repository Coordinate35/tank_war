local helper = loadfile(ngx.var.root .. "/v1/helper/global_helper.lua")()
local json = loadfile(ngx.var.root .. "/v1/core/json.lua")()
local zh_lang = loadfile(ngx.var.root .. "/v1/lang/chinese.lua")()
local form_validation = loadfile(ngx.var.root .. "/v1/core/form_validation.lua")()
local form_check_config = loadfile(ngx.var.root .. "/v1/config/form_check_config.lua")()
local const = loadfile(ngx.var.root .. "/v1/config/constants.lua")()

local user = {}

user.screen = {}
user._packet_id = 1

function user:_response_hello()
	local response = {
		["id"] = self._packet_id,
		["cmd"] = "hello",
		["ver"] = 1
	}
	local bytes, err = self._wb:send_text(json.encode_empty_as_object(response))
	self._packet_id = self._packet_id + 1
	if not bytes then
		ngx.log(ngx.ERR, "Failed to send hello")
	end
end

function user:_response_received()
	local response = {
		["id"] = self._packet_id,
		["status"] = zh_lang.received,
		["ver"] = 1
	}
	local bytes, err = self._wb:send_text(json.encode_empty_as_object(response))
	self._packet_id = self._packet_id + 1
	if not bytes then
		ngx.log(ngx.ERR, "Failed to send hello")
	end
end

function user:_set_user_param(params)
	self.player_id = helper.generate_id()
	self.screen = {
		["width"] = params.screen[1],
		["height"] = params.screen[2]
	}
end

function user:_response_close()
	self._tank = self._red:get("tank")
	self._tank[self.player_id] = nil
	ok, err = self._red:set("tank", json.encode_empty_as_object(self._tank))
	-- ok, err = self._red:set("bullet", json.encode_empty_as_object(self._bullet))
	-- ok, err = self._red:set("blast", json.encode_empty_as_object(self._blast))
	local bytes, err = self._wb:send_close(1000, "")
	if not bytes then
		ngx.log(ngx.ERR, "Failed to send the close frame: ", err)
	end
end

function user:_receive_command()
	while true do 
		local data, typ, err = self._wb:recv_frame()
		if "close" == typ then
			self:_response_close()
			self._is_start = nil
			break
		end
		if nil ~= data then
			local body = json.decode(data)
			local check_item = form_check_config[body.cmd]
			if nil == check_item then
				local err = zh_lang.invalid_request
				self:_response_error(err, err)
			else
				local result, err = form_validation.check(body, check_item)
				if false == result then
					local err = zh_lang.invalid_request
					self:_response_error(err, err)
				else
					if "hello" == body.cmd then
						self:_response_hello(body.id)
						self:_set_user_param(body)
					elseif nil ~= self.player_id then
						if "start" == body.cmd then
							self._is_start = true
						end
						body.player_id = self.player_id
						self._red:publish("command", json.encode_empty_as_object(body))
						self:_response_received()
					end
				end
			end
		end
		ngx.sleep(0.015)
	end
end

function user:_update_render()
	local myself
	local response = {}
	local near_object_type = {"tank", "bullet", "blast"}
	while true do 
		if nil == self._is_start then
			break
		end
		if true == self._is_start then
			self._tank = self._red:get("tank")
			self._bullet = self._red:get("bullet")
			self._blast = self._red:get("blast")
			for _, value in pairs(near_object_type) do
				if ngx.null == self["_" .. value] or false == self["_" .. value] then
					self["_" .. value] = {}
				else
					self["_" .. value] = json.decode(self["_" .. value])
				end
			end
			ngx.update_time()
			self._current_time = ngx.time()
			if {} == self._tank then
				print("update_render failed" .. self._current_time)
			else
				myself = self._tank[self.player_id]
				response.objs = {}
				for _, object_type in pairs(near_object_type) do
					response.objs[object_type] = self._find_near(self, myself, self["_" .. object_type], self.screen)
				end
				response.objs.camera = {
					{
						["id"] = helper.generate_id(),
						["x"] = myself.x,
						["y"] = myself.y,
						["visibleRect"] = self.screen,
						["active"] = true
					}
				}
				response.objs.map = {
					{
						["id"] = helper.generate_id(),
						["x"] = myself.x,
						["y"] = myself.y,
						["width"] = const.world_width,
						["height"] = const.world_height
					}
				}
				response.cmd = "update"
				local bytes, err = self._wb:send_text(json.encode_empty_as_array(response))
				self._packet_id = self._packet_id + 1
				if not bytes then
					ngx.log(ngx.ERR, "Failed to send hello")
				end
			end
		end
		ngx.sleep(1)
	end
end

function user:_find_near(myself, objects, screen)
	local near_objects = {}
	for id, object in pairs(objects) do
		if math.abs(object.x - myself.x) < screen.width / 2 and math.abs(object.y - myself.y) < screen.height / 2 then
			object.id = id
			table.insert(near_objects, object)
		end
	end
	return near_objects
end

function user:_connect_redis()
	local ok, err = self._red:connect(ngx.var.redis_host, ngx.var.redis_port)
	if not ok then
		return false, err
	end
	return true, nil
end

function user:_create_socket()
	local server = require "resty.websocket.server"
	local wb, err = server:new{
		max_payload_len = 65535
	}
	if not wb then
		return false, err
	end
	self._wb = wb
	return true, nil
end

function user:_response(str)
	local bytes, err = self._wb:send_text(str)
	self._packet_id = self._packet_id + 1
	if not bytes then
		ngx.log(ngx.ERR, "Failed to send hello")
	end
end

function user:_response_error(msg, err)
	local response = {
		["error"] = zh_lang.server_error .. ": " .. msg
	}
	ngx.log(ngx.ERR, err)
	self:_response(json.encode_empty_as_object(response))
end

function user:start()
	self:start_receive_loop()
	self:start_update_render_loop()
end

function user:start_receive_loop()
	ngx.thread.spawn(self._receive_command, self)	
end

function user:start_update_render_loop()
	ngx.thread.spawn(self._update_render, self)
end

function user:new()
	local is_success, err
	local redis = require "resty.redis"
	self._red = redis:new()
	is_success, err = self:_connect_redis()
	if false == is_success then
		self:response_error("", err)
	end
	is_success, err = self:_create_socket()
	if false == is_success then
		self:response_error("", err)
	end
	self._is_start = false
	return setmetatable({}, {__index = self})
end

return user


