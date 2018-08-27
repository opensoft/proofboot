include($$(PROOF_PATH)/proof_functions.pri)
CONFIG += c++14 proof

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

linux:!android {
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
