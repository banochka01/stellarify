Unicode true
!include "MUI2.nsh"
!include "x64.nsh"

!ifndef APP_VERSION
  !define APP_VERSION "1.3.0"
!endif
!ifndef BUILD_DIR
  !define BUILD_DIR "..\..\build\windows\x64\runner\Release"
!endif
!ifndef OUTPUT_DIR
  !define OUTPUT_DIR "..\..\..\artifacts\resonance-1.3.0"
!endif

Name "Resonance"
OutFile "${OUTPUT_DIR}\Resonance-Setup-${APP_VERSION}-x64.exe"
InstallDir "$LOCALAPPDATA\Programs\Resonance"
InstallDirRegKey HKCU "Software\WebCord\Resonance" "InstallLocation"
RequestExecutionLevel user
SetCompressor /SOLID lzma
Icon "..\runner\resources\app_icon.ico"
UninstallIcon "..\runner\resources\app_icon.ico"
VIProductVersion "${APP_VERSION}.0"
VIAddVersionKey /LANG=1049 "ProductName" "Resonance"
VIAddVersionKey /LANG=1049 "CompanyName" "WebCord"
VIAddVersionKey /LANG=1049 "LegalCopyright" "Copyright 2026 WebCord"
VIAddVersionKey /LANG=1049 "FileDescription" "Resonance music player installer"
VIAddVersionKey /LANG=1049 "FileVersion" "${APP_VERSION}"
VIAddVersionKey /LANG=1049 "ProductVersion" "${APP_VERSION}"

!define MUI_ABORTWARNING
!define MUI_ICON "..\runner\resources\app_icon.ico"
!define MUI_UNICON "..\runner\resources\app_icon.ico"
!define MUI_FINISHPAGE_RUN "$INSTDIR\resonance.exe"
!define MUI_FINISHPAGE_RUN_TEXT "Запустить Resonance"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "Russian"
!insertmacro MUI_LANGUAGE "English"

Section "Resonance" CoreSection
  SectionIn RO
  SetShellVarContext current
  SetOutPath "$INSTDIR"
  File /r "${BUILD_DIR}\*"
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  WriteRegStr HKCU "Software\WebCord\Resonance" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Resonance" "DisplayName" "Resonance"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Resonance" "DisplayVersion" "${APP_VERSION}"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Resonance" "Publisher" "WebCord"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Resonance" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Resonance" "DisplayIcon" "$INSTDIR\resonance.exe"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Resonance" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Resonance" "NoModify" 1
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Resonance" "NoRepair" 1
  CreateDirectory "$SMPROGRAMS\Resonance"
  CreateShortcut "$SMPROGRAMS\Resonance\Resonance.lnk" "$INSTDIR\resonance.exe"
  CreateShortcut "$SMPROGRAMS\Resonance\Удалить Resonance.lnk" "$INSTDIR\Uninstall.exe"
SectionEnd

Section /o "Ярлык на рабочем столе" DesktopShortcutSection
  SetShellVarContext current
  CreateShortcut "$DESKTOP\Resonance.lnk" "$INSTDIR\resonance.exe"
SectionEnd

Section "Uninstall"
  SetShellVarContext current
  Delete "$DESKTOP\Resonance.lnk"
  RMDir /r "$SMPROGRAMS\Resonance"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Resonance"
  DeleteRegKey HKCU "Software\WebCord\Resonance"
  RMDir /r "$INSTDIR"
SectionEnd
