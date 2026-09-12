#!/usr/bin/env bash

# Trims leading and trailing whitespace from a string.
program::trim() {
	# Original variable with leading and trailing whitespace
	local var="$1"

	# Trim leading whitespace
	var="${var#"${var%%[![:space:]]*}"}"

	# Trim trailing whitespace
	var="${var%"${var##*[![:space:]]}"}"

	echo "$var"
}
