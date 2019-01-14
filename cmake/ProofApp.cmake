include(ProofCommon)
get_filename_component(PROOF_CMAKE_PATH ${CMAKE_CURRENT_LIST_DIR} DIRECTORY)

macro(proof_project project_name)
    cmake_parse_arguments(_arg
        ""
        "VERSION"
        ""
        ${ARGN}
    )

    project(${project_name} VERSION ${_arg_VERSION} LANGUAGES CXX)
    find_package(Qt5Core CONFIG REQUIRED)
    include(ProofAndroidApk OPTIONAL)
    add_compile_definitions(APP_VERSION=\"${_arg_VERSION}\")
    include_directories(${CMAKE_CURRENT_SOURCE_DIR})
    include_directories(${CMAKE_CURRENT_SOURCE_DIR}/src)
    list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
    include(GoogleTest)
    enable_testing()
    install(CODE "MESSAGE(\"\")")
endmacro()

function(proof_add_app target)
    cmake_parse_arguments(_arg
        "AUTOSTART;HAS_UI"
        ""
        "QT_LIBS;PROOF_LIBS;OTHER_LIBS"
        ${ARGN}
    )

    foreach(QT_LIB ${_arg_QT_LIBS})
        find_package("Qt5${QT_LIB}" CONFIG REQUIRED)
        set(QT_LIBS ${QT_LIBS} "Qt5::${QT_LIB}")
    endforeach()

    foreach(PROOF_LIB ${_arg_PROOF_LIBS})
        find_package("Proof${PROOF_LIB}" CONFIG REQUIRED)
        set(PROOF_LIBS ${PROOF_LIBS} "Proof::${PROOF_LIB}")
    endforeach()

    if (EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/CHANGELOG.md)
        proof_add_target_misc(${target} ${CMAKE_CURRENT_SOURCE_DIR}/CHANGELOG.md)
    endif()
    if (EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/UPGRADE.md)
        proof_add_target_misc(${target} ${CMAKE_CURRENT_SOURCE_DIR}/UPGRADE.md)
    endif()
    if (EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/README.md)
        proof_add_target_misc(${target} ${CMAKE_CURRENT_SOURCE_DIR}/README.md)
    endif()
    if (EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/Manifest)
        proof_add_target_misc(${target} ${CMAKE_CURRENT_SOURCE_DIR}/Manifest)
    endif()
    if (EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/.travis.yml)
        proof_add_target_misc(${target} ${CMAKE_CURRENT_SOURCE_DIR}/.travis.yml)
    endif()

    proof_process_target_resources(${target})
    if (ANDROID)
        add_library(${target} SHARED
            ${Proof_${target}_SOURCES} ${Proof_${target}_PROCESSED_RESOURCES}
            ${Proof_${target}_PUBLIC_HEADERS}
            ${Proof_${target}_MOC_SOURCES} ${Proof_${target}_MISC}
        )
    else()
        add_executable(${target}
            ${Proof_${target}_SOURCES} ${Proof_${target}_PROCESSED_RESOURCES}
            ${Proof_${target}_PUBLIC_HEADERS}
            ${Proof_${target}_MOC_SOURCES} ${Proof_${target}_MISC}
        )
    endif()
    proof_set_cxx_target_properties(${target})
    proof_add_translations(${target})
    target_link_libraries(${target} ${QT_LIBS} ${PROOF_LIBS} ${_arg_OTHER_LIBS})

    if (${CMAKE_SYSTEM_NAME} STREQUAL "Linux")
        set_target_properties(${target} PROPERTIES
            OUTPUT_NAME "${target}-bin"
        )
        install(TARGETS ${target}
            RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}/opt/Opensoft/${target}/bin"
        )
        set(WRAPPER_TEXT "#!/bin/bash
export LD_LIBRARY_PATH=/opt/Opensoft/${target}/lib:/opt/Opensoft/Qt/lib:/usr/local/lib:$LD_LIBRARY_PATH
exec /opt/Opensoft/${target}/bin/${target}-bin $1 $2 $3 $4 $5 $6 $7 $8 $9
")
        if(_arg_HAS_UI)
            set(RESTARTER_TEXT "#!/bin/bash
DISPLAY=:0.0 exec /opt/Opensoft/${target}/bin/${target}
")
        else()
            set(RESTARTER_TEXT "#!/bin/bash
exec /opt/Opensoft/${target}/bin/${target}
")
        endif()
        file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/debian)
        file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/debian/supervise)
        file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/debian/wrapper.sh "${WRAPPER_TEXT}")
        file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/debian/restarter.sh "${RESTARTER_TEXT}")
        install(FILES ${CMAKE_CURRENT_BINARY_DIR}/debian/wrapper.sh
            DESTINATION opt/Opensoft/${target}/bin
            RENAME ${target}
            PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE
        )
        install(FILES ${CMAKE_CURRENT_BINARY_DIR}/debian/restarter.sh
            DESTINATION opt/Opensoft/proof-restarter/${target}
            RENAME run
            PERMISSIONS
            OWNER_READ OWNER_WRITE OWNER_EXECUTE
            GROUP_READ GROUP_EXECUTE
            WORLD_READ WORLD_EXECUTE
        )
        install(DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/debian/supervise
            DESTINATION opt/Opensoft/proof-restarter/${target}
            DIRECTORY_PERMISSIONS
            OWNER_READ OWNER_WRITE OWNER_EXECUTE
            GROUP_READ GROUP_WRITE GROUP_EXECUTE
            WORLD_READ WORLD_WRITE WORLD_EXECUTE
        )
        if(NOT _arg_AUTOSTART)
            install(CODE "file(TOUCH \${CMAKE_INSTALL_PREFIX}/opt/Opensoft/proof-restarter/${target}/down)")
        endif()
    endif()
endfunction()

function(proof_add_station target)
    proof_add_app(${target} ${ARGN} HAS_UI)
endfunction()

function(proof_add_service target)
    proof_add_app(${target} ${ARGN} AUTOSTART)
endfunction()

function(proof_add_app_test target)
    if (PROOF_SKIP_TESTS)
        return()
    endif()
    find_package(proof-gtest CONFIG REQUIRED)

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
        find_package("Proof${PROOF_LIB}" CONFIG REQUIRED)
        set(PROOF_LIBS ${PROOF_LIBS} "Proof::${PROOF_LIB}")
    endforeach()

    if (EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/tests/main.cpp)
        set(sources_copy ${Proof_${target}_SOURCES} "")
        list(FILTER sources_copy INCLUDE REGEX ".*main.cpp$")
        list(LENGTH sources_copy main_found)
        if (main_found EQUAL 0)
            set(Proof_${target}_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/tests/main.cpp ${Proof_${target}_SOURCES})
        endif()
    endif()

    proof_process_target_resources(${target})

    add_executable(${target}
        ${Proof_${target}_SOURCES} ${Proof_${target}_PROCESSED_RESOURCES}
        ${Proof_${target}_PUBLIC_HEADERS}
        ${Proof_${target}_MOC_SOURCES} ${Proof_${target}_MISC}
    )

    proof_set_cxx_target_properties(${target})
    target_link_libraries(${target} ${QT_LIBS} ${PROOF_LIBS} ${_arg_OTHER_LIBS} proof-gtest)

    if ((NOT ANDROID) AND (NOT PROOF_SKIP_CTEST_TARGETS))
        gtest_discover_tests(${target}
            DISCOVERY_TIMEOUT 30
            PROPERTIES TIMEOUT 30
        )
    endif()
endfunction()

function(proof_parse_infusion_arguments prefix)
    cmake_parse_arguments(_arg
        ""
        "PREFIX"
        ""
        ${ARGN}
    )
    if(NOT _arg_PREFIX)
        set(_arg_PREFIX ".")
    endif()
    set(${prefix}_PREFIX ${_arg_PREFIX} PARENT_SCOPE)
endfunction()
