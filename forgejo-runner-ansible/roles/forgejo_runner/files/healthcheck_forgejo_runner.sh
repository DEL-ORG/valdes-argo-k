#!/usr/bin/env bash
set -euo pipefail
USER="${1:-}"
NAME="${2:-}"
TEXTDIR="{{ forgejo_runner__prometheus_textfile_dir }}"
OUTFILE="${TEXTDIR}/forgejo_runner_${USER}.prom"

if [[ -z "${USER}" ]]; then
  echo "Usage: $0 <user> <runner-name>"
  exit 2
fi

RUNNER_BIN="/usr/local/bin/forgejo-runner"
OK=0

if su - "${USER}" -c "test -f /home/${USER}/.runner/executor" >/dev/null 2>&1; then
  OK=1
fi

# write basic prometheus metric (1 = registered/present, 0 = missing)
mkdir -p "${TEXTDIR}"
cat > "${OUTFILE}" <<EOF
# HELP forgejo_runner_up Is the runner registered and present on host (1 = yes, 0 = no)
# TYPE forgejo_runner_up gauge
forgejo_runner_up{user="${USER}",name="${NAME}"} ${OK}
EOF

if [[ "${OK}" -eq 1 ]]; then
  exit 0
else
  exit 1
fi
