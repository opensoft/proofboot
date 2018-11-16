include(GoogleTest)
include(ProofCommon)

set(PROOF_VERSION 0.8.11.1)

macro(proof_init)
    set_property(GLOBAL PROPERTY USE_FOLDERS ON)
    list(APPEND CMAKE_PREFIX_PATH "${CMAKE_INSTALL_PREFIX}/lib/cmake")
    list(APPEND CMAKE_PREFIX_PATH "${CMAKE_INSTALL_PREFIX}/lib/cmake/3rdparty")
endmacro()

function(__proof_find_module_root_dirname module_root dir_before)
    set(current_folder ${CMAKE_CURRENT_SOURCE_DIR})
    get_filename_component(current_folder_name ${current_folder} NAME)
    while(NOT ("${current_folder_name}" STREQUAL ${dir_before} OR "${current_folder_name}" STREQUAL ""))
        get_filename_component(current_folder ${current_folder} DIRECTORY)
        get_filename_component(current_folder_name ${current_folder} NAME)
    endwhile()
    get_filename_component(current_folder ${current_folder} DIRECTORY)
    get_filename_component(current_folder ${current_folder} NAME)
    set(${module_root} ${current_folder} PARENT_SCOPE)
endfunction()

function(proof_add_target_private_headers target)
    set(Proof_${target}_PRIVATE_HEADERS ${Proof_${target}_PRIVATE_HEADERS} ${ARGN} PARENT_SCOPE)
endfunction()

function(proof_add_module target)
    cmake_parse_arguments(_arg
        "HAS_QML"
        ""
        "QT_LIBS;PROOF_LIBS;OTHER_LIBS;OTHER_PRIVATE_LIBS"
        ${ARGN}
    )

    foreach(QT_LIB ${_arg_QT_LIBS})
        find_package("Qt5${QT_LIB}" CONFIG REQUIRED)
        set(QT_LIBS ${QT_LIBS} "Qt5::${QT_LIB}")
    endforeach()

    foreach(PROOF_LIB ${_arg_PROOF_LIBS})
        set(PROOF_LIBS ${PROOF_LIBS} "Proof::${PROOF_LIB}")
    endforeach()

    add_library(${target} SHARED
        ${Proof_${target}_SOURCES} ${Proof_${target}_RESOURCES}
        ${Proof_${target}_PUBLIC_HEADERS} ${Proof_${target}_PRIVATE_HEADERS}
        ${Proof_${target}_MOC_SOURCES}
    )
    add_library("Proof::${target}" ALIAS ${target})

    proof_set_cxx_target_properties(${target})
    get_filename_component(module_root_dirname ${CMAKE_CURRENT_SOURCE_DIR} NAME)
    set_target_properties(${target} PROPERTIES
        C_VISIBILITY_PRESET hidden
        CXX_VISIBILITY_PRESET hidden
        OUTPUT_NAME "Proof${target}"
        DEFINE_SYMBOL "Proof_${target}_EXPORTS"
        FOLDER ${module_root_dirname}
    )

    target_include_directories(${target}
        PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:include>
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    )

    if(DEFINED Proof_${target}_PRIVATE_HEADERS)
        target_include_directories(${target}
            PUBLIC
            $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include/private>
            $<INSTALL_INTERFACE:include/private>
        )
    endif()

    target_link_libraries(${target}
        PUBLIC ${QT_LIBS} ${PROOF_LIBS} ${_arg_OTHER_LIBS}
        PRIVATE ${_arg_OTHER_PRIVATE_LIBS}
    )

    foreach(HEADER ${Proof_${target}_PUBLIC_HEADERS})
        get_filename_component(DEST ${HEADER} DIRECTORY)
        install(FILES ${HEADER} DESTINATION ${DEST})
    endforeach()

    install(TARGETS ${target}
        EXPORT Proof${target}Targets
        LIBRARY DESTINATION lib
        RUNTIME DESTINATION lib
    )
    install(EXPORT Proof${target}Targets DESTINATION lib/cmake
        NAMESPACE Proof::
    )
    install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/cmake/Proof${target}Config.cmake
        DESTINATION lib/cmake
    )
    install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/cmake/modules
        DESTINATION lib/cmake
        OPTIONAL
        FILES_MATCHING PATTERN "*.cmake"
    )

    install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/cmake/3rdparty
        DESTINATION lib/cmake
        OPTIONAL
        FILES_MATCHING PATTERN "*.cmake"
    )

    if ((NOT DEFINED PROOF_FULL_BUILD) OR PROOF_DEV_BUILD)
        foreach(HEADER ${Proof_${target}_PRIVATE_HEADERS})
            get_filename_component(DEST ${HEADER} DIRECTORY)
            install(FILES ${HEADER} DESTINATION ${DEST})
        endforeach()

        if (_arg_HAS_QML)
            install(DIRECTORY qml
                DESTINATION .
                FILES_MATCHING PATTERN "*.qml" PATTERN "*.js"
            )
        endif()
    endif()
endfunction()

function(proof_add_qml_plugin target)
    cmake_parse_arguments(_arg
        ""
        "QMLDIR;PLUGIN_PATH"
        "PROOF_LIBS"
        ${ARGN}
    )
    find_package(Qt5Qml CONFIG REQUIRED)

    foreach(PROOF_LIB ${_arg_PROOF_LIBS})
        set(PROOF_LIBS ${PROOF_LIBS} "Proof::${PROOF_LIB}")
    endforeach()

    set(PLUGIN_PATH "imports/Proof/${_arg_PLUGIN_PATH}")

    if(NOT DEFINED _arg_QMLDIR)
        set(_arg_QMLDIR "${CMAKE_CURRENT_SOURCE_DIR}/qmldir")
    endif()

    add_library(${target} MODULE
        ${Proof_${target}_SOURCES} ${Proof_${target}_RESOURCES}
        ${Proof_${target}_PUBLIC_HEADERS} ${Proof_${target}_PRIVATE_HEADERS}
        ${Proof_${target}_MOC_SOURCES}
        ${_arg_QMLDIR}
    )
    proof_set_cxx_target_properties(${target})
    __proof_find_module_root_dirname(module_root_dirname "plugins")
    set_target_properties(${target} PROPERTIES
        C_VISIBILITY_PRESET hidden
        CXX_VISIBILITY_PRESET hidden
        FOLDER "${module_root_dirname}/plugins"
    )

    target_link_libraries(${target} PUBLIC Qt5::Qml ${PROOF_LIBS})

    install(TARGETS ${target} LIBRARY DESTINATION ${PLUGIN_PATH})
    install(FILES ${_arg_QMLDIR} DESTINATION ${PLUGIN_PATH})
endfunction()

function(proof_add_test target)
    cmake_parse_arguments(_arg
        ""
        ""
        "PROOF_LIBS"
        ${ARGN}
    )

    foreach(PROOF_LIB ${_arg_PROOF_LIBS})
        set(PROOF_LIBS ${PROOF_LIBS} "Proof::${PROOF_LIB}")
    endforeach()

    add_executable(${target} main.cpp
        ${Proof_${target}_SOURCES} ${Proof_${target}_RESOURCES}
        ${Proof_${target}_PUBLIC_HEADERS} ${Proof_${target}_PRIVATE_HEADERS}
        ${Proof_${target}_MOC_SOURCES}
    )

    proof_set_cxx_target_properties(${target})
    __proof_find_module_root_dirname(module_root_dirname "tests")
    set_target_properties(${target} PROPERTIES
        FOLDER "${module_root_dirname}/tests"
    )
    target_link_libraries(${target} ${PROOF_LIBS} proof-gtest)

    if (NOT ANDROID)
        gtest_discover_tests(${target}
            DISCOVERY_TIMEOUT 30
            PROPERTIES TIMEOUT 30
        )
        install(TARGETS ${target} RUNTIME DESTINATION tests)
    endif()
endfunction()

function(proof_add_tool target)
    cmake_parse_arguments(_arg
        ""
        ""
        "QT_LIBS;PROOF_LIBS;OTHER_LIBS"
        ${ARGN}
    )

    foreach(QT_LIB ${_arg_QT_LIBS})
        find_package("Qt5${QT_LIB}" CONFIG REQUIRED)
        set(QT_LIBS ${QT_LIBS} "Qt5::${QT_LIB}")
    endforeach()

    foreach(PROOF_LIB ${_arg_PROOF_LIBS})
        set(PROOF_LIBS ${PROOF_LIBS} "Proof::${PROOF_LIB}")
    endforeach()

    add_executable(${target}
        ${Proof_${target}_SOURCES} ${Proof_${target}_RESOURCES}
        ${Proof_${target}_PUBLIC_HEADERS} ${Proof_${target}_PRIVATE_HEADERS}
        ${Proof_${target}_MOC_SOURCES}
    )

    proof_set_cxx_target_properties(${target})
    __proof_find_module_root_dirname(module_root_dirname "tools")
    set_target_properties(${target} PROPERTIES
        FOLDER "${module_root_dirname}/tools"
    )

    target_link_libraries(${target} ${QT_LIBS} ${PROOF_LIBS} ${_arg_OTHER_LIBS})

    install(TARGETS ${target} RUNTIME DESTINATION tools)
endfunction()
