cjson = require("cjson")
local refresh_interval = 10 -- timer interval (in seconds)
local expire_seconds = refresh_interval * 6

function http_GET(url)
	local http = require("resty.http")
	local httpc = http.new()
	local data = ''
	httpc:set_timeout(6000) -- 6s timeout

	local res, err = httpc:request_uri(url)
	if not err then
		data = res.body
	end

	httpc:close()
	return data, err
end

local function discover_services()
	local json, err = http_GET('http://127.0.0.1/services')
	if err then
		errstr = '~~ sock:connect err: ' .. err .. ' ~~'
		return
	end

	local services = cjson.decode(json)
	local new_route_map = {}

	for _, service in ipairs(services) do
		-- Parse Docker services API
		local Spec = service['Spec']
		local Labels = Spec['Labels']
		local service_name = Spec['Name']
		local gateway_route, service_port, protect_paths
		for key in pairs(Labels) do
			local val = Labels[key]
			if key == 'gateway.jwt_port' then
				local jwt_token, err = http_GET(
					'http://' .. service_name .. ':' .. val
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

		-- Update new_route_map
		if gateway_route and service_port then
			-- Get route meta data
			if not new_route_map[gateway_route] then
				new_route_map[gateway_route] = {}
			end
			local route_meta = new_route_map[gateway_route]

			-- Set services
			if not route_meta['services'] then
				route_meta['services'] = {service_name}
			else
				table.insert(route_meta['services'], service_name)
			end

			-- Set port
			route_meta['port'] = service_port

			-- Any protected path?
			if protect_paths then
				-- Let's split the protect paths
				for path in string.gmatch(protect_paths, "[^,]+") do
					local protected_path = gateway_route .. path
					print('[protect] ', protected_path)
					ngx.shared.protected:set(protected_path, true)
				end
			end
		end
	end -- End of for

	-- Update global route map using new_route_map
	for gateway_route, route_meta in pairs(new_route_map) do
		local route_meta_str = cjson.encode(route_meta)
		print('[service] /', gateway_route, ' -> ', route_meta_str)
		ngx.shared.route_map:set(gateway_route, route_meta_str, expire_seconds)
	end

	print('=== SERVICE LIST REFRESHED ===')
end

-- For timer jobs
ngx.timer.at(0, discover_services)
ngx.timer.every(refresh_interval, discover_services)

-- For Prometheus metrics
prometheus = require("prometheus").init("metrics")

metric_request_uri = prometheus:counter("request_uri", "Request URI", {
	"uri",
	"status"
})

metric_request_geoip = prometheus:counter("request_geoip", "Request GeoIP", {
	"ip",
	"city",
	"ctry",
	"longitude",
	"latitude"
})

metric_response_bytes = prometheus:counter("response_bytes", "Response Bytes", {"uri"})

metric_request_timecost = prometheus:counter("request_timecost", "Request Timecost", {"uri"})

metric_connections = prometheus:gauge("connections", "Number of HTTP connections", {"state"})

metric_swarm_services = prometheus:gauge("swarm_services", "Swarm services", {"number"})

metric_swarm_nodes = prometheus:gauge("swarm_nodes", "Swarm nodes", {"number"})

-- For GeoIP
enable_geo_lookup = true

if enable_geo_lookup then
	local geo = require('resty.maxminddb')
	if not geo.initted() then
		geo.init("./conf/GeoLite2-City.mmdb")
	end
end

function geo_lookup(IP_addr)
	if not enable_geo_lookup then
		return false, 'GeoIP is not enabled'
	end

	local res, err = geo.lookup(IP_addr)
	if res then
		-- Refer to GeoIP.md for an example JSON
		return true, {
			city = res.city.names,en,
			country = res.country.names,en,
			longitude = res.location.longitude,
			latitude = res.location.latitude
		}
	else
		return false, err
	end
end
