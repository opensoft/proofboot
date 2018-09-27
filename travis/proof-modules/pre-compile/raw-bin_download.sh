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

travis_fold start "prepare.awscli" && travis_time_start;
echo -e "\033[1;33mInstalling awscli...\033[0m";
pip install --user awscli;
travis_time_finish && travis_fold end "prepare.awscli";
echo " ";

PLATFORM=$1;

if [ ! -f proofmodule.json ]; then
    echo -e "\033[1;31mproofmodule.json not found!\033[0m";
    exit 1;
fi

mkdir __dependencies && cd __dependencies;
for DEP in `jq -rM "if (keys | contains([\"depends_${PLATFORM}\"])) then .depends_${PLATFORM}[] else .depends[] end" ../proofmodule.json | tr -s '\r\n' '\n'`; do
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
