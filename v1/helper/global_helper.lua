local helper = {}
local random = require("resty.random")
local resty_string = require("resty.string")

function helper.calculate_distance(x1, y1, x2, y2)
	return math.sqrt(math.pow(x1 - x2, 2) + math.pow(y1 - y2, 2))
end

function helper.get_13bit_time()
	ngx.update_time()
	return math.floor(ngx.now() * 1000)
end

function helper.rad_to_angle(rad)
	return rad / math.pi * 180
end

function helper.get_age(time)
	if 0 == #tostring(time) then
		return 0
	end
	local life_time = math.floor(tonumber(ngx.time())) - math.floor(tonumber(time))
	local age = math.floor(life_time / const.one_year_have_second)
	return age
end

function helper.atoi(str)
	if nil == str then 
		return nil
	end
	str = tonumber(str)
	if nil == str then 
		return nil
	end
	return math.floor(str)
end

function helper.atof(str)
	if nil == str then 
		return nil
	end
	str = tonumber(str)
	if nil == str then 
		return nil
	end
	return str
end


function helper.split(str, delimiter)
	if nil == str or '' == str or nil == delimiter then
		return nil
	end
	local result = {}
	local params_num = 0
	local str = str .. delimiter
	for match in str:gmatch("(.-)" .. delimiter) do
		table.insert(result, match)
		params_num = params_num + 1
	end
	local last_length = #result[params_num]
	if "%" == string.sub(result[params_num], last_length, last_length) then
		result[params_num] = string.sub(result[params_num], 1, last_length - 1)
	end
	return result
end

function helper.hex2raw(str)
    assert(#str % 2 == 0)
    ret = {}
    for i = 1, #str, 2 do
        ret[#ret+1] = string.char(tonumber(string.sub(str, i, i+1), 16))
    end
    return table.concat(ret, "")
end

function helper.generate_validate_code()
	return random.number(100000, 999999)
end

function helper.generate_id()
	return helper.generate_salt()
end

function helper.generate_access_token()
	return helper.generate_salt()
end

function helper.generate_salt()
	local str = random.bytes(8)
	return ngx.md5(str)
end

function helper.crypt(raw, salt)
	local digest
	local object = salt .. raw
	local i = {1, 2, 3, 4, 5, 6, 7, 8}
	local resty_sha256 = require("resty.sha256")
	for _, v in ipairs(i) do
		sha256 = resty_sha256:new()
		sha256:update(object)
		digest = sha256:final()
		object = resty_string.to_hex(digest)
	end
	return object
end

return helper