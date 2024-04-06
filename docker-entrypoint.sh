#!/bin/bash

set -Eeo pipefail

if [ "$DOCKER_ENTRYPOINT_DEBUG" = '1' ] || [ "$DOCKER_ENTRYPOINT_DEBUG" = "true" ]; then
  set -x
fi

export USER_ID=$(id -u)
export GROUP_ID=$(id -g)

# Switch to another user if the ROOT_SWITCH_USER variable is set
if [ "$USER_ID" = '0' ] && [ ! -z "$ROOT_SWITCH_USER" ]; then
  exec gosu "$ROOT_SWITCH_USER" "$BASH_SOURCE" "$@"
fi

# Test and store if this is the initial startup process for the container
test $$ = '1'
export DOCKER_IS_INIT=$?

# Root always exists, so we skip the libnss wrapper when root
if ! [ "$USER_ID" = '0' ]; then

  # Add wrapper passwd file if the user does not exist
  if ! getent passwd "$USER_ID" 2>&1 >/dev/null; then
    export NSS_WRAPPER_PASSWD=$(mktemp --tmpdir passwd.XXXXXX)
    cat /etc/passwd > "${NSS_WRAPPER_PASSWD}"
    echo "${DYNAMIC_USER_NAME}:x:${USER_ID}:${GROUP_ID}:${DYNAMIC_USER_NAME}:${DYNAMIC_USER_HOME}:${DYNAMIC_USER_SHELL}" >> "${NSS_WRAPPER_PASSWD}"

    # Re-export home to make sure it is set for the current session
    export HOME="${DYNAMIC_USER_HOME}"
  fi

  # Add wrapper group file if the group does not exist
  if ! getent group "$GROUP_ID" 2>&1 >/dev/null; then
    export NSS_WRAPPER_GROUP=$(mktemp --tmpdir group.XXXXXX)
    cat /etc/group > "${NSS_WRAPPER_GROUP}"
    echo "${DYNAMIC_GROUP_NAME}:x:${GROUP_ID}:" >> "${NSS_WRAPPER_GROUP}"
  fi

  # Preload the libnss_wrapper library when running the command
  dpkgArch="$(dpkg --print-architecture)"
  case "${dpkgArch##*-}" in
    amd64) export LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libnss_wrapper.so ;;
    arm64) export LD_PRELOAD=/usr/lib/aarch64-linux-gnu/libnss_wrapper.so ;;
        *) echo >&2 "unsupported architecture: ${dpkgArch}"; exit 1 ;;
  esac
fi

eval $(docker-secrets-to-env)

# Load additional scripts from /usr/local/bin/docker-entrypoint.d
if [ -d /usr/local/bin/docker-entrypoint.d ]; then
  find "/usr/local/bin/docker-entrypoint.d/" -executable -follow -type f -print | sort -n | while read -r f; do
    "$f"
  done
fi

if [ -d /usr/local/bin/docker-entrypoint-scripts.d ]; then
  find "/usr/local/bin/docker-entrypoint-scripts.d/" -name '*.sh' -follow -type f -print | sort -n | while read -r f; do
    source "$f"
  done
fi

# Run the command
exec "$@"
