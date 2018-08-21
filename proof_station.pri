include($$(PROOF_PATH)/proof_functions.pri)
CONFIG += c++14 proof
versionAtLeast(QT_VERSION, 5.11.0):!msvc:CONFIG += qtquickcompiler

OBJECTS_DIR = $$OUT_PWD
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

DEFINES += APP_VERSION=\\\"$${VERSION}\\\"

android {
    PRE_TARGETDEPS += $$(PROOF_PATH)/android/src/com/opensoftdev/proof/ProofApplication.java
    PRE_TARGETDEPS += $$(PROOF_PATH)/android/src/com/opensoftdev/proof/ProofActivity.java
    PRE_TARGETDEPS += $$(PROOF_PATH)/android/src/com/opensoftdev/proof/ProofConfigurationActivity.java
    PRE_TARGETDEPS += $$(PROOF_PATH)/android/src/com/opensoftdev/proof/ControlCenterProtocol.java
    !isEmpty(win_host) {
        QMAKE_POST_LINK += xcopy $$(PROOF_PATH)\\android $$replace(OUT_PWD, /, \\)\\android-build\\ /S /E /Y
    } else {
        QMAKE_POST_LINK += mkdir -p $${OUT_PWD}/android-build && cp -R $$(PROOF_PATH)/android/src $${OUT_PWD}/android-build/
    }
} else:linux {
    target.path = $$PREFIX/opt/Opensoft/proof/bin/
    rename_target.path = $$PREFIX/opt/Opensoft/proof/bin/
    rename_target.files = $$PREFIX/opt/Opensoft/proof/bin/$$TARGET
    rename_target.extra = mv $$PREFIX/opt/Opensoft/proof/bin/$$TARGET $$PREFIX/opt/Opensoft/proof/bin/$$TARGET-bin
    target_link.path = $$PREFIX/opt/Opensoft/proof/bin/
    target_link.commands = cd $$PREFIX/opt/Opensoft/proof/bin/ && ln -s ./proof-wrapper $$TARGET
    INSTALLS += target
    INSTALLS += rename_target
    INSTALLS += target_link
}

build-package: include($$(PROOF_PATH)/proof_build_package.pri)
