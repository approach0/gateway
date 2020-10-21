local route = ngx.var.service_route
local modified_uri = ngx.var.modified_uri
local query_params = ngx.var.is_args .. (ngx.var.args or '')

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
	print('[gateway] service for "', route, '" not found.')
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

-- Print final rewriting rule (if no ngx.exit/redirect is called)
print(ngx.var.request_uri, ' ==> ', modified_uri, query_params)
