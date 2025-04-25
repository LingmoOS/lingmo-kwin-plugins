project (lingdecoration)
set(CMAKE_CXX_STANDARD 11)

set(CMAKE_INCLUDE_CURRENT_DIR ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTORCC ON)

find_package(KF6CoreAddons REQUIRED)
find_package(KF6Config REQUIRED)
find_package(KF6WindowSystem REQUIRED)
find_package(KDecoration2 REQUIRED)
find_package(Qt6 COMPONENTS Gui Widgets Core REQUIRED)

find_package(Qt6 COMPONENTS Core Gui REQUIRED)

set(QT_PLUGINS_DIR "plugins/")

# 输出插件目录路径
message(STATUS "Qt6 plugins directory: ${QT_PLUGINS_DIR}")

set (decoration_SRCS
    decoration.cpp
    x11shadow.cpp
    button.cpp
    resources.qrc
)

add_library (lingdecoration MODULE
    ${decoration_SRCS}
)

target_link_libraries (lingdecoration
    PUBLIC
        Qt6::Core
        Qt6::Gui
        Qt6::Widgets
        KF6::ConfigCore
        KF6::ConfigGui
        KF6::CoreAddons
        KF6::WindowSystem

    PRIVATE
        KDecoration2::KDecoration
)

install (TARGETS lingdecoration
         DESTINATION ${QT_PLUGINS_DIR}/org.kde.kdecoration2)
