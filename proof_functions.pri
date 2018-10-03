QMAKE_SPEC_T = $$[QMAKE_SPEC]
contains(QMAKE_SPEC_T,.*win.*) {
    win_host = 1
}

defineTest(print_log) {
    !build_pass:log($$ARGS $$escape_expand(\\n))
}

defineTest(add_proof_module_includes) {
    MODULE_NAME = $$1
    contains(CONFIG, proof_internal):exists($$_PRO_FILE_PWD_/../proof.pro) {
        INCLUDEPATH *= $$clean_path($$system_path($$_PRO_FILE_PWD_/../$$MODULE_NAME))
        INCLUDEPATH *= $$clean_path($$system_path($$_PRO_FILE_PWD_/../$$MODULE_NAME/include))
        INCLUDEPATH *= $$clean_path($$system_path($$_PRO_FILE_PWD_/../$$MODULE_NAME/include/private))
        export(INCLUDEPATH)
    } else:contains(CONFIG, proof_internal):exists($$_PRO_FILE_PWD_/../../../proof.pro) {
# This one is for plugins
        INCLUDEPATH *= $$clean_path($$system_path($$_PRO_FILE_PWD_/../../../$$MODULE_NAME))
        INCLUDEPATH *= $$clean_path($$system_path($$_PRO_FILE_PWD_/../../../$$MODULE_NAME/include))
        INCLUDEPATH *= $$clean_path($$system_path($$_PRO_FILE_PWD_/../../../$$MODULE_NAME/include/private))
        export(INCLUDEPATH)
    }
    return(true)
}

defineTest(parse_proof_module) {
    MODULE_INFO_PATH = $$1
    MODULE_DIR = $$dirname(MODULE_INFO_PATH)
    MODULE_INFO_JSON = $$cat($$MODULE_INFO_PATH)
    parseJson(MODULE_INFO_JSON, MODULE_INFO)
    MODULE_NAME = $${MODULE_INFO.name}
    isEmpty(MODULE_NAME):return(false)
    !exists($${MODULE_DIR}/$${MODULE_NAME}.pro):return(true)

    $${MODULE_NAME}.subdir = $$MODULE_DIR
    android:contains(MODULE_INFO._KEYS_, android):contains(MODULE_INFO.android._KEYS_, depends) {
        for (key, MODULE_INFO.android.depends._KEYS_):$${MODULE_NAME}.depends *= $$eval(MODULE_INFO.android.depends.$${key})
    } else:!android:linux:contains(MODULE_INFO._KEYS_, linux):contains(MODULE_INFO.linux._KEYS_, depends) {
        for (key, MODULE_INFO.linux.depends._KEYS_):$${MODULE_NAME}.depends *= $$eval(MODULE_INFO.linux.depends.$${key})
    } else:win32:contains(MODULE_INFO._KEYS_, windows):contains(MODULE_INFO.windows._KEYS_, depends) {
        for (key, MODULE_INFO.windows.depends._KEYS_):$${MODULE_NAME}.depends *= $$eval(MODULE_INFO.windows.depends.$${key})
    } else {
        for (key, MODULE_INFO.depends._KEYS_):$${MODULE_NAME}.depends *= $$eval(MODULE_INFO.depends.$${key})
    }
    export($${MODULE_NAME}.subdir)
    export($${MODULE_NAME}.depends)
    contains(TARGETS_LIST, libs):SUBDIRS += $${MODULE_NAME}

    contains(MODULE_INFO._KEYS_, has_tests):$${MODULE_INFO.has_tests} {
        $${MODULE_NAME}_tests.file = $${MODULE_DIR}/$${MODULE_NAME}_tests.pro
        $${MODULE_NAME}_tests.depends = $${MODULE_NAME}
        export($${MODULE_NAME}_tests.file)
        export($${MODULE_NAME}_tests.depends)
        contains(TARGETS_LIST, tests):SUBDIRS += $${MODULE_NAME}_tests
    }
    contains(MODULE_INFO._KEYS_, has_plugins):$${MODULE_INFO.has_plugins} {
        $${MODULE_NAME}_plugins.file = $${MODULE_DIR}/$${MODULE_NAME}_plugins.pro
        $${MODULE_NAME}_plugins.depends = $${MODULE_NAME}
        export($${MODULE_NAME}_plugins.file)
        export($${MODULE_NAME}_plugins.depends)
        contains(TARGETS_LIST, libs):SUBDIRS += $${MODULE_NAME}_plugins
    }
    contains(MODULE_INFO._KEYS_, has_tools):$${MODULE_INFO.has_tools} {
        $${MODULE_NAME}_tools.file = $${MODULE_DIR}/$${MODULE_NAME}_tools.pro
        $${MODULE_NAME}_tools.depends = $${MODULE_NAME}
        export($${MODULE_NAME}_tools.file)
        export($${MODULE_NAME}_tools.depends)
        contains(TARGETS_LIST, tools):SUBDIRS += $${MODULE_NAME}_tools
    }

    export(SUBDIRS)
    return(true)
}

defineReplace(all_proof_modules) {
    POSSIBLE_MODULES = $$files(proof*, false)
    FOUND_MODULES=
    for (module, POSSIBLE_MODULES):exists($$module/proofmodule.json):FOUND_MODULES += $$module
    return ($$FOUND_MODULES)
}

defineTest(add_proof_modules_to_subdirs) {
    for (module, $$1):parse_proof_module($${module}/proofmodule.json)
}

#Usage find_package(<pkgconfig package>[, <Macro definition if find>])
defineTest(find_package) {
    package = $$1
    macro = $$2

    isEmpty(package) {
        warning("$$TARGET: Wrong arguments. Usage: find_package(<pkgconfig package>[, <Macro definition if find>])")
        return (false)
    }
    isEmpty(macro){
        up = $$upper($$package)
        up = $$split(up,+)
        up = $$split(up,-)
        up = $$split(up,.)
        macro = $$join(up, _, , _FOUND)
    }
    contains(DEFINES, $$macro): return (true)

    # Can't use packagesExist because it always return true
    AVAILABILITY = $$system("pkg-config $$package --exists && echo true")
    equals(AVAILABILITY, "true") {
        AVAILABILITY = $$system("pkg-config $$package --print-requires --print-requires-private --print-errors --errors-to-stdout \
                                 || echo RequirementsFailure")
    } else:exists(/usr/local/lib/lib$$package*)|exists(/usr/lib/lib$$package*) {
        LIBS *=-l$$package
        DEFINES *= $$macro
        print_log("$$TARGET: Package '$$package' probably found. Macro defined $$macro")
        export(LIBS)
        export(DEFINES)
        return (true)
    }

    !equals(AVAILABILITY, "true") {
        contains(AVAILABILITY, "RequirementsFailure") {
            print_log("$$TARGET: Not found '$$package': $$AVAILABILITY")
            return (false)
        } else:!equals(AVAILABILITY, "") {
            REQ = "Requires: '$$AVAILABILITY'. "
        }
    }
    QT_CONFIG -= no-pkg-config
    CONFIG *= link_pkgconfig
    PKGCONFIG *= $$package
    DEFINES *= $$macro
    print_log("$$TARGET: Package '$$package' found. $${REQ}Macro defined $$macro")

    export(CONFIG)
    export(PKGCONFIG)
    export(DEFINES)
    return (true)
}
