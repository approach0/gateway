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
	# Enable TLS in Nginx using boostrap key/cert.pem
	sed -i 's/# UNCOMMENT_THIS//g' ./conf/nginx.conf
	sed -i '/DELETE_THIS/d' ./conf/nginx.conf
	cat ./conf/nginx.conf
	$RELOAD_CMD

	# try to reload a real key/cert.pem, install it if it's missing.
	set -x
	CERT_DIR='/root/keys'
	UPDATE_CERT="cp $CERT_DIR/key.pem /root; cp $CERT_DIR/cert.pem /root; $RELOAD_CMD"
	if [ -e $CERT_DIR/key.pem ]; then
		echo "Real certificates exist, use them..."
		bash -c "$UPDATE_CERT"

		# setup cron job by myself
		echo "23 1 * * * /root/.acme.sh/acme.sh --cron --home /root/.acme.sh > /dev/null" | crontab -
	else
		pushd ./acme.sh
		# Install acme.sh in ~/.acme.sh directory
		./acme.sh --install
		# Verify and issue certificate
		./acme.sh --issue -d $DOMAIN -d www.$DOMAIN -w /root
		# Generate certificate pem files
		mkdir -p $CERT_DIR
		./acme.sh --install-cert -d $DOMAIN -d www.$DOMAIN \
			--key-file $CERT_DIR/key.pem \
			--fullchain-file $CERT_DIR/cert.pem \
			--reloadcmd "bash -c '$UPDATE_CERT'"
		popd
	fi
	set +x

	# see if we have cron job to renew certificates
	crontab -l

	echo 'To forcely renew certificates:'
	echo ./acme.sh --renew -d $DOMAIN -d www.$DOMAIN --force
fi

fg
