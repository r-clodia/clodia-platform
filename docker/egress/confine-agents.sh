#!/usr/bin/env bash
# Confine the agent container's egress (clodia-platform#104, phase C).
#
# WHY A HOST FIREWALL AND NOT `internal: true`
# --------------------------------------------
# A docker network with `internal: true` does block egress — measured — but it
# also breaks host port publishing, and the API must stay reachable from the host
# for the browser to talk to it. So the network stays a normal bridge and the
# block lives here, in the one place that can distinguish "packet leaving the
# host" from "packet arriving from the host".
#
# WHAT IT DOES
# ------------
# In the DOCKER-USER chain (evaluated before docker's own rules):
#   * allow the agents' subnet to reach the egress proxy, and only it;
#   * allow traffic that stays inside the docker subnets (gateway, webui, pwa);
#   * allow replies to connections opened from outside (so publishing works);
#   * drop everything else leaving that subnet.
# The gateway is attached to a SECOND network and leaves through that subnet,
# which no rule here touches: mediated verbs keep working.
#
# Run as root. Idempotent: it flushes its own rules before adding them.
# Rollback: ./confine-agents.sh --off
set -euo pipefail

INT_SUBNET="${CLODIA_INT_SUBNET:-172.31.7.0/24}"
EXT_SUBNET="${CLODIA_EXT_SUBNET:-172.31.8.0/24}"
PROXY_NAME="${CLODIA_EGRESS_PROXY_CONTAINER:-clodia-personal-egress-proxy-1}"
COMMENT="clodia-agent-egress"

[[ $EUID -eq 0 ]] || { echo "must run as root (iptables)"; exit 1; }

flush() {
  # Remove previous rules of ours, identified by the comment.
  while iptables -L DOCKER-USER -n --line-numbers | grep -q "$COMMENT"; do
    local n
    n=$(iptables -L DOCKER-USER -n --line-numbers | grep "$COMMENT" | head -1 | awk '{print $1}')
    iptables -D DOCKER-USER "$n"
  done
}

if [[ "${1:-}" == "--off" ]]; then
  flush
  echo "confinement removed: the agents' subnet can reach the network again"
  exit 0
fi

PROXY_IP=$(docker inspect "$PROXY_NAME" \
  --format '{{range .NetworkSettings.Networks}}{{if .IPAddress}}{{.IPAddress}} {{end}}{{end}}' \
  2>/dev/null | tr ' ' '\n' | grep -F "${INT_SUBNET%.*.*}" | head -1 || true)
[[ -n "$PROXY_IP" ]] || { echo "egress proxy not found on $INT_SUBNET (container: $PROXY_NAME)"; exit 1; }

flush
# Order matters: accepts first, drop last.
iptables -I DOCKER-USER 1 -s "$INT_SUBNET" -d "$PROXY_IP" -p tcp --dport 8888 \
  -m comment --comment "$COMMENT allow-proxy" -j ACCEPT
iptables -I DOCKER-USER 2 -s "$INT_SUBNET" -d "$INT_SUBNET" \
  -m comment --comment "$COMMENT allow-internal" -j ACCEPT
iptables -I DOCKER-USER 3 -s "$INT_SUBNET" -d "$EXT_SUBNET" \
  -m comment --comment "$COMMENT allow-ext-services" -j ACCEPT
iptables -I DOCKER-USER 4 -s "$INT_SUBNET" -m conntrack --ctstate ESTABLISHED,RELATED \
  -m comment --comment "$COMMENT allow-established" -j ACCEPT
iptables -A DOCKER-USER -s "$INT_SUBNET" \
  -m comment --comment "$COMMENT drop-rest" -j DROP

echo "confinement active — proxy $PROXY_IP is the only route out of $INT_SUBNET"
echo "verify:  docker exec <agent-container> sh -c 'curl -s -m5 https://example.com || echo BLOCKED'"
