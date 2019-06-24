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

source $HOME/proof-bin/dev-tools/travis/clang-tidy_${1}_checks.sh;
DOCKER_IMAGE=opensoftdev/proof-check-clang-tidy;

mkdir $HOME/builder_logs;

travis_fold start "prepare.docker" && travis_time_start;
echo -e "\033[1;33mDownloading and starting Docker container...\033[0m";
docker pull $DOCKER_IMAGE:latest;
cp -R $HOME/proof-bin $HOME/proof-bin-copy;
docker run --privileged -id --name builder -w="/sandbox" -v $(pwd):/sandbox/$TARGET_NAME -v $HOME/proof-bin-copy:/sandbox/bin -v $HOME/builder_logs:/sandbox/logs \
    $DOCKER_IMAGE tail -f /dev/null;
docker ps;
travis_time_finish && travis_fold end "prepare.docker";
echo " ";

travis_fold start "build.cmake" && travis_time_start;
echo -e "\033[1;33mRunning cmake...\033[0m";
echo "$ cmake -DCMAKE_BUILD_TYPE=Debug '-DCMAKE_CXX_FLAGS=-ferror-limit=0 -fcolor-diagnostics -stdlib=libc++ -isystem /usr/lib/llvm-7/include/c++/v1 -isystem /usr/lib/jvm/java-8-openjdk-amd64/include -isystem /usr/lib/jvm/java-8-openjdk-amd64/include/linux -isystem /sandbox/non_tidy -DSTATIC_CODE_CHECK_BUILD' -DPROOF_STATIC_CODE_CHECK_BUILD:BOOL=ON -DPROOF_CLANG_TIDY=ON -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DPROOF_CI_BUILD:BOOL=ON -DCMAKE_INSTALL_PREFIX=/sandbox/bin -DCMAKE_PREFIX_PATH=/opt/Opensoft/Qt -G 'Unix Makefiles' ../$TARGET_NAME";
docker exec -t builder bash -c "exec 3>&1; set -o pipefail; rm -rf /sandbox/logs/*; mkdir build && cd build; \
    cmake -DCMAKE_BUILD_TYPE=Debug \
        '-DCMAKE_CXX_FLAGS=-ferror-limit=0 -fcolor-diagnostics -stdlib=libc++ -isystem /usr/lib/llvm-7/include/c++/v1 -isystem /usr/lib/jvm/java-8-openjdk-amd64/include -isystem /usr/lib/jvm/java-8-openjdk-amd64/include/linux -isystem /sandbox/non_tidy -DSTATIC_CODE_CHECK_BUILD' \
        -DPROOF_STATIC_CODE_CHECK_BUILD:BOOL=ON -DPROOF_CLANG_TIDY=ON -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DPROOF_CI_BUILD:BOOL=ON \
        -DCMAKE_INSTALL_PREFIX=/sandbox/bin -DCMAKE_PREFIX_PATH=/opt/Opensoft/Qt -G 'Unix Makefiles' \
        ../$TARGET_NAME 2>&1 1>&3 | (tee /sandbox/logs/errors.log 1>&2)";
travis_time_finish && travis_fold end "build.cmake" && $HOME/proof-bin/dev-tools/travis/check_for_errorslog.sh cmake || true;
echo " ";

if [ -z "$TIDY_KEEP_3RDPARTY" ]; then
    echo -e "\033[1;33mMoving 3rdparty to non_tidy folder...\033[0m";
    docker exec -t builder bash -c "mkdir -p /sandbox/non_tidy && mv /sandbox/$TARGET_NAME/3rdparty /sandbox/non_tidy/" || true;
    echo " ";
fi

travis_fold start "build.clang-tidy" && travis_time_start;
echo -e "\033[1;33mRunning clang-tidy...\033[0m";
echo "$ run-clang-tidy-opensoft.py -header-filter='.*(h|cpp)$' -checks='-*,$CLANG_TIDY_CHECKS' -j4 -quiet";
docker exec -t builder bash -c "rm -rf /sandbox/logs/*; cd build; \
    run-clang-tidy-opensoft.py -header-filter='.*(h|cpp)$' -checks='-*,$CLANG_TIDY_CHECKS' -j4 -quiet > /sandbox/logs/errors.log" || true;
travis_time_finish && travis_fold end "build.clang-tidy" && $HOME/proof-bin/dev-tools/travis/check_for_errorslog.sh clang-tidy;
echo " ";
