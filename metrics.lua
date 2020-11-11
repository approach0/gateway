local json, err = unixsock_get('unix:/var/run/docker.sock', '/services')
if err then
	metric_swarm_services:set(0, {"number"})
else
	local j = cjson.decode(json)
	metric_swarm_services:set(#j, {"number"})
end

local json, err = unixsock_get('unix:/var/run/docker.sock', '/nodes')
if err then
	metric_swarm_nodes:set(0, {"number"})
else
	local j = cjson.decode(json)
	metric_swarm_nodes:set(#j, {"number"})
end

metric_connections:set(ngx.var.connections_active,  {"active"})
metric_connections:set(ngx.var.connections_reading, {"reading"})
metric_connections:set(ngx.var.connections_waiting, {"waiting"})
metric_connections:set(ngx.var.connections_writing, {"writing"})
prometheus:collect()
