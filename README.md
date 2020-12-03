# Approach Zero Gateway :guard:
This is yet another API gateway service, built upon OpenResty in minimalist fashion.

## Features
* Docker Swarm service discovery
* JWT login
* Rate limit for unique IP
* Statistics and Metrics (based on Prometheus)
* TLS / Let's encrypt and auto-renewal

## Quick start
Build the image
```
# docker build -t gateway .
```

Run gateway locally
```
# docker run -it --publish 8080:443 --mount=type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock gateway
```

Test in your browser with URL: `http://localhost:8080/nonexist`

## Swarm environment

### Initialization
To test in a swarm environment, use mock-up micro services `ga6840/hello-httpd` and setup like the following:
```
# docker swarm init
# docker network create --driver=overlay --attachable testnet
# docker service create --name gateway --network testnet --publish 8080:443 --mount=type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock ga6840/gateway
```

### Hello-world service discovery
Setup a few hello-world services to test the gateway
```
# docker service create --label=gateway.port=8080 --label=gateway.route=404 --network testnet ga6840/hello-httpd node hello.js 404
# docker service create --label=gateway.port=8080 --label=gateway.route=_root_ --network testnet ga6840/hello-httpd node hello.js This is index service
# docker service create --label=gateway.port=8080 --label=gateway.route=foo --network testnet ga6840/hello-httpd node hello.js This is foo service
```
Now try visiting `http://localhost:8080/foo?bar=baz` to visit micro-service `foo`, and `http://localhost:8080/?bar=baz` for the landing root page.
The former URL will be automatically redirected to an URI with trailing slash (`http://localhost:8080/foo/?bar=baz`),
this rule is enforced by gateway to ensure requests to relative paths in service UI are working as expected.

### JWT login
Want to have a JWT login service?
```
# mkdir -p ./tmp
# docker service create --name testdb --label=gateway.port=80 --label=gateway.route=usersdb --mount=type=bind,src=`pwd`/tmp,dst=/postgres/data --network testnet ga6840/postgres13
# docker run --env LATTICE_DATABASE_HOST=testdb --network testnet ga6840/lattice node db.js --init
# docker service create --env LATTICE_DATABASE_HOST=testdb --label=gateway.port=19721 --label=gateway.route=lattice --label=gateway.jwt_port=64264 --network testnet ga6840/lattice
# docker service create --label=gateway.port=8080 --label=gateway.route=bar --label=gateway.protect=/ --network testnet ga6840/hello-httpd node hello.js This is bar service
# docker service create --label=gateway.port=8080 --label=gateway.route=baz --label=gateway.protect=/pocket,/bag --network testnet ga6840/hello-httpd node hello.js This is baz service
```
to test it, issue:
```
# docker run --network host ga6840/lattice node test/test-authd.js --host http://localhost:8080/lattice
{ pass: true,
  msg:
   { info:
      { exp: 1603291752,
        maxAge: 10,
        loggedInAs: 'admin',
        scope: [Array] },
     algorithm: { algorithm: 'HS256' },
     token:
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE2MDMyOTE3NTIsIm1heEFnZSI6MTAsImxvZ2dlZEluQXMiOiJhZG1pbiIsInNjb3BlIjpbIi8qIl0sImlhdCI6MTYwMzI5MTc0Mn0.MY5T_ROirpdoDDzBz17zJfe8vjtQmwC2bw392La3nnw' } }
lattice-jwt-token=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE2MDMyOTE3NTIsIm1heEFnZSI6MTAsImxvZ2dlZEluQXMiOiJhZG1pbiIsInNjb3BlIjpbIi8qIl0sImlhdCI6MTYwMzI5MTc0Mn0.MY5T_ROirpdoDDzBz17zJfe8vjtQmwC2bw392La3nnw; Max-Age=10; Path=/; Expires=Wed, 21 Oct 2020 14:49:12 GMT
{ pass: true }
```

### Prometheus metrics
Now, let us hookup a Prometheus monitor for metrics
```
# docker run -it --name prometheus -p 9090:9090 --mount=type=bind,src=`pwd`/prometheus.yml,dst=/etc/prometheus/prometheus.yml --network testnet prom/prometheus
```
to view Prometheus *expression browser*.

A quick-start prometheus.yml looks like this
```
scrape_configs:
  - job_name: 'foo'
    scrape_interval: 5s
    metrics_path: '/metrics'
    static_configs:
    - targets: ['gateway']
```
In query box, enter metrics such as `total_requests` as defined in `init.lua` file.

### Let's Encrypt certificates bootstrap
When `entrypoint.sh` is passed with a domain name argument, it will invoke `acme.sh` to install HTTPs certificates using Let's Encrypt service.

Mount a persistent directory or volume to `/root/keys` directory in container. Otherwise each time this service is updated, it will consume the certificates issue quota posed by Let's Encrypt.
