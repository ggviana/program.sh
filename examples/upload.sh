#!/usr/bin/env bash
# Demonstrates: multiple positional tokens in a single argument declaration
# shellcheck source=bin/program.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../bin/program.sh"

name "upload"
description "Upload a file to a bucket"
argument "<file> <bucket>" "File to upload and destination bucket"
parse "$@"

file="${program_arg["file"]}"
bucket="${program_arg["bucket"]}"

echo "Uploading $file to $bucket..."
