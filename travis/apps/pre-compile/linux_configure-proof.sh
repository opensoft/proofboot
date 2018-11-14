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

sudo rm -rf $HOME/extra_s3_deps && mkdir -p $HOME/extra_s3_deps;
if [ -n "$EXTRA_S3_DEPS" ]; then
    travis_fold start "prepare.awscli" && travis_time_start;
    echo -e "\033[1;33mInstalling awscli...\033[0m";
    pip install --user awscli;
    travis_time_finish && travis_fold end "prepare.awscli";
    echo " ";
    for s3_dep in $EXTRA_S3_DEPS; do
        travis_fold start "prepare.extra_s3_dep_download" && travis_time_start;
        echo -e "\033[1;33mDownloading $s3_dep...\033[0m";
        aws s3 cp s3://proof.travis.builds/__dependencies/$s3_dep.deb $HOME/extra_s3_deps/$s3_dep.deb;
    travis_time_finish && travis_fold end "prepare.extra_s3_dep_download";
    done
    echo " ";
fi
