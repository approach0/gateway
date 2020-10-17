FROM debian:buster
RUN sed -i s@/deb.debian.org/@/mirrors.aliyun.com/@g /etc/apt/sources.list
RUN apt-get update
RUN apt-get -y install --no-install-recommends wget gnupg ca-certificates
RUN wget -O - https://openresty.org/package/pubkey.gpg | apt-key add -
RUN echo "deb http://openresty.org/package/debian `grep -Po 'VERSION="[0-9]+ \(\K[^)]+' /etc/os-release` openresty" | tee /etc/apt/sources.list.d/openresty.list
RUN apt-get update
RUN apt-get install -y --no-install-recommends openresty
#RUN apt-get install -y --no-install-recommends nginx libnginx-mod-http-lua # The nginx-lua way
ENV PATH="${PATH}:/usr/local/openresty/nginx/sbin:/usr/local/openresty/bin"
WORKDIR /root
RUN mkdir logs/ conf/
COPY ./nginx.conf ./conf/
COPY ./*.lua ./conf/
RUN chmod +x ./conf/*.lua
CMD nginx -p `pwd`/ -c conf/nginx.conf -g 'daemon off;'
