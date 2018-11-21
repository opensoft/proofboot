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

CLAZY_CHECKS="level3,container-inside-loop,inefficient-qlist,qhash-with-char-pointer-key,qstring-varargs,tr-non-literal,unneeded-cast,no-non-pod-global-static,no-ctor-missing-parent-argument,no-detaching-member,no-missing-typeinfo,no-inefficient-qlist"

travis_fold start "prepare.docker" && travis_time_start;
echo -e "\033[1;33mDownloading and starting Docker container...\033[0m";
docker pull opensoftdev/proof-builder-clazy:latest;
docker run -id --name builder -w="/sandbox" -v $(pwd):/sandbox/proof -v $HOME/builder_logs:/sandbox/logs \
    -e "PROOF_PATH=/sandbox/bin" -e "QMAKEFEATURES=/sandbox/bin/features" opensoftdev/proof-builder-clazy tail -f /dev/null;
docker ps;
travis_time_finish && travis_fold end "prepare.docker";
echo " ";

ISYSTEM="-isystem /opt/Opensoft/Qt/include -isystem /opt/Opensoft/Qt/include/Qca-qt5/QtCrypto -isystem /opt/Opensoft/Qt/include/QtSql -isystem /opt/Opensoft/Qt/include/QtCore -isystem /opt/Opensoft/Qt/include/QtGui -isystem /opt/Opensoft/Qt/include/QtMultimedia -isystem /opt/Opensoft/Qt/include/QtNetwork -isystem /opt/Opensoft/Qt/include/QtNetworkAuth -isystem /opt/Opensoft/Qt/include/QtOpenGL -isystem /opt/Opensoft/Qt/include/QtOpenGLExtensions -isystem /opt/Opensoft/Qt/include/QtQml -isystem /opt/Opensoft/Qt/include/QtQuick -isystem /opt/Opensoft/Qt/include/QtSerialPort -isystem /opt/Opensoft/Qt/include/QtSvg -isystem /opt/Opensoft/Qt/include/QtWebEngine -isystem /opt/Opensoft/Qt/include/QtWebEngineCore -isystem /opt/Opensoft/Qt/include/QtWebSockets -isystem /opt/Opensoft/Qt/include/QtWebView -isystem /opt/Opensoft/Qt/include/QtWidgets -isystem /opt/Opensoft/Qt/include/QtX11Extras -isystem /opt/Opensoft/Qt/include/QtXml -isystem /opt/Opensoft/Qt/include/QtXmlPatterns -isystem /opt/Opensoft/Qt/include/QtTest";

travis_fold start "build.bootstrap" && travis_time_start;
echo -e "\033[1;33mBootstrapping...\033[0m";
echo "$ proof/proofboot/bootstrap.py --src proof --dest bin";
docker exec -t builder bash -c "exec 3>&1; set -o pipefail; rm -rf /sandbox/logs/*; \
    proof/proofboot/bootstrap.py --src proof --dest bin 2>&1 1>&3 | (tee /sandbox/logs/errors.log 1>&2)";
travis_time_finish && travis_fold end "build.bootstrap" && proofboot/travis/check_for_errorslog.sh bootstrap || true;
echo " ";

travis_fold start "build.qmake" && travis_time_start;
echo -e "\033[1;33mRunning qmake...\033[0m";
echo "$ qmake -r 'QMAKE_CXX=clazy' 'DEFINES += STATIC_CODE_CHECK_BUILD' 'CONFIG += libs' 'QMAKE_CXXFLAGS += -ferror-limit=0 -fcolor-diagnostics $ISYSTEM -Xclang -plugin-arg-clazy -Xclang $CLAZY_CHECKS' ../proof/proof.pro";
docker exec -t builder bash -c "exec 3>&1; set -o pipefail; rm -rf /sandbox/logs/*; mkdir build && cd build; \
    qmake -r 'QMAKE_CXX=clazy' 'DEFINES += STATIC_CODE_CHECK_BUILD' 'CONFIG += libs' \
    'QMAKE_CXXFLAGS += -ferror-limit=0 -fcolor-diagnostics $ISYSTEM -Xclang -plugin-arg-clazy -Xclang $CLAZY_CHECKS' \
    ../proof/proof.pro 2>&1 1>&3 | (tee /sandbox/logs/errors.log 1>&2)";
travis_time_finish && travis_fold end "build.qmake" && proofboot/travis/check_for_errorslog.sh qmake || true;
echo " ";

travis_fold start "build.compile" && travis_time_start;
echo -e "\033[1;33mCompiling...\033[0m";
echo "$ make -j4";
docker exec -t builder bash -c "exec 3>&1; set -o pipefail; rm -rf /sandbox/logs/*; cd build; make -j4 2>&1 1>&3 | (tee /sandbox/logs/raw_errors.log 1>&2)";
if [ -f "$HOME/builder_logs/raw_errors.log" ]; then
    echo "$ cat \"$HOME/builder_logs/raw_errors.log\" | grep -v 'internal error' > \"$HOME/builder_logs/errors.log\"";
    (cat "$HOME/builder_logs/raw_errors.log" | grep -v 'internal error' > "$HOME/builder_logs/errors.log") || true;
fi
travis_time_finish && travis_fold end "build.compile" && proofboot/travis/check_for_errorslog.sh compilation;
