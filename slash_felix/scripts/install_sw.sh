#!/usr/bin/env bash
# install_sw.sh -- install the locally built .debs from deb/ and VERIFY they landed.
#
# Why this exists rather than a copy-pasted apt line:
#   1. Every package is version 0.1.0 and the version string never changes, so a
#      plain `apt-get install ./foo.deb` reports "already the newest version" and
#      SILENTLY SKIPS it.  --reinstall is mandatory here.
#   2. The full package list is long enough that pasting it into a terminal wraps,
#      and bash then runs the wrapped remainder as a separate command -- which is
#      how slash-dkms got missed once already.
#   3. A partial install leaves the kernel module and libslash built from
#      different revisions of slash_interface.h, which used to fail as
#      "Inappropriate ioctl for device" and crash-loop vrtd.
#
# Run:  sudo bash scripts/install_sw.sh
# Then: reboot / `sudo ipmitool chassis power cycle` (the module cannot hot-swap).
set -Eeuo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

[ "$(id -u)" -eq 0 ] || { echo "ERROR: run with sudo: sudo bash scripts/install_sw.sh" >&2; exit 1; }
[ -d deb ] || { echo "ERROR: deb/ not found -- run ./build_all.sh sw first" >&2; exit 1; }

PKGS=(
    libslash libslash-dev
    libvrtd libvrtd-dev
    libvrt  libvrt-dev
    vrtd v80-smi v80++
    slash-dkms
)

files=()
for p in "${PKGS[@]}"; do
    # shellcheck disable=SC2206
    hits=( deb/${p}_*.deb )
    [ -e "${hits[0]}" ] || { echo "ERROR: no .deb found for $p in deb/" >&2; exit 1; }
    files+=( "./${hits[0]}" )
done
# ami has an distro-suffixed name
ami=( deb/ami_*_22.04.deb )
[ -e "${ami[0]}" ] || { echo "ERROR: no ami .deb found in deb/" >&2; exit 1; }
files+=( "./${ami[0]}" )

echo "== installing ${#files[@]} packages (forced reinstall) =="
apt-get install -y --reinstall --allow-downgrades "${files[@]}"

echo
echo "== verifying the install actually landed =="
rc=0
check() {  # check <description> <file> <needle>
    if grep -q -- "$3" "$2" 2>/dev/null; then
        echo "  OK   : $1"
    else
        echo "  FAIL : $1  (missing '$3' in $2)"
        rc=1
    fi
}

# libslash-dev owns the uapi header that libslash/vrtd compile against.
check "libslash-dev header has aperture_size" \
      /usr/include/slash/uapi/slash_interface.h aperture_size
check "libslash-dev header has the frozen v1 ioctl struct" \
      /usr/include/slash/uapi/slash_interface.h slash_qdma_qpair_add_v1
# slash-dkms owns the driver source DKMS rebuilds the module from.
check "dkms driver source has aperture_size" \
      /usr/src/slash-0.1/driver/libslash/include/slash/uapi/slash_interface.h aperture_size
check "dkms driver source has the frozen v1 ioctl struct" \
      /usr/src/slash-0.1/driver/libslash/include/slash/uapi/slash_interface.h slash_qdma_qpair_add_v1

echo
echo "== dkms status =="
dkms status | grep -iE 'slash|ami' || true
if ! dkms status | grep -q "slash/0.1, $(uname -r).*installed"; then
    echo "  FAIL : slash.ko not built+installed for $(uname -r)"
    rc=1
else
    echo "  OK   : slash.ko built for $(uname -r)"
    ko=/lib/modules/$(uname -r)/updates/dkms/slash.ko
    [ -f "$ko" ] && echo "         $(ls -la --time-style=long-iso "$ko" | awk '{print $6, $7, $NF}')"
fi

echo
if [ "$rc" -ne 0 ]; then
    echo "########## INSTALL INCOMPLETE -- do NOT power cycle. Fix the FAILs above. ##########"
    exit 1
fi
cat <<'EOF'
##############################################################################
# INSTALL VERIFIED. Now power cycle (the module cannot hot-swap -- stale QDMA
# queues hold a refcount):
#
#     sudo sync && sudo ipmitool chassis power cycle
#
# After it comes back, check vrtd is healthy BEFORE running an example:
#     systemctl status vrtd.socket --no-pager
#     journalctl -u vrtd -n 15 --no-pager      # no "Inappropriate ioctl", no restart loop
##############################################################################
EOF
