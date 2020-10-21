# gateway

## Features
* Docker Swarm service discovery
* Rate limit for unique IP
* TLS / Let's encrypt and auto-renewal
* Statistics and Metrics (InfluxDB, Prometheus)
* JWT verification

## Usage
Build the image
```
# docker build -t gateway .
```

Run gateway locally
```
# docker run -it --publish 8080:80 --mount=type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock gateway
```

Test in your browser with URL: `http://localhost:8080/nonexist`

To test in swarm environment, use mock-up micro services `ga6840/hello-httpd` and setup like the following
```
# docker swarm init
# docker network create --driver=overlay testnet
# docker service create --network testnet --publish 8080:80 --mount=type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock ga6840/gateway
# docker service create --label=gateway.port=8080 --label=gateway.route=404 --network testnet ga6840/hello-httpd node hello.js 404
```
