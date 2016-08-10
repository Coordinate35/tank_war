local cjson = require("cjson")

local json = {}

json._VERSION = "0.0.1"

function json.encode_empty_as_object(tbe)
	return cjson.encode(tbe)
end

function json.encode_empty_as_array(tbe)
	cjson.encode_empty_table_as_object(false)
	return cjson.encode(tbe)
end

function json.decode(str)
	return cjson.decode(str)
end

return json