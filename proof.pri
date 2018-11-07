include ($$PWD/proof_functions.pri)
BUILDPATH = $$(PROOF_PATH)
isEmpty(BUILDPATH):BUILDPATH = $$PWD/bin
LIBS += -L$${BUILDPATH}/lib
CONFIG += proof_internal c++14
win32:CONFIG *= skip_target_version_ext
versionAtLeast(QT_VERSION, 5.11.0):!msvc:CONFIG += qtquickcompiler

OBJECTS_DIR = $$OUT_PWD/$$TARGET
MOC_DIR = $$OBJECTS_DIR
RCC_DIR = $$OBJECTS_DIR
DESTDIR = $$BUILDPATH/lib

load(crypto)

msvc {
    # QtCore/qvector.h(656): warning C4127: conditional expression is constant
    QMAKE_CXXFLAGS += /wd4127
}

INCLUDEPATH *= $$clean_path($$system_path($$PWD/include))
INCLUDEPATH *= $$clean_path($$system_path($$PWD/include/private))
INCLUDEPATH *= $$clean_path($$system_path($$_PRO_FILE_PWD_/include))
INCLUDEPATH *= $$clean_path($$system_path($$_PRO_FILE_PWD_/include/private))
android:QT += androidextras
