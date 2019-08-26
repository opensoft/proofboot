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

travis_fold start "prepare.docker" && travis_time_start;
echo -e "\033[1;33mDownloading and starting Docker container...\033[0m";
docker pull opensoftdev/proof-builder-base:latest;
docker run --privileged -id --name builder -w="/sandbox" -v $(pwd):/sandbox/target_src -v $HOME/full_build:/sandbox/build \
    -v $HOME/proof-bin:/opt/Opensoft/proof -v $HOME/extra_s3_deps:/sandbox/extra_s3_deps \
    -e "PACKAGE_ROOT=/sandbox/package-$TARGET_NAME" -e "TARGET_NAME=$TARGET_NAME" -e "PROOF_PATH=/opt/Opensoft/proof" \
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

if [ -n "$(ls -A $HOME/extra_s3_deps/*.deb 2>/dev/null)" ]; then
    travis_fold start "prepare.extra_s3_deps" && travis_time_start;
    echo -e "\033[1;33mInstalling extra dependencies downloaded from S3...\033[0m";
    docker exec -t builder bash -c "(dpkg -i /sandbox/extra_s3_deps/*.deb 2> /dev/null || apt-get -qq -f install -y --no-install-recommends)";
    travis_time_finish && travis_fold end "prepare.extra_s3_deps";
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
echo "$ /opt/Opensoft/proof/dev-tools/deploy/debian/build_deb_package.sh /sandbox/target_src";
docker exec -t builder bash -c "/opt/Opensoft/proof/dev-tools/deploy/debian/build_deb_package.sh /sandbox/target_src";
travis_time_finish && travis_fold end "pack.deb";
echo " ";
