local game_loop = loadfile(ngx.var.root .. "/v1/controller/game_loop.lua")():new()

game_loop:start_game_loop()