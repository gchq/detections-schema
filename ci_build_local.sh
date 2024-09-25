#!/usr/bin/env bash

# Runs ci_build.sh on your local machine by first setting
# up some env vars to imitate what GH actions would do.

set -eo pipefail

error_exit() {
    local -r msg="$1"
    echo -e "${msg}"
    exit 1
}

check_for_installed_binary() {
    local -r binary_name=$1
    command -v "${binary_name}" 1>/dev/null \
      || error_exit "${GREEN}${binary_name}${RED} is not installed${NC}"
}

main() {
  check_for_installed_binary "xmllint"
  check_for_installed_binary "wget"
  check_for_installed_binary "java"

  SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

  # Set the env vars that ci_build.sh needs
  export BUILD_IS_SCHEMA_RELEASE=false
  export BUILD_DIR="${SCRIPT_DIR}"

  # Clear out old stuff
  rm -f "${BUILD_DIR}/pipelines/generated/*"

  echo "Using BUILD_DIR: ${BUILD_DIR}"

  pushd "${BUILD_DIR}" > /dev/null

  # Run the CI build locally
  "${BUILD_DIR}/ci_build.sh"

  popd > /dev/null
}

main "$@"
