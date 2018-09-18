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

if [ -z "$VERSION_CHECK_PATTERN" ]; then
    VERSION_CHECK_PATTERN=ALL
fi

LIBS=`find "$1" -type f \( -executable -o -name "*.so*" \) -exec ldd "{}" \; | awk '{print $1}' | sort | uniq`
QT_LIBS=`find "/opt/Opensoft/Qt" -type f \( -executable -o -name "*.so*" \) -exec ldd "{}" \; | awk '{print $1}' | sort | uniq`
OPENCV_LIBS=`find "/usr/local/lib" -type f \( -name "libopencv*.so*" \) -exec ldd "{}" \; | awk '{print $1}' | sort | uniq`
LOCAL_LIBS=`find "$1" -type f,l \( -executable -o -name "*.so*" \) -exec basename "{}" \; | sort | uniq`
OPENCV_NEEDED=`echo "$LIBS" | grep libopencv | wc -l`
LIBS=`( echo "$LIBS"; echo "$QT_LIBS"; echo "$QT_LIBS"; echo "$OPENCV_LIBS"; echo "$OPENCV_LIBS"; echo "$LOCAL_LIBS"; echo "$LOCAL_LIBS" ) | sort | uniq -u`

FOUND_PACKAGES=$( (echo "qt5-opensoft"; echo "qca-opensoft"; test $OPENCV_NEEDED -ne 0 && echo "opencv-opensoft"; for l in $LIBS; do
    IGNORE=0
    package=`find $(echo $LD_LIBRARY_PATH | sed "s/:/ /g") /lib /usr/lib /usr/local/lib -name "$(basename $l)" -exec dpkg -S '{}' \; -quit | awk -F: '{print $1}'`
    if [ -z "$package" ]; then
        continue
    fi

    for p in $(echo $IGNORE_PACKAGES_PATTERN | tr -s ':' ' '); do
        echo $package | grep -q $p &> /dev/null
        if [ $? -eq 0 ]; then
            IGNORE=1
            break
        fi
    done

    test $IGNORE -ne 0 && continue

    dpkg -s "$package" &> /dev/null
    if [ $? -eq 0 ]; then
        echo $package
    fi
done) | sort | uniq )

for package in $FOUND_PACKAGES; do
    echo -n $package
    if [ "x$VERSION_CHECK_PATTERN" == "xALL" ]; then
        echo -n \ \(\>=`dpkg -s "$package" | grep -m 1 -e "Version:" | awk '{print $2}'`\)
    else
        for p in $(echo $VERSION_CHECK_PATTERN | tr -s ':' ' '); do
             echo $package | grep -q $p &> /dev/null
             if [ $? -eq 0 ]; then
                echo -n \ \(\>=`dpkg -s "$package" | grep -m 1 -e "Version:" | awk '{print $2}'`\)
                break
             fi
        done
    fi
    echo
done
