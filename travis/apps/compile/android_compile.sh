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
if [ -n "$RELEASE_BUILD" ]; then
    DOCKER_IMAGE=opensoftdev/proof-builder-android-base;
else
    DOCKER_IMAGE=opensoftdev/proof-builder-android-ccache;
fi

mkdir $HOME/builder_logs;

travis_fold start "prepare.docker" && travis_time_start;
echo -e "\033[1;33mDownloading and starting Docker container...\033[0m";
sudo rm -rf $HOME/full_build && mkdir $HOME/full_build;
docker pull $DOCKER_IMAGE:latest;
docker run -id --name builder -w="/sandbox" -e "PROOF_PATH=/sandbox/proof-bin" -e "QMAKEFEATURES=/sandbox/proof-bin/features" \
    -v /usr/local/android-sdk:/opt/android/sdk \
    -v $(pwd):/sandbox/target_src -v $HOME/proof-bin:/sandbox/proof-bin -v $HOME/builder_logs:/sandbox/logs \
    -v $HOME/builder_ccache:/root/.ccache -v $HOME/full_build:/sandbox/full_build \
    -v $HOME/builder_gradle:/root/.gradle -v $HOME/builder_android:/root/.android $DOCKER_IMAGE tail -f /dev/null;
docker ps;
travis_time_finish && travis_fold end "prepare.docker";
echo " ";

travis_fold start "prepare.android_ndk" && travis_time_start;
echo -e "\033[1;33mPreparing Android NDK...\033[0m";
echo "$ mv /ndk-bundle.tar.xz /opt/android/sdk/ndk-bundle.tar.xz";
docker exec -t builder sh -c "mv /ndk-bundle.tar.xz /opt/android/sdk/ndk-bundle.tar.xz";
echo "$ cd /opt/android/sdk && tar -xJf ndk-bundle.tar.xz";
docker exec -t builder sh -c "cd /opt/android/sdk && tar -xJf ndk-bundle.tar.xz";
echo "$ rm /opt/android/sdk/ndk-bundle.tar.xz";
docker exec -t builder sh -c "rm /opt/android/sdk/ndk-bundle.tar.xz";
travis_time_finish && travis_fold end "prepare.android_ndk";
echo " ";

travis_fold start "build.qmake" && travis_time_start;
echo -e "\033[1;33mRunning qmake...\033[0m";
echo "$ /qmake_wrapper.sh ../target_src/$TARGET_NAME.pro";
docker exec -t builder bash -c "exec 3>&1; set -o pipefail; rm -rf /sandbox/logs/*; mkdir build && cd build; \
    /qmake_wrapper.sh ../target_src/$TARGET_NAME.pro 2>&1 1>&3 | (tee /sandbox/logs/errors.log 1>&2)";
travis_time_finish && travis_fold end "build.qmake" && $HOME/proof-bin/dev-tools/travis/check_for_errorslog.sh qmake || true;
echo " ";

travis_fold start "build.compile" && travis_time_start;
echo -e "\033[1;33mCompiling...\033[0m";
echo "$ make -j4";
docker exec -t builder bash -c "exec 3>&1; set -o pipefail; rm -rf /sandbox/logs/*; cd build; make -j4 2>&1 1>&3 | (tee /sandbox/logs/errors.log 1>&2)";
travis_time_finish && travis_fold end "build.compile" && $HOME/proof-bin/dev-tools/travis/check_for_errorslog.sh compilation || true;
echo " ";

travis_fold start "build.install" && travis_time_start;
echo -e "\033[1;33mMake install...\033[0m";
echo "$ make INSTALL_ROOT=/sandbox/build/android-build install";
docker exec -t builder bash -c "exec 3>&1; set -o pipefail; rm -rf /sandbox/logs/*; cd build; \
    make INSTALL_ROOT=/sandbox/build/android-build install 2>&1 1>&3 | (tee /sandbox/logs/errors.log 1>&2)";
travis_time_finish && travis_fold end "build.install" && $HOME/proof-bin/dev-tools/travis/check_for_errorslog.sh "make install" || true;
echo " ";

travis_fold start "build.apk" && travis_time_start;
echo -e "\033[1;33mCreating APK...\033[0m";
echo "$ androiddeployqt --input /sandbox/build/android-lib$TARGET_NAME.so-deployment-settings.json --output /sandbox/build/android-build --android-platform android-27 --jdk /usr/lib/jvm/java-8-openjdk-amd64 --gradle";
docker exec -t builder bash -c "exec 3>&1; set -o pipefail; rm -rf /sandbox/logs/*; cd build; \
    androiddeployqt --input /sandbox/build/android-lib$TARGET_NAME.so-deployment-settings.json \
    --output /sandbox/build/android-build --android-platform android-27 \
    --jdk /usr/lib/jvm/java-8-openjdk-amd64 --gradle 2>&1 1>&3 | (tee /sandbox/logs/errors.log 1>&2)";
echo "$ mkdir -p /sandbox/full_build/debug && cp /sandbox/build/android-build/build/outputs/apk/android-build-debug.apk /sandbox/full_build/debug/$TARGET_NAME.apk";
docker exec -t builder sh -c "mkdir -p /sandbox/full_build/debug \
    && cp /sandbox/build/android-build/build/outputs/apk/android-build-debug.apk /sandbox/full_build/debug/$TARGET_NAME.apk";
travis_time_finish && travis_fold end "build.apk" && $HOME/proof-bin/dev-tools/travis/check_for_errorslog.sh "apk packaging" || true;
echo " ";
