defineReplace(languages_list) {
    return (en es ja de zh)
}

defineReplace(translations_path) {
    file = $$1
    result = translations/$$file
    return ($$result)
}

defineReplace(file_paths_in_pro_dir) {
    files = $$1
    result =
    for (file, files) {
        result += $$_PRO_FILE_PWD_/$$file
    }
    return ($$result)
}

defineReplace(generate_translations_qrc) {
    qm_files = $$1
    body = <RCC> "<qresource prefix=\"/translations\">"
    for (file, qm_files) {
        qm_filepath = $$_PRO_FILE_PWD_/$$translations_path($$file)
        !exists($$qm_filepath) {
            write_file($$_PRO_FILE_PWD_/$$translations_path($$file))
        }
        body += "<file>$$file</file>"
    }
    body += </qresource> </RCC>
    body = $$join(body, " ")
    qrc_file = $$_PRO_FILE_PWD_/$$translations_path($${TARGET}_translations.qrc)
    qrc_contents = $$cat($$qrc_file, blob)
    !equals($$qrc_contents, body) {
        write_file($$qrc_file, body)
    }
    return ($$qrc_file)
}

defineReplace(list_for_lupdate) {
    extensions = java jui ui c c++ cc cpp cxx ch h h++ hh hpp hxx js qs qml
    source_files = $$file_paths_in_pro_dir($$HEADERS $$SOURCES $$OTHER_FILES $$DISTFILES)
    result_list =
    for (file, source_files) {
        splitted_file = $$split(file, .)
        ext = $$last(splitted_file)
        contains(extensions, $$ext):result_list += $$file
    }
    result = $$RCC_DIR/ts_files.list
    write_file($$result, result_list)
    return ($$result)
}

defineReplace(qm_file_list) {
    languages = $$languages_list()
    result =
    for (lang, languages) {
        result += $${TARGET}.$${lang}.qm
    }
    return ($$result)
}

RESOURCES += $$generate_translations_qrc($$qm_file_list())
!with-translations:system($$(PROOF_PATH)/generate_translation.py --target $$TARGET --keep_ts --ts_dir $$_PRO_FILE_PWD_/translations --lst $$list_for_lupdate() $$languages_list())
with-translations:system($$(PROOF_PATH)/generate_translation.py --target $$TARGET --ts_dir $$_PRO_FILE_PWD_/translations --lst $$list_for_lupdate() $$languages_list())
