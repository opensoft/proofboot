# This ideally should be done by cmake itself but for some reason breaks at Android platform
macro(proof_qt_init)
    if (DEFINED QT_PATH)
        set(Qt5Core_DIR ${QT_PATH}/lib/cmake/Qt5Core)
        set(Qt5Gui_DIR ${QT_PATH}/lib/cmake/Qt5Gui)
        set(Qt5Network_DIR ${QT_PATH}/lib/cmake/Qt5Network)
        set(Qt5Qml_DIR ${QT_PATH}/lib/cmake/Qt5Qml)
        set(Qt5Quick_DIR ${QT_PATH}/lib/cmake/Qt5Quick)
        set(Qt5QuickCompiler_DIR ${QT_PATH}/lib/cmake/Qt5QuickCompiler)
        set(Qt5Test_DIR ${QT_PATH}/lib/cmake/Qt5Test)
        set(Qt5Xml_DIR ${QT_PATH}/lib/cmake/Qt5Xml)
        set(Qt5AndroidExtras_DIR ${QT_PATH}/lib/cmake/Qt5AndroidExtras)
        set(Qca-qt5_DIR ${QT_PATH}/lib/cmake/Qca-qt5)
    endif()
endmacro()

function(proof_set_cxx_target_properties target)
    set_target_properties(${target} PROPERTIES
        CXX_STANDARD 14
        CXX_STANDARD_REQUIRED ON
        CXX_EXTENSIONS OFF
        POSITION_INDEPENDENT_CODE ON
        AUTOMOC ON
    )
endfunction()

function(proof_add_target_sources target)
    set(Proof_${target}_SOURCES ${Proof_${target}_SOURCES} ${ARGN} PARENT_SCOPE)
endfunction()

function(proof_add_target_headers target)
    set(Proof_${target}_PUBLIC_HEADERS ${Proof_${target}_PUBLIC_HEADERS} ${ARGN} PARENT_SCOPE)
endfunction()

function(proof_add_target_resources target)
    if(Qt5Core_VERSION VERSION_GREATER "5.11")
        find_package(Qt5QuickCompiler CONFIG REQUIRED)
        qtquick_compiler_add_resources(Proof_${target}_RESOURCES ${ARGN})
    else()
        qt5_add_resources(Proof_${target}_RESOURCES ${ARGN})
    endif()
    set(Proof_${target}_RESOURCES ${Proof_${target}_RESOURCES} PARENT_SCOPE)
endfunction()

function(proof_force_moc target)
    qt5_wrap_cpp(Proof_${target}_MOC_SOURCES ${ARGN})
    set(Proof_${target}_MOC_SOURCES ${Proof_${target}_MOC_SOURCES} PARENT_SCOPE)
endfunction()
