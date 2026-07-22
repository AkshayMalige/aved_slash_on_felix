#!/bin/bash

# ##################################################################################################
#  The MIT License (MIT)
#  Copyright (c) 2026 Advanced Micro Devices, Inc. All rights reserved.
#
#  Permission is hereby granted, free of charge, to any person obtaining a copy of this software
#  and associated documentation files (the "Software"), to deal in the Software without restriction,
#  including without limitation the rights to use, copy, modify, merge, publish, distribute,
#  sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
#  furnished to do so, subject to the following conditions:
#
#  The above copyright notice and this permission notice shall be included in all copies or
#  substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
# NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
# DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
# ##################################################################################################

set -euxo pipefail

# Ensure directories created during packaging have standard permissions.
# dpkg-deb requires the control directory to be >=0755 and <=0775.
umask 0022

# SLASH root
cd "$(dirname "$0")/.."

ARTIFACTS_DIR="${ARTIFACTS_DIR:-$(pwd)/ami}"
AMI_BUILD_DIR="$(pwd)/ami-build"
AVED_DIR="$(pwd)/linker/resources/submodules/AVED"
AMI_DIR="${AVED_DIR}/sw/AMI"
PKG_PY="${AMI_DIR}/scripts/package_data/pkg.py"
GEN_PKG_PY="${AMI_DIR}/scripts/gen_package.py"

rm -rf "${AMI_BUILD_DIR}"
mkdir -p "${ARTIFACTS_DIR}"

# Restore the patched files and clean up the build directory on exit.
#
# FELIX: upstream restores these with `git -C "${AVED_DIR}" checkout --`, which
# assumes AVED is a git submodule with its own index. In felix, AVED is VENDORED
# into the parent repo, so that would restore from the parent's index (and fails
# outright if the tree is not a checkout at all). Use plain file backups instead
# — no git assumption, works from a tarball export too.
cp -p "${PKG_PY}"     "${PKG_PY}.felix-bak"
cp -p "${GEN_PKG_PY}" "${GEN_PKG_PY}.felix-bak"
trap 'mv -f "${PKG_PY}.felix-bak" "${PKG_PY}"; mv -f "${GEN_PKG_PY}.felix-bak" "${GEN_PKG_PY}"; rm -rf "${AMI_BUILD_DIR}"' EXIT

# Patch in Rocky Linux support (RHEL-compatible, RPM-based)
sed -i "/^DIST_ID_RHEL /a DIST_ID_ROCKY   = 'rocky'" "${PKG_PY}"
sed -i "/^    DIST_ID_RHEL,$/a\\    DIST_ID_ROCKY," "${PKG_PY}"
sed -i "s/DIST_RPM = \[DIST_ID_CENTOS, DIST_ID_REDHAT, DIST_ID_REDHAT2, DIST_ID_SLES, DIST_ID_RHEL\]/DIST_RPM = [DIST_ID_CENTOS, DIST_ID_REDHAT, DIST_ID_REDHAT2, DIST_ID_SLES, DIST_ID_RHEL, DIST_ID_ROCKY]/" "${PKG_PY}"
sed -i "s/DIST_ID_CENTOS, DIST_ID_REDHAT, DIST_ID_REDHAT2, DIST_ID_RHEL\]/DIST_ID_CENTOS, DIST_ID_REDHAT, DIST_ID_REDHAT2, DIST_ID_RHEL, DIST_ID_ROCKY]/" "${GEN_PKG_PY}"

# FELIX: AMI's packaging imports the long-deprecated `pkg_resources`, which
# setuptools REMOVED in v81. A conda/miniforge python3 on PATH typically ships
# setuptools >= 81 and fails with ModuleNotFoundError. Pick the first
# interpreter that actually provides pkg_resources, preferring the distro one.
AMI_PYTHON=""
for _py in /usr/bin/python3 python3; do
    if command -v "${_py}" > /dev/null 2>&1 \
        && "${_py}" -c 'import pkg_resources' > /dev/null 2>&1; then
        AMI_PYTHON="${_py}"
        break
    fi
done
if [[ -z "${AMI_PYTHON}" ]]; then
    echo "ERROR: no python3 with 'pkg_resources' found (AMI packaging needs it)." >&2
    echo "Install it, e.g.:  sudo apt-get install -y python3-pkg-resources" >&2
    echo "or pin setuptools<81 in the active environment." >&2
    exit 1
fi

cd "${AMI_DIR}"
# --no_driver skips a pre-flight driver compilation check (build+clean) only;
# it does NOT affect which files are included in the package.
# We skip it here so the packaging can run in environments (eg. containers)
# that may not have linux-headers available to compile the driver.
"${AMI_PYTHON}" scripts/gen_package.py --no_driver -o "${AMI_BUILD_DIR}"

# Copy only the package files to the artifacts directory
cp "${AMI_BUILD_DIR}"/*.rpm "${ARTIFACTS_DIR}/" 2>/dev/null || \
cp "${AMI_BUILD_DIR}"/*.deb "${ARTIFACTS_DIR}/" 2>/dev/null || true
