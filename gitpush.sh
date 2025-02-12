#!/bin/bash

# Check if a commit message is provided
if [ -z "$1" ]; then
  echo "Error: No commit message provided."
  echo "Usage: ./gitpush.sh \"Your commit message\""
  exit 1
fi

# Run git commands
git add .
git commit -m "$1"
git push origin main