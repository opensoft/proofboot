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

mkdir $HOME/builder_logs;

travis_fold start "prepare.awscli" && travis_time_start;
echo -e "\033[1;33mInstalling awscli...\033[0m";
pip install --user awscli;
travis_time_finish && travis_fold end "prepare.awscli";
echo " ";

travis_fold start "prepare.docker" && travis_time_start;
echo -e "\033[1;33mDownloading and starting Docker container...\033[0m";
docker pull opensoftdev/proof-check-abi:latest;
docker run -id --name builder -w="/sandbox" -v $(pwd):/sandbox/proof -v $HOME/builder_logs:/sandbox/logs \
    -e "PROOF_PATH=/sandbox/bin" -e "QMAKEFEATURES=/sandbox/bin/features" opensoftdev/proof-check-abi tail -f /dev/null;
docker ps;
travis_time_finish && travis_fold end "prepare.docker";
echo " ";

travis_fold start "build.bootstrap" && travis_time_start;
echo -e "\033[1;33mBootstrapping...\033[0m";
echo "$ proof/proofboot/bootstrap.py --src proof --dest bin";
docker exec -t builder bash -c "exec 3>&1; set -o pipefail; rm -rf /sandbox/logs/*; \
    proof/proofboot/bootstrap.py --src proof --dest bin 2>&1 1>&3 | (tee /sandbox/logs/errors.log 1>&2)";
travis_time_finish && travis_fold end "build.bootstrap" && proofboot/travis/check_for_errorslog.sh bootstrap || true;
echo " ";

travis_fold start "build.qmake" && travis_time_start;
echo -e "\033[1;33mRunning qmake...\033[0m";
echo "$ qmake -r 'CONFIG += libs debug' 'QMAKE_CXXFLAGS += -Og -isystem /opt/Opensoft/Qt/include' -spec linux-g++ ../proof/proof.pro";
docker exec -t builder bash -c "exec 3>&1; set -o pipefail; rm -rf /sandbox/logs/*; mkdir build && cd build; \
    qmake -r 'CONFIG += libs debug' 'QMAKE_CXXFLAGS += -Og -isystem /opt/Opensoft/Qt/include' -spec linux-g++ \
    ../proof/proof.pro 2>&1 1>&3 | (tee /sandbox/logs/errors.log 1>&2)";
travis_time_finish && travis_fold end "build.qmake" && proofboot/travis/check_for_errorslog.sh qmake || true;
echo " ";

travis_fold start "build.compile" && travis_time_start;
echo -e "\033[1;33mCompiling...\033[0m";
echo "$ make -j4";
docker exec -t builder bash -c "exec 3>&1; set -o pipefail; rm -rf /sandbox/logs/*; cd build; make -j4 2>&1 1>&3 | (tee /sandbox/logs/errors.log 1>&2)";
travis_time_finish && travis_fold end "build.compile" && proofboot/travis/check_for_errorslog.sh compilation || true;

PROOF_VERSION=`proofboot/travis/grep_proof_version.sh proofboot`

ABI_ISSUES=""
API_ISSUES=""

for module in `find * -name proofmodule.json`; do
    LIBRARIES=`docker exec -t builder jq -rM '.libraries[].name' "/sandbox/proof/$module" | tr -s '\r\n' '\n'`;
    for library in $LIBRARIES; do
        travis_fold start "abi_check.dump" && travis_time_start;
        echo -e "\033[1;33mPreparing ABI dump for $library from $module...\033[0m";
        docker exec -t builder rm -f abi_dumper_includes.list || true;
        HEADERS_SUBDIR=`docker exec -t builder jq -rM ".libraries[] | select(.name == \"$library\") | .headers_subdir" "/sandbox/proof/$module" | tr -s '\r\n' '\n'`;
        DUMP_FILENAME="${library}-${PROOF_VERSION}.dump";
        if [ "$TRAVIS_PULL_REQUEST" == "false" ] && [ "$TRAVIS_BRANCH" == "master" ]; then
            DUMP_FILENAME="${library}-master.dump";
        fi
        echo "$ find \"/sandbox/bin/include/$HEADERS_SUBDIR\" -name '*.h' | sort | uniq > abi_dumper_includes.list";
        docker exec -t builder bash -c "find \"/sandbox/bin/include/$HEADERS_SUBDIR\" -name '*.h' | sort | uniq > abi_dumper_includes.list";
        echo "$ abi-dumper \"/sandbox/bin/lib/lib$library.so\" -o \"/sandbox/proof/${DUMP_FILENAME}\" -skip-cxx -dir -lambda -lver \"$PROOF_VERSION\" -ld-library-path /opt/Opensoft/Qt/lib:/sandbox/bin/lib -public-headers abi_dumper_includes.list";
        docker exec -t builder abi-dumper "/sandbox/bin/lib/lib$library.so" -o "/sandbox/proof/${DUMP_FILENAME}" -skip-cxx -dir -lambda \
            -lver "$PROOF_VERSION" -ld-library-path /opt/Opensoft/Qt/lib:/sandbox/bin/lib -public-headers abi_dumper_includes.list;
        travis_time_finish && travis_fold end "abi_check.dump";

        if [ "$TRAVIS_PULL_REQUEST" != "false" ] || [ "$TRAVIS_BRANCH" != "master" ]; then
            if [ "$TRAVIS_PULL_REQUEST" = "false" ]; then
                travis_fold start "abi_check.fetch_reference" && travis_time_start;
                echo -e "\033[1;33mFetching new ABI dump reference for $library...\033[0m";
                rm "$HOME/full_build/${library}-master.dump.gz" 2&>/dev/null || true;
                aws s3 cp "s3://proof.travis.builds/__abi-dumps/${library}-master.dump.gz" "${library}-master.dump.gz" || true;
                cp "${library}-master.dump.gz" "$HOME/full_build/${library}-master.dump.gz" || true;
                travis_time_finish && travis_fold end "abi_check.fetch_reference";
            else
                cp "$HOME/full_build/${library}-master.dump.gz" "${library}-master.dump.gz" 2&>/dev/null || true;
            fi
            if [ -f "${library}-master.dump.gz" ]; then
                travis_fold start "abi_check.compare" && travis_time_start;
                echo -e "\033[1;33mComparing ABI dump for $library with reference from master branch...\033[0m";
                echo "$ gzip -fd \"${library}-master.dump.gz\"";
                gzip -fd "${library}-master.dump.gz";
                echo "$ abi-compliance-checker -l \"$library\" -old \"/sandbox/proof/${library}-master.dump\" -new \"/sandbox/proof/${DUMP_FILENAME}\" -ext -list-affected";
                COMPARE_RESULTS=`docker exec -t builder abi-compliance-checker -l "$library" -old "/sandbox/proof/${library}-master.dump" -new "/sandbox/proof/${DUMP_FILENAME}" -ext -list-affected || true`;
                echo "$COMPARE_RESULTS";
                travis_time_finish && travis_fold end "abi_check.compare";

                RESULTS_DIR=`echo "$COMPARE_RESULTS" | sed -nE 's|Report: (.+)/compat_report.html|\1|p' | tr -s '\r\n' '\n'`;
                BINARY_COUNT=`echo "$COMPARE_RESULTS" | sed -nE 's|Total binary compatibility problems: ([0-9]+).*|\1|p' | tr -s '\r\n' '\n'`
                SOURCE_COUNT=`echo "$COMPARE_RESULTS" | sed -nE 's|Total source compatibility problems: ([0-9]+).*|\1|p' | tr -s '\r\n' '\n'`
                if [ "$BINARY_COUNT" -ne 0 ]; then
                    echo -e "\033[1;31mABI issues found:\033[0m";
                    CURRENT_ISSUES=`docker exec -t builder bash -c "echo | c++filt @'$RESULTS_DIR/abi_affected.txt'"`;
                    echo "$CURRENT_ISSUES";
                    echo;
                    ABI_ISSUES=`( echo "$ABI_ISSUES"; echo "$library:"; echo "$CURRENT_ISSUES"; echo )`;
                fi
                if [ "$SOURCE_COUNT" -ne 0 ]; then
                    echo -e "\033[1;31mAPI issues found:\033[0m";
                    CURRENT_ISSUES=`docker exec -t builder bash -c "echo | c++filt @'$RESULTS_DIR/src_affected.txt'"`;
                    echo "$CURRENT_ISSUES";
                    echo;
                    API_ISSUES=`( echo "$API_ISSUES"; echo "$library:"; echo "$CURRENT_ISSUES"; echo )`;
                fi
                docker exec -t builder rm -rf "$RESULTS_DIR" || true;
            else
                echo -e "\033[1;33mNo reference dump found for $library from $module. Should be new one, skipping it\033[0m";
            fi
            echo;
        fi
    done
done

if [ "$TRAVIS_PULL_REQUEST" == "false" ] && [ "$TRAVIS_BRANCH" == "master" ]; then
    travis_fold start "abi_check.upload_master_dump" && travis_time_start;
    echo -e "\033[1;33mSending dump references to S3...\033[0m";
    for dump_file in *.dump; do
        echo "$ gzip \"$dump_file\"";
        gzip "$dump_file";
        echo "$ aws s3 cp \"${dump_file}.gz\" \"s3://proof.travis.builds/__abi-dumps/${dump_file}.gz\"";
        aws s3 cp "${dump_file}.gz" "s3://proof.travis.builds/__abi-dumps/${dump_file}.gz";
    done
    travis_time_finish && travis_fold end "abi_check.upload_master_dump";
fi

if [ "$TRAVIS_PULL_REQUEST" != "false" ]; then
    travis_fold start "abi_check.pr_comment" && travis_time_start;
    echo -e "\033[1;33mSending comment to GitHub pull request...\033[0m";

    GITHUB_COMMENT=""
    if [ -n "$API_ISSUES" ]; then
        ESCAPED_API_ISSUES=`echo -e "$API_ISSUES" | awk -v ORS='\\n' '1'`;
        GITHUB_COMMENT="$GITHUB_COMMENT"'#### API issues found:\\n\\n'"$ESCAPED_API_ISSUES"'\\n';
    fi
    if [ -n "$ABI_ISSUES" ]; then
        ESCAPED_ABI_ISSUES=`echo -e "$ABI_ISSUES" | awk -v ORS='\\n' '1'`;
        GITHUB_COMMENT="$GITHUB_COMMENT"'#### ABI issues found:\\n\\n'"$ESCAPED_ABI_ISSUES"'\\n';
    fi

    if [ -z "$GITHUB_COMMENT" ]; then
        $GITHUB_COMMENT="#### No API or ABI issues found!"
    fi

    curl -s -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: token $GITHUB_ACCESS_TOKEN" \
        -d "{\"body\": \"$GITHUB_COMMENT\"}" \
        "https://api.github.com/repos/$TRAVIS_REPO_SLUG/issues/$TRAVIS_PULL_REQUEST/comments";

    travis_time_finish && travis_fold end "abi_check.pr_comment";
fi

if [ -n "$API_ISSUES" ]; then
    echo -e "\033[1;31mAPI is incompatible!\033[0m";
    # TODO: 1.0: Replace with code below to make it failing build
    # echo -e "\033[1;31mAPI is incompatible, halting!\033[0m";
    # exit 1;
else
    echo -e "\033[1;32mAPI is compatible, good job!\033[0m";
fi
