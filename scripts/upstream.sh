#!/usr/bin/env bash
# Sync local work onto the latest trunk and publish.
#
# Fetches new revisions from the git remote, rebases everything off the
# current working copy onto trunk(), formats, runs the flake checks,
# moves `main` to the resulting tip, and pushes.
set -euo pipefail

jj git fetch
jj rebase -o "trunk()"
nix fmt
nix flake check
jj bookmark set main
jj git push
