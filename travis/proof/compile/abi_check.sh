#!/bin/bash
set -e

mkdir $HOME/builder_logs;

travis_fold start "prepare.docker" && travis_time_start;
echo -e "\033[1;33mDownloading and starting Docker container...\033[0m";
docker pull opensoftdev/proof-check-abi:latest;
docker run -id --name builder -w="/sandbox" -v $(pwd):/sandbox/proof -v $HOME/builder_logs:/sandbox/logs \
    -e "PROOF_PATH=/sandbox/bin" -e "QMAKEFEATURES=/sandbox/bin/features" opensoftdev/proof-check-abi tail -f /dev/null;
docker ps;
travis_time_finish && travis_fold end "prepare.docker";
echo " ";

travis_fold start "build.bootstrap" && travis_time_start;
echo -e "\033[1;33mBootstrapping...\033[0m";
echo "$ proof/proofboot/bootstrap.py --src proof --dest bin";
docker exec -t builder bash -c "exec 3>&1; set -o pipefail; rm -rf /sandbox/logs/*; \
    proof/proofboot/bootstrap.py --src proof --dest bin 2>&1 1>&3 | (tee /sandbox/logs/errors.log 1>&2)";
travis_time_finish && travis_fold end "build.bootstrap" && proofboot/travis/check_for_errorslog.sh bootstrap || true;
echo " ";

travis_fold start "build.qmake" && travis_time_start;
echo -e "\033[1;33mRunning qmake...\033[0m";
echo "$ qmake -r 'CONFIG += libs debug' 'QMAKE_CXXFLAGS += -Og -isystem /opt/Opensoft/Qt/include' -spec linux-g++ ../proof/proof.pro";
docker exec -t builder bash -c "exec 3>&1; set -o pipefail; rm -rf /sandbox/logs/*; mkdir build && cd build; \
    qmake -r 'CONFIG += libs debug' 'QMAKE_CXXFLAGS += -Og -isystem /opt/Opensoft/Qt/include' -spec linux-g++ \
    ../proof/proof.pro 2>&1 1>&3 | (tee /sandbox/logs/errors.log 1>&2)";
travis_time_finish && travis_fold end "build.qmake" && proofboot/travis/check_for_errorslog.sh qmake || true;
echo " ";

travis_fold start "build.compile" && travis_time_start;
echo -e "\033[1;33mCompiling...\033[0m";
echo "$ make -j4";
docker exec -t builder bash -c "exec 3>&1; set -o pipefail; rm -rf /sandbox/logs/*; cd build; make -j4 2>&1 1>&3 | (tee /sandbox/logs/errors.log 1>&2)";
travis_time_finish && travis_fold end "build.compile" && proofboot/travis/check_for_errorslog.sh compilation || true;

travis_fold start "prepare.abi_dump" && travis_time_start;
echo -e "\033[1;33mRunning clang-format...\033[0m";
docker exec -t codestyle-check bash -c "find -iname '*.h' -o -iname '*.cpp' | grep -v 3rdparty | grep -v gtest | xargs clang-format -i";
travis_time_finish && travis_fold end "check.format";
echo " ";

echo -e "\033[1;35m$ git diff --shortstat:\033[0m" && git diff --shortstat;
echo -e "\033[1;35m$ git diff:\033[0m" && git diff;

exit `git diff | wc -l`
