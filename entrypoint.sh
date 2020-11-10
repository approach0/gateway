#!/bin/bash

# Original entrypoint command
set -x
nginx -p `pwd`/ -c ./conf/nginx.conf -g 'daemon off;'
set +x

# If DOMAIN env variable is set, setup TLS server.
# Example: DOMAIN=approach0.xyz
if [ -n "$DOMAIN" ]; then
	pushd ./acme.sh
	# Verify and issue certificate
	./acme.sh --issue -d $DOMAIN -d www.$DOMAIN -w /root
	# Generate certificate pem files
	./acme.sh --install-cert -d $DOMAIN -d www.$DOMAIN \
		--key-file /root/key.pem \
		--fullchain-file /root/cert.pem \
		--reloadcmd 'nginx -p /root/ -s reload'
	popd
	# Enable TLS in nginx.conf
	sed -i 's/# ssl_certificate/ssl_certificate/g' ./conf/nginx.conf
	# We should have timer job to renew certification now
	crontab -l

	echo 'To forcely renew certification:'
	echo ./acme.sh --renew -d $DOMAIN -d www.$DOMAIN --force
fi
