#!/usr/bin/env bash
# Run `jevgate check` and pass its exit code on: 0 passed, 1 failed, 2 incomplete.
set -uo pipefail

command=(jevgate check --format "$FORMAT")
if [ -n "$BASE" ]; then
    if ! git cat-file -e "$BASE^{commit}" 2> /dev/null; then
        echo "::error::The base revision $BASE is not in the checkout. Check out with fetch-depth: 0 so --base can find the fork point."
        exit 2
    fi
    command+=(--base "$BASE")
fi
# Extra arguments are split on spaces, as written in the workflow.
read -r -a extra <<< "$ARGS"
command+=(${extra[@]+"${extra[@]}"})

"${command[@]}"
code=$?

echo "exit-code=$code" >> "$GITHUB_OUTPUT"
echo "report=$PWD/.jevgate/latest.json" >> "$GITHUB_OUTPUT"
if [ "$code" = 2 ] && [ -z "${TYPESAFE_API_KEY:-}" ]; then
    echo "::error::No TypeSafe API key. Pass api-key: \${{ secrets.TYPESAFE_API_KEY }}. Pull requests from forks don't receive secrets; skip the job for them."
fi
exit "$code"
