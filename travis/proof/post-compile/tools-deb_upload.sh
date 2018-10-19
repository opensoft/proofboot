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

APP_VERSION=`proofboot/travis/grep_proof_version.sh proofboot`
TARGET_NAME=proof-tools

travis_fold start "prepare.awscli" && travis_time_start;
echo -e "\033[1;33mInstalling awscli...\033[0m";
pip install --user awscli;
travis_time_finish && travis_fold end "prepare.awscli";
echo " ";

travis_time_start;
echo -e "\033[1;33mPreparing sources...\033[0m";
mkdir $HOME/tools-src && find ./ -type d -name tools | xargs cp -t $HOME/tools-src/ -R;
travis_time_finish;

travis_time_start;
echo -e "\033[1;33mUnpacking bin.tar.gz from cache...\033[0m";
cd $HOME;
cp full_build/bin.tar.gz bin.tar.gz;
tar -xzf bin.tar.gz;
mv bin proof-bin;
mkdir -p $HOME/tools-bin/opt/Opensoft/proof-tools;
mv proof-bin/tools $HOME/tools-bin/opt/Opensoft/proof-tools/bin;
for f in $HOME/tools-bin/opt/Opensoft/proof-tools/bin/*; do
    f_name=`basename $f`
    mv $f ${f}-bin;
    cat << EOT > "$f"
#!/bin/bash
export PROOF_PATH="/opt/Opensoft/proof-tools"
export LD_LIBRARY_PATH="/opt/Opensoft/proof-tools/lib"
exec "/opt/Opensoft/proof-tools/bin/${f_name}-bin" \$1 \$2 \$3 \$4 \$5 \$6 \$7 \$8 \$9
EOT
done
cat << EOT > "$HOME/tools-src/Manifest"
#!/bin/bash
DESCRIPTION="Proof Tools.
 Various proof tools. Mostly hardware-related stuff like cutter emulators.
"
EXTRA_RECOMMENDS=socat
EOT
cat << EOT > "$HOME/tools-src/proof-tools.pro"
VERSION = $APP_VERSION
EOT
travis_time_finish;

travis_fold start "prepare.docker" && travis_time_start;
echo -e "\033[1;33mDownloading and starting Docker container...\033[0m";
docker pull opensoftdev/proof-builder-base:latest;
docker run -id --name builder -w="/sandbox" -v $HOME/tools-src:/sandbox/target_src -v $HOME/tools-bin:/sandbox/build -v $HOME/proof-bin:/opt/Opensoft/proof \
    -e "BUILD_ROOT=/sandbox/build" -e "PACKAGE_ROOT=/sandbox/build" -e "TARGET_NAME=$TARGET_NAME" \
    -e "SKIP_BUILD_FOR_DEB_PACKAGE=true" -e "SKIP_DEB_SCRIPTS=true" \
    -e "PROOF_PATH=/opt/Opensoft/proof" -e "QMAKEFEATURES=/opt/Opensoft/proof/features" \
    opensoftdev/proof-builder-base tail -f /dev/null;
docker ps;
travis_time_finish && travis_fold end "prepare.docker";
echo " ";

travis_fold start "prepare.apt_cache" && travis_time_start;
echo -e "\033[1;33mUpdating apt cache...\033[0m";
docker exec -t builder apt-get update;
travis_time_finish && travis_fold end "prepare.apt_cache";
echo " ";

travis_fold start "pack.deb" && travis_time_start;
echo -e "\033[1;33mCreating deb package...\033[0m";
echo "$ /opt/Opensoft/proof/dev-tools/deploy/debian/build_deb_package.sh -f /sandbox/target_src/Manifest /sandbox/target_src";
docker exec -t builder bash -c "/opt/Opensoft/proof/dev-tools/deploy/debian/build_deb_package.sh -f /sandbox/target_src/Manifest /sandbox/target_src";
travis_time_finish && travis_fold end "pack.deb";
echo " ";

cd $HOME/tools-src;
DEB_FILENAME=`find -maxdepth 1 -name "$TARGET_NAME-*.deb" -exec basename "{}" \; -quit`
if [ -z  "$DEB_FILENAME" ]; then
    echo -e "\033[1;31mCan't find created deb package, halting\033[0m";
    exit 1
fi

travis_time_start;
echo -e "\033[1;33mUploading to AWS S3...\033[0m";
if [ -n "$RELEASE_BUILD" ]; then
    $HOME/proof-bin/dev-tools/travis/s3_upload.sh "$DEB_FILENAME" __releases/proof $TARGET_NAME-$APP_VERSION.deb;
else
    $HOME/proof-bin/dev-tools/travis/s3_upload.sh "$DEB_FILENAME" $TRAVIS_BRANCH $TARGET_NAME-$APP_VERSION-$TRAVIS_BRANCH.deb;
fi
travis_time_finish
