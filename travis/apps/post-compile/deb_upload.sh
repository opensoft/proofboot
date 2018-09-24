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

APP_VERSION="$(grep -e 'VERSION\ =' $TARGET_NAME.pro | sed 's/^VERSION\ =\ \(.*\)/\1/')";

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

travis_fold start "prepare.docker" && travis_time_start;
echo -e "\033[1;33mDownloading and starting Docker container...\033[0m";
docker pull opensoftdev/proof-builder-base:latest;
docker run -id --name builder -w="/sandbox" -v $(pwd):/sandbox/target_src -v $HOME/full_build:/sandbox/build -v $HOME/proof-bin:/opt/Opensoft/proof \
    -e "BUILD_ROOT=/sandbox/build" -e "PACKAGE_ROOT=/sandbox/package-$TARGET_NAME" -e "SKIP_BUILD_FOR_DEB_PACKAGE=true" -e "TARGET_NAME=$TARGET_NAME" \
    -e "PROOF_PATH=/opt/Opensoft/proof" -e "QMAKEFEATURES=/opt/Opensoft/proof/features" \
    opensoftdev/proof-builder-base tail -f /dev/null;
docker ps;
travis_time_finish && travis_fold end "prepare.docker";
echo " ";

travis_fold start "prepare.apt_cache" && travis_time_start;
echo -e "\033[1;33mUpdating apt cache...\033[0m";
docker exec -t builder apt-get update;
travis_time_finish && travis_fold end "prepare.apt_cache";
echo " ";

if [ -n "$EXTRA_DEPS" ]; then
    travis_fold start "prepare.extra_deps" && travis_time_start;
    echo -e "\033[1;33mInstalling extra dependencies...\033[0m";
    docker exec -t builder bash -c "apt-get -qq install $EXTRA_DEPS -y --no-install-recommends";
    travis_time_finish && travis_fold end "prepare.extra_deps";
    echo " ";
fi

travis_fold start "prepare.dirs" && travis_time_start;
echo -e "\033[1;33mPreparing dirs structure...\033[0m";
echo "$ cp build/package-$TARGET_NAME.tar.gz ./ && tar -xzf package-$TARGET_NAME.tar.gz";
docker exec -t builder bash -c "cp build/package-$TARGET_NAME.tar.gz ./ && tar -xzf package-$TARGET_NAME.tar.gz";
travis_time_finish && travis_fold end "prepare.dirs";
echo " ";

travis_fold start "pack.deb" && travis_time_start;
echo -e "\033[1;33mCreating deb package...\033[0m";
echo "$ /opt/Opensoft/proof/dev-tools/deploy/debian/build_deb_package.sh -f /sandbox/target_src/Manifest /sandbox/target_src";
docker exec -t builder bash -c "/opt/Opensoft/proof/dev-tools/deploy/debian/build_deb_package.sh -f /sandbox/target_src/Manifest /sandbox/target_src";
travis_time_finish && travis_fold end "pack.deb";
echo " ";

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
