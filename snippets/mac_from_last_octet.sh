#!/bin/bash
set -o errexit
set -o nounset

echo 00:00:80:ed:9d:$(printf '%x' $1)
