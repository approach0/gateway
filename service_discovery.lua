local function http_GET(url)
	local http = require("resty.http")
	local httpc = http.new()
	local data = ''
	httpc:set_timeout(500) -- 500 ms timeout

	local res, err = httpc:request_uri(url)
	if not err then
		data = res.body
	end

	http:close()
	return data, err
end

local function discover_services()
	local json, err = http_GET('http://127.0.0.1/services')
	if err then
		errstr = '~~ sock:connect err: ' .. err .. ' ~~'
		return
	end

	local cjson = require("cjson")
	local services = cjson.decode(json)

	for _, service in ipairs(services) do
		local Spec = service['Spec']
		local Name = Spec['Name']
		local Labels = Spec['Labels']

		local gateway_route, service_port
		for key in pairs(Labels) do
			local val = Labels[key]
			if key == 'gateway.jwt_port' then
				local jwt_token, err = http_GET(Name .. ':' .. val)
				if not err then
					print('JWT token: ', jwt_token)
					ngx.shared.JWT:set('token', jwt_token)
				end
			elseif key == 'gateway.route' then
				gateway_route = val
			elseif key == 'gateway.port' then
				service_port = val
			end
		end

		if gateway_route and service_port then
			ngx.shared.service_name:set(gateway_route, Name)
			ngx.shared.service_port:set(gateway_route, service_port)
			print('/', gateway_route, ' -> ', Name, ':', service_port)
		end
	end

	print('~~ service list refreshed. ~~')
end

ngx.timer.at(0, discover_services)
ngx.timer.every(10, discover_services)
