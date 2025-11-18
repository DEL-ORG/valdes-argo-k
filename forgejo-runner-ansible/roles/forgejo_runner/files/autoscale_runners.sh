#!/usr/bin/env bash
set -euo pipefail
# Very small local autoscaler:
# - Observes a rough metric (number of pending jobs) via available API if available (not implemented)
# - Fallback: scale based on CPU load average if pending metric not provided.
# This script expects the Ansible-managed list in /etc/forgejo_runner_config.json (optional).
# Here we implement a very conservative CPU-based scale: spawn additional systemd instance users
# named runner-N when CPU load > 1.0 per CPU and shrink when low.

MIN={{ forgejo_runner__autoscale_min }}
MAX={{ forgejo_runner__autoscale_max }}
PENDING_THRESHOLD={{ forgejo_runner__autoscale_pending_threshold }}

# naive metric: 1-minute loadavg
loadavg=$(cut -d' ' -f1 /proc/loadavg)
loadint=${loadavg%.*}
current_instances=$(systemctl list-units --type=service --state=active | grep -c '^forgejo-runner@')

if (( loadint > PENDING_THRESHOLD )); then
  # attempt to scale up
  to_create=$(( loadint - current_instances ))
  if (( to_create > 0 )); then
    for i in $(seq 1 $to_create); do
      if (( current_instances >= MAX )); then
        exit 0
      fi
      # create a simple new user and start a new instance
      new_user="forgejo-runner-extra-${RANDOM}"
      useradd -m -s /bin/bash "${new_user}" || true
      touch /home/${new_user}/.runner
      systemctl enable --now forgejo-runner@${new_user} || true
      current_instances=$((current_instances+1))
    done
  fi
else
  # scale down: stop extra users matching pattern
  for u in $(compgen -u | grep '^forgejo-runner-extra-' || true); do
    if (( current_instances <= MIN )); then
      break
    fi
    systemctl stop forgejo-runner@${u} || true
    systemctl disable forgejo-runner@${u} || true
    userdel -r ${u} || true
    current_instances=$((current_instances-1))
  done
fi
