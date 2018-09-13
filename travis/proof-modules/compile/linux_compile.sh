#!/bin/bash
set -e

source $HOME/proof-bin/dev-tools/travis/detect_build_type.sh;
DOCKER_IMAGE=opensoftdev/proof-builder-ccache;

mkdir $HOME/builder_logs;

travis_fold start "prepare.docker" && travis_time_start;
echo -e "\033[1;33mDownloading and starting Docker container...\033[0m";
docker pull $DOCKER_IMAGE:latest;
cp -R $HOME/proof-bin $HOME/proof-bin-copy;
docker run -id --name builder -w="/sandbox" -e "PROOF_PATH=/sandbox/bin" -e "QMAKEFEATURES=/sandbox/bin/features" \
    -v $(pwd):/sandbox/$TARGET_NAME -v $HOME/proof-bin-copy:/sandbox/bin -v $HOME/builder_logs:/sandbox/logs \
    -v $HOME/builder_ccache:/root/.ccache -v $HOME/full_build:/sandbox/full_build \
    $DOCKER_IMAGE tail -f /dev/null;
docker ps;
travis_time_finish && travis_fold end "prepare.docker";
echo " ";

travis_fold start "build.bootstrap" && travis_time_start;
echo -e "\033[1;33mBootstrapping...\033[0m";
echo "$ bin/bootstrap.py --src $TARGET_NAME --dest bin --single-module";
docker exec -t builder bash -c "exec 3>&1; set -o pipefail; rm -rf /sandbox/logs/*; \
    bin/bootstrap.py --src $TARGET_NAME --dest bin --single-module 2>&1 1>&3 | (tee /sandbox/logs/errors.log 1>&2)";
travis_time_finish && travis_fold end "build.bootstrap" && $HOME/proof-bin/dev-tools/travis/check_for_errorslog.sh bootstrap || true;
echo " ";

travis_fold start "build.qmake" && travis_time_start;
echo -e "\033[1;33mRunning qmake...\033[0m";
echo "$ qmake -r 'QMAKE_CXXFLAGS += -ferror-limit=0 -fcolor-diagnostics' ../$TARGET_NAME/$TARGET_NAME.pro";
docker exec -t builder bash -c "exec 3>&1; set -o pipefail; rm -rf /sandbox/logs/*; mkdir build && cd build; \
    qmake -r 'QMAKE_CXXFLAGS += -ferror-limit=0 -fcolor-diagnostics' ../$TARGET_NAME/$TARGET_NAME.pro 2>&1 1>&3 | (tee /sandbox/logs/errors.log 1>&2)";
travis_time_finish && travis_fold end "build.qmake" && $HOME/proof-bin/dev-tools/travis/check_for_errorslog.sh qmake || true;
echo " ";

travis_fold start "build.compile" && travis_time_start;
echo -e "\033[1;33mCompiling...\033[0m";
echo "$ make -j4";
docker exec -t builder bash -c "exec 3>&1; set -o pipefail; rm -rf /sandbox/logs/*; cd build; make -j4 2>&1 1>&3 | (tee /sandbox/logs/errors.log 1>&2)";
travis_time_finish && travis_fold end "build.compile" && $HOME/proof-bin/dev-tools/travis/check_for_errorslog.sh compilation || true;
echo " ";

if [ -f ${TARGET_NAME}_tests.pro ]; then
    travis_fold start "build.qmake_tests" && travis_time_start;
    echo -e "\033[1;33mRunning qmake for tests...\033[0m";
    echo "$ qmake -r 'QMAKE_CXXFLAGS += -ferror-limit=0 -fcolor-diagnostics' ../$TARGET_NAME/${TARGET_NAME}_tests.pro";
    docker exec -t builder bash -c "exec 3>&1; set -o pipefail; rm -rf /sandbox/logs/*; mkdir build_tests && cd build_tests; \
        qmake -r 'QMAKE_CXXFLAGS += -ferror-limit=0 -fcolor-diagnostics' ../$TARGET_NAME/${TARGET_NAME}_tests.pro 2>&1 1>&3 | (tee /sandbox/logs/errors.log 1>&2)";
    travis_time_finish && travis_fold end "build.qmake_tests" && $HOME/proof-bin/dev-tools/travis/check_for_errorslog.sh qmake || true;
    echo " ";

    travis_fold start "build.compile_tests" && travis_time_start;
    echo -e "\033[1;33mCompiling tests...\033[0m";
    echo "$ make -j4";
    docker exec -t builder bash -c "exec 3>&1; set -o pipefail; rm -rf /sandbox/logs/*; cd build_tests; make -j4 2>&1 1>&3 | (tee /sandbox/logs/errors.log 1>&2)";
    travis_time_finish && travis_fold end "build.compile_tests" && $HOME/proof-bin/dev-tools/travis/check_for_errorslog.sh compilation || true;
    echo " ";
fi

if [ -f ${TARGET_NAME}_tools.pro ]; then
    travis_fold start "build.qmake_tools" && travis_time_start;
    echo -e "\033[1;33mRunning qmake for tools...\033[0m";
    echo "$ qmake -r 'QMAKE_CXXFLAGS += -ferror-limit=0 -fcolor-diagnostics' ../$TARGET_NAME/${TARGET_NAME}_tools.pro";
    docker exec -t builder bash -c "exec 3>&1; set -o pipefail; rm -rf /sandbox/logs/*; mkdir build_tools && cd build_tools; \
        qmake -r 'QMAKE_CXXFLAGS += -ferror-limit=0 -fcolor-diagnostics' ../$TARGET_NAME/${TARGET_NAME}_tools.pro 2>&1 1>&3 | (tee /sandbox/logs/errors.log 1>&2)";
    travis_time_finish && travis_fold end "build.qmake_tools" && $HOME/proof-bin/dev-tools/travis/check_for_errorslog.sh qmake || true;
    echo " ";

    travis_fold start "build.compile_tools" && travis_time_start;
    echo -e "\033[1;33mCompiling tools...\033[0m";
    echo "$ make -j4";
    docker exec -t builder bash -c "exec 3>&1; set -o pipefail; rm -rf /sandbox/logs/*; cd build_tools; make -j4 2>&1 1>&3 | (tee /sandbox/logs/errors.log 1>&2)";
    travis_time_finish && travis_fold end "build.compile_tools" && $HOME/proof-bin/dev-tools/travis/check_for_errorslog.sh compilation || true;
    echo " ";
fi

if [ -f ${TARGET_NAME}_plugins.pro ]; then
    travis_fold start "build.qmake_plugins" && travis_time_start;
    echo -e "\033[1;33mRunning qmake for plugins...\033[0m";
    echo "$ qmake -r 'QMAKE_CXXFLAGS += -ferror-limit=0 -fcolor-diagnostics' ../$TARGET_NAME/${TARGET_NAME}_plugins.pro";
    docker exec -t builder bash -c "exec 3>&1; set -o pipefail; rm -rf /sandbox/logs/*; mkdir build_plugins && cd build_plugins; \
        qmake -r 'QMAKE_CXXFLAGS += -ferror-limit=0 -fcolor-diagnostics' ../$TARGET_NAME/${TARGET_NAME}_plugins.pro 2>&1 1>&3 | (tee /sandbox/logs/errors.log 1>&2)";
    travis_time_finish && travis_fold end "build.qmake_plugins" && $HOME/proof-bin/dev-tools/travis/check_for_errorslog.sh qmake || true;
    echo " ";

    travis_fold start "build.compile_plugins" && travis_time_start;
    echo -e "\033[1;33mCompiling plugins...\033[0m";
    echo "$ make -j4";
    docker exec -t builder bash -c "exec 3>&1; set -o pipefail; rm -rf /sandbox/logs/*; cd build_plugins; make -j4 2>&1 1>&3 | (tee /sandbox/logs/errors.log 1>&2)";
    travis_time_finish && travis_fold end "build.compile_plugins" && $HOME/proof-bin/dev-tools/travis/check_for_errorslog.sh compilation || true;
    echo " ";
fi

travis_fold start "build.bin_cache_prepare" && travis_time_start;
echo -e "\033[1;33mMoving bin to cacheable zone...\033[0m";
echo "$ rm -rf /sandbox/full_build/*";
docker exec -t builder sh -c "rm -rf /sandbox/full_build/*";
echo "$ tar -czf bin.tar.gz bin";
docker exec -t builder sh -c "tar -czf bin.tar.gz bin";
echo "$ mv bin.tar.gz /sandbox/full_build/";
docker exec -t builder sh -c "mv bin.tar.gz /sandbox/full_build/";
travis_time_finish && travis_fold end "build.bin_cache_prepare";


