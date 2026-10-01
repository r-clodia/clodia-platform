# Minimal egress proxy: Alpine + Python (stdlib only), policy baked in.
# Pinned base digest is intentionally absent here — the file is meant to be
# reviewed and pinned by whoever deploys it, see docker/egress/README.md.
#
# It replaced tinyproxy (clodia-platform#463): same policy, plus the join of
# every request to the turn that made it, which tinyproxy has no way to log.
FROM alpine:3.21

RUN apk add --no-cache python3 \
 && mkdir -p /opt/egress /etc/egress

COPY egress_proxy.py /opt/egress/egress_proxy.py
COPY allowlist /etc/egress/allowlist

USER nobody
EXPOSE 8888
# No ports published on the host: reachable only from the internal network.
CMD ["python3", "-u", "/opt/egress/egress_proxy.py"]
