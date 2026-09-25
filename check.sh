#!/usr/bin/env bash
# Run `jevgate check` and pass its exit code on: 0 passed, 1 failed, 2 incomplete.
set -uo pipefail

command=(jevgate check)
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

"${command[@]}" --format "$FORMAT"
code=$?

# The same check again from the answers just cached: no request is sent.
if [ -n "${SARIF_FILE:-}" ]; then
    "${command[@]}" --cache-only --format sarif > "$SARIF_FILE"
    replay=$?
    if [ "$replay" -gt 1 ]; then
        echo "::warning::Could not write $SARIF_FILE (exit $replay); --format sarif needs JevGate 0.18.0 or later."
    fi
fi

echo "exit-code=$code" >> "$GITHUB_OUTPUT"
echo "report=$PWD/.jevgate/latest.json" >> "$GITHUB_OUTPUT"
if [ "$code" = 2 ] && [ -z "${TYPESAFE_API_KEY:-}" ]; then
    echo "::error::No TypeSafe API key. Pass api-key: \${{ secrets.TYPESAFE_API_KEY }}. Pull requests from forks don't receive secrets; skip the job for them."
fi
exit "$code"
