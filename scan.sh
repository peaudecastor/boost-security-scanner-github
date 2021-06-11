#!/bin/bash

set -e
set -o pipefail
set -u

#
# State
#
declare -a TMP_FILES
declare CONTAINER_ID

#
# Helpers
#
log.info ()
{ echo "[Plugin] ${*}"; }

container.stop ()
{
  if [ -n "${CONTAINER_ID:-}" ]; then
    docker stop "${CONTAINER_ID}" &>/dev/null || true
    unset CONTAINER_ID
  fi
}

env.list ()
{ awk 'BEGIN{for(v in ENVIRON) print v}'; }

env.list.boost ()
{ env.list | grep "^BOOST_"; }

tmp.create ()
{ # $1=label
  tmp_file=$(mktemp -t boost-scanner.${1}.XXXXXX)
  TMP_FILES+=(${tmp_file})
}

tmp.clean ()
{
  for file in "${TMP_FILES[@]:-}"; do
    if test -f "${file}"; then
      rm -f "${file}"
    fi
  done

  TMP_FILES=()
}

#
# Main
#
main.exit ()
{
  container.stop
  tmp.clean

  while read name; do
    unset "${name}"
  done < <(env.list.boost)
}

main.run ()
{
  #
  # Build docker container
  #
  tmp.create env
  ENV_FILE="${tmp_file}"
  unset tmp_file

  tmp.create cid
  CID_FILE="${tmp_file}"
  unset tmp_file

  rm -f "${CID_FILE}"

  declare -a CREATE_ARGS
  CREATE_ARGS=(create
    --cidfile "${CID_FILE}"
    --env-file "${ENV_FILE}"
    --entrypoint boost
    --rm
    --tty
    "${BOOST_SCANNER_IMAGE}:${BOOST_SCANNER_VERSION}"
    ${INPUT_SCANNER_COMMAND}
  )

  log.info "Initializing"
  declare scanref
  declare headref=${BOOST_HEAD_REVISION}
  declare baseref=${BOOST_BASE_REVISION:-}

  if [ -n "${baseref:-}" ]; then
    log.info "Fetching pull request base commit"
    git fetch --depth=1 origin "${baseref}"
    baseref=$(git rev-parse FETCH_HEAD)
    git fetch --filter=blob:none origin "${headref}"
    if $(git rev-parse --is-shallow-repository); then
      git fetch --negotiation-tip=${baseref} --no-tags --unshallow origin "${headref}"
    fi
  else
    if $(git rev-parse --is-shallow-repository); then
      log.info "Shallow repository detected, fetching additional commits"
      git fetch --deepen=2 origin "${headref}"
    fi
  fi

  if [ -n "${baseref}" ]; then
    scanref="${headref}..${baseref}"
  else
    scanref="${headref}"
  fi

  CREATE_ARGS+=(${BOOST_CLI_ARGUMENTS:-})
  CREATE_ARGS+=("${scanref}")

  #
  # Create docker env file
  #
  while read name; do
    echo "${name}=${!name:-}" >> "${ENV_FILE}"
  done < <(env.list.boost)

  #
  # Launch containers
  #
  log.info "Creating docker container"
  docker pull "${BOOST_SCANNER_IMAGE}:${BOOST_SCANNER_VERSION}"
  docker ${CREATE_ARGS[@]}
  CONTAINER_ID=$(cat "${CID_FILE}")
  docker cp "." "${CONTAINER_ID}:/app/mount/"

  log.info "Starting scanner for ${scanref}"
  docker start --attach "${CONTAINER_ID}"
}

main ()
{
  trap 'main.exit' EXIT

  #
  # Local vars
  #
  declare tmp_file

  #
  # Remap CI parameters to BOOST_
  #
  export BOOST_API_ENDPOINT=${BOOST_API_ENDPOINT:-${INPUT_API_ENDPOINT:-}}
  export BOOST_API_TOKEN=${BOOST_API_TOKEN:-${INPUT_API_TOKEN:-}}

  export BOOST_SCANNER_IMAGE=${INPUT_SCANNER_IMAGE}
  export BOOST_SCANNER_VERSION=${INPUT_SCANNER_VERSION}
  export BOOST_CLI_ARGUMENTS=${INPUT_ADDITIONAL_ARGS:-}

  export BOOST_GIT_BRANCH=${GITHUB_REF#refs/heads/}
  export BOOST_GIT_PROJECT=${GITHUB_REPOSITORY}
  export BOOST_GIT_REPOSITORY=/app/mount
  export BOOST_BASE_REVISION=${GITHUB_BASE_REF:-}
  export BOOST_HEAD_REVISION=${GITHUB_SHA}
  export BOOST_WORK_DIR=${GITHUB_WORKSPACE}

  if [ "${GITHUB_EVENT_NAME:-}" == "pull_request" ]; then
    export BOOST_GIT_PULL_REQUEST=$(jq -r .number ${GITHUB_EVENT_PATH})
    BOOST_BASE_REVISION=$(jq -r .pull_request.base.sha ${GITHUB_EVENT_PATH})
    BOOST_HEAD_REVISION=$(jq -r .pull_request.head.sha ${GITHUB_EVENT_PATH})
    BOOST_GIT_BRANCH=$(jq -r .pull_request.head.ref ${GITHUB_EVENT_PATH})
  fi

  main.run
}


ORB_TEST_ENV="bats-core"
if [ "${0#*$ORB_TEST_ENV}" == "$0" ]; then
    main
fi

