FROM debian:bullseye
LABEL maintainer="Razvan Crainea <razvan@opensips.org>"

# Environment Variables
ENV DEBIAN_FRONTEND=noninteractive
ARG SAMPO_PORT=1042
ARG APP=sampo
ARG OPENSIPS_VERSION=3.6
ARG OPENSIPS_BUILD=releases

USER root

# 1. Install Base Dependencies + Log & Schedule Tools
RUN apt-get -y update -qq && \
    apt-get -y install bash gnupg2 ca-certificates curl socat python3 gettext-base \
    default-mysql-client python3-pip libpcre3-dev rsyslog cron procps && \
    rm -rf /var/lib/apt/lists/*

# 2. Add OpenSIPS GPG & Repo
RUN curl -o /usr/share/keyrings/opensips-org.gpg https://apt.opensips.org/opensips-org.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/opensips-org.gpg] https://apt.opensips.org bullseye ${OPENSIPS_VERSION}-${OPENSIPS_BUILD}" > /etc/apt/sources.list.d/opensips.list

# 3. Install OpenSIPS & Modules
RUN apt-get -y update -qq && apt-get -y install opensips opensips-mysql-module \
    opensips-regex-module opensips-restclient-module opensips-http-modules \
    opensips-json-module opensips-tls-module opensips-auth-modules opensips-wss-module make && \
    rm -rf /var/lib/apt/lists/*

# 4. Setup Dual Logging Routing (rsyslog)
# Captures local0 into a file and streams to stdout
RUN mkdir -p /var/log/opensips && \
    echo "local0.* /var/log/opensips/opensips.log\nlocal0.* /dev/stdout" > /etc/rsyslog.d/opensips.conf

# 5. Setup Cleanup Task
COPY scripts/cleanup_opensips_logs.sh /usr/local/bin/cleanup_opensips_logs.sh
RUN mkdir -p /etc/cron.d

RUN chmod +x /usr/local/bin/cleanup_opensips_logs.sh && \
    echo "0 3 * * * /usr/local/bin/cleanup_opensips_logs.sh" > /etc/cron.d/log-cleanup && \
    chmod 0644 /etc/cron.d/log-cleanup && \
    crontab /etc/cron.d/log-cleanup

# 6. Setup Remaining Application Files
RUN curl -qL -o /usr/bin/netdiscover https://github.com/CyCoreSystems/netdiscover/releases/download/v1.2.3/netdiscover.linux.amd64 && \
    chmod +x /usr/bin/netdiscover

COPY ./configs/opensips.cfg.template /tmp/opensips.cfg
COPY entrypoint.sh /entrypoint.sh
COPY create_opensips_cfg .
COPY ./${APP}/sampo.sh /${APP}/sampo.sh
COPY ./${APP}/sampo.conf /${APP}/sampo.conf
COPY ./${APP}/scripts /${APP}/scripts
COPY ./tls /etc/opensips/tls
COPY ./ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

RUN chmod +x /entrypoint.sh && \
    chmod 0755 /${APP}/${APP}.sh && \
    chmod 0644 /${APP}/${APP}.conf && \
    python3 -m pip install pymysql pybars3

EXPOSE ${SAMPO_PORT} 5060/udp
VOLUME [ "/ssh-agent"]
ENTRYPOINT ["/entrypoint.sh"]