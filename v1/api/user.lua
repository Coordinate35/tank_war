local user = loadfile(ngx.var.root .. "/v1/controller/user.lua")():new()

user:start()