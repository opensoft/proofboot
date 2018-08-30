#!/bin/bash
set -e

if [[ $TRAVIS_EVENT_TYPE = "pull_request" ]]; then
    exit 0;
elif [[ $TRAVIS_BRANCH = "master" ]]; then
    exit 0;
elif [[ $TRAVIS_TAG != "" ]]; then
    exit 0;
fi

REPO_NAME=`echo "$TRAVIS_REPO_SLUG" | sed -r 's|(.*/)?(.+)|\2|'`

BODY='{
    "request": {
        "message": "Requested from '$REPO_NAME' (#'$TRAVIS_BUILD_NUMBER')",
        "branch": "'$TRAVIS_BRANCH'"
    }
}';

for DEP in "$@"; do
    travis_fold start "ping.dep" && travis_time_start;
    echo -e "\033[1;33mStarting $DEP build...\033[0m";
    ESCAPED_DEP=`echo $DEP | sed -e "s|/|%2F|"`;
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -H "Travis-API-Version: 3" \
        -H "Authorization: token $TRAVIS_ACCESS_TOKEN" \
        -d "$BODY" \
        https://api.travis-ci.com/repo/$ESCAPED_DEP/requests;
    travis_time_finish && travis_fold end "ping.dep";
    echo " ";
done
