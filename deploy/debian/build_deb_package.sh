#!/bin/bash

# Copyright 2018, OpenSoft Inc.
# All rights reserved.

# Redistribution and use in source and binary forms, with or without modification, are permitted
# provided that the following conditions are met:

#     * Redistributions of source code must retain the above copyright notice, this list of
# conditions and the following disclaimer.
#    * Redistributions in binary form must reproduce the above copyright notice, this list of
# conditions and the following disclaimer in the documentation and/or other materials provided
# with the distribution.
#     * Neither the name of OpenSoft Inc. nor the names of its contributors may be used to endorse
# or promote products derived from this software without specific prior written permission.

# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
# FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
# IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
# OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# Author: denis.kormalev@opensoftdev.com (Denis Kormalev)

set -e

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
MANIFEST="$1/Manifest"

# Import project Manifest
if [[ ! -f "$MANIFEST" ]]; then
    echo "Manifest file not found by path '$MANIFEST'"
    exit 1
fi
source "$MANIFEST"

if [ -n "$TARGET_NAME" ]; then
    PACKAGE_NAME="$TARGET_NAME"
fi

if [ -z "$PACKAGE_NAME" ]; then
    echo "PACKAGE_NAME or TARGET_NAME not set"
    exit 2
fi

PROJECT_DIR="$( cd "$1" && pwd )"
APP_ROOT="$PACKAGE_ROOT/opt/Opensoft/$PACKAGE_NAME"

if [ -z "$DESCRIPTION" ]; then
    DESCRIPTION="$PACKAGE_NAME"
fi
DESCRIPTION=`echo -n "$DESCRIPTION"`

if [ -z "$MAINTAINER" ]; then
    MAINTAINER="Denis Kormalev <denis.kormalev@opensoftdev.com>"
fi

# Building project
mkdir -p "$PACKAGE_ROOT"

if [ -z "$PROOF_PATH" ]; then
    export PROOF_PATH=/opt/Opensoft/proof;
fi
export LD_LIBRARY_PATH="/opt/Opensoft/Qt/lib:$PROOF_PATH/lib"
export PATH="/opt/Opensoft/Qt/bin:$PATH"

"$ROOT/copy_proof_libs.sh" "$APP_ROOT" "$PROJECT_DIR"
strip -v `find "$APP_ROOT" -type f \( -name "*-bin" -o -name "*.so*" \)`

if [ -z "$DEPENDS" ]; then
    # We don't need any system qt/qca stuff
    # We also don't need proof since we are copying it to app
    export IGNORE_PACKAGES_PATTERN="^libqt:^libqca:^qml-module:fglrx:^proof:^libproxy:$IGNORE_PACKAGES_PATTERN";
    export VERSION_CHECK_PATTERN="qt5-opensoft:qca-opensoft:opencv-opensoft:qrencode:$VERSION_CHECK_PATTERN";
    DEPENDS="`"$ROOT/extract_app_dependencies.sh" "$PACKAGE_ROOT" | paste -s -d,`"
fi
echo "Depends found: $DEPENDS"

BASE_DEPENDS="sudo,resolvconf,libproxy1v5,libproxy1-plugin-webkit"

if [ -z "$DEPENDS" ]; then
    DEPENDS=$BASE_DEPENDS
else
    DEPENDS="$BASE_DEPENDS,$DEPENDS"
fi

if [ -n "$EXTRA_DEPENDS" ]; then
    echo "Adding extra depends from Manifest: $EXTRA_DEPENDS"
    DEPENDS="$DEPENDS,$EXTRA_DEPENDS"
fi

SUGGESTS="openvpn,xinput-calibrator"
if [ -n "$EXTRA_SUGGESTS" ]; then
    echo "Adding extra suggests from Manifest: $EXTRA_SUGGESTS"
    SUGGESTS="$SUGGESTS,$EXTRA_SUGGESTS"
fi

RECOMMENDS=proof-restarter
if [ -n "$EXTRA_RECOMMENDS" ]; then
    echo "Adding extra recommends from Manifest: $EXTRA_RECOMMENDS"
    RECOMMENDS="$RECOMMENDS,$EXTRA_RECOMMENDS"
fi

VERSION=`$PROOF_PATH/dev-tools/travis/grep_proof_app_version.sh $PROJECT_DIR`
PROOF_VERSION=`$PROOF_PATH/dev-tools/travis/grep_proof_version.sh $PROOF_PATH`

# Building package
mkdir -p "$PACKAGE_ROOT/DEBIAN";
if [ -z "SKIP_DEB_SCRIPTS" ]; then
    cp -R "$ROOT"/DEBIAN/* "$PACKAGE_ROOT"/DEBIAN/;
    sed -E "s|##APP_RESTARTER_PATH##|/opt/Opensoft/proof-restarter/$PACKAGE_NAME|" -i "$PACKAGE_ROOT"/DEBIAN/preinst;
    sed -E "s|##APP_RESTARTER_PATH##|/opt/Opensoft/proof-restarter/$PACKAGE_NAME|" -i "$PACKAGE_ROOT"/DEBIAN/postinst;
fi

cat << EOT > "$PACKAGE_ROOT/DEBIAN/control"
Package: $PACKAGE_NAME
Version: $VERSION
Section: misc
Depends: $DEPENDS
Suggests: $SUGGESTS
Recommends: $RECOMMENDS
Architecture: amd64
Maintainer: $MAINTAINER
Description: $DESCRIPTION
 Built with and partially includes Proof ver.$PROOF_VERSION.
EOT

echo "DEBIAN/control contents:"
cat $PACKAGE_ROOT/DEBIAN/control

fakeroot dpkg-deb --build "$PACKAGE_ROOT" "$PROJECT_DIR/$PACKAGE_NAME-${VERSION}-proof${PROOF_VERSION}.deb"
