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

		local gateway_route, service_port, protect_paths
		for key in pairs(Labels) do
			local val = Labels[key]
			if key == 'gateway.jwt_port' then
				local jwt_token, err = http_GET(
					'http://' .. Name .. ':' .. val
				)
				if not err then
					ngx.shared.JWT:set('secret', jwt_token)
				else
					print('[JWT] update error: ', err)
				end
			elseif key == 'gateway.protect' then
				-- val is a string of paths with comma as delimiter
				-- e.g., "/runjob,/delejob".
				protect_paths = val
			elseif key == 'gateway.route' then
				gateway_route = val
			elseif key == 'gateway.port' then
				service_port = val
			end
		end

		if gateway_route and service_port then
			ngx.shared.service_name:set(gateway_route, Name)
			ngx.shared.service_port:set(gateway_route, service_port)
			print('[rule] /', gateway_route, ' -> ', Name, ':', service_port)
			-- Any protected path?
			if protect_paths then
				-- Let's split the protect paths
				for path in string.gmatch(protect_paths, "[^,]+") do
					local protect_path = gateway_route .. path
					ngx.shared.protect_path:set(protect_path, true)
					print('[rule] protect: ', protect_path)
				end
			end
		end
	end

	print('=== SERVICE LIST REFRESHED ===')
end

ngx.timer.at(0, discover_services)
ngx.timer.every(10, discover_services)
