# Exports Sopt so other packages can access it
export(TARGETS sopt FILE "${PROJECT_BINARY_DIR}/SoptCPPTargets.cmake")

# Avoids creating an entry in the cmake registry.
if(NOT NOEXPORT)
    export(PACKAGE Sopt)
endif()

# First in binary dir
set(ALL_INCLUDE_DIRS "${PROJECT_SOURCE_DIR}/cpp" "${PROJECT_BINARY_DIR}/include")
configure_File(cmake_files/SoptConfig.in.cmake
    "${PROJECT_BINARY_DIR}/SoptConfig.cmake" @ONLY
)
configure_File(cmake_files/SoptConfigVersion.in.cmake
    "${PROJECT_BINARY_DIR}/SoptConfigVersion.cmake" @ONLY
)

# Then for installation tree
file(RELATIVE_PATH REL_INCLUDE_DIR
    "${CMAKE_INSTALL_PREFIX}/share/cmake/sopt"
    "${CMAKE_INSTALL_PREFIX}/include"
)
set(ALL_INCLUDE_DIRS "\${Sopt_CMAKE_DIR}/${REL_INCLUDE_DIR}")
configure_file(cmake_files/SoptConfig.in.cmake
    "${PROJECT_BINARY_DIR}/CMakeFiles/SoptConfig.cmake" @ONLY
)

# Finally install all files
install(FILES
    "${PROJECT_BINARY_DIR}/CMakeFiles/SoptConfig.cmake"
    "${PROJECT_BINARY_DIR}/SoptConfigVersion.cmake"
    DESTINATION share/cmake/sopt
    COMPONENT dev
)

install(EXPORT SoptCPPTargets DESTINATION share/cmake/sopt COMPONENT dev)
