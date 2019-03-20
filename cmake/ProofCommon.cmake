set(__PROOF_MODULES_DIR ${CMAKE_CURRENT_LIST_DIR})

function(proof_set_cxx_target_properties target)
    set_target_properties(${target} PROPERTIES
        CXX_STANDARD 17
        CXX_STANDARD_REQUIRED ON
        CXX_EXTENSIONS OFF
        POSITION_INDEPENDENT_CODE ON
        AUTOMOC ON
    )
    if (WIN32)
        if (MSVC)
            target_compile_options(${target} PUBLIC /bigobj /W4 $<$<CONFIG:Debug>:/ZI>)
        else()
            target_compile_options(${target} PUBLIC -Wa,-mbig-obj)
        endif()
    else()
        set_target_properties(${target} PROPERTIES LINK_FLAGS "-Wl,-export-dynamic")
    endif()
    if (ANDROID)
        set(CMAKE_SYSROOT_COMPILE "${CMAKE_SYSROOT}")
    endif()
    target_compile_definitions(${target} PRIVATE QT_MESSAGELOGCONTEXT QT_DISABLE_DEPRECATED_BEFORE=0x060000)
    target_compile_definitions(${target} PUBLIC ASYNQRO_QT_SUPPORT)
endfunction()

function(proof_process_target_resources target)
    if(Qt5Core_VERSION VERSION_GREATER "5.11")
        find_package(Qt5QuickCompiler CONFIG REQUIRED)
        qtquick_compiler_add_resources(Proof_${target}_PROCESSED_RESOURCES ${Proof_${target}_RESOURCES})
        set(Proof_${target}_PROCESSED_RESOURCES ${Proof_${target}_PROCESSED_RESOURCES} ${Proof_${target}_RESOURCES})
    else()
        qt5_add_resources(Proof_${target}_PROCESSED_RESOURCES ${Proof_${target}_RESOURCES})
    endif()
    set(Proof_${target}_PROCESSED_RESOURCES ${Proof_${target}_PROCESSED_RESOURCES} PARENT_SCOPE)
endfunction()

function(proof_add_target_sources target)
    set(Proof_${target}_SOURCES ${Proof_${target}_SOURCES} ${ARGN} PARENT_SCOPE)
endfunction()

function(proof_add_target_headers target)
    set(Proof_${target}_PUBLIC_HEADERS ${Proof_${target}_PUBLIC_HEADERS} ${ARGN} PARENT_SCOPE)
endfunction()

function(proof_add_target_resources target)
    set(Proof_${target}_RESOURCES ${Proof_${target}_RESOURCES} ${ARGN} PARENT_SCOPE)
endfunction()

function(proof_add_target_misc target)
    set(Proof_${target}_MISC ${Proof_${target}_MISC} ${ARGN} PARENT_SCOPE)
endfunction()

function(proof_force_moc target)
    qt5_wrap_cpp(Proof_${target}_MOC_SOURCES ${ARGN})
    set(Proof_${target}_MOC_SOURCES ${Proof_${target}_MOC_SOURCES} PARENT_SCOPE)
endfunction()

macro(proof_update_parent_scope target)
    if(Proof_${target}_SOURCES)
        set(Proof_${target}_SOURCES ${Proof_${target}_SOURCES} PARENT_SCOPE)
    endif()
    if(Proof_${target}_PUBLIC_HEADERS)
        set(Proof_${target}_PUBLIC_HEADERS ${Proof_${target}_PUBLIC_HEADERS} PARENT_SCOPE)
    endif()
    if(Proof_${target}_PRIVATE_HEADERS)
        set(Proof_${target}_PRIVATE_HEADERS ${Proof_${target}_PRIVATE_HEADERS} PARENT_SCOPE)
    endif()
    if(Proof_${target}_MOC_SOURCES)
        set(Proof_${target}_MOC_SOURCES ${Proof_${target}_MOC_SOURCES} PARENT_SCOPE)
    endif()
    if(Proof_${target}_RESOURCES)
        set(Proof_${target}_RESOURCES ${Proof_${target}_RESOURCES} PARENT_SCOPE)
    endif()
    if(Proof_${target}_MISC)
        set(Proof_${target}_MISC ${Proof_${target}_MISC} PARENT_SCOPE)
    endif()
endmacro()

function(proof_add_translations target)
    cmake_parse_arguments(_arg
        ""
        "PREFIX;TARGET_CMAKE_FOLDER"
        ""
        ${ARGN}
    )

    find_package(Qt5LinguistTools REQUIRED)
    set(LANGS en de es ja zh)
    list(TRANSFORM LANGS PREPEND "${CMAKE_CURRENT_SOURCE_DIR}/translations/${_arg_PREFIX}${target}." OUTPUT_VARIABLE TS_FILES)
    list(TRANSFORM TS_FILES APPEND ".ts")

    if(PROOF_GENERATE_TRANSLATIONS)
        set(translation_sources ${Proof_${target}_SOURCES} ${Proof_${target}_PUBLIC_HEADERS} ${Proof_${target}_PRIVATE_HEADERS})
        if (EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/qml)
            set(translation_sources ${translation_sources} ${CMAKE_CURRENT_SOURCE_DIR}/qml)
        endif()
        qt5_create_translation(QM_FILES ${translation_sources} ${TS_FILES})
        set(add_translations 1)
    elseif(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/translations/${_arg_PREFIX}${target}.en.ts)
        qt5_add_translation(QM_FILES ${TS_FILES})
        set(add_translations 1)
    endif()
    if(add_translations)
        add_custom_target(${target}_translations DEPENDS ${QM_FILES})
        if(_arg_TARGET_CMAKE_FOLDER)
            set_target_properties(${target}_translations PROPERTIES FOLDER ${_arg_TARGET_CMAKE_FOLDER})
        endif()
        add_dependencies(${target} ${target}_translations)
        set(qm_for_qrc ${LANGS})
        list(TRANSFORM qm_for_qrc PREPEND "    <file>${_arg_PREFIX}${target}.")
        list(TRANSFORM qm_for_qrc APPEND ".qm</file>")
        list(JOIN qm_for_qrc "\n" translations_qrc_content)
        file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/${target}_translations.qrc
            "<RCC>\n  <qresource prefix=\"/translations\">\n${translations_qrc_content}\n  </qresource>\n</RCC>"
        )
        qt5_add_resources(TRANSLATIONS_QRC ${CMAKE_CURRENT_BINARY_DIR}/${target}_translations.qrc)
        target_sources(${target} PRIVATE ${TRANSLATIONS_QRC})
    endif()
endfunction()
