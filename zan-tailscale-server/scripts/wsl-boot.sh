#!/usr/bin/env bash
# Run by the Windows boot-time scheduled task (as root inside WSL).
# systemd starts Docker; Docker restarts the containers (restart: unless-stopped).
# This script then stays alive so WSL doesn't shut the VM down while idle.
# OpenHands sandboxes use host networking and copy this host's /etc/hosts. They call back to the
# app at host.docker.internal:<port>, so map it to loopback. (WSL regenerates /etc/hosts on start,
# hence re-applied at every boot. On native Ubuntu, add the line once.)
grep -qE '^[^#]*\shost\.docker\.internal(\s|$)' /etc/hosts || echo '127.0.0.1 host.docker.internal' >> /etc/hosts
systemctl start docker
logger -t local-ai "WSL keepalive started; docker is $(systemctl is-active docker)"
exec sleep infinity
