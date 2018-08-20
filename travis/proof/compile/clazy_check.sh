#!/bin/bash
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

ISYSTEM="-isystem /opt/Opensoft/Qt/include -isystem /opt/Opensoft/Qt/include/Qca-qt5/QtCrypto -isystem /opt/Opensoft/Qt/include/QtCore -isystem /opt/Opensoft/Qt/include/QtGui -isystem /opt/Opensoft/Qt/include/QtMultimedia -isystem /opt/Opensoft/Qt/include/QtNetwork -isystem /opt/Opensoft/Qt/include/QtNetworkAuth -isystem /opt/Opensoft/Qt/include/QtOpenGL -isystem /opt/Opensoft/Qt/include/QtOpenGLExtensions -isystem /opt/Opensoft/Qt/include/QtQml -isystem /opt/Opensoft/Qt/include/QtQuick -isystem /opt/Opensoft/Qt/include/QtSerialPort -isystem /opt/Opensoft/Qt/include/QtSvg -isystem /opt/Opensoft/Qt/include/QtWebEngine -isystem /opt/Opensoft/Qt/include/QtWebEngineCore -isystem /opt/Opensoft/Qt/include/QtWebSockets -isystem /opt/Opensoft/Qt/include/QtWebView -isystem /opt/Opensoft/Qt/include/QtWidgets -isystem /opt/Opensoft/Qt/include/QtX11Extras -isystem /opt/Opensoft/Qt/include/QtXml -isystem /opt/Opensoft/Qt/include/QtXmlPatterns";

travis_fold start "build.bootstrap" && travis_time_start;
echo -e "\033[1;33mBootstrapping...\033[0m";
echo "$ proof/proofboot/bootstrap.py --src proof --dest bin";
docker exec -t builder bash -c "exec 3>&1; set -o pipefail; rm -rf /sandbox/logs/*; \
    proof/proofboot/bootstrap.py --src proof --dest bin 2>&1 1>&3 | (tee /sandbox/logs/errors.log 1>&2)";
travis_time_finish && travis_fold end "build.bootstrap" && proofboot/travis/check_for_errorslog.sh bootstrap || true;
echo " ";

travis_fold start "build.qmake" && travis_time_start;
echo -e "\033[1;33mRunning qmake...\033[0m";
echo "$ qmake -r 'QMAKE_CXX=clazy' 'DEFINES += STATIC_CODE_CHECK_BUILD' 'CONFIG += libs' 'QMAKE_CXXFLAGS += -ferror-limit=0 -fcolor-diagnostics $ISYSTEM -Xclang -plugin-arg-clang-lazy -Xclang $CLAZY_CHECKS' ../proof/proof.pro";
docker exec -t builder bash -c "exec 3>&1; set -o pipefail; rm -rf /sandbox/logs/*; mkdir build && cd build; \
    qmake -r 'QMAKE_CXX=clazy' 'DEFINES += STATIC_CODE_CHECK_BUILD' 'CONFIG += libs' \
    'QMAKE_CXXFLAGS += -ferror-limit=0 -fcolor-diagnostics $ISYSTEM -Xclang -plugin-arg-clang-lazy -Xclang $CLAZY_CHECKS' \
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
