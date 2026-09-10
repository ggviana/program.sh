#!/usr/bin/env bash
# Demonstrates: required_option — a flag the script cannot run without
# shellcheck source=bin/program.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../bin/program.sh"

name "deploy"
description "Deploy a service to an environment"
argument "<service>" "Service to deploy"
required_option "-e, --env <environment>" "Target environment"
option_type "--env" choice "staging" "production"
option "--dry-run" "Print what would happen without deploying"
parse "$@"

service="${program_arg["service"]}"
target="${program_option["env"]}"

if [ "${program_option["dry-run"]}" = "true" ]; then
	echo "[dry run] Would deploy $service to $target"
	exit 0
fi

echo "Deploying $service to $target..."
