#!/bin/bash
DOMAIN="$1"

# Enable job control
set -m

# Original entrypoint command
set -x
nginx -p `pwd`/ -c ./conf/nginx.conf -g 'daemon off;' &
sleep 3 # ensure nginx is ready for LetsEncrypt challenge
set +x

# If DOMAIN env variable is set, setup TLS server.
# Example: DOMAIN=approach0.xyz
if [ -n "$DOMAIN" ]; then
	RELOAD_CMD='nginx -p /root/ -s reload'

	pushd ./acme.sh
	# Verify and issue certificate
	./acme.sh --issue -d $DOMAIN -d www.$DOMAIN -w /root
	# Generate certificate pem files
	./acme.sh --install-cert -d $DOMAIN -d www.$DOMAIN \
		--key-file /root/key.pem \
		--fullchain-file /root/cert.pem \
		--reloadcmd "$RELOAD_CMD"
	popd

	# Enable TLS in nginx.conf and reload httpd
	sed -i 's/# UNCOMMENT_THIS//g' ./conf/nginx.conf
	sed -i '/DELETE_THIS/d' ./conf/nginx.conf
	$RELOAD_CMD

	# We should have timer job to renew certification now
	crontab -l

	echo 'To forcely renew certification:'
	echo ./acme.sh --renew -d $DOMAIN -d www.$DOMAIN --force
fi

fg
