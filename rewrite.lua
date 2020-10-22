local route = ngx.var.service_route
local modified_uri = ngx.var.modified_uri
local query_params = ngx.var.is_args .. (ngx.var.args or '')
local full_req_uri = ngx.var.request_uri

-- Handle URI rewriting
if modified_uri == '' then
	-- force service root URL to have trailing slash so that
	-- we ensure correct relative path for micro-services
	ngx.redirect('/' .. route .. '/' .. query_params)
end

-- Handle proxy host rewriting
local name = ngx.shared.service_name:get(route)
local port = ngx.shared.service_port:get(route)
if name and port then
	-- Output service address for proxy_pass
	ngx.var.service_addr = name .. ':' .. port
else
	print('[route] service for "', route, '" not found.')
	if route == '404' then
		-- No micro-service for 404 route, use built-in page.
		ngx.header.content_type = 'text/html; charset=utf-8'
		ngx.print([[
		<h2>404 Page not found</h2>
		<p>Please check out later if you keep seeing this.</p>
		]])
		ngx.exit(ngx.HTTP_OK)
	else
		-- Redirect client browser to route 404
		ngx.redirect("/404")
	end
end

-- Handle route JWT verification
local jwt = require "resty.jwt"
local sub_route = string.match(modified_uri, '[^/]+') or ''
local test_path = route .. '/' .. sub_route
local protected = ngx.shared.protect_path:get(test_path)
print('[route] protected=', protected or 'No', ': ', test_path)
if protected then
	local jwt_secret = ngx.shared.JWT:get('secret')
	local jwt_token = ngx.var.cookie_latticejwt
	if jwt_secret and jwt_token then
		local jwt_res = jwt:verify(jwt_secret, jwt_token)
		if not jwt_res.valid or not jwt_res.verified then
			print('[JWT] request rejected: ', jwt_res.reason)
		end
	else
		-- Redirect client to login
		local qry = ngx.encode_args({["next"] = full_req_uri})
		ngx.redirect("/login/?" .. qry)
	end
end

-- Print final rewriting rule (if no ngx.exit/redirect is called)
print('[route] pass: ', full_req_uri, ' ==> ', modified_uri, query_params)
