#!/bin/bash
set -e

source $HOME/proof-bin/travis/detect_build_type.sh;
if [ -n "$SKIP_UPLOAD" ]; then
    echo -e "\033[1;33mSkipping artifact upload\033[0m";
    exit 0;
fi

travis_fold start "prepare.awscli" && travis_time_start;
echo -e "\033[1;33mInstalling awscli...\033[0m";
pip install --user awscli;
travis_time_finish && travis_fold end "prepare.awscli";
echo " ";

travis_time_start;
echo -e "\033[1;33mUnpacking bin.tar.gz from cache...\033[0m";
mkdir $HOME/final && cd $HOME/final;
cp $HOME/full_build/bin.tar.gz bin.tar.gz;
tar -xzf bin.tar.gz;
mv bin proof-bin;
travis_time_finish;

travis_time_start;
echo -e "\033[1;33mRemoving tests and examples stuff...\033[0m";
rm -rf proof-bin/tools proof-bin/tests proof-bin/examples;
travis_time_finish;
travis_time_start;
echo -e "\033[1;33mPacking proof-bin.tar.gz...\033[0m";
tar -czf proof-bin.tar.gz proof-bin && du -h proof-bin.tar.gz;
travis_time_finish;

travis_time_start;
echo -e "\033[1;33mUploading to AWS S3...\033[0m";
aws s3 cp proof-bin.tar.gz s3://proof.travis.builds/$TRAVIS_BRANCH/raw-bin/$TARGET_NAME-bin-$1.tar.gz;
travis_time_finish
