#!/bin/bash
set -e

git config --global color.ui always;

travis_fold start "prepare.docker" && travis_time_start;
echo -e "\033[1;33mDownloading and starting Docker container...\033[0m";
docker pull opensoftdev/proof-check-codestyle:latest;
docker run -id --name codestyle-check -v $(pwd):/sandbox/src -w="/sandbox/src" opensoftdev/proof-check-codestyle tail -f /dev/null;
docker ps;
travis_time_finish && travis_fold end "prepare.docker";
echo " ";

travis_fold start "check.format" && travis_time_start;
echo -e "\033[1;33mRunning clang-format...\033[0m";
docker exec -t codestyle-check bash -c "find -iname '*.h' -o -iname '*.cpp' | grep -v 3rdparty | xargs clang-format -i";
travis_time_finish && travis_fold end "check.format";
echo " ";

echo -e "\033[1;35m$ git diff --stat:\033[0m" && git diff --shortstat;
echo -e "\033[1;35m$ git diff:\033[0m" && git diff;

exit `git diff | wc -l`
