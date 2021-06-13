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
  # Create docker env file
  #
  tmp.create env
  ENV_FILE="${tmp_file}"
  unset tmp_file

  while read name; do
    echo "${name}=${!name:-}" >> "${ENV_FILE}"
  done < <(env.list.boost)

  #
  # Build docker container
  #
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
    "${BOOST_SCANNER_IMAGE}:${BOOST_SCANNER_VERSION}"
  )

  CREATE_ARGS+=(scan ci "${BOOST_PROJECT_SLUG}")
  CREATE_ARGS+=("${BOOST_BRANCH_NAME}")

  declare scanref
  declare headref=${BOOST_HEAD_REVISION}
  declare baseref=${BOOST_BASE_REVISION:-}

  if [ -n "${baseref}" ]; then
    scanref="${baseref}..${headref}"
  else
    scanref="${headref}"
  fi

  if [ -n "${BOOST_MAIN_BRANCH:-}" ]; then
    CREATE_ARGS+=(--main-branch "${BOOST_MAIN_BRANCH}")
  fi

  if [ -n "${BOOST_PR_NUMBER:-}" ] &&
     [ "${BOOST_PR_NUMBER}" != "false" ];
  then
    CREATE_ARGS+=(--pull-request "${BOOST_PR_NUMBER}")
  fi

  CREATE_ARGS+=(${BOOST_CLI_ARGUMENTS:-})
  
  CREATE_ARGS+=("${scanref}")

  #
  # Launch containers
  #
  log.info "Initializing"

  if [ -n "${baseref:-}" ]; then
    if $(git rev-parse --is-shallow-repository); then
      log.info "Shallow repository detected, fetching since ${baseref}"
      git fetch --negotiation-tip="${baseref}" origin "${headref}:${headref}"
    fi
  else
    if $(git rev-parse --is-shallow-repository); then
      log.info "Shallow repository detected, fetching additional commits"
      git fetch --deepen=2 origin "${headref}"
    fi
  fi

  log.info "Creating docker container"
  docker pull "${BOOST_SCANNER_IMAGE}:${BOOST_SCANNER_VERSION}"
  docker "${CREATE_ARGS[@]}"
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

  declare BOOST_SCANNER_IMAGE=${INPUT_SCANNER_IMAGE}
  declare BOOST_SCANNER_VERSION=${INPUT_SCANNER_VERSION}
  declare BOOST_CLI_ARGUMENTS=${INPUT_ADDITIONAL_ARGS:-}

  declare BOOST_BRANCH_NAME=${GITHUB_REF#refs/heads/}
  declare BOOST_PROJECT_SLUG=${GITHUB_REPOSITORY}
  declare BOOST_BASE_REVISION=${GITHUB_BASE_REF:-}
  declare BOOST_HEAD_REVISION=${GITHUB_SHA}
  declare BOOST_WORK_DIR=${GITHUB_WORKSPACE}

  if [ "${GITHUB_EVENT_NAME:-}" == "pull_request" ]; then
    wget -q -O /tmp/jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
    chmod 755 /tmp/jq

    export BOOST_GIT_PULL_REQUEST=$(/tmp/jq -r .number ${GITHUB_EVENT_PATH})
    BOOST_BASE_REVISION=$(/tmp/jq -r .pull_request.base.sha ${GITHUB_EVENT_PATH})
    BOOST_HEAD_REVISION=$(/tmp/jq -r .pull_request.head.sha ${GITHUB_EVENT_PATH})
    BOOST_BRANCH_NAME=$(/tmp/jq -r .pull_request.head.ref ${GITHUB_EVENT_PATH})
  fi

  main.run
}


ORB_TEST_ENV="bats-core"
if [ "${0#*$ORB_TEST_ENV}" == "$0" ]; then
    main
fi

