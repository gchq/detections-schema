#!/usr/bin/env bash

set -eo pipefail

# Set variables in github's special env file which are then automatically 
# read into env vars in each subsequent step

is_schema_release=false

echo -e "${GREEN}GITHUB_REF: ${BLUE}${GITHUB_REF}${NC}"

if [[ ${GITHUB_REF} =~ ^refs/tags/ ]]; then
  # This is build is for a git tag
  # strip off the 'refs/tags/' bit
  tag_name="${GITHUB_REF#refs/tags/}"
  if [[ "${tag_name}" =~ ^v ]]; then
    # e.g. 'v4.0.2'
    is_schema_release=true
    echo "tag_name=${tag_name}"
  fi
elif [[ ${GITHUB_REF} =~ ^refs/heads/ ]]; then
  # This build is just a commit on a branch
  # strip off the 'ref/heads/' bit
  build_branch="${GITHUB_REF#refs/heads/}"
fi

# Brace block means all echo stdout get appended to GITHUB_ENV
{
  # Map the GITHUB env vars to our own
  echo "BUILD_DIR=${GITHUB_WORKSPACE}"
  echo "BUILD_COMMIT=${GITHUB_SHA}"

  build_number="${GITHUB_RUN_NUMBER}"
  echo "BUILD_NUMBER=${build_number}"

  echo "ACTIONS_SCRIPTS_DIR=${GITHUB_WORKSPACE}/.github/workflows/scripts"

  if [[ ${GITHUB_REF} =~ ^refs/heads/ ]]; then
    echo "BUILD_BRANCH=${build_branch}"
  fi

  # Only do a release based on our schedule, e.g. nightly
  # Skip release if we have same commit as last time
  if [[ "${is_schema_release}" = "true" ]]; then
    echo "BUILD_IS_SCHEMA_RELEASE=true"
    echo "BUILD_TAG=${GITHUB_REF#refs/tags/}"
  else
    echo "BUILD_IS_SCHEMA_RELEASE=false"
  fi

  if [[ ${GITHUB_REF} =~ ^refs/pulls/ ]]; then
    echo "BUILD_IS_PULL_REQUEST=true"
  else
    echo "BUILD_IS_PULL_REQUEST=false"
  fi

} >> "${GITHUB_ENV}"
