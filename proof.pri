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

!contains(DEFINES, FORCE_QCA_DISABLED) {
    load(crypto) {
        DEFINES -= QCA_DISABLED
    } else {
        CONFIG -= crypto
        DEFINES += QCA_DISABLED
    }
}

msvc {
    # QtCore/qvector.h(656): warning C4127: conditional expression is constant
    QMAKE_CXXFLAGS += /wd4127
}

# TODO: Can we somehow move that modules includes into features maybe?
INCLUDEPATH += $$PWD/.. \
    $$proof_module_includes(proofseed) \
    $$proof_module_includes(proofbase) \
    $$proof_module_includes(proofutils) \
    $$proof_module_includes(proofnetworkjdf)
android:QT += androidextras
