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

source $HOME/proof-bin/dev-tools/travis/detect_build_type.sh;
if [ -n "$SKIP_UPLOAD" ]; then
    -e "\033[1;33mSkipping artifact upload\033[0m";
    exit 0;
fi

APP_VERSION="$($HOME/proof-bin/dev-tools/travis/grep_proof_app_version.sh .)";

echo -e "\033[1;32mApp version: $APP_VERSION\033[0m";
if [ -n "$RELEASE_BUILD" ]; then
    echo -e "\033[1;32mWill be uploaded as release to __releases/$TARGET_NAME folder\033[0m";
else
    echo -e "\033[1;32mWill be uploaded to $TRAVIS_BRANCH/$TARGET_NAME-$APP_VERSION-$TRAVIS_BRANCH.deb\033[0m";
fi
echo " ";

travis_fold start "prepare.awscli" && travis_time_start;
echo -e "\033[1;33mInstalling awscli...\033[0m";
pip install --user awscli;
travis_time_finish && travis_fold end "prepare.awscli";
echo " ";

$HOME/proof-bin/dev-tools/travis/pack_app_deb_helper.sh

DEB_FILENAME=`find -maxdepth 1 -name "$TARGET_NAME-*.deb" -exec basename "{}" \; -quit`
if [ -z  "$DEB_FILENAME" ]; then
    echo -e "\033[1;31mCan't find created deb package, halting\033[0m";
    exit 1
fi

travis_time_start;
echo -e "\033[1;33mUploading to AWS S3...\033[0m";
if [ -n "$RELEASE_BUILD" ]; then
    $HOME/proof-bin/dev-tools/travis/s3_upload.sh "$DEB_FILENAME" __releases/$TARGET_NAME "$DEB_FILENAME";
else
    $HOME/proof-bin/dev-tools/travis/s3_upload.sh "$DEB_FILENAME" $TRAVIS_BRANCH $TARGET_NAME-$APP_VERSION-$TRAVIS_BRANCH.deb;
fi
travis_time_finish
