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

if [[ $# -lt 1 ]] ; then
    echo "Usage: $0 [-f MANIFEST] [PROJECT_PATH]"
    exit 0
fi

MANIFEST=""
while getopts "f:" opt; do
    case $opt in
        f)
            MANIFEST="$OPTARG"
            ;;
        \?)
            echo "Invalid option" >&2
            exit 1
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            exit 1
            ;;
    esac
done
shift $(($OPTIND - 1))

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [[ "x" == "x$MANIFEST" ]]; then
    MANIFEST="$1/Manifest"
fi

# Import project Manifest
if [[ ! -f "$MANIFEST" ]]; then
    echo "Manifest file not found by path '$MANIFEST'"
    exit 1
fi
source "$MANIFEST"

if [ -n "$TARGET_NAME" ]; then
    PACKAGE_NAME="$TARGET_NAME"
fi

# Check for required variables
if [ -z "$PACKAGE_NAME" ]; then
    echo "Wrong Manifest file (PACKAGE_NAME not set)"
    exit 2
fi

if [ -z "$PROJECT_DIR" ]; then
    PROJECT_DIR="$( cd "$( dirname "$MANIFEST" )" && pwd )"
fi

if [ -z "$PROJECT_FILE" ]; then
    PROJECT_FILE="$PROJECT_DIR/$PACKAGE_NAME.pro"
fi

if [ -z $BUILD_ROOT ]; then
    BUILD_ROOT="/tmp/build-$PACKAGE_NAME-$$"
fi
if [ -z "$PACKAGE_ROOT" ]; then
    PACKAGE_ROOT="$BUILD_ROOT/package-$PACKAGE_NAME"
fi

APP_ROOT="$PACKAGE_ROOT/opt/Opensoft/$PACKAGE_NAME"

if [ -z "$DESCRIPTION" ]; then
    DESCRIPTION="$PACKAGE_NAME"
fi

DESCRIPTION=`echo -n "$DESCRIPTION"`

if [ -z "$MAINTAINER" ]; then
    MAINTAINER="Denis Kormalev <denis.kormalev@opensoftdev.com>"
fi

# Building project
mkdir -p "$BUILD_ROOT"
mkdir -p "$PACKAGE_ROOT"
cd "$BUILD_ROOT"

# Remember PROOF_PATH if defined
if [ -n "$PROOF_PATH" ]; then
    export _PROOF_PATH="$PROOF_PATH"
else
    export PROOF_PATH=/opt/Opensoft/proof;
fi

export LD_LIBRARY_PATH=$PROOF_PATH/lib;
export QMAKEFEATURES=$PROOF_PATH/features;

# Execute prebuild steps from Manifest
if [ -n "$PREBUILD" ]; then
    eval $PREBUILD
fi

# Build with custom PROOF_PATH instead of Manifested one
if [ -n "$_PROOF_PATH" ]; then
    export PROOF_PATH="$_PROOF_PATH"
    export LD_LIBRARY_PATH=$PROOF_PATH/lib
    export QMAKEFEATURES=$PROOF_PATH/features
fi

export LD_LIBRARY_PATH="/opt/Opensoft/Qt/lib:$LD_LIBRARY_PATH"
export PATH="/opt/Opensoft/Qt/bin:$PATH"

cd "$BUILD_ROOT"

if [ -z "$SKIP_BUILD_FOR_DEB_PACKAGE" ]; then
    if [ -n "$EXTRA_QMAKE_CONFIG" ]; then
        QMAKECONFIG="$QMAKECONFIG $EXTRA_QMAKE_CONFIG"
    fi
    qmake PREFIX="$PACKAGE_ROOT" "CONFIG+=$QMAKECONFIG" "$PROJECT_FILE"
    make -j $(( $(cat /proc/cpuinfo | grep processor | wc -l) + 1 ))
    make install
else
    echo "Skipping qmake & make stages because SKIP_BUILD_FOR_DEB_PACKAGE is set"
fi

"$ROOT/copy_proof_libs.sh" "$APP_ROOT" "$PROJECT_DIR"
strip -v `find "$APP_ROOT" -type f \( -name "*-bin" -o -name "*.so*" \)`

if [ -z "$DEPENDS" ]; then
    # We don't need any system qt/qca stuff
    # We also don't need proof since we are copying it to app
    export IGNORE_PACKAGES_PATTERN="^libqt:^libqca:^qml-module:fglrx:^proof:$IGNORE_PACKAGES_PATTERN";
    export VERSION_CHECK_PATTERN="qt5-opensoft:qca-opensoft:opencv-opensoft:qrencode:$VERSION_CHECK_PATTERN";
    DEPENDS="`"$ROOT/extract_app_dependencies.sh" "$PACKAGE_ROOT" | paste -s -d,`"
fi
echo "Depends found: $DEPENDS"

if [ -z "$DEPENDS" ]; then
    DEPENDS="sudo,resolvconf"
else
    DEPENDS="sudo,resolvconf,$DEPENDS"
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

VERSION=`grep -e "VERSION\ =" $PROJECT_FILE | sed 's/^VERSION\ =\ \(.*\)/\1/'`
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

if [ -n "$POSTBUILD" ]; then
    eval $POSTBUILD
fi

fakeroot dpkg-deb --build "$PACKAGE_ROOT" "$PROJECT_DIR/$PACKAGE_NAME-${VERSION}-proof${PROOF_VERSION}.deb"

if [ -z $SKIP_BUILD_FOR_DEB_PACKAGE ]; then
    rm -rf "$BUILD_ROOT" || true
else
    echo "Skipping cleanup stage because SKIP_BUILD_FOR_DEB_PACKAGE is set"
fi
