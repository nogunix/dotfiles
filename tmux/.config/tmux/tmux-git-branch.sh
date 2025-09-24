#!/bin/bash

# Get the current git branch, if in a git repository
branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

if [ -n "$branch" ]; then
  echo " $branch"
fi
