local route = ngx.var.service_route
local modified_uri = ngx.var.modified_uri
local query_params = ngx.var.is_args .. (ngx.var.args or '')
local full_req_uri = ngx.var.request_uri

-- Handle proxy host rewriting
local name = ngx.shared.service_name:get(route)
local port = ngx.shared.service_port:get(route)
if name and port then
	-- Output service address for proxy_pass
	ngx.var.service_addr = name .. ':' .. port

	if route ~= '_root_' and modified_uri == '' then
		-- force service root URL to have trailing slash so that
		-- we ensure correct relative path for micro-services
		ngx.redirect('/' .. route .. '/' .. query_params)
	end
else
	print('[route] service for "', route, '" not found.')
	local root_name = ngx.shared.service_name:get('_root_')
	local root_port = ngx.shared.service_port:get('_root_')
	if not root_name or not root_port then
		-- No micro-service for 404 route, use built-in page.
		ngx.header.content_type = 'text/html; charset=utf-8'
		ngx.print([[
		<h2>404 Page not found</h2>
		<p>Please check out later if you keep seeing this.</p>
		]])
		ngx.exit(ngx.HTTP_OK)
	else
		-- Fall through and pass to _root_ service
		ngx.var.service_addr = root_name .. ':' .. root_port
		ngx.var.modified_uri = full_req_uri
	end
end

-- Handle route JWT verification
local jwt = require "resty.jwt"
local sub_route = string.match(modified_uri, '[^/]+') or ''
for _, test_path in pairs({route .. '/', route .. '/' .. sub_route}) do
	local protected = ngx.shared.protect_path:get(test_path)
	print('[route] protected=', protected or 'No', ': ', test_path)
	if protected then
		local jwt_secret = ngx.shared.JWT:get('secret')
		local jwt_token = ngx.var.cookie_latticejwt
		if jwt_secret and jwt_token then
			local jwt_res = jwt:verify(jwt_secret, jwt_token)
			if jwt_res.valid and jwt_res.verified then
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
