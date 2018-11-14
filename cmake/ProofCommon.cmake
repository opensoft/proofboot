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
