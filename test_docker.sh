#!/usr/bin/env bash

set -e

docker build -t local_test --build-arg=BUILD_NUM=00 .

docker run -p "80:8000" local_test
