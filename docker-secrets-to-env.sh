#!/usr/bin/env bash

# Setup error handling
set -Eeo pipefail
shopt -s nullglob

list_all=false
secrets_path="${DOCKER_SECRETS_PATH:-/run/secrets}"
IFS=',' read -r -a listed_secrets <<<${DOCKER_ENV_SECRETS:-}

# Read all data before any '--', they should be the requested secrets
while [[ $# -gt 0 ]]; do
  key="$1"
  shift

  case $key in
    --all)
      list_all=true
      ;;
    --)
      break
      ;;
    *)
      listed_secrets+=("$key")
      ;;
  esac
done

# If there are any remaining arguments after the '--' assume it is a runnable command
if [[ "$#" -gt 0 ]]; then
  exec_command=true
else
  exec_command=false
fi

# If the listed secrets is empty we load all secrets
if [ "${list_all}" = true ]; then
  listed_secrets=()
  for file in "${secrets_path}"/*; do
    filename="${file#"$secrets_path/"}"
    listed_secrets+=("$filename")
  done
fi

# Loop over the requested secret names
for item in "${listed_secrets[@]}"; do
  # If a secret has an additional question mark we don't warn about it missing
  warn_missing=true
  if [ "${item: -1}" = '?' ]; then
    warn_missing=false
    item="${item%?}"
  fi

  # Check if there is a file with the requested name
  if [ -f "${secrets_path}/$item" ]; then
    # Generate the command
    cmd="export ${item}=\"\$(cat '${secrets_path}/$item')\""

    # Either eval or echo the command
    if [ "$exec_command" = true ]; then
      eval "$cmd"
    else
      echo "$cmd"
    fi
  else
    if [ "$warn_missing" = true ]; then
      echo "Warning: Secret for $item is not defined in file '$secrets_path/$item'" 1>&2
    fi
  fi
done

# If there is a command to exec, run it
if [ "$exec_command" = true ]; then
  exec "$@"
fi
