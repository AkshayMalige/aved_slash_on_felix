#!/usr/bin/env bash
# uninstall_sw.sh -- scripted DEPLOY_RUNBOOK.md "Part 0": remove every installed
# ami/slash/vrt component so a clean build can be installed from scratch.
#
#   sudo bash scripts/uninstall_sw.sh            # purge, then verify
#   sudo bash scripts/uninstall_sw.sh --check    # verify only, change nothing
#
# Removes, in this order:
#   1. running daemon + loaded kernel modules
#   2. the .deb packages (apt, then dpkg for the ones apt can't name)
#   3. ad-hoc systemd units / udev rules that OVERRIDE the packaged ones
#   4. DKMS build trees for every kernel
#   5. /usr/local leftovers from any past `cmake --install`
#
# Deliberately NOT removed: the vrt / vrtd / vrtadmin groups (the packages reuse
# them) and /etc/vrt/vrtd.conf (your config).
#
# Exit status: 0 = clean, 1 = something still present (details printed).
set -uo pipefail          # NOT -e: most steps are "remove if present" and may fail

CHECK_ONLY=0
[ "${1:-}" = "--check" ] && CHECK_ONLY=1

# --check only reads, so it does not need root; purging does.
if [ "$CHECK_ONLY" -eq 0 ] && [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: run with sudo: sudo bash scripts/uninstall_sw.sh" >&2
    echo "       (or 'bash scripts/uninstall_sw.sh --check' to verify without root)" >&2
    exit 1
fi

hr() { printf '=== %s\n' "$1"; }

if [ "$CHECK_ONLY" -eq 0 ]; then

hr "0.1 stop daemon, unload modules"
systemctl stop vrtd.socket vrtd.service 2>/dev/null
rmmod ami   2>/dev/null && echo "  unloaded ami"   || true
rmmod slash 2>/dev/null && echo "  unloaded slash" || true

hr "0.2 purge packages"
# 'v80++' must NOT go on an apt command line: a trailing '+' is an apt action
# modifier, so apt reads it as package 'v80', fails, and ABORTS the whole remove
# without touching anything. dpkg handles it.
apt-get remove --purge -y \
    ami slash-dkms libslash libslash-dev libvrt libvrt-dev libvrtd libvrtd-dev vrtd
dpkg --purge v80++ 2>/dev/null
dpkg --purge v80-smi amd-vrt slash-dev slash slash-sim-emu slash-sim-emu-dev 2>/dev/null
apt-get autoremove --purge -y

# If ami's prerm wedges on `rmmod ami` (module waiting on an absent card), dpkg
# aborts with exit 137. Neutralise that step and force the purge through.
if dpkg -l ami 2>/dev/null | grep -q '^i[^i]'; then
    echo "  ami purge incomplete -- neutralising its rmmod prerm and retrying"
    rm -f /var/lib/dpkg/info/ami.prerm
    dpkg --purge --force-all ami 2>/dev/null
fi

hr "0.2b remove ad-hoc systemd units / udev rules"
# /etc/systemd/system OVERRIDES /lib/systemd/system, where the .deb installs its
# units. A hand-installed unit in /etc keeps winning after reinstall, usually with
# an ExecStart pointing at a stale /usr/local binary. Use stop, never disable --
# `disable` is a persistent admin decision deb-systemd-helper honours at install
# time, leaving you a correct install with a dead daemon.
rm -f /etc/systemd/system/vrtd.service /etc/systemd/system/vrtd.socket
rm -f /etc/udev/rules.d/99-vrtd.rules      # the .deb ships 60-vrtd.rules in /lib
rm -f /usr/lib/vrt/vrtd                    # symlink into /usr/local, if present
systemctl daemon-reload
udevadm control --reload-rules

hr "0.3 remove DKMS trees for ALL kernels"
for m in ami/2.4.0 slash/0.1; do dkms remove "$m" --all 2>/dev/null; done
rm -rf /usr/src/slash-0.1 /usr/src/ami-2.4.0
depmod -a

hr "0.4 remove /usr/local leftovers from any past cmake --install"
# dpkg does not own these, so they survive every purge above AND shadow the
# packaged copies (/usr/local/lib precedes /usr/lib for ld.so; /usr/local/bin
# precedes /usr/bin in PATH). Skip this and your rebuild appears to do nothing.
rm -f  /usr/local/lib/lib{slash,vrt,vrtd,vrtdpp}.so*
rm -rf /usr/local/lib/cmake/{slash,vrt,vrtd}
rm -rf /usr/local/include/{slash,vrt,vrtd}
rm -f  /usr/local/bin/{vrtd,vrtd-*,v80-smi,v80++}
ldconfig

echo
fi   # end purge

hr "VERIFY -- all of these must be empty"
rc=0
check() {  # check <label> <command>
    local out; out=$(eval "$2" 2>/dev/null)
    if [ -n "$out" ]; then
        echo "  STILL PRESENT: $1"; echo "$out" | sed 's/^/      /'; rc=1
    else
        echo "  clean: $1"
    fi
}
# Match on the PACKAGE NAME column only (field 2) -- matching the whole line makes
# 'v80++' pass by accident via its "SLASH Linker" description, and would miss it if
# that description ever changed. node-slash is an unrelated Node.js package.
check "dpkg packages" \
      "dpkg -l | awk '/^ii/ && \$2 ~ /^(ami|slash|slash-dkms|slash-dev|slash-sim-emu(-dev)?|libslash(-dev)?|libvrt(-dev)?|libvrtd(-dev)?|vrtd|v80-smi|v80\+\+|amd-vrt)$/ {print \$2, \$3}'"
check "dkms trees"    "dkms status | grep -iE 'ami|slash'"
check "loaded modules" "lsmod | grep -iE '^ami|^slash|qdma'"
check "installed .ko" \
      "find /lib/modules/\$(uname -r) \( -name 'ami.ko*' -o -name 'slash.ko*' \) -print"
check "/usr/local leftovers" \
      "ls /usr/local/lib/libslash* /usr/local/lib/libvrt* /usr/local/lib/libvrtd* /usr/local/bin/vrtd /usr/local/bin/v80-smi 2>/dev/null"
check "ad-hoc systemd units" \
      "ls /etc/systemd/system/vrtd.service /etc/systemd/system/vrtd.socket 2>/dev/null"
check "installed headers" "ls -d /usr/include/slash /usr/include/vrt /usr/include/vrtd 2>/dev/null"

echo
if [ "$rc" -eq 0 ]; then
    echo "UNINSTALL_CLEAN -- ready for a fresh build+install."
else
    cat <<'EOF'
UNINSTALL_INCOMPLETE -- resolve the items above before rebuilding.
  * a wedged `ami` module that will not rmmod needs a REBOOT to clear
    (it will not reload -- the DKMS package is gone), then re-run with --check.
  * anything else: purge it directly, e.g. sudo dpkg --purge <name>
EOF
fi
exit "$rc"
