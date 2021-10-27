#!/usr/bin/env bash

# Fail on just about anything
set -euo pipefail

# Set this to your project name
PROJECT_NAME=zube_submission

# Get the dir of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Harden the design in the OpenLANE Docker
docker run -it --rm \
	-v ${OPENLANE_ROOT}:/openlane \
	-v ${SCRIPT_DIR}:/openlane/designs/${PROJECT_NAME} \
	-v ${PDK_ROOT}:${PDK_ROOT} \
	-e PDK_ROOT=${PDK_ROOT} \
	-u $(id -u ${USER}):$(id -g ${USER}) \
	efabless/openlane:mpw-3a \
	./flow.tcl -design ${PROJECT_NAME}

