FROM debian:bookworm-slim
RUN apt-get update \
    && apt-get install --yes -qq --no-install-recommends --no-install-suggests \
    iproute2 \
    nftables \
    wireguard-tools \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/*
COPY docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]
