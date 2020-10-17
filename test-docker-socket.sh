# get all services
curl -v --unix-socket /var/run/docker.sock http://localhost/services
# inspect a service
curl -v --unix-socket /var/run/docker.sock http://localhost/services/foo
