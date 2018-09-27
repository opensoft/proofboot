#!/bin/bash

# Copyright 2018, OpenSoft Inc.
# All rights reserved.

# Redistribution and use in source and binary forms, with or without modification, are permitted
# provided that the following conditions are met:

#     * Redistributions of source code must retain the above copyright notice, this list of
# conditions and the following disclaimer.
#    * Redistributions in binary form must reproduce the above copyright notice, this list of
# conditions and the following disclaimer in the documentation and/or other materials provided
# with the distribution.
#     * Neither the name of OpenSoft Inc. nor the names of its contributors may be used to endorse
# or promote products derived from this software without specific prior written permission.

# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
# FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
# IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
# OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# Author: denis.kormalev@opensoftdev.com (Denis Kormalev)

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

AFFECTED="$@"
if [ -f proofmodule.json ]; then
    AFFECTED=`jq -rM '"opensoft/" + .affects[]' proofmodule.json | tr -s '\r\n' '\n'`
fi

for DEP in $AFFECTED; do
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
