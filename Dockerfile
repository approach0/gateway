FROM debian:buster
RUN sed -i s@/deb.debian.org/@/mirrors.aliyun.com/@g /etc/apt/sources.list
RUN apt-get update
RUN apt-get -y install --no-install-recommends wget gnupg ca-certificates

## Setup OpenResty
RUN wget -O - https://openresty.org/package/pubkey.gpg | apt-key add -
RUN echo "deb http://openresty.org/package/debian `grep -Po 'VERSION="[0-9]+ \(\K[^)]+' /etc/os-release` openresty" | tee /etc/apt/sources.list.d/openresty.list
RUN apt-get update
RUN apt-get install -y --no-install-recommends openresty openresty-opm
RUN opm install ledgetech/lua-resty-http
RUN opm install SkyLothar/lua-resty-jwt
RUN opm install knyar/nginx-lua-prometheus
RUN opm install anjia0532/lua-resty-maxminddb
ENV PATH="${PATH}:/usr/local/openresty/nginx/sbin:/usr/local/openresty/bin"

WORKDIR /root

## Get GeoIP database
RUN wget https://raw.githubusercontent.com/t-k-/download/master/downcity.tar.gz -O GeoLite2-City.tar.gz && tar -xzvf GeoLite2-City.tar.gz && mv GeoLite2-City*/*.mmdb ./conf && rm -rf GeoLite2-City*
RUN mkdir -p /root/conf
RUN apt-get install -y --no-install-recommends libmaxminddb0 libmaxminddb-dev mmdb-bin # for libmaxminddb.so

## Install Let's encrypt
RUN apt-get install -y --no-install-recommends git cron
RUN git clone --depth 1 https://github.com/approach0/acme.sh.git
RUN mkdir .well-known && echo '<!DOCTYPE html><html><body>test</body></html>' > .well-known/test.html
RUN openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes -subj "/C=US/ST=Oregon/L=Portland/O=Linux/OU=Org/CN=www.microsoft.com" # a self-signed key to bootstrap TLS

## Setup root directory
RUN mkdir -p logs/ conf/
COPY ./*.conf ./conf/
COPY ./*.lua ./conf/
COPY ./entrypoint.sh .
RUN chmod +x ./conf/*.lua

CMD ./entrypoint.sh
