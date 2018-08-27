include($$(PROOF_PATH)/proof_app.pri)

QT += network
CONFIG += proofnetwork
CONFIG -= app_bundle

linux:!android {
    # Needs proof-restarter init.d script from proof package
    target_spawn.path = $$PREFIX/opt/Opensoft/proof/bin/
    target_spawn.commands = \
        mkdir -p $$PREFIX/opt/Opensoft/proof/bin/spawn/$$TARGET/supervise && \
        echo \"$$LITERAL_HASH!/bin/bash\nexec \`dirname \\\$$0\`/../../$$TARGET\" > $$PREFIX/opt/Opensoft/proof/bin/spawn/$$TARGET/run && \
        chmod 777 $$PREFIX/opt/Opensoft/proof/bin/spawn/$$TARGET/supervise && \
        chmod +x $$PREFIX/opt/Opensoft/proof/bin/spawn/$$TARGET/run
    INSTALLS += target_spawn
}
