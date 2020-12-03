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
	$RELOAD_CMD

	# try to reload a real key/cert.pem, install it if it's missing.
	CERT_DIR='/root/keys'
	UPDATE_CERT="cp $CERT_DIR/key.pem /root; cp $CERT_DIR/cert.pem /root; $RELOAD_CMD"
	if [ -e $CERT_DIR/key.pem ]; then
		$UPDATE_CERT
	else
		pushd ./acme.sh
		# Verify and issue certificate
		./acme.sh --issue -d $DOMAIN -d www.$DOMAIN -w /root
		# Generate certificate pem files
		mkdir -p $CERT_DIR
		./acme.sh --install-cert -d $DOMAIN -d www.$DOMAIN \
			--key-file $CERT_DIR/key.pem \
			--fullchain-file $CERT_DIR/cert.pem \
			--reloadcmd "$UPDATE_CERT"
		popd
	fi

	# We should have timer job to renew certification now
	crontab -l

	echo 'To forcely renew certification:'
	echo ./acme.sh --renew -d $DOMAIN -d www.$DOMAIN --force
fi

fg
