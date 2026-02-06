FROM debian:bullseye
LABEL maintainer="Razvan Crainea <razvan@opensips.org>"

LABEL             app=${APP}
ARG               SAMPO_PORT=1042
ARG               APP=sampo

USER root

# Set Environment Variables
ENV DEBIAN_FRONTEND noninteractive

# Updated to 3.6
ARG OPENSIPS_VERSION=3.6
ARG OPENSIPS_BUILD=releases

# Install basic components
# Added 'curl' and 'ca-certificates' explicitly early for repo setup
RUN apt-get -y update -qq && \
    apt-get -y install bash gnupg2 ca-certificates curl socat python3 gettext-base default-mysql-client python3-pip libpcre3-dev

# Add OpenSIPS GPG Key and Repository
# Note: apt-key is deprecated; we now use signed-by keyrings
RUN curl -o /usr/share/keyrings/opensips-org.gpg https://apt.opensips.org/opensips-org.gpg
RUN echo "deb [signed-by=/usr/share/keyrings/opensips-org.gpg] https://apt.opensips.org bullseye ${OPENSIPS_VERSION}-${OPENSIPS_BUILD}" > /etc/apt/sources.list.d/opensips.list

# Install OpenSIPS
RUN apt-get -y update -qq && apt-get -y install opensips

# Install CLI (Optional)
ARG OPENSIPS_CLI=false
RUN if [ ${OPENSIPS_CLI} = true ]; then \
    echo "deb [signed-by=/usr/share/keyrings/opensips-org.gpg] https://apt.opensips.org bullseye cli-nightly" > /etc/apt/sources.list.d/opensips-cli.list \
    && apt-get -y update -qq && apt-get -y install opensips-cli \
    ;fi

# Install Modules
# Note: Ensure these specific modules exist in your 3.6 setup; names are generally backward compatible
RUN apt-get -y install opensips-mysql-module opensips-regex-module opensips-restclient-module opensips-http-modules opensips-json-module opensips-tls-module opensips-auth-modules opensips-wss-module make

# Clean up apt lists to reduce image size
RUN rm -rf /var/lib/apt/lists/*

# Netdiscover tool
RUN curl -qL -o /usr/bin/netdiscover https://github.com/CyCoreSystems/netdiscover/releases/download/v1.2.3/netdiscover.linux.amd64
RUN chmod +x /usr/bin/netdiscover

# Copy configs
COPY ./configs/opensips.cfg.template /tmp/opensips.cfg
COPY entrypoint.sh /entrypoint.sh
COPY create_opensips_cfg .

# Python dependencies
# 'whereis' is purely informational here, usually removed in prod but left as requested
RUN whereis python3
RUN python3 -m pip install pymysql pybars3

# Add sampo files
ENV               APP=${APP} \
                  DEBUG=false \
                  SAMPO_PORT=${SAMPO_PORT} \
                  SSH_AUTH_SOCK=/ssh-agent

# Install sampo, the config, and the scripts/ directory
COPY              ./${APP}/sampo.sh /${APP}/sampo.sh
COPY              ./${APP}/sampo.conf /${APP}/sampo.conf
COPY              ./${APP}/scripts /${APP}/scripts
COPY              ./tls /etc/opensips/tls
COPY              ./ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

RUN               chmod 0755 /${APP}/${APP}.sh
RUN               chmod 0644 /${APP}/${APP}.conf
#RUN sed -i "s/^\(socket\|listen\)=udp.*5060/\1=udp:eth0:5060/g" /etc/opensips/opensips.cfg

EXPOSE ${SAMPO_PORT}
EXPOSE 5060/udp

RUN chmod +x /entrypoint.sh

VOLUME [ "/ssh-agent"]

ENTRYPOINT ["/entrypoint.sh"]