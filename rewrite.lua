local route = ngx.var.service_route
local modified_uri = ngx.var.modified_uri
local query_params = ngx.var.is_args .. (ngx.var.args or '')
local full_req_uri = ngx.var.request_uri

-- Anything /non_root will be redirected to /non_root/
-- to ensure correct relative path for micro-services.
if route ~= '_root_' and modified_uri == '' then
	ngx.redirect('/' .. route .. '/' .. query_params)
end

-- Handle GeoIP information
local success, info = geo_lookup(ngx.var.remote_addr)
if success then
	ngx.var.geo_city = info.city
	ngx.var.geo_subd = info.subdivisions
	ngx.var.geo_ctry = info.country
	ngx.var.geo_longitude = info.longitude
	ngx.var.geo_latitude  = info.latitude
end

-- Handle proxy host rewriting
local function get_service_addr(route, route_meta)
	local services = route_meta['services']
	local service_port = route_meta['port']

	local last_rrb = ngx.shared.route_rrb:get(route)
	if not last_rrb then
		last_rrb = 0
	end

	local curr_rrb = (last_rrb + 1) % #services
	-- print('[route] round robin: ', cjson.encode(services), '@'..curr_rrb)
	ngx.shared.route_rrb:set(route, curr_rrb)
	return services[curr_rrb + 1] .. ':' .. service_port
end

local route_meta_str = ngx.shared.route_map:get(route)
if route_meta_str then
	local route_meta = cjson.decode(route_meta_str)
	-- Output service address for proxy_pass
	ngx.var.service_addr = get_service_addr(route, route_meta)
else
	print('[route] service for "', route, '" not found, '..
		'fall through to the root.')

	local root_meta_str = ngx.shared.route_map:get('_root_')
	if not root_meta_str then
		-- No micro-service for 404 route, use built-in page.
		ngx.status = ngx.HTTP_NOT_FOUND
		ngx.header.content_type = 'text/html; charset=utf-8'
		ngx.print([[
		<h2>404 Page not found</h2>
		<p>Please check out later if you keep seeing this.</p>
		]])
		ngx.exit(ngx.HTTP_OK)
	else
		-- Pass to _root_ service
		local root_meta = cjson.decode(root_meta_str)
		ngx.var.service_addr = get_service_addr('_root_', root_meta)
		ngx.var.modified_uri = full_req_uri
	end
end

-- Handle route JWT verification
local jwt = require "resty.jwt"
local validators = require "resty.jwt-validators"
local sub_route = string.match(modified_uri, '[^/]+') or ''
for _, test_path in pairs({route .. '/', route .. '/' .. sub_route}) do
	local protected = ngx.shared.protected:get(test_path)
	if protected then
		print('[route] ', test_path, ' is under protection.')
		local jwt_secret = ngx.shared.JWT:get('secret')
		local jwt_token = ngx.var.cookie_latticejwt
		local claim_spec = { exp = validators.is_not_expired() }
		if jwt_secret and jwt_token then
			local jwt_res = jwt:verify(jwt_secret, jwt_token, claim_spec)
			if jwt_res.valid and jwt_res.verified then
				print('[JWT] verified, will expire@: ', jwt_res.payload.exp)
				break
			else
				print('[JWT] request rejected: ', jwt_res.reason)
			end
		end

		-- Redirect client to login
		local qry = ngx.encode_args({["next"] = full_req_uri})
		-- ngx.redirect("/lattice/login?" .. qry) -- for DEBUG
		ngx.redirect("/login/?" .. qry) -- for PRODUCTION
	end
end

-- Print final rewriting rule (if no ngx.exit/redirect is called)
print('[route] pass: ', full_req_uri, ' ==> ',
	ngx.var.service_addr, ngx.var.modified_uri, query_params)
