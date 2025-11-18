#!/usr/bin/env bash
set -euo pipefail

: "${FORGEJO_USER:?FORGEJO_USER is required}"
RUNNER_BIN="/usr/local/bin/forgejo-runner"

if [[ ! -x "${RUNNER_BIN}" ]]; then
  echo "runner binary missing at ${RUNNER_BIN}"
  exit 1
fi

# stop systemd instance
systemctl stop "forgejo-runner@${FORGEJO_USER}" || true
systemctl disable "forgejo-runner@${FORGEJO_USER}" || true

# run unregister if config present
RUNNER_HOME="/home/${FORGEJO_USER}"
if [[ -d "${RUNNER_HOME}/.runner" ]]; then
  su - "${FORGEJO_USER}" -c "${RUNNER_BIN} unregister --token '' --name '' --instance '' || true" || true
  rm -rf "${RUNNER_HOME}/.runner"
fi

# remove sudoers
rm -f "/etc/sudoers.d/${FORGEJO_USER}"
echo "Unregistered runner for ${FORGEJO_USER}"
