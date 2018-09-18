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

source proofboot/travis/detect_build_type.sh;
if [ -n "$SKIP_UPLOAD" ]; then
    echo -e "\033[1;33mSkipping artifact upload\033[0m";
    exit 0;
fi

PROOF_VERSION=`proofboot/travis/grep_proof_version.sh proofboot`

travis_fold start "prepare.awscli" && travis_time_start;
echo -e "\033[1;33mInstalling awscli...\033[0m";
pip install --user awscli;
travis_time_finish && travis_fold end "prepare.awscli";
echo " ";

travis_time_start;
echo -e "\033[1;33mUnpacking bin.tar.gz from cache...\033[0m";
cd $HOME;
cp full_build/bin.tar.gz bin.tar.gz;
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
if [ -n "$RELEASE_BUILD" ]; then
    aws s3 cp proof-bin.tar.gz s3://proof.travis.builds/__releases/proof/raw-bin/$PROOF_VERSION/proof-bin-$1.tar.gz;
else
    aws s3 cp proof-bin.tar.gz s3://proof.travis.builds/$TRAVIS_BRANCH/raw-bin/proof-bin-$1.tar.gz;
fi
travis_time_finish
