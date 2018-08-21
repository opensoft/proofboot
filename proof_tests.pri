TEMPLATE = app
PROOF_PRI_PATH = $$PWD/../proofboot
# TODO: remove after full switch to submodules
!exists($$PROOF_PRI_PATH/proof.pri):PROOF_PRI_PATH = $$PWD/../../proofboot
!exists($$PROOF_PRI_PATH/proof.pri):PROOF_PRI_PATH = $$(PROOF_PATH)
include($$PROOF_PRI_PATH/proof.pri)
DESTDIR = $$BUILDPATH/tests
INCLUDEPATH += $$BUILDPATH ../3rdparty/proof-gtest

QT *= testlib
QT -= gui
CONFIG += console
CONFIG += proofcore proof-gtest
macx:CONFIG -= app_bundle

