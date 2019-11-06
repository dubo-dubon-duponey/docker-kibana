#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

export TITLE="Kibana"
export DESCRIPTION="A dubo image for Kibana"
export IMAGE_NAME="kibana"

# shellcheck source=vars.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]:-$PWD}")" 2>/dev/null 1>&2 && pwd)/helpers.sh"
