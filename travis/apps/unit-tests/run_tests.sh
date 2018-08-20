#!/bin/bash
set -e

travis_fold start "prepare.docker" && travis_time_start;
echo -e "\033[1;33mDownloading Docker container...\033[0m";
docker pull opensoftdev/proof-runner:latest;
docker run -id --name runner -w="/sandbox" -e "PROOF_PATH=/opt/Opensoft/proof" \
    -v $HOME/proof-bin:/opt/Opensoft/proof -v $HOME/tests_build:/sandbox/build opensoftdev/proof-runner tail -f /dev/null;
docker ps;
travis_time_finish && travis_fold end "prepare.docker";
echo " ";

travis_fold start "prepare.dirs" && travis_time_start;
echo -e "\033[1;33mPreparing...\033[0m";
docker exec runner bash -c "mkdir -p /root/.config/Opensoft && echo -e \"proof.*=false\nproofstation.*=false\" > /root/.config/Opensoft/proof_tests.qtlogging.rules";
travis_time_finish && travis_fold end "prepare.dirs";
echo " ";

# Add folding later here if will be needed for any apps
echo -e "\033[1;33mRunning tests...\033[0m";
travis_time_start;
docker exec -t runner /sandbox/build/${TARGET_NAME}_tests;
travis_time_finish;
