FROM debian:buster
RUN sed -i s@/deb.debian.org/@/mirrors.aliyun.com/@g /etc/apt/sources.list
RUN apt-get update
RUN apt-get -y install --no-install-recommends wget gnupg ca-certificates
RUN wget -O - https://openresty.org/package/pubkey.gpg | apt-key add -
RUN echo "deb http://openresty.org/package/debian `grep -Po 'VERSION="[0-9]+ \(\K[^)]+' /etc/os-release` openresty" | tee /etc/apt/sources.list.d/openresty.list
RUN apt-get update
RUN apt-get install -y --no-install-recommends openresty openresty-opm
#RUN apt-get install -y --no-install-recommends nginx libnginx-mod-http-lua # The nginx-lua way
RUN opm install ledgetech/lua-resty-http
RUN opm install SkyLothar/lua-resty-jwt
RUN opm install knyar/nginx-lua-prometheus
RUN opm install anjia0532/lua-resty-maxminddb
ENV PATH="${PATH}:/usr/local/openresty/nginx/sbin:/usr/local/openresty/bin"
WORKDIR /root
RUN mkdir logs/ conf/ .well-known/
RUN echo '<!DOCTYPE html><html><body>test</body></html>' > .well-known/test.html
## Install Let's encrypt
RUN apt-get install -y --no-install-recommends git cron
RUN git clone --depth 1 https://github.com/approach0/acme.sh.git
RUN cd ./acme.sh && ./acme.sh --install
## Get GeoIP database
ENV license=vP65qsGQCxfewnTs
RUN wget "https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-City&license_key=${license}&suffix=tar.gz" -O GeoLite2-City.tar.gz
RUN tar -xzvf GeoLite2-City.tar.gz && mv GeoLite2-City*/*.mmdb ./conf
RUN rm -rf GeoLite2-*
RUN apt-get install -y --no-install-recommends libmaxminddb0 libmaxminddb-dev mmdb-bin # for libmaxminddb.so
## Copy files into image
COPY ./nginx.conf ./conf/
COPY ./*.lua ./conf/
RUN chmod +x ./conf/*.lua
CMD nginx -p `pwd`/ -c conf/nginx.conf -g 'daemon off;'
