#!/bin/bash
set -euo pipefail

HOSTNAME_TO_ADD="${hostname:-$(hostname)}"
DESIRED_LINE="127.0.1.1 ${HOSTNAME_TO_ADD}"
HOSTS_FILE="/etc/hosts"

if grep -qFx "$DESIRED_LINE" "$HOSTS_FILE"; then
  echo "OK: '${DESIRED_LINE}' already present in ${HOSTS_FILE}"
  exit 0
fi

cp -a "$HOSTS_FILE" "${HOSTS_FILE}.bak.$(date +%s)"
printf "\n%s\n" "$DESIRED_LINE" >> "$HOSTS_FILE"

echo "Added '${DESIRED_LINE}' to ${HOSTS_FILE} (backup at ${HOSTS_FILE}.bak.*)"