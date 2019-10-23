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

APP_VERSION="$($HOME/proof-bin/dev-tools/travis/grep_proof_app_version.sh .)";

DEB_FILENAME=$(locate -n 1 *$TARGET_NAME-*.deb)
if [ -z "$DEB_FILENAME" ]; then
    echo -e "\033[1;31mCan't find created deb package, halting\033[0m";
    exit 1
fi

echo "deb package found $DEB_FILENAME"

travis_time_start;
echo -e "\033[1;33mCreating docker image...\033[0m";
mkdir build && mv $DEB_FILENAME build/;

if [ -n "$(ls -A $HOME/extra_s3_deps/*.deb 2>/dev/null)" ]; then
    cp $HOME/extra_s3_deps/*.deb build/;
fi

if [ ! -f Dockerfile ]; then
cat << EOT > Dockerfile
FROM opensoftdev/proof-app-deploy-base
COPY build/*.deb /build/
RUN apt-get -qq update \
    && if [ -n "$USE_OPENCV" ]; then (apt install /prebuilt-extras/*opencv*.deb -y --no-install-recommends); fi \
    && cd /build && (apt install ./*.deb -y --no-install-recommends) \
    && rm -rf /build && /image_cleaner.sh
USER proof:proof
VOLUME /home/proof
ENTRYPOINT ["/opt/Opensoft/$TARGET_NAME/bin/$TARGET_NAME"]
EOT
fi

echo -e "\033[1mDockerfile contents:\033[0m"
cat Dockerfile;
echo "";
docker build -t opensoftdev/$TARGET_NAME -f Dockerfile ./;

echo -e "\033[1;33mTagging docker images for upload from one built above:\033[0m";
if [ -n "$TRAVIS_TAG" ]; then
    echo "$DOCKER_REGISTRY/$TARGET_NAME:$APP_VERSION";
    docker tag opensoftdev/$TARGET_NAME $DOCKER_REGISTRY/$TARGET_NAME:$APP_VERSION;
    echo "$DOCKER_REGISTRY/$TARGET_NAME:latest";
    docker tag opensoftdev/$TARGET_NAME $DOCKER_REGISTRY/$TARGET_NAME:latest;
    echo "$DOCKER_REGISTRY/$TARGET_NAME-prod:$APP_VERSION";
    docker tag opensoftdev/$TARGET_NAME $DOCKER_REGISTRY/$TARGET_NAME-prod:$APP_VERSION;
    echo "$DOCKER_REGISTRY/$TARGET_NAME-prod:latest";
    docker tag opensoftdev/$TARGET_NAME $DOCKER_REGISTRY/$TARGET_NAME-prod:latest;
else
    echo "$DOCKER_REGISTRY/$TARGET_NAME:$TRAVIS_BRANCH-$APP_VERSION";
    docker tag opensoftdev/$TARGET_NAME $DOCKER_REGISTRY/$TARGET_NAME:$TRAVIS_BRANCH-$APP_VERSION;
    echo "$DOCKER_REGISTRY/$TARGET_NAME:$TRAVIS_BRANCH-latest";
    docker tag opensoftdev/$TARGET_NAME $DOCKER_REGISTRY/$TARGET_NAME:$TRAVIS_BRANCH-latest;
fi
travis_time_finish

source $HOME/proof-bin/dev-tools/travis/detect_build_type.sh;
if [ -z "$SKIP_UPLOAD" ]; then
    travis_time_start;
    echo -e "\033[1;33mPushing docker images to registry...\033[0m";
    echo "$DOCKER_PASSWORD" | docker login -u $DOCKER_USERNAME --password-stdin $DOCKER_REGISTRY;
    for img in `docker images --format "{{.Repository}}:{{.Tag}}" $DOCKER_REGISTRY/$TARGET_NAME* | grep -v "<none>"`; do
        echo -e "\033[1mPushing $img...\033[0m";
        docker push $img;
    done
    travis_time_finish;
fi
