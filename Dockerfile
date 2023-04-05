FROM debian:buster
LABEL maintainer="Razvan Crainea <razvan@opensips.org>"

USER root

# Set Environment Variables
ENV DEBIAN_FRONTEND noninteractive

ARG OPENSIPS_VERSION=3.1
ARG OPENSIPS_BUILD=releases

#install basic components
RUN apt-get -y update -qq && apt-get -y install bash gnupg2 ca-certificates curl socat

#add keyserver, repository
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 049AD65B
RUN echo "deb https://apt.opensips.org buster ${OPENSIPS_VERSION}-${OPENSIPS_BUILD}" >/etc/apt/sources.list.d/opensips.list

RUN apt-get -y update -qq && apt-get -y install opensips

ARG OPENSIPS_CLI=false
RUN if [ ${OPENSIPS_CLI} = true ]; then \
    echo "deb https://apt.opensips.org buster cli-nightly" >/etc/apt/sources.list.d/opensips-cli.list \
    && apt-get -y update -qq && apt-get -y install opensips-cli \
    ;fi

#ARG OPENSIPS_EXTRA_MODULES

RUN apt-cache search "opensips-"

RUN apt-cache search "opensips"
RUN apt-get -y install opensips-mysql-module opensips-regex-module opensips-restclient-module opensips-http-modules opensips-json-module make

RUN rm -rf /var/lib/apt/lists/*

RUN curl -qL -o /usr/bin/netdiscover https://github.com/CyCoreSystems/netdiscover/releases/download/v1.2.3/netdiscover.linux.amd64
RUN chmod +x /usr/bin/netdiscover

# Copy configs

RUN cat /etc/opensips/opensips.cfg

COPY ./configs/opensips.cfg /etc/opensips/opensips.cfg
COPY entrypoint.sh /entrypoint.sh
COPY sampo .
#RUN sed -i "s/^\(socket\|listen\)=udp.*5060/\1=udp:eth0:5060/g" /etc/opensips/opensips.cfg

EXPOSE 1042/tcp
EXPOSE 5060/udp

RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
#ENTRYPOINT ["/usr/sbin/opensips", "-FE"]
