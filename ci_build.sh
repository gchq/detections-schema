#!/usr/bin/env bash

set -eo pipefail

setup_echo_colours() {
  # Exit the script on any error
  set -e

  # shellcheck disable=SC2034
  if [ "${MONOCHROME}" = true ]; then
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    BLUE2=''
    DGREY=''
    NC='' # No Colour
  else 
    RED='\033[1;31m'
    GREEN='\033[1;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[1;34m'
    BLUE2='\033[1;34m'
    DGREY='\e[90m'
    NC='\033[0m' # No Colour
  fi
}

error_exit() {
    local -r msg="$1"
    echo -e "${msg}"
    exit 1
}

prepare_for_schema_release() {
  echo -e "${GREEN}Preparing for a schema release${NC}"
  prepare_release_artefacts
}

validate_source_schema() {
  # validate the source schema - probably overkill as java will validate 
  # the generated schemas

  echo -e "::group::Validating source schema"
  xmllint \
    --noout \
    --schema http://www.w3.org/2001/XMLSchema.xsd \
    "${BUILD_DIR}/${SOURCE_SCHEMA_FILE_NAME}"
  echo "::endgroup::"

  echo -e "::group::Validating versions in schema file"
  "${BUILD_DIR}/validateSchemaVersions.py" "${SCHEMA_VERSION}"
  echo "::endgroup::"
}

build_schema_variants() {
  echo -e "::group::Running schema transformations"
  # Download the jar

  pushd "${LIB_DIR}"
  # If running locally, we don't want to keep downloading the same thing
  if [[ ! -f "${TRANSFORMER_JAR_FILENAME}" ]]; then
    echo -e "${GREEN}Downloading ${BLUE}${TRANSFORMER_JAR_URL}${NC}"
    wget --quiet "${TRANSFORMER_JAR_URL}"
  fi
  popd

  local PIPELINES_DIR="${BUILD_DIR}/pipelines"
  local GENERATED_DIR="${PIPELINES_DIR}/generated"

  # Run the transformations
  java \
    -jar "${LIB_DIR}/${TRANSFORMER_JAR_FILENAME}" \
    "${PIPELINES_DIR}/" \
    "${BUILD_DIR}/${SOURCE_SCHEMA_FILE_NAME}"

    
  echo -e "${GREEN}Dumping contents of ${BLUE}${GENERATED_DIR}${NC}"
  ls -l "${GENERATED_DIR}"

  if [[ "${BUILD_IS_SCHEMA_RELEASE}" = "true" ]]; then
    echo -e "${GREEN}Copying build artefacts for release${NC}"

    # Copy the schemas to the release dir for upload to gh releases
    cp "${GENERATED_DIR}"/detection-v*-safe.xsd "${RELEASE_ARTEFACTS_DIR}/"
    cp "${GENERATED_DIR}"/detection-v*.xsd "${RELEASE_ARTEFACTS_DIR}/"
  fi
  echo "::endgroup::"
}

dump_build_info() {
  echo "::group::Build info"

  #Dump all the env vars to the console for debugging
  echo -e "PWD:                          [${GREEN}$(pwd)${NC}]"
  echo -e "BUILD_DIR:                    [${GREEN}${BUILD_DIR}${NC}]"
  echo -e "BUILD_NUMBER:                 [${GREEN}${BUILD_NUMBER}${NC}]"
  echo -e "BUILD_COMMIT:                 [${GREEN}${BUILD_COMMIT}${NC}]"
  echo -e "BUILD_BRANCH:                 [${GREEN}${BUILD_BRANCH}${NC}]"
  echo -e "BUILD_TAG:                    [${GREEN}${BUILD_TAG}${NC}]"
  echo -e "BUILD_IS_PULL_REQUEST:        [${GREEN}${BUILD_IS_PULL_REQUEST}${NC}]"
  echo -e "BUILD_IS_SCHEMA_RELEASE:      [${GREEN}${BUILD_IS_SCHEMA_RELEASE}${NC}]"
  echo -e "RELEASE_ARTEFACTS_DIR:        [${GREEN}${RELEASE_ARTEFACTS_DIR}${NC}]"
  echo -e "SCHEMA_VERSION:               [${GREEN}${SCHEMA_VERSION}${NC}]"
  echo -e "SOURCE_SCHEMA_FILE_NAME:      [${GREEN}${SOURCE_SCHEMA_FILE_NAME}${NC}]"
  echo -e "TRANSFORMER_JAR_FILENAME      [${GREEN}${TRANSFORMER_JAR_FILENAME}${NC}]"

  echo -e "\nJava version:"
  java --version

  echo "::endgroup::"
}

create_dir() {
  local dir="${1:?dir not set}"; shift
  echo -e "${GREEN}Creating directory ${BLUE}${dir}${NC}"
  mkdir -p "${dir}"
}

main() {
  setup_echo_colours

  if [[ -z "$BUILD_DIR" ]]; then
    error_exit "${RED}ERROR${NC} BUILD_DIR is not set"
  fi

  if [ -n "$BUILD_TAG" ]; then
      #Tagged commit so use that as our stroom version, e.g. v3.0.0
      SCHEMA_VERSION="${BUILD_TAG}"
  else
      SCHEMA_VERSION="SNAPSHOT"
  fi

  local RELEASE_ARTEFACTS_DIR_NAME="release_artefacts"
  local RELEASE_ARTEFACTS_DIR="${BUILD_DIR}/${RELEASE_ARTEFACTS_DIR_NAME}"
  local LIB_DIR="${BUILD_DIR}/lib"
  local SOURCE_SCHEMA_FILE_NAME="detection.xsd"
  local TRANSFORMER_JAR_VERSION="v4.1.0"
  local TRANSFORMER_JAR_URL_BASE="https://github.com/gchq/event-logging-schema/releases/download"
  local TRANSFORMER_JAR_FILENAME="event-logging-transformer-${TRANSFORMER_JAR_VERSION}-all.jar"
  local TRANSFORMER_JAR_URL="${TRANSFORMER_JAR_URL_BASE}/${TRANSFORMER_JAR_VERSION}/${TRANSFORMER_JAR_FILENAME}"

  dump_build_info

  echo "::group::Create dirs"
  create_dir "${RELEASE_ARTEFACTS_DIR}"
  create_dir "${LIB_DIR}"
  echo "::endgroup::"

  validate_source_schema

  build_schema_variants

  if [[ "${BUILD_IS_SCHEMA_RELEASE}" = "true" ]]; then
    echo -e "${GREEN}This is a release build${NC}"
    echo -e "${GREEN}Dumping contents of ${BLUE}${RELEASE_ARTEFACTS_DIR}${NC}"
    ls -l "${RELEASE_ARTEFACTS_DIR}"
  else
    echo -e "${GREEN}Not a release so skipping release preparation${NC}"
    # Clear out any artefacts to make sure nothing can get uploaded to github
    # Only do the delete if we are in a github action (i.e. GITHUB_REF is set)
    # to reduce the risk of doing 'rm -rf /*' on your local machine, which
    # would be BAD.
    if [[ -n "${RELEASE_ARTEFACTS_DIR}" && -n "${GITHUB_REF}" ]]; then
      rm -rf "${RELEASE_ARTEFACTS_DIR:?}/*"
    fi
  fi
}

main "$@"
