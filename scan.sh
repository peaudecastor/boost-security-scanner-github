#!/bin/bash

set -e
set -o pipefail
set -u

export BOOST_TMP_DIR=${BOOST_TMP_DIR:-${WORKSPACE_TMP:-${TMPDIR:-/tmp}}}
export BOOST_BIN=${BOOST_BIN:-${BOOST_TMP_DIR}/boost.sh}
export BOOST_CLI=${BOOST_CLI:-${BOOST_TMP_DIR}/boost/cli/latest}
export BOOST_EXE=${BOOST_EXE:-${BOOST_CLI}/boost.dist/boost}


log.info ()
{ # $@=message
  printf "$(date +'%H:%M:%S') [\033[34m%s\033[0m] %s\n" "INFO" "${*}";
}

log.error ()
{ # $@=message
  printf "$(date +'%H:%M:%S') [\033[31m%s\033[0m] %s\n" "ERROR" "${*}";
}

init.config ()
{
  log.info "initializing configuration"

  declare api_endpoint="https://api.boostsecurity.io"

  export BOOST_API_ENDPOINT=${BOOST_API_ENDPOINT:-${INPUT_API_ENDPOINT:-api_endpoint}}
  export BOOST_API_TOKEN=${BOOST_API_TOKEN:-${INPUT_API_TOKEN:-}}

  export BOOST_SCANNER_IMAGE=${INPUT_SCANNER_IMAGE}
  export BOOST_SCANNER_VERSION=${INPUT_SCANNER_VERSION}

  export BOOST_EXEC_COMMAND=${INPUT_EXEC_COMMAND:-}

  export BOOST_CLI_ARGUMENTS=${INPUT_ADDITIONAL_ARGS:-}
  export BOOST_CLI_VERSION=${INPUT_CLI_VERSION}

  export BOOST_CLI_URL=${BOOST_CLI_URL:-${BOOST_API_ENDPOINT/api/assets}}
         BOOST_CLI_URL=${BOOST_CLI_URL%*/}

  export DOCKER_COPY_REQUIRED=false
}

init.cli ()
{
  if [ -f "${BOOST_BIN:-}" ]; then
    return
  fi

  log.info "installing cli to ${BOOST_BIN}"
  mkdir -p "${BOOST_TMP_DIR}"
  declare BOOST_DOWNLOAD_URL=${BOOST_CLI_URL}/boost/get-boost-cli
  curl --silent "${BOOST_DOWNLOAD_URL}" | bash
}

main.complete ()
{
  init.config
  init.cli

  ${BOOST_EXE} scan complete
}

main.exec ()
{
  init.config
  init.cli

  if [ -z "${BOOST_EXEC_COMMAND:-}" ]; then
    log.error "the 'exec_command' option must be defined when in exec mode"
    exit 1
  fi

  exec ${BOOST_EXE} scan exec ${BOOST_CLI_ARGUMENTS:-} --command "${BOOST_EXEC_COMMAND}"
}

main.scan ()
{
  init.config
  init.cli

  if [ -n "${BOOST_EXEC_COMMAND:-}" ]; then
    log.error "the 'exec_command' option must only be defined in exec mode"
    exit 1
  fi

  exec ${BOOST_EXE} scan run ${BOOST_CLI_ARGUMENTS:-}
}

case "${INPUT_ACTION:-scan}" in
  exec)     main.exec ;;
  scan)     main.scan ;;
  complete) main.complete;;
  *)        log.error "invalid action ${INPUT_ACTION}"
            exit 1
            ;;
esac
