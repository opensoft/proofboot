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

DOCKER_IMAGE=opensoftdev/proof-check-codecoverage:latest;

LCOV_REMOVALS="'*/3rdparty/*' '*/tests/*' '*/proofhardware*' '*/tools/*' '*/plugins/*' '*amqp*' '*/proofcv/*' '*/proofgui/*' '*/bin/*' '*/build/*'"

mkdir $HOME/builder_logs;

travis_fold start "prepare.docker" && travis_time_start;
echo -e "\033[1;33mDownloading and starting Docker container...\033[0m";
docker pull $DOCKER_IMAGE;
docker run --privileged -id --name builder -w="/sandbox" -v $(pwd):/sandbox/proof \
    -v $HOME/builder_logs:/sandbox/logs -v $HOME/builder_ccache:/root/.ccache \
    $DOCKER_IMAGE tail -f /dev/null;
docker ps;
docker exec builder bash -c "mkdir -p /root/.config/Opensoft && echo -e \"proof.*=false\nproofstations.*=false\nproofservices.*=false\" > /root/.config/Opensoft/proof_tests.qtlogging.rules"
travis_time_finish && travis_fold end "prepare.docker";
echo " ";

travis_fold start "build.cmake" && travis_time_start;
echo -e "\033[1;33mRunning cmake...\033[0m";
echo "$ cmake -DCMAKE_BUILD_TYPE=Debug '-DCMAKE_CXX_FLAGS=-fdiagnostics-color' -DPROOF_ADD_CODE_COVERAGE:BOOL=ON -DPROOF_CI_BUILD:BOOL=ON -DCMAKE_PREFIX_PATH=/opt/Opensoft/Qt -G 'Unix Makefiles' ../proof";
docker exec -t builder bash -c "exec 3>&1; set -o pipefail; rm -rf /sandbox/logs/*; mkdir build && cd build; \
    cmake -DCMAKE_BUILD_TYPE=Debug '-DCMAKE_CXX_FLAGS=-fdiagnostics-color' -DPROOF_ADD_CODE_COVERAGE:BOOL=ON -DPROOF_CI_BUILD:BOOL=ON \
        -DCMAKE_PREFIX_PATH=/opt/Opensoft/Qt -G 'Unix Makefiles' \
        ../proof 2>&1 1>&3 | (tee /sandbox/logs/errors.log 1>&2)";
travis_time_finish && travis_fold end "build.cmake" && proofboot/travis/check_for_errorslog.sh cmake || true;
echo " ";

travis_fold start "build.compile" && travis_time_start;
echo -e "\033[1;33mCompiling...\033[0m";
echo "$ cmake --build . --target all -- -j4";
docker exec -t builder bash -c "exec 3>&1; set -o pipefail; rm -rf /sandbox/logs/*; cd build; \
    cmake --build . --target all -- -j4 2>&1 1>&3 | (tee /sandbox/logs/errors.log 1>&2)";
travis_time_finish && travis_fold end "build.compile" && proofboot/travis/check_for_errorslog.sh compilation || true;
echo " ";

travis_fold start "lcov.initial" && travis_time_start;
echo -e "\033[1;33mCollecting initial coverage data...\033[0m";
echo "$ lcov --no-external --capture --initial --directory . --output-file code_coverage.baseline | grep -v 'ignoring data for external file'";
docker exec -t builder bash -c "lcov --no-external --capture --initial --directory . --output-file code_coverage.baseline | grep -v 'ignoring data for external file'";
echo " ";
echo "$ lcov --remove code_coverage.baseline $LCOV_REMOVALS --output-file code_coverage.baseline";
docker exec -t builder bash -c "lcov --remove code_coverage.baseline $LCOV_REMOVALS --output-file code_coverage.baseline";
travis_time_finish && travis_fold end "lcov.initial";
echo " ";

travis_fold start "tests" && travis_time_start;
echo -e "\033[1;33mRunning tests...\033[0m";
echo "$ cmake --build . --target test";
docker exec -t builder bash -c "cd build; cmake --build . --target test || true";
travis_time_finish && travis_fold end "tests";
echo " ";

travis_fold start "lcov.after_tests" && travis_time_start;
echo -e "\033[1;33mCollecting coverage data after tests...\033[0m";
echo "$ lcov --no-external --capture --directory . --output-file code_coverage.after_tests | grep -v 'ignoring data for external file'";
docker exec -t builder bash -c "lcov --no-external --capture --directory . --output-file code_coverage.after_tests | grep -v 'ignoring data for external file'";
echo " ";
echo "$ lcov --remove code_coverage.after_tests $LCOV_REMOVALS --output-file code_coverage.after_tests";
docker exec -t builder bash -c "lcov --remove code_coverage.after_tests $LCOV_REMOVALS --output-file code_coverage.after_tests";
travis_time_finish && travis_fold end "lcov.after_tests";
echo " ";

travis_fold start "lcov.combine" && travis_time_start;
echo -e "\033[1;33mCombining coverage data...\033[0m";
echo "$ lcov --add-tracefile code_coverage.baseline --add-tracefile code_coverage.after_tests --output-file /sandbox/proof/code_coverage.total";
docker exec -t builder bash -c "lcov --add-tracefile code_coverage.baseline --add-tracefile code_coverage.after_tests --output-file /sandbox/proof/code_coverage.total";
echo " ";
echo "$ lcov --list /sandbox/proof/code_coverage.total";
docker exec -t builder bash -c "lcov --list /sandbox/proof/code_coverage.total";
travis_time_finish && travis_fold end "lcov.combine";
echo " ";

travis_fold start "codecov.io" && travis_time_start;
echo -e "\033[1;33mSending coverage data to codecov.io...\033[0m";
bash <(curl -s https://codecov.io/bash) -f code_coverage.total;
travis_time_finish && travis_fold end "codecov.io";
