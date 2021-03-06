FROM alpine:latest


ENV TOR_START_PORT_SOCKS 9000
ENV TOR_START_PORT_CONTROL 9900
ENV TOR_INSTANCES 10
ENV BUILD_PACKAGES="build-base openssl" \
    PACKAGES="tor sudo bash git haproxy privoxy npm procps"

# install requirements
RUN \
  apk update && apk add --no-cache $BUILD_PACKAGES $PACKAGES && \
  npm install -g http-proxy-to-socks

# fix certificate problem (avoid con reset by peer)
RUN \
  apk add ca-certificates wget && \
  update-ca-certificates

# install polipo
RUN \
	wget https://github.com/jech/polipo/archive/master.zip -O polipo.zip && \
	unzip polipo.zip && \
  cd polipo-master && \
  make && \
  install polipo /usr/local/bin/ && \
  cd .. && \
  rm -rf polipo.zip polipo-master && \
  mkdir -p /usr/share/polipo/www /var/cache/polipo 

# clean build packages
RUN \
  apk del $BUILD_PACKAGES

# install multitor
RUN	git clone https://github.com/trimstray/multitor && \
	cd multitor && \
	./setup.sh install && \
# create log folders
  mkdir -p /var/log/multitor/privoxy/ && \
  mkdir -p /var/log/polipo/ && \
# let haproxy listen from outside, instand only in the docker container
  sed -i s/127.0.0.1:16379/0.0.0.0:16379/g templates/haproxy-template.cfg

WORKDIR /multitor/
EXPOSE	16379

CMD multitor \
--init ${TOR_INSTANCES} \
--user root \
--socks-port ${TOR_START_PORT_SOCKS} \
--control-port ${TOR_START_PORT_CONTROL} \
--proxy privoxy \
--haproxy \
--verbose \
--debug > /mnt/multitor.log; tail -f /mnt/multitor.log
