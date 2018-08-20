include($$(PROOF_PATH)/proof_functions.pri)

win32: CONFIG(release, debug|release)  {
    _PRO_FILE_PWD_PREPARE_SEPARATORS_ = $$system_path($$_PRO_FILE_PWD_)
    DESTDIR = $$_PRO_FILE_PWD_PREPARE_SEPARATORS_\\deploy\\packages\\proof\\data
    INSTALLERPATH = $$_PRO_FILE_PWD_PREPARE_SEPARATORS_\\bin

    BINARYCREATORHELPTEXT = $$system("binarycreator")
    !contains(BINARYCREATORHELPTEXT, -p|--packages): message("Qt\Tools\QtInstallerFramework\2.X\bin must be in PATH")
    !exists($$DESTDIR/libeay32.dll): message("$$DESTDIR/libeay32.dll not found. Please put libeay32.dll to $$DESTDIR before run to build")
    !exists($$DESTDIR/ssleay32.dll): message("$$DESTDIR/ssleay32.dll not found. Please put ssleay32.dll to $$DESTDIR before run to build")

    PROOFMODULES = $$find(CONFIG, proof)
    PROOFMODULES *= $$PACKAGEADDITIONALMODULES
    PROOFMODULES *= $$find(CONFIG, qamqp)
    for (PROOFMODULE, PROOFMODULES) {
        QMAKE_POST_LINK += robocopy $$(PROOF_PATH)\\lib $$DESTDIR $$PROOFMODULE"0.dll" /E &
        PROOFMODULEPLUGINSDIR = $$proof_plugin_dir_by_module($$PROOFMODULE)
        !isEmpty(PROOFMODULEPLUGINSDIR) {
            QMAKE_POST_LINK += robocopy $$(PROOF_PATH)\\imports\\$$PROOFMODULEPLUGINSDIR $$DESTDIR\\$$PROOFMODULEPLUGINSDIR *.* /E &
        }
    }

    QMAKE_POST_LINK += echo "Copying libqca to $$DESTDIR" \
                    & robocopy $(QTDIR)\\bin $$DESTDIR libqca-qt5.dll \
                    & echo "Running windeployqt to $$DESTDIR" \
                    & windeployqt -serialport --qmldir $(QTDIR)/qml $$DESTDIR \
                    & echo "Creating folder $$INSTALLERPATH" \
                    & mkdir $$INSTALLERPATH \
                    & echo "Runing binarycreator for $$INSTALLERPATH/$$TARGET-installer target with config from $$_PRO_FILE_PWD_/deploy/config/config.xml and package contents from $$_PRO_FILE_PWD_/deploy/packages" \
                    & binarycreator -f -c $$_PRO_FILE_PWD_/deploy/config/config.xml -p $$_PRO_FILE_PWD_/deploy/packages $$INSTALLERPATH/$$TARGET-installer \
                    & echo "Installer created at $$INSTALLERPATH/$$TARGET-installer"
}
