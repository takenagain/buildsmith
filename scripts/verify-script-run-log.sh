#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -lt 3 ]; then
    echo "Usage: $0 <scripts-root> <collected-csv> <runner-log> [exclusion ...]" >&2
    exit 2
fi

scripts_root="${1%/}"
collected_scripts_file="$2"
runner_log="$3"
shift 3
exclusions=("$@")
expected_count=0

fail() {
    printf 'script-run verification failure: %s\n' "$1" >&2
    exit 1
}

while IFS=, read -r script_name os_type script_path; do
    if [ "$script_name" = 'Script Name' ] && [ "$os_type" = 'OS Type' ]; then
        continue
    fi

    script_path="${script_path%$'\r'}"
    script_path="${script_path#\"}"
    script_path="${script_path%\"}"
    case "$script_path" in
        "$scripts_root"/*) relative_path="${script_path#"$scripts_root"/}" ;;
        *) fail "collected path is outside scripts root: $script_path" ;;
    esac

    relative_path_lower="${relative_path,,}"
    excluded=0
    for exclusion in "${exclusions[@]}"; do
        if [[ "$relative_path_lower" == *"${exclusion,,}"* ]]; then
            excluded=1
            break
        fi
    done
    if [ "$excluded" -eq 1 ]; then
        continue
    fi

    expected_count=$((expected_count + 1))
    if ! grep -Fq -- "Script completed successfully: $script_path" "$runner_log"; then
        fail "missing successful completion for $relative_path"
    fi
done < "$collected_scripts_file"

if [ "$expected_count" -eq 0 ]; then
    fail 'no non-excluded scripts were collected'
fi

printf 'Verified successful completion for %d non-excluded scripts.\n' "$expected_count"
