cmake_minimum_required(VERSION 3.16)
project(piholemanager NONE)

# Pure-QML app: nothing to compile, just install files into the click package.
# Clickable fills in @CLICK_ARCH@, @CLICK_FRAMEWORK@ and @APPARMOR_POLICY@
# in manifest.json / the .apparmor file, so they are installed verbatim.
set(CMAKE_INSTALL_PREFIX "/")

install(FILES manifest.json.in DESTINATION . RENAME manifest.json)
install(FILES piholemanager.apparmor piholemanager.desktop DESTINATION .)
install(DIRECTORY qml DESTINATION .)
install(DIRECTORY assets DESTINATION .)
