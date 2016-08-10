local model = {}

function model:connect_database()
    local p = "/usr/local/openresty/lualib/"
    local m_package_path = package.path
    package.path = string.format("%s?.lua;%s?/init.lua;%s",
    p, p, m_package_path)
    local mongol = require("resty.mongol")
    self.conn = mongol:new()
    local ok, err = self.conn:connect(ngx.var.mongo_host, ngx.var.mongo_port)
    if not ok then
        return false
    end
    return true
end

function model:new()
	if false == self:connect_database() then
        return false
    end
    return setmetatable({}, {__index = self})
end

return model