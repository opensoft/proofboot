TEMPLATE = lib
CONFIG += plugin
QT += qml

include($$PWD/proof.pri)

CONFIG += proofcore
DESTDIR = $$system_path($$BUILDPATH/imports/Proof/$$PLUGIN_PATH)

!isEmpty(win_host) {
    msvc {
        QMAKE_POST_LINK = copy $$shell_path($$clean_path($$_PRO_FILE_PWD_/qmldir)) $$shell_path($$clean_path($$DESTDIR/qmldir))
    } else {
        qmldir-copy.commands = copy $$replace(_PRO_FILE_PWD_, /, \\)\\qmldir $$replace(DESTDIR, /, \\)\\qmldir
    }
} else {
    qmldir-copy.commands = cp $${_PRO_FILE_PWD_}/qmldir $${DESTDIR}/
}
QMAKE_EXTRA_TARGETS += qmldir-copy
POST_TARGETDEPS += qmldir-copy
