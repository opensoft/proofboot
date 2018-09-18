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

QML_IMPORTS=$(grep -hR --include="*.qml" "import Proof\." "$2" | awk '{print $2}' | sort | uniq)
IMPORTS_STABILIZED=0
while [ $IMPORTS_STABILIZED -eq 0 ]; do
    OLD_QML_IMPORTS="$QML_IMPORTS"
    FOUND_IMPORTS=$( for import in $QML_IMPORTS; do
        possible_import_path=$PROOF_PATH/qml/`echo $import | tr -s '.' '/'`
        if [ -f $possible_import_path/qmldir ]; then
            grep -hR --include="*.qml" "import Proof\." "$possible_import_path" | awk '{print $2}'
        fi
    done )
    QML_IMPORTS=`(echo "$QML_IMPORTS"; echo "$FOUND_IMPORTS") | sort | uniq`
    if [[ $QML_IMPORTS = $OLD_QML_IMPORTS ]]; then
        IMPORTS_STABILIZED=1
    fi
done

echo "Copying Proof QML imports to $1/imports:"
for import in $QML_IMPORTS; do
    possible_import_dir=`echo $import | tr -s '.' '/'`
    possible_import_path=$PROOF_PATH/imports/$possible_import_dir
    if [ -f $possible_import_path/qmldir ]; then
        echo "$possible_import_path"
        mkdir -p "$1/imports/$possible_import_dir";
        cp -R "$possible_import_path"/* "$1/imports/$possible_import_dir/";
    fi
done
echo "Proof QML imports copied"

PROOF_LIBS=$( for l in $(find "$1" -type f \( -executable -o -name "*.so" \) -exec ldd "{}" \; | awk '{print $1}' | sort | uniq); do
    find $PROOF_PATH -name "$(basename $l)"
done | sort | uniq )

echo -e "Copying Proof libs to $1/lib:\n$PROOF_LIBS"
if [ -n "$PROOF_LIBS" ]; then
    mkdir -p "$1/lib";
    cp -t "$1/lib" $PROOF_LIBS;
fi
echo "Proof libs copied"
