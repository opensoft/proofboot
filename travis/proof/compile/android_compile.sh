#!/bin/bash
set -e

source proofboot/travis/detect_build_type.sh;
if [ -n "$RELEASE_BUILD" ]; then
    DOCKER_IMAGE=opensoftdev/proof-builder-android-base;
else
    DOCKER_IMAGE=opensoftdev/proof-builder-android-ccache;
fi

mkdir $HOME/builder_logs;

travis_fold start "prepare.docker" && travis_time_start;
echo -e "\033[1;33mDownloading and starting Docker container...\033[0m";
docker pull $DOCKER_IMAGE:latest;
docker run -id --name builder -w="/sandbox" -e "PROOF_PATH=/sandbox/bin" -e "QMAKEFEATURES=/sandbox/bin/features" \
    -v /usr/local/android-sdk:/opt/android/sdk \
    -v $(pwd):/sandbox/proof -v $HOME/builder_logs:/sandbox/logs -v $HOME/builder_ccache:/root/.ccache -v $HOME/full_build:/sandbox/full_build \
    $DOCKER_IMAGE tail -f /dev/null;
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

travis_fold start "build.bootstrap" && travis_time_start;
echo -e "\033[1;33mBootstrapping...\033[0m";
echo "$ proof/proofboot/bootstrap.py --src proof --dest bin";
docker exec -t builder bash -c "exec 3>&1; set -o pipefail; rm -rf /sandbox/logs/*; \
    proof/proofboot/bootstrap.py --src proof --dest bin 2>&1 1>&3 | (tee /sandbox/logs/errors.log 1>&2)";
travis_time_finish && travis_fold end "build.bootstrap" && proofboot/travis/check_for_errorslog.sh bootstrap || true;
echo " ";

travis_fold start "build.qmake" && travis_time_start;
echo -e "\033[1;33mRunning qmake...\033[0m";
echo "$ /qmake_wrapper.sh ../proof/proof.pro";
docker exec -t builder bash -c "exec 3>&1; set -o pipefail; rm -rf /sandbox/logs/*; mkdir build && cd build; \
    /qmake_wrapper.sh ../proof/proof.pro 2>&1 1>&3 | (tee /sandbox/logs/errors.log 1>&2)";
travis_time_finish && travis_fold end "build.qmake" && proofboot/travis/check_for_errorslog.sh qmake || true;
echo " ";

travis_fold start "build.compile" && travis_time_start;
echo -e "\033[1;33mCompiling...\033[0m";
echo "$ make -j4";
docker exec -t builder bash -c "exec 3>&1; set -o pipefail; rm -rf /sandbox/logs/*; cd build; make -j4 2>&1 1>&3 | (tee /sandbox/logs/errors.log 1>&2)";
travis_time_finish && travis_fold end "build.compile" && proofboot/travis/check_for_errorslog.sh compilation || true;
echo " ";

travis_fold start "build.bin_cache_prepare" && travis_time_start;
echo -e "\033[1;33mMoving bin to cacheable zone...\033[0m";
echo "$ rm -rf /sandbox/full_build/*";
docker exec -t builder sh -c "rm -rf /sandbox/full_build/*";
echo "$ tar -czf bin.tar.gz bin";
docker exec -t builder sh -c "tar -czf bin.tar.gz bin";
echo "$ mv bin.tar.gz /sandbox/full_build/";
docker exec -t builder sh -c "mv bin.tar.gz /sandbox/full_build/";
travis_time_finish && travis_fold end "build.bin_cache_prepare";
