#!/usr/bin/env bash
set -euo pipefail

# usage: install_forgejo_runner.sh <TOKEN> [labels...]
TOKEN="${1:-}"
shift || true
LABELS="${*:-}"

: "${FORGEJO_USER:?FORGEJO_USER is required (env)}"
: "${FORGEJO_INSTANCE:?FORGEJO_INSTANCE is required (env)}"
: "${FORGEJO_RUNNER_NAME:?FORGEJO_RUNNER_NAME is required (env)}"

FORGEJO_HOME="/home/${FORGEJO_USER}"
FORGEJO_RUNNER_EXEC="/usr/local/bin/forgejo-runner"
MARKER_DIR="${FORGEJO_HOME}/.runner"

if [[ -z "${TOKEN}" ]]; then
  echo "No token supplied as arg. If you expect the environment to provide the token, provide it as the first arg."
  exit 2
fi

echo "Installing Forgejo runner for ${FORGEJO_USER} (name=${FORGEJO_RUNNER_NAME})"

apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ca-certificates curl gnupg jq wget

if ! command -v node >/dev/null 2>&1; then
  echo "Installing node LTS (optional)"
  curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
  DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs
fi

# create user if missing
if ! id "${FORGEJO_USER}" &>/dev/null; then
  useradd -m -d "${FORGEJO_HOME}" -s /bin/bash "${FORGEJO_USER}"
fi

echo "${FORGEJO_USER} ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/${FORGEJO_USER}"
chmod 0440 "/etc/sudoers.d/${FORGEJO_USER}"

# ensure docker group membership if present
if getent group docker >/dev/null; then
  usermod -aG docker "${FORGEJO_USER}" || true
fi

# simple detection for architecture
ARCH="$(uname -m)"
case "${ARCH}" in
  x86_64) RUNNER_ARCH="linux-amd64" ;;
  aarch64|arm64) RUNNER_ARCH="linux-arm64" ;;
  *) echo "Unsupported architecture: ${ARCH}"; exit 1 ;;
esac

# hardcoded fallback runner version (change in role defaults to pin)
RUNNER_VERSION="6.2.2"
RUNNER_BIN="/usr/local/bin/forgejo-runner"

if [[ ! -x "${RUNNER_BIN}" ]]; then
  TMP_BIN="$(mktemp)"
  DOWNLOAD_URL="https://code.forgejo.org/forgejo/runner/releases/download/v${RUNNER_VERSION}/forgejo-runner-${RUNNER_VERSION}-linux-amd64"
  echo "Downloading runner from ${DOWNLOAD_URL}"
  wget -q -O "${TMP_BIN}" "${DOWNLOAD_URL}"
  install -m 0755 "${TMP_BIN}" "${RUNNER_BIN}"
  rm -f "${TMP_BIN}"
fi

# create user's runner home config if missing
if [[ ! -d "${MARKER_DIR}" ]]; then
  su - "${FORGEJO_USER}" -c "mkdir -p ${MARKER_DIR} && chmod 700 ${MARKER_DIR}"
fi

# Register only if not already registered (runner config exists under ~/.runner or _work)
if su - "${FORGEJO_USER}" -c "test -f ${FORGEJO_HOME}/.runner/executor" >/dev/null 2>&1; then
  echo "Runner appears already registered for ${FORGEJO_USER} — skipping registration"
else
  echo "Registering runner (non-interactive)"
  su - "${FORGEJO_USER}" -c \
    "${RUNNER_BIN} register --no-interactive --token '${TOKEN}' --instance '${FORGEJO_INSTANCE}' --name '${FORGEJO_RUNNER_NAME}' --labels '${LABELS}' || true"
fi

# Create systemd service file is handled by ansible template. Ensure service can start
systemctl daemon-reload || true
systemctl enable --now "forgejo-runner@${FORGEJO_USER}" || true

echo "Runner installed for ${FORGEJO_USER}"



#!/usr/bin/env bash
# set -euo pipefail

# # usage: install_forgejo_runner.sh <TOKEN> [labels...]
# TOKEN="${1:-}"
# shift || true
# LABELS="${*:-}"

# : "${FORGEJO_USER:?FORGEJO_USER is required (env)}"
# : "${FORGEJO_INSTANCE:?FORGEJO_INSTANCE is required (env)}"
# : "${FORGEJO_RUNNER_NAME:?FORGEJO_RUNNER_NAME is required (env)}"

# FORGEJO_HOME="/home/${FORGEJO_USER}"
# FORGEJO_RUNNER_EXEC="/usr/local/bin/forgejo-runner"
# MARKER_FILE="${FORGEJO_HOME}/.runner_registered"
# REG_FILE="${FORGEJO_HOME}/.runner"   # runner expects a file named ".runner"

# if [[ -z "${TOKEN}" ]]; then
#   echo "No token supplied as arg. If you expect the environment to provide the token, provide it as the first arg."
#   exit 2
# fi

# echo "Installing Forgejo runner for ${FORGEJO_USER} (name=${FORGEJO_RUNNER_NAME})"

# # Safe apt update with retry if lock present
# attempts=0
# until apt-get update -y >/dev/null 2>&1; do
#   attempts=$((attempts+1))
#   if (( attempts >= 10 )); then
#     echo "apt-get update failed after ${attempts} attempts" >&2
#     exit 10
#   fi
#   echo "apt-get update blocked by lock or network — retrying in 3s (attempt ${attempts})"
#   sleep 3
# done

# DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ca-certificates curl gnupg jq wget || true

# # Node.js optional
# if ! command -v node >/dev/null 2>&1; then
#   echo "Installing node LTS (optional)"
#   curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - >/dev/null 2>&1 || true
#   DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs || true
# fi

# # create user if missing
# if ! id "${FORGEJO_USER}" &>/dev/null; then
#   useradd -m -d "${FORGEJO_HOME}" -s /bin/bash "${FORGEJO_USER}"
# fi

# echo "${FORGEJO_USER} ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/${FORGEJO_USER}"
# chmod 0440 "/etc/sudoers.d/${FORGEJO_USER}"

# # ensure docker group membership if present
# if getent group docker >/dev/null; then
#   usermod -aG docker "${FORGEJO_USER}" || true
# fi

# # simple detection for architecture
# ARCH="$(uname -m)"
# case "${ARCH}" in
#   x86_64) RUNNER_ARCH="linux-amd64" ;;
#   aarch64|arm64) RUNNER_ARCH="linux-arm64" ;;
#   *) echo "Unsupported architecture: ${ARCH}"; exit 1 ;;
# esac

# # runner binary version (pin here or make variable)
# RUNNER_VERSION="6.2.2"
# RUNNER_BIN="/usr/local/bin/forgejo-runner"

# if [[ ! -x "${RUNNER_BIN}" ]]; then
#   TMP_BIN="$(mktemp)"
#   DOWNLOAD_URL="https://code.forgejo.org/forgejo/runner/releases/download/v${RUNNER_VERSION}/forgejo-runner-${RUNNER_VERSION}-linux-amd64"
#   echo "Downloading runner from ${DOWNLOAD_URL}"
#   if ! wget -q -O "${TMP_BIN}" "${DOWNLOAD_URL}"; then
#     echo "ERROR: failed to download runner binary" >&2
#     rm -f "${TMP_BIN}" || true
#     exit 22
#   fi
#   install -m 0755 "${TMP_BIN}" "${RUNNER_BIN}"
#   rm -f "${TMP_BIN}"
# fi

# # If there's an accidental .runner directory, remove it (it breaks the daemon)
# if [[ -d "${FORGEJO_HOME}/.runner" && ! -f "${FORGEJO_HOME}/.runner" ]]; then
#   echo "Found existing directory ${FORGEJO_HOME}/.runner — removing so runner can create registration file"
#   rm -rf "${FORGEJO_HOME}/.runner"
# fi

# # If registration marker already exists, skip
# if [[ -f "${MARKER_FILE}" ]]; then
#   echo "Marker ${MARKER_FILE} exists — runner already installed/registered. Skipping registration."
# else
#   # If the runner CLI already created a .runner file (registration file), consider it registered
#   if su - "${FORGEJO_USER}" -c "test -f '${REG_FILE}'" >/dev/null 2>&1; then
#     echo "Registration file ${REG_FILE} already present — marking as registered"
#     su - "${FORGEJO_USER}" -c "touch '${MARKER_FILE}' && chmod 600 '${MARKER_FILE}'" || true
#   else
#     echo "Registering runner (non-interactive) for ${FORGEJO_USER}"
#     set +e
#     su - "${FORGEJO_USER}" -c \
#       "${RUNNER_BIN} register --no-interactive --token '${TOKEN}' --instance '${FORGEJO_INSTANCE}' --name '${FORGEJO_RUNNER_NAME}' --labels '${LABELS}'"
#     rc=$?
#     set -e
#     if [[ $rc -ne 0 ]]; then
#       echo "Runner register command failed with exit code ${rc}" >&2
#       exit $rc
#     fi

#     # After successful register, verify the registration file exists and is a file
#     if su - "${FORGEJO_USER}" -c "test -f '${REG_FILE}'" >/dev/null 2>&1; then
#       echo "Registration file ${REG_FILE} present — creating marker file"
#       su - "${FORGEJO_USER}" -c "touch '${MARKER_FILE}' && chmod 600 '${MARKER_FILE}'" || true
#     else
#       echo "ERROR: registration did not create ${REG_FILE} as expected" >&2
#       exit 30
#     fi
#   fi
# fi

# # Now enable/start systemd instance (safe even if already enabled)
# systemctl daemon-reload || true
# systemctl enable --now "forgejo-runner@${FORGEJO_USER}" || true

# echo "Runner installed for ${FORGEJO_USER}"
