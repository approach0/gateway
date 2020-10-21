local route = ngx.var.service_route

local name = ngx.shared.service_name:get(route)
local port = ngx.shared.service_port:get(route)
if name and port then
	-- Output service address for proxy_pass
	ngx.var.service_addr = name .. ':' .. port
else
	print('[gateway] service for "', route, '" not found.')
	name = ngx.shared.service_name:get('404')
	port = ngx.shared.service_port:get('404')
	if name and port then
		-- Output service address for proxy_pass
		ngx.var.service_addr = name .. ':' .. port
	else
		ngx.print('<h1>404</h1> <p>Page not found.</p>')
		ngx.exit(ngx.HTTP_OK)
	end
end
