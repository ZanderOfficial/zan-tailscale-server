#!/usr/bin/env bash
# Run by the Windows boot-time scheduled task (as root inside WSL).
# systemd starts Docker; Docker restarts the containers (restart: unless-stopped).
# This script then stays alive so WSL doesn't shut the VM down while idle.
systemctl start docker
logger -t local-ai "WSL keepalive started; docker is $(systemctl is-active docker)"
exec sleep infinity
