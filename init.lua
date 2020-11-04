cjson = require("cjson")
local refresh_interval = 10 -- timer interval (10 secs)

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
			local expire_secs = refresh_interval * 6
			ngx.shared.service_name:set(gateway_route, Name, expire_secs)
			ngx.shared.service_port:set(gateway_route, service_port)
			print('[rule] /', gateway_route, ' -> ', Name, ':', service_port)
			-- Any protected path?
			if protect_paths then
				-- Let's split the protect paths
				for path in string.gmatch(protect_paths, "[^,]+") do
					local protect_path = gateway_route .. path
					ngx.shared.protect_path:set(protect_path, true)
					print('[rule] @ protect: ', protect_path)
				end
			end
		end
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
geo = require('resty.maxminddb')
if not geo.initted() then
	geo.init("./conf/GeoLite2-City.mmdb")
end

function geo_lookup(IP_addr)
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
