#!/usr/bin/env bash
set -euo pipefail
# This script is executed by systemd timer or cron to refresh tokens for all runners.
# It expects a command configured in defaults (forgejo_runner__token_refresh_cmd) to return a token as stdout.
# If you use vault, perform the vault lookup in your Ansible playbook and populate forgejo_runner__token at deploy time.

REFRESH_CMD="{{ forgejo_runner__token_refresh_cmd | default('') }}"

if [[ -z "${REFRESH_CMD}" ]]; then
  echo "No refresh command configured. Exiting."
  exit 0
fi

TOKEN="$(${REFRESH_CMD})"
if [[ -z "${TOKEN}" ]]; then
  echo "Token refresh command returned empty token"
  exit 2
fi

# For each runner user in /etc/passwd that looks like a runner, re-run registration with the new token.
# This is intentionally conservative: re-register only if user has ~/.runner marker.
for home in /home/*; do
  user=$(basename "${home}")
  if [[ -d "${home}/.runner" ]]; then
    echo "Refreshing token for ${user}"
    su - "${user}" -c "/usr/local/bin/forgejo-runner register --no-interactive --token '${TOKEN}' || true"
  fi
done
