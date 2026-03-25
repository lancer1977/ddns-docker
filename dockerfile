FROM alpine:3.20

RUN apk add --no-cache bash curl jq ca-certificates

WORKDIR /app

COPY scripts/ddns-sync.sh /scripts/ddns-sync.sh
COPY scripts/entrypoint.sh /scripts/entrypoint.sh
COPY scripts/healthcheck.sh /scripts/healthcheck.sh

RUN chmod +x /scripts/*.sh \
  && mkdir -p /state

VOLUME ["/state"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD /scripts/healthcheck.sh

ENTRYPOINT ["/scripts/entrypoint.sh"]
