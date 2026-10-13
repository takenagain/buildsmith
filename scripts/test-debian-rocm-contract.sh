#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
installer_invocation="$test_root/amdgpu-install.args"
downloaded_package_url="$test_root/downloaded-package-url"
expected_package_url='https://repo.radeon.com/amdgpu-install/31.60/ubuntu/noble/amdgpu-install_31.60.316000-1_all.deb'

trap 'rm -rf -- "$test_root"' EXIT

fail() {
    printf 'ROCm contract failure: %s\n' "$1" >&2
    exit 1
}

mkdir -p "$test_root/bin"

cat > "$test_root/bin/id" <<'EOF'
#!/usr/bin/env bash

if [ "${1:-}" = '-u' ]; then
    printf '0\n'
    exit 0
fi

exec /usr/bin/id "$@"
EOF

cat > "$test_root/bin/apt-get" <<'EOF'
#!/usr/bin/env bash

exit 0
EOF

cat > "$test_root/bin/curl" <<'EOF'
#!/usr/bin/env bash

output=''
url=''
while [ "$#" -gt 0 ]; do
    case "$1" in
        --output)
            output="$2"
            shift 2
            ;;
        https://*)
            url="$1"
            shift
            ;;
        *) shift ;;
    esac
done

[ -n "$output" ] && [ -n "$url" ] || exit 2
: > "${ROCM_TEST_URL:?}"
printf '%s\n' "$url" > "$ROCM_TEST_URL"
: > "$output"
EOF

cat > "$test_root/bin/amdgpu-install" <<'EOF'
#!/usr/bin/env bash

printf '%s\n' "$@" > "${ROCM_TEST_INVOCATION:?}"
EOF

chmod +x "$test_root/bin/"*

env \
    PATH="$test_root/bin:/usr/bin:/bin" \
    ROCM_TEST_URL="$downloaded_package_url" \
    ROCM_TEST_INVOCATION="$installer_invocation" \
    bash "$repository_root/scripts/debian/rocm.sh"

[ -f "$installer_invocation" ] || fail 'amdgpu-install was not invoked'
[ "$(cat "$downloaded_package_url")" = "$expected_package_url" ] || \
    fail "expected AMDGPU installer 31.60 package URL: $expected_package_url"

while IFS= read -r argument; do
    [ "$argument" != '-y' ] || {
            printf 'ROCm 31.60 package and noninteractive installer contracts passed.\n'
        exit 0
    }
done < "$installer_invocation"

fail 'amdgpu-install invocation omitted -y'
