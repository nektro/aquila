#!/bin/sh

set -eu

tagcount=$(git tag | wc -l)
tagcount=$((tagcount+1))

echo $tagcount
