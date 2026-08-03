# Minimal egress proxy: Alpine + tinyproxy, config baked in.
# Pinned base digest is intentionally absent here — the file is meant to be
# reviewed and pinned by whoever deploys it, see docker/egress/README.md.
FROM alpine:3.21

RUN apk add --no-cache tinyproxy \
 && mkdir -p /var/log/tinyproxy \
 && chown nobody:nogroup /var/log/tinyproxy

COPY tinyproxy.conf /etc/tinyproxy/tinyproxy.conf
COPY allowlist /etc/tinyproxy/allowlist

EXPOSE 8888
# No ports published on the host: reachable only from the internal network.
CMD ["tinyproxy", "-d", "-c", "/etc/tinyproxy/tinyproxy.conf"]
