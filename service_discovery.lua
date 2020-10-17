local function docker_cli_get(url)
	local data, errstr, line, last_line, _ -- default = nil

	-- invoke ngx-socket (only available when ngx.timer.at(0))
	local sock = ngx.socket.stream()
	sock:settimeout(1000) -- 100 ms timeout

	-- connect to unix domain socket
	local ok, err = sock:connect("unix:/var/run/docker.sock")
	if not ok then
		errstr = '~~ sock:connect err: ' .. err .. ' ~~'
		goto close
	end

	-- compose and send HTTP GET request
	_, err = sock:send(
		'GET '.. url ..' HTTP/1.1\r\n' ..
		'Host: localhost\r\n' ..
		'Accept: */*\r\n' ..
		'\r\n'
	)
	if err then
		errstr = '~~ sock:send err: ' .. err .. ' ~~'
		goto close
	end

	-- receive response data line by line
	-- and extract body data
	while true do
		line, err = sock:receive("*l")
		if err then
			errstr = '~~ sock:receive err: ' .. err .. ' ~~'
			goto close
		elseif last_line == '' then
			data = line
			goto close
		end
		last_line = line
	end

	::close::
	sock:close()
	return data, errstr
end

local function discover_services()
	local cjson = require("cjson")
	local json, err = docker_cli_get('/services')
	if err then
		print(err)
		return
	end

	local services = cjson.decode(json)
	local service_port = ngx.shared.service_port

	for _, serv in ipairs(services) do
		local Spec = serv['Spec']
		local Name = Spec['Name']
		local Labels = Spec['Labels']
		local gateway_route, gateway_port
		for key in pairs(Labels) do
			local val = Labels[key]
			if key == 'gateway.port' then
				print('/', Name, ' -> ', Name, ':', val)
				service_port:set(Name, val)
			end
		end
	end

	print('~~ service list refreshed. ~~')
end

ngx.timer.at(0, discover_services)
ngx.timer.every(10, discover_services)
