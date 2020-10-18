local function docker_cli_get(url)
	local http = require("resty.http")
	local httpc = http.new()
	httpc:set_timeout(500) -- 500 ms timeout

	local res, err = httpc:request_uri(
		"http://127.0.0.1/dockersock/services"
	)

	if not err then
		data = res.body
	end

	http:close()
	return data, errstr
end

local function discover_services()
	local cjson = require("cjson")
	local json, err = docker_cli_get('/services')
	if err then
		errstr = '~~ sock:connect err: ' .. err .. ' ~~'
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
