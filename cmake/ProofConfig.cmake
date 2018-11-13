# This file shouldn't contain anything except variables or includes
# It is loaded before project() so it does know nothing about platform
set(PROOF_PATH ${CMAKE_CURRENT_LIST_DIR})
list(APPEND CMAKE_PREFIX_PATH "${PROOF_PATH}/lib/cmake")
list(APPEND CMAKE_PREFIX_PATH "${PROOF_PATH}/lib/cmake/3rdparty")
list(APPEND CMAKE_MODULE_PATH "${PROOF_PATH}/lib/cmake/modules")
include(ProofApp)
