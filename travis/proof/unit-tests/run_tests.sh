#!/bin/bash
set -e

travis_fold start "prepare.docker" && travis_time_start;
echo -e "\033[1;33mDownloading Docker container...\033[0m";
docker pull opensoftdev/proof-runner:latest;
docker ps;
travis_time_finish && travis_fold end "prepare.docker";
echo " ";

travis_fold start "prepare.dirs" && travis_time_start;
echo -e "\033[1;33mUnpacking bin.tar.gz...\033[0m";
cp $HOME/full_build/bin.tar.gz bin.tar.gz;
tar -xzf bin.tar.gz;
mv bin $HOME/proof-bin;
travis_time_finish && travis_fold end "prepare.dirs";
echo " ";

travis_time_start;
echo -e "\033[1;33mRunning tests...\033[0m";
proofboot/travis/proof/unit-tests/proof_tests_runner.py "$@";
travis_time_finish
