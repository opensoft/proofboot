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

    if (ANDROID)
        add_library(${target} SHARED
            ${Proof_${target}_SOURCES} ${Proof_${target}_RESOURCES}
            ${Proof_${target}_PUBLIC_HEADERS}
            ${Proof_${target}_MOC_SOURCES}
        )
    else()
        add_executable(${target}
            ${Proof_${target}_SOURCES} ${Proof_${target}_RESOURCES}
            ${Proof_${target}_PUBLIC_HEADERS}
            ${Proof_${target}_MOC_SOURCES}
        )
    endif()
    proof_set_cxx_target_properties(${target})
    target_link_libraries(${target} ${QT_LIBS} ${PROOF_LIBS} ${_arg_OTHER_LIBS})

    if (${CMAKE_SYSTEM_NAME} STREQUAL "Linux")
        set_target_properties(${target} PROPERTIES
            OUTPUT_NAME "${target}-bin"
        )
        install(TARGETS ${target}
            RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}/opt/Opensoft/${target}/bin"
        )
        set(WRAPPER_TEXT "#!/bin/bash
export LD_LIBRARY_PATH=/opt/Opensoft/${target}/lib:/opt/Opensoft/Qt/lib:$LD_LIBRARY_PATH
exec /opt/Opensoft/${target}/bin/${target}-bin $1 $2 $3 $4 $5 $6 $7 $8 $9")
        if(_arg_HAS_UI)
            set(RESTARTER_TEXT "#!/bin/bash
DISPLAY=:0.0 exec /opt/Opensoft/${target}/bin/${target}")
        else()
            set(RESTARTER_TEXT "#!/bin/bash
exec /opt/Opensoft/${target}/bin/${target}")
        endif()
        file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/wrapper.sh "${WRAPPER_TEXT}")
        file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/restarter.sh "${RESTARTER_TEXT}")
        install(FILES ${CMAKE_CURRENT_BINARY_DIR}/wrapper.sh
            DESTINATION opt/Opensoft/${target}/bin
            RENAME ${target}
            PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE
        )
        install(FILES ${CMAKE_CURRENT_BINARY_DIR}/restarter.sh
            DESTINATION opt/Opensoft/proof-restarter/${target}
            RENAME run
            PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE
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
