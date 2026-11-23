; 眼動鼠貪吃蛇 Windows 安裝程式（Inno Setup 6）
; 用法：ISCC /DAppVersion=1.0.0 installer.iss
; 安裝到使用者資料夾，不需系統管理員權限；程式內更新會用 /SILENT 覆蓋安裝並自動重開。

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
#define AppName "眼動鼠貪吃蛇"
#define AppExe "EyeMouseSnake.exe"

[Setup]
AppId={{D18FC1DC-D0E2-4626-8C96-56D301F48FB6}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=吳玉柱 先生 與 Claude AI Opus 5.5
AppPublisherURL=https://achir1015.github.io/eyemouse-snake/
AppSupportURL=https://github.com/achir1015/eyemouse-snake
AppUpdatesURL=https://github.com/achir1015/eyemouse-snake/releases
DefaultDirName={localappdata}\Programs\EyeMouseSnake
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=..\..\..\build\release
OutputBaseFilename=EyeMouseSnake-Setup
SetupIconFile=..\icon.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no
VersionInfoVersion={#AppVersion}.0
VersionInfoProductName={#AppName}
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "cht"; MessagesFile: "ChineseTraditional.isl"

[Tasks]
Name: "desktopicon"; Description: "建立桌面捷徑"; GroupDescription: "其他工作："

[Files]
Source: "..\..\..\build\windows\{#AppExe}"; DestDir: "{app}"; Flags: ignoreversion
; 內建網路攝影機眼動追蹤小程式（遊戲自動啟動、關閉遊戲就結束）
Source: "..\..\..\build\eyecam\EyeCam\*"; DestDir: "{app}\eyecam"; Flags: ignoreversion recursesubdirs createallsubdirs

[InstallDelete]
Type: filesandordirs; Name: "{app}\eyecam\_internal"

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{group}\解除安裝 {#AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[UninstallRun]
Filename: "{sys}\taskkill.exe"; Parameters: "/F /IM EyeCam.exe"; Flags: runhidden; RunOnceId: "KillEyeCam"

[Run]
; 不加 skipifsilent：程式內更新（/SILENT）完成後也會自動重新開啟
Filename: "{app}\{#AppExe}"; Description: "立即開啟眼動鼠貪吃蛇"; Flags: nowait postinstall
