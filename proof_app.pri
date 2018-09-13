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
    target.path = $$PREFIX/opt/Opensoft/$$TARGET/bin/
    rename_target.path = $$PREFIX/opt/Opensoft/$$TARGET/bin/
    rename_target.commands = \
        mv $$PREFIX/opt/Opensoft/$$TARGET/bin/$$TARGET $$PREFIX/opt/Opensoft/$$TARGET/bin/$$TARGET-bin \
        && cp $$(PROOF_PATH)/dev-tools/deploy/debian/proof-wrapper $$PREFIX/opt/Opensoft/$$TARGET/bin/$$TARGET
    rename_target.depends = install_target # qmake adds install_ prefix to then
    INSTALLS += target
    INSTALLS += rename_target
}
