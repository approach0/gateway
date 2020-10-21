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
docker build -t gateway .
```

Run gateway locally
```
docker run -it --publish 8080:80 --mount=type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock gateway
```

Test in your browser with URL: `http://localhost:8080/nonexist`
