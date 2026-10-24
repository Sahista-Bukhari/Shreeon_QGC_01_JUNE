# ============================================================================
# LibEvents - MAVLink Event Handling
# Event logging, health reporting, and arming checks
# ============================================================================

target_sources(${CMAKE_PROJECT_NAME}
    PRIVATE
        EventHandler.cc
        EventHandler.h
        HealthAndArmingCheckReport.cc
        HealthAndArmingCheckReport.h
        logging.cpp
)

target_include_directories(${CMAKE_PROJECT_NAME} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

# ============================================================================
# LibEvents Library Integration
# ============================================================================

CPMAddPackage(
    NAME libevents
    GITHUB_REPOSITORY mavlink/libevents
    # Keep this revision compatible with QGC_MAVLINK_GIT_TAG. Newer libevents
    # revisions require the MAVLink 32-bit system-ID helper API.
    GIT_TAG 840a88ea226d4eb0fd4c391ce860317422756435
    SOURCE_SUBDIR libs/cpp
)

target_link_libraries(${CMAKE_PROJECT_NAME} PRIVATE libevents)
target_include_directories(${CMAKE_PROJECT_NAME} PRIVATE ${libevents_SOURCE_DIR}/libs/cpp)
