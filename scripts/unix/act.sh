#!/bin/sh

installer_url='https://raw.githubusercontent.com/nektos/act/master/install.sh'
max_attempts=3
attempt=1
status=1

installer_file="$(mktemp "${TMPDIR:-/tmp}/act-installer.XXXXXX")" || {
    printf '%s\n' 'Unable to create a temporary file for the act installer.' >&2
    exit 1
}

cleanup() {
    rm -f "$installer_file"
}

trap cleanup 0
trap 'exit 1' HUP INT TERM

while [ "$attempt" -le "$max_attempts" ]; do
    status=0

    curl --proto '=https' --tlsv1.2 -sSf \
        --output "$installer_file" \
        "$installer_url" || status=$?

    if [ "$status" -eq 0 ]; then
        sudo bash -s -- -b /usr/local/bin < "$installer_file" || status=$?
    fi

    if [ "$status" -eq 0 ]; then
        exit 0
    fi

    if [ "$attempt" -lt "$max_attempts" ]; then
        printf 'act installation attempt %s of %s failed with status %s; retrying.\n' \
            "$attempt" "$max_attempts" "$status" >&2
        sleep "$attempt"
    fi

    attempt=$((attempt + 1))
done

printf 'act installation failed after %s attempts (last status: %s).\n' \
    "$max_attempts" "$status" >&2
exit "$status"
