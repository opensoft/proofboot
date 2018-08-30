#!/bin/bash
set -e

travis_fold start "prepare.awscli" && travis_time_start;
echo -e "\033[1;33mInstalling awscli...\033[0m";
pip install --user awscli;
travis_time_finish && travis_fold end "prepare.awscli";
echo " ";

PLATFORM=$1;

mkdir __dependencies && cd __dependencies;
for DEP in "${@:2}"; do
    travis_time_start;
    echo -e "\033[1;33mDownloading $DEP...\033[0m";
    aws s3 cp s3://proof.travis.builds/$TRAVIS_BRANCH/raw-bin/$DEP-bin-$PLATFORM.tar.gz proof-bin.tar.gz \
    || aws s3 cp s3://proof.travis.builds/develop/raw-bin/$DEP-bin-$PLATFORM.tar.gz proof-bin.tar.gz;
    tar --overwrite -xzf proof-bin.tar.gz;
    cp -uR -t $HOME/proof-bin proof-bin/*;
    rm -rf proof-bin proof-bin.tar.gz;
    travis_time_finish;
done;
echo " ";

travis_fold start "list.bin";
echo -e "\033[1;32mProof-bin contents:\033[0m";
ls -Rlh $HOME/proof-bin;
travis_fold end "list.bin";
