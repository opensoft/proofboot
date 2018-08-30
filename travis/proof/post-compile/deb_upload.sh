#!/bin/bash
set -e

source proofboot/travis/detect_build_type.sh;
if [ -n "$SKIP_UPLOAD" ]; then
    echo -e "\033[1;33mSkipping artifact upload\033[0m";
    exit 0;
fi

PROOF_VERSION=`proofboot/travis/grep_proof_version.sh proofboot`

travis_fold start "prepare.awscli" && travis_time_start;
echo -e "\033[1;33mInstalling awscli...\033[0m";
pip install --user awscli;
travis_time_finish && travis_fold end "prepare.awscli";
echo " ";

travis_fold start "prepare.docker" && travis_time_start;
echo -e "\033[1;33mDownloading and starting Docker container...\033[0m";
docker pull opensoftdev/proof-builder-base:latest;
docker run -id --name builder -w="/sandbox" -v $(pwd):/sandbox/proof -v $HOME/full_build:/sandbox/full_build \
    -e "BUILD_ROOT=/sandbox/build" -e "PACKAGE_ROOT=/sandbox/package-proof" -e "SKIP_BUILD_FOR_DEB_PACKAGE=true" \
    opensoftdev/proof-builder-base tail -f /dev/null;
docker ps;
travis_time_finish && travis_fold end "prepare.docker";
echo " ";

travis_fold start "prepare.apt_cache" && travis_time_start;
echo -e "\033[1;33mUpdating apt cache...\033[0m";
docker exec -t builder apt-get update;
travis_time_finish && travis_fold end "prepare.apt_cache";
echo " ";

travis_fold start "prepare.dirs" && travis_time_start;
echo -e "\033[1;33mPreparing dirs structure...\033[0m";
echo "$ cp full_build/build.tar.gz full_build/bin.tar.gz ./";
docker exec -t builder bash -c "cp full_build/build.tar.gz full_build/bin.tar.gz ./";
echo "$ tar -xzf build.tar.gz && tar -xzf bin.tar.gz";
docker exec -t builder bash -c "tar -xzf build.tar.gz && tar -xzf bin.tar.gz";
echo "$ mkdir -p package-proof/opt/Opensoft && mv bin package-proof/opt/Opensoft/proof";
docker exec -t builder bash -c "mkdir -p package-proof/opt/Opensoft && mv bin package-proof/opt/Opensoft/proof";
travis_time_finish && travis_fold end "prepare.dirs";
echo " ";

travis_fold start "pack.deb" && travis_time_start;
echo -e "\033[1;33mCreating deb package...\033[0m";
echo "$ proof/deploy/deb/build-deb-package -f /sandbox/proof/deploy/deb/Manifest /sandbox/proof";
docker exec -t builder bash -c "proof/deploy/deb/build-deb-package -f /sandbox/proof/deploy/deb/Manifest /sandbox/proof";
travis_time_finish && travis_fold end "pack.deb";
echo " ";

travis_time_start;
echo -e "\033[1;33mUploading to AWS S3...\033[0m";
if [ -n "$RELEASE_BUILD" ]; then
    proofboot/travis/s3_upload.sh proof-$PROOF_VERSION.deb __releases/proof proof-$PROOF_VERSION.deb;
else
    proofboot/travis/s3_upload.sh proof-$PROOF_VERSION.deb $TRAVIS_BRANCH proof-$PROOF_VERSION-$TRAVIS_BRANCH.deb;
fi
travis_time_finish
