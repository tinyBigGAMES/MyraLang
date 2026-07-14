{===============================================================================
  Myra™ - Pascal. Refined.

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://myralang.org

  See LICENSE for license information

 -------------------------------------------------------------------------------

  Myra.Build - Zig/Clang build driver (configuration + target model).

  Drives the bundled Zig/Clang toolchain. This unit models the full target
  triple (arch-os-abi carried as a single raw string), collects build
  configuration (mode, optimize, subsystem, source files, include/library
  paths, link libraries, defines/undefines, copy-DLLs), tracks post-build
  resource metadata (version info, icon), maintains a save/restore state
  stack for nested module builds, and exposes the Zig target-query and
  platform extension derivations used by later build stages.

  Unlike the reference, SetTarget never injects platform -D defines. Platform
  macros come from the compiler for the selected target, not from a define
  list maintained here.

  STAGE 1 of the unit: configuration and the target model only. No zig
  invocation, no file I/O, and no build.zig generation - those arrive in
  later stages that extend this same class.

  Dependencies: StdApp.Base, StdApp.Utils, Myra.Build.Targets
===============================================================================}

unit Myra.Build;

{$I StdApp.Defines.inc}

interface

uses
  WinAPI.Windows,
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.NetEncoding,
  System.Generics.Collections,
  StdApp.Base,
  StdApp.Utils,
  StdApp.Config,
  StdApp.Resources,
  Myra.Common,
  Myra.Build.Targets;

const
  { Error codes }
  JB_ERR_NO_OUTPUT_PATH = 'J0001';
  JB_ERR_NO_SOURCES     = 'J0002';
  JB_ERR_SAVE_FAILED    = 'J0003';
  JB_ERR_ZIG_NOT_FOUND  = 'J0004';
  JB_ERR_BUILD_FAILED   = 'J0005';

  { Warning codes }
  JB_WRN_CANNOT_RUN   = 'J0006';
  JB_WRN_MANIFEST     = 'J0007';
  JB_WRN_ICON         = 'J0008';
  JB_WRN_VERSIONINFO  = 'J0009';
  JB_WRN_WASM         = 'J0010';

  { Build constants }
  RESOLVEPATH_BEHAVIOR  = 1;
  DEFAULT_TOOLCHAIN_PATH = 'res';
  DEFAULT_TARGET        = 'x86_64-windows-gnu';
  DEFAULT_PROJECT_NAME  = 'output';

  { Official target aliases }
  MYR_TARGET_WIN64      = 'win64';
  MYR_TARGET_WINARM64   = 'winarm64';
  MYR_TARGET_LINUX64    = 'linux64';
  MYR_TARGET_LINUXARM64 = 'linuxarm64';
  MYR_TARGET_MACOS64    = 'macos64';
  MYR_TARGET_WASM32     = 'wasm32';

  { Language standard flags }
  // Sources are grouped by extension: .c compiles as C, everything else as
  // C++. Each group is emitted as its own addCSourceFiles block with its own
  // std flag, so C libraries (raylib, ...) and C++23 sources can coexist in
  // one artifact.
  C_STD_FLAG            = '"-std=c23"';
  CPP_STD_FLAG          = '"-std=c++23"';
  C_SOURCE_EXT          = '.c';

type

  { TBuildMode }
  TBuildMode = (
    bmExe,
    bmLib,
    bmDll
  );

  { TOptimizeLevel }
  TOptimizeLevel = (
    olDebug,
    olReleaseSafe,
    olReleaseFast,
    olReleaseSmall
  );

  { TSubsystemType }
  TSubsystemType = (
    stConsole,
    stGUI
  );

  { TBreakpointEntry }
  TBreakpointEntry = record
    FileName: string;
    LineNumber: Integer;
  end;

  { TBuildState }
  // Snapshot of scalar build settings for PushState/PopState. Target is a
  // raw triple string, matching the enhanced string-based target model.
  TBuildState = record
    BuildMode: TBuildMode;
    OptimizeLevel: TOptimizeLevel;
    Target: string;
    Subsystem: TSubsystemType;
    ProjectName: string;
    AddVersionInfo: Boolean;
    VIMajor: Word;
    VIMinor: Word;
    VIPatch: Word;
    VIProductName: string;
    VIDescription: string;
    VIFilename: string;
    VICompanyName: string;
    VICopyright: string;
    ExeIcon: string;
  end;

  { TBuild }
  TBuild = class(TBaseObject)
  private
    FOutputPath: string;
    FProjectName: string;
    FBuildMode: TBuildMode;
    FOptimizeLevel: TOptimizeLevel;
    FTarget: string;
    FSubsystem: TSubsystemType;
    FSourceFiles: TStringList;
    FIncludePaths: TStringList;
    FLibraryPaths: TStringList;
    FLinkLibraries: TStringList;
    FDefines: TStringList;
    FUndefines: TStringList;
    FCopyDLLs: TStringList;
    FOutput: TCallback<TCaptureConsoleCallback>;
    FLastExitCode: DWORD;
    FRawOutput: Boolean;

    // Toolchain path + persisted build config (build.toml)
    FToolchainPath: string;
    FBuildConfig: TConfig;
    FBuildConfigPath: string;

    // Version info / post-build resources
    FAddVersionInfo: Boolean;
    FVIMajor: Word;
    FVIMinor: Word;
    FVIPatch: Word;
    FVIProductName: string;
    FVIDescription: string;
    FVIFilename: string;
    FVICompanyName: string;
    FVICopyright: string;
    FExeIcon: string;

    // Breakpoints
    FBreakpoints: TList<TBreakpointEntry>;

    // State stack for save/restore across module imports
    FStateStack: TStack<TBuildState>;

    function FindDefineIndex(const ADefineName: string): Integer;
    function DoSplitTarget(const ATarget: string; out AArch: string;
      out AOS: string; out AAbi: string): Boolean;

    // Publishes the current target as a Myra define: TARGET_WIN64,
    // TARGET_LINUX64, and so on -- one per curated alias, exactly one live at
    // a time.
    //
    // This is what makes `@ifdef TARGET_WIN64` work. The lexer
    // (TMyrGenericLexer) resolves @ifdef against THIS object's define table via
    // HasDefine, at LEX time -- long before zig is invoked. That timing is the
    // whole point: build configuration (@librarypath, @copydll, @linklibrary)
    // has to be chosen per target while the build is still being assembled. A
    // C++ #ifdef cannot do this job, because clang does not run until the build
    // config is already frozen.
    //
    // Must be called from every path that changes FTarget.
    procedure DoApplyTargetDefines();

    // True when wsl.exe is present on this host. Running a Linux target from
    // Windows goes through WSL; without it, the run is skipped with a warning
    // rather than failing the build.
    function DoWslInstalled(): Boolean;

    // build.zig generation helpers (decomposition of GenerateBuildZig)
    function MakeRelativePath(const ABasePath: string;
      const ATargetPath: string): string;
    function IsCSource(const ASourceFile: string): Boolean;
    procedure DoZigHeader(const ABuilder: TStringBuilder);
    procedure DoZigArtifact(const ABuilder: TStringBuilder;
      out AArtifactVar: string);
    procedure DoZigSourceGroup(const ABuilder: TStringBuilder;
      const AArtifactVar: string; const AFiles: TStringList;
      const AFlagsStr: string);
    procedure DoZigSources(const ABuilder: TStringBuilder;
      const AArtifactVar: string);

    // Diagnostics + post-build helpers
    function FilterOutputBuffer(const ABuffer: string): string;
    procedure HandleOutputLine(const ALine: string; const AUserData: Pointer);
    procedure ApplyPostBuildResources(const AExePath: string);

  public
    constructor Create(); override;
    destructor Destroy(); override;

    // Configuration
    procedure SetOutputPath(const APath: string);
    procedure SetProjectName(const AProjectName: string);
    procedure SetBuildMode(const ABuildMode: TBuildMode);
    procedure SetOptimizeLevel(const AOptimizeLevel: TOptimizeLevel);
    procedure SetSubsystem(const ASubsystem: TSubsystemType);
    procedure SetOutputCallback(const ACallback: TCaptureConsoleCallback;
      const AUserData: Pointer = nil);
    procedure SetRawOutput(const AValue: Boolean);

    // Target model (raw triple string; no define injection)
    function SetTargetAlias(const ATarget: string): Boolean;
    procedure SetTarget(const ATarget: string); overload;
    procedure SetTarget(const AArch: string; const AOS: string;
      const AAbi: string = ''); overload;
    function GetTarget(): string;

    // The OS component of the current target triple, e.g. 'windows'.
    // Compare against the OS_* constants in Myra.Build.Targets. Falls back to
    // DEFAULT_TARGET's OS when the triple is malformed, matching the fallback
    // used throughout this unit.
    function GetTargetOS(): string;

    // The arch component of the current target triple, e.g. 'x86_64'.
    // Compare against the ARCH_* constants in Myra.Build.Targets.
    function GetTargetArch(): string;

    // False when the target's toolchain cannot provide C++ exception handling.
    //
    // WebAssembly is the case that matters: Zig has no implementation for
    // __cxa_throw / __cxa_allocate_exception, so any C++ source compiled with
    // -fexceptions fails at link. Such targets must be built -fno-exceptions.
    // This is a hard property of the toolchain, not a user preference.
    function TargetSupportsExceptions(): Boolean;

    // True when the built artifact can be launched on THIS (Windows x64) host.
    //
    // Only two targets qualify:
    //   x86_64-windows-*  runs natively
    //   x86_64-linux-*    runs through WSL (which must be installed)
    //
    // Everything else is a cross-compile: a winarm64 PE or a linuxarm64 ELF
    // cannot execute on an x64 host, and macOS/wasm artifacts need a different
    // machine or runtime entirely. Checking the OS alone is not enough -- the
    // ARCH must match the host too.
    function CanAutoRun(): Boolean;

    // True when the target is a WebAssembly arch. Wasm has no native execution
    // path: it runs in a browser through the emitted self-contained HTML.
    function DoIsWasmTarget(): Boolean;

    // Emits <project>.html beside <project>.wasm, with the module bytes and the
    // WASI shim both inlined so the file runs by double-click, without a server.
    procedure DoWriteWasmShim();

    // Hands the emitted HTML to the default browser. Fire-and-forget: there is
    // no process, so no exit code can be captured.
    function DoRunWasmHtml(): Boolean;

    function DoZigTargetQuery(): string;

    // Source files
    procedure AddSourceFile(const ASourceFile: string);
    procedure RemoveSourceFile(const ASourceFile: string);
    procedure ClearSourceFiles();

    // Include paths
    procedure AddIncludePath(const APath: string);
    procedure RemoveIncludePath(const APath: string);
    procedure ClearIncludePaths();

    // Library paths
    procedure AddLibraryPath(const APath: string);
    procedure RemoveLibraryPath(const APath: string);
    procedure ClearLibraryPaths();

    // Link libraries
    procedure AddLinkLibrary(const ALibrary: string);
    procedure RemoveLinkLibrary(const ALibrary: string);
    procedure ClearLinkLibraries();

    // Defines (-DNAME or -DNAME=VALUE)
    procedure SetDefine(const ADefineName: string); overload;
    procedure SetDefine(const ADefineName: string; const AValue: string); overload;
    procedure RemoveDefine(const ADefineName: string);
    procedure ClearDefines();
    function HasDefine(const ADefineName: string): Boolean;
    function GetDefines(): TStringList;

    // Undefines (-UNAME)
    procedure UnsetDefine(const ADefineName: string);
    procedure RemoveUndefine(const ADefineName: string);
    procedure ClearUndefines();
    function HasUndefine(const ADefineName: string): Boolean;
    function GetUndefines(): TStringList;

    // Copy DLLs (copied to exe output directory after build)
    procedure AddCopyDLL(const ADLLPath: string);
    procedure RemoveCopyDLL(const ADLLPath: string);
    procedure ClearCopyDLLs();

    // Clear all
    procedure Clear();

    // State stack (save/restore scalar settings across module imports)
    procedure PushState();
    procedure PopState();

    // Actions
    function LoadBuildFile(const AFilename: string): Boolean;
    function SaveBuildFile(): Boolean;
    function Process(const AAutoRun: Boolean = True): Boolean;
    function Run(): Boolean;
    function ClearCache(): Boolean;
    function ClearOutput(): Boolean;

    // Getters
    function GetLastExitCode(): DWORD;
    function GetOutputPath(): string;
    function GetProjectName(): string;
    function GetBuildMode(): TBuildMode;
    function GetOptimizeLevel(): TOptimizeLevel;
    function GetSubsystem(): TSubsystemType;
    function GetSourceFileCount(): Integer;
    function GetSourceFile(const AIndex: Integer): string;

    // Platform extension helpers (derived from the target triple)
    function GetExeExtension(): string;
    function GetDllExtension(): string;
    function GetLibExtension(): string;
    function GetOutputFilename(): string;

    // Display names
    function GetTargetDisplayName(): string;
    function GetOptimizeLevelDisplayName(): string;
    function GetSubsystemDisplayName(): string;

    // build.zig generation
    function GetZigOptimizeString(): string;
    function BuildFlagsString(const AStdFlag: string): string;
    function GenerateBuildZig(): string;
    procedure ParseFlagsLine(const ALine: string);

    // Version info / post-build resources
    procedure SetAddVersionInfo(const AValue: Boolean);
    function GetAddVersionInfo(): Boolean;
    procedure SetVIMajor(const AValue: Word);
    function GetVIMajor(): Word;
    procedure SetVIMinor(const AValue: Word);
    function GetVIMinor(): Word;
    procedure SetVIPatch(const AValue: Word);
    function GetVIPatch(): Word;
    procedure SetVIProductName(const AValue: string);
    function GetVIProductName(): string;
    procedure SetVIDescription(const AValue: string);
    function GetVIDescription(): string;
    procedure SetVIFilename(const AValue: string);
    function GetVIFilename(): string;
    procedure SetVICompanyName(const AValue: string);
    function GetVICompanyName(): string;
    procedure SetVICopyright(const AValue: string);
    function GetVICopyright(): string;
    procedure SetExeIcon(const AValue: string);
    function GetExeIcon(): string;

    // Breakpoints
    procedure AddBreakpoint(const AFileName: string; const ALineNumber: Integer);
    procedure ClearBreakpoints();
    function GetBreakpoints(): TArray<TBreakpointEntry>;
    procedure WriteBreakpointsFile(const AExePath: string);

    // Toolchain paths
    procedure SetToolchainPath(const APath: string);
    function GetToolchainPath(): string;
    function GetZigPath(const AFilename: string = ''): string;
    function GetRuntimePath(const AFilename: string = ''): string;
    function GetLibsPath(const AFilename: string = ''): string;
    function GetAssetsPath(const AFilename: string = ''): string;
    function GetWasmPath(const AFilename: string = ''): string;
    function GetWasmHtmlFilename(): string;

    // Centralized path resolution
    function ResolvePath(const AFilename: string;
      const ARelativePath: string;
      const ABasePath: string = '';
      const ABehavior: Integer = RESOLVEPATH_BEHAVIOR): string;
  end;

implementation

{ TBuild }

constructor TBuild.Create();
begin
  inherited;

  FOutputPath := '';
  FProjectName := DEFAULT_PROJECT_NAME;
  FBuildMode := bmExe;
  FOptimizeLevel := olDebug;
  FSubsystem := stConsole;
  FSourceFiles := TStringList.Create();
  FIncludePaths := TStringList.Create();
  FLibraryPaths := TStringList.Create();
  FLinkLibraries := TStringList.Create();
  FDefines := TStringList.Create();
  FUndefines := TStringList.Create();
  FCopyDLLs := TStringList.Create();
  FLastExitCode := 0;
  FRawOutput := False;

  // Default target triple. Routed through SetTarget so the matching TARGET_*
  // define is published from the outset -- a build that never calls SetTarget
  // explicitly still gets TARGET_WIN64, and @ifdef sees it.
  SetTarget(DEFAULT_TARGET);

  // Version info defaults
  FAddVersionInfo := False;
  FVIMajor := 0;
  FVIMinor := 0;
  FVIPatch := 0;
  FVIProductName := '';
  FVIDescription := '';
  FVIFilename := '';
  FVICompanyName := '';
  FVICopyright := '';
  FExeIcon := '';

  // Breakpoints + state stack
  FBreakpoints := TList<TBreakpointEntry>.Create();
  FStateStack := TStack<TBuildState>.Create();

  // Toolchain config: load build.toml next to the executable if present
  FBuildConfig := TConfig.Create();
  FBuildConfig.SetErrors(FErrors);
  FBuildConfigPath := TPath.Combine(
    TPath.GetDirectoryName(ParamStr(0)), 'build.toml');
  FToolchainPath := DEFAULT_TOOLCHAIN_PATH;
  if TFile.Exists(FBuildConfigPath) then
  begin
    FBuildConfig.LoadFromFile(FBuildConfigPath);
    FToolchainPath := FBuildConfig.GetString('build.toolchain_path',
      DEFAULT_TOOLCHAIN_PATH);
  end;

  // Resolve the toolchain path: empty means the executable's own directory
  if FToolchainPath = '' then
    FToolchainPath := TPath.GetDirectoryName(ParamStr(0))
  else
  begin
    if not TPath.IsPathRooted(FToolchainPath) then
      FToolchainPath := TPath.Combine(
        TPath.GetDirectoryName(ParamStr(0)), FToolchainPath);
    // Normalize (resolve any '..' segments)
    FToolchainPath := TPath.GetFullPath(FToolchainPath);
  end;
end;

destructor TBuild.Destroy();
begin
  // Persist the toolchain path back to build.toml, then release the config
  if Assigned(FBuildConfig) then
  begin
    FBuildConfig.SetString('build.toolchain_path', FToolchainPath);
    FBuildConfig.SaveToFile(FBuildConfigPath);
  end;
  FreeAndNil(FBuildConfig);

  FreeAndNil(FStateStack);
  FreeAndNil(FBreakpoints);
  FreeAndNil(FCopyDLLs);
  FreeAndNil(FUndefines);
  FreeAndNil(FDefines);
  FreeAndNil(FLinkLibraries);
  FreeAndNil(FLibraryPaths);
  FreeAndNil(FIncludePaths);
  FreeAndNil(FSourceFiles);

  inherited;
end;

// Configuration

procedure TBuild.SetOutputPath(const APath: string);
begin
  FOutputPath := APath;
end;

procedure TBuild.SetProjectName(const AProjectName: string);
begin
  FProjectName := AProjectName;
end;

procedure TBuild.SetBuildMode(const ABuildMode: TBuildMode);
begin
  FBuildMode := ABuildMode;
end;

procedure TBuild.SetOptimizeLevel(const AOptimizeLevel: TOptimizeLevel);
begin
  FOptimizeLevel := AOptimizeLevel;
end;

procedure TBuild.SetSubsystem(const ASubsystem: TSubsystemType);
begin
  FSubsystem := ASubsystem;
end;

procedure TBuild.SetOutputCallback(const ACallback: TCaptureConsoleCallback;
  const AUserData: Pointer);
begin
  FOutput.Callback := ACallback;
  FOutput.UserData := AUserData;
end;

procedure TBuild.SetRawOutput(const AValue: Boolean);
begin
  FRawOutput := AValue;
end;

// Target model

type
  { TTargetAlias }
  // One row of the curated alias vocabulary.
  TTargetAlias = record
    Alias:  string;
    Triple: string;
  end;

const
  { MYR_TARGET_ALIASES }
  // HAND-CURATED, not derived. Every entry has been verified to compile and
  // link C++23 from a Windows host with the bundled toolchain. This
  // deliberately does NOT expose the full arch/os/abi space: most of the tag
  // combinations Zig accepts are not actually buildable (windows+msvc collides
  // libc++ with MSVC's vcruntime; wasm64 and emscripten have no libc).
  // Flexibility that cannot build is worse than a short honest list.
  MYR_TARGET_ALIASES: array[0..5] of TTargetAlias = (
    (Alias: MYR_TARGET_WIN64;      Triple: 'x86_64-windows-gnu'),
    (Alias: MYR_TARGET_WINARM64;   Triple: 'aarch64-windows-gnu'),
    (Alias: MYR_TARGET_LINUX64;    Triple: 'x86_64-linux-gnu'),
    (Alias: MYR_TARGET_LINUXARM64; Triple: 'aarch64-linux-gnu'),
    (Alias: MYR_TARGET_MACOS64;    Triple: 'aarch64-macos-none'),
    (Alias: MYR_TARGET_WASM32;     Triple: 'wasm32-wasi')
  );

// Resolve a curated alias to a full Zig triple and set it as the build target.
//
// A name containing '-' is treated as a raw triple and passed through
// untouched. That is an undocumented escape hatch, not a supported surface --
// you are on your own out there.
//
// Returns False when the name is neither a known alias nor a raw triple. The
// caller owns the diagnostic: it has the source location, this does not.
function TBuild.SetTargetAlias(const ATarget: string): Boolean;
var
  LI: Integer;
begin
  for LI := Low(MYR_TARGET_ALIASES) to High(MYR_TARGET_ALIASES) do
  begin
    if ATarget = MYR_TARGET_ALIASES[LI].Alias then
    begin
      SetTarget(MYR_TARGET_ALIASES[LI].Triple);
      Exit(True);
    end;
  end;

  // Undocumented: anything shaped like a triple goes straight to Zig.
  if ATarget.Contains('-') then
  begin
    SetTarget(ATarget);
    Exit(True);
  end;

  Result := False;
end;

procedure TBuild.DoApplyTargetDefines();
var
  LI: Integer;
begin
  // Retract the whole vocabulary first. SetTarget can be called repeatedly in
  // one process -- the tester walks every target in a single run -- and a stale
  // TARGET_* left behind would satisfy BOTH arms of an @ifdef/@elseif chain.
  for LI := Low(MYR_TARGET_ALIASES) to High(MYR_TARGET_ALIASES) do
    RemoveDefine('TARGET_' + UpperCase(MYR_TARGET_ALIASES[LI].Alias));

  // Publish exactly the one that matches. A raw triple with no curated alias
  // gets NO define, which is the honest answer: there is no name to condition
  // on, so every @ifdef TARGET_* correctly evaluates false.
  for LI := Low(MYR_TARGET_ALIASES) to High(MYR_TARGET_ALIASES) do
  begin
    if SameText(FTarget, MYR_TARGET_ALIASES[LI].Triple) then
    begin
      SetDefine('TARGET_' + UpperCase(MYR_TARGET_ALIASES[LI].Alias));
      Break;
    end;
  end;
end;

procedure TBuild.SetTarget(const ATarget: string);
begin
  FTarget := ATarget;
  DoApplyTargetDefines();
end;

procedure TBuild.SetTarget(const AArch: string; const AOS: string;
  const AAbi: string);
var
  LTarget: string;
begin
  LTarget := AArch + '-' + AOS;
  if AAbi <> '' then
    LTarget := LTarget + '-' + AAbi;
  FTarget := LTarget;
  DoApplyTargetDefines();
end;

function TBuild.GetTarget(): string;
begin
  Result := FTarget;
end;

function TBuild.GetTargetOS(): string;
var
  LArch: string;
  LOS: string;
  LAbi: string;
begin
  // A malformed triple falls back to the default target's OS, consistent with
  // every other DoSplitTarget call site in this unit.
  if not DoSplitTarget(FTarget, LArch, LOS, LAbi) then
    DoSplitTarget(DEFAULT_TARGET, LArch, LOS, LAbi);
  Result := LOS;
end;

function TBuild.GetTargetArch(): string;
var
  LArch: string;
  LOS: string;
  LAbi: string;
begin
  if not DoSplitTarget(FTarget, LArch, LOS, LAbi) then
    DoSplitTarget(DEFAULT_TARGET, LArch, LOS, LAbi);
  Result := LArch;
end;

function TBuild.TargetSupportsExceptions(): Boolean;
var
  LArch: string;
begin
  // Every WebAssembly arch lacks the libcxxabi throw machinery.
  LArch := GetTargetArch();
  Result := not (SameText(LArch, ARCH_WASM32) or SameText(LArch, ARCH_WASM64));
end;

function TBuild.CanAutoRun(): Boolean;
var
  LArch: string;
  LOS: string;
  LAbi: string;
begin
  if not DoSplitTarget(FTarget, LArch, LOS, LAbi) then
    DoSplitTarget(DEFAULT_TARGET, LArch, LOS, LAbi);

  // wasm32 IS launchable from here. Run() dispatches it to DoRunWasmHtml(),
  // which hands the emitted self-contained <project>.html to the default
  // browser -- no server, no runtime to install. It is as runnable as the two
  // native triples below, so it belongs in this check.
  if DoIsWasmTarget() then
    Exit(True);

  // Beyond wasm, exactly two triples can be launched from this Windows x64
  // host:
  //   x86_64-windows-gnu -- runs natively
  //   x86_64-linux-gnu   -- runs through WSL
  // Every other triple builds fine but cannot be executed here.
  Result := SameText(LArch, ARCH_X86_64) and
            SameText(LAbi, ABI_GNU) and
            (SameText(LOS, OS_WINDOWS) or SameText(LOS, OS_LINUX));
end;

function TBuild.DoWslInstalled(): Boolean;
var
  LSystemRoot: string;
begin
  // wsl.exe ships in System32 on machines where WSL is enabled.
  LSystemRoot := GetEnvironmentVariable('SystemRoot');
  if LSystemRoot = '' then
    LSystemRoot := 'C:\Windows';
  Result := TFile.Exists(TPath.Combine(LSystemRoot,
    TPath.Combine('System32', 'wsl.exe')));
end;

function TBuild.DoSplitTarget(const ATarget: string; out AArch: string;
  out AOS: string; out AAbi: string): Boolean;
var
  LParts: TArray<string>;
  LI: Integer;
begin
  AArch := '';
  AOS := '';
  AAbi := '';
  Result := False;

  LParts := ATarget.Split(['-']);
  if Length(LParts) < 2 then
    Exit;

  AArch := LParts[0];
  AOS := LParts[1];

  // Third and any further segments together form the ABI, rejoined with '-'
  if Length(LParts) >= 3 then
  begin
    AAbi := LParts[2];
    for LI := 3 to High(LParts) do
      AAbi := AAbi + '-' + LParts[LI];
  end;

  Result := True;
end;

function TBuild.DoZigTargetQuery(): string;
var
  LArch: string;
  LOS: string;
  LAbi: string;
begin
  // Fall back to the default triple if the current target is malformed
  if not DoSplitTarget(FTarget, LArch, LOS, LAbi) then
    DoSplitTarget(DEFAULT_TARGET, LArch, LOS, LAbi);

  Result := '.{ .cpu_arch = .' + LArch + ', .os_tag = .' + LOS;
  if LAbi <> '' then
    Result := Result + ', .abi = .' + LAbi;
  Result := Result + ' }';
end;

// Source files

procedure TBuild.AddSourceFile(const ASourceFile: string);
begin
  if (ASourceFile <> '') and (FSourceFiles.IndexOf(ASourceFile) < 0) then
    FSourceFiles.Add(ASourceFile);
end;

procedure TBuild.RemoveSourceFile(const ASourceFile: string);
var
  LIndex: Integer;
begin
  LIndex := FSourceFiles.IndexOf(ASourceFile);
  if LIndex >= 0 then
    FSourceFiles.Delete(LIndex);
end;

procedure TBuild.ClearSourceFiles();
begin
  FSourceFiles.Clear();
end;

// Include paths

procedure TBuild.AddIncludePath(const APath: string);
begin
  if (APath <> '') and (FIncludePaths.IndexOf(APath) < 0) then
    FIncludePaths.Add(APath);
end;

procedure TBuild.RemoveIncludePath(const APath: string);
var
  LIndex: Integer;
begin
  LIndex := FIncludePaths.IndexOf(APath);
  if LIndex >= 0 then
    FIncludePaths.Delete(LIndex);
end;

procedure TBuild.ClearIncludePaths();
begin
  FIncludePaths.Clear();
end;

// Library paths

procedure TBuild.AddLibraryPath(const APath: string);
begin
  if (APath <> '') and (FLibraryPaths.IndexOf(APath) < 0) then
    FLibraryPaths.Add(APath);
end;

procedure TBuild.RemoveLibraryPath(const APath: string);
var
  LIndex: Integer;
begin
  LIndex := FLibraryPaths.IndexOf(APath);
  if LIndex >= 0 then
    FLibraryPaths.Delete(LIndex);
end;

procedure TBuild.ClearLibraryPaths();
begin
  FLibraryPaths.Clear();
end;

// Link libraries

procedure TBuild.AddLinkLibrary(const ALibrary: string);
begin
  if (ALibrary <> '') and (FLinkLibraries.IndexOf(ALibrary) < 0) then
    FLinkLibraries.Add(ALibrary);
end;

procedure TBuild.RemoveLinkLibrary(const ALibrary: string);
var
  LIndex: Integer;
begin
  LIndex := FLinkLibraries.IndexOf(ALibrary);
  if LIndex >= 0 then
    FLinkLibraries.Delete(LIndex);
end;

procedure TBuild.ClearLinkLibraries();
begin
  FLinkLibraries.Clear();
end;

// Defines

function TBuild.FindDefineIndex(const ADefineName: string): Integer;
var
  LI: Integer;
  LEntry: string;
  LEqualPos: Integer;
  LName: string;
begin
  Result := -1;
  for LI := 0 to FDefines.Count - 1 do
  begin
    LEntry := FDefines[LI];
    LEqualPos := Pos('=', LEntry);
    if LEqualPos > 0 then
      LName := Copy(LEntry, 1, LEqualPos - 1)
    else
      LName := LEntry;

    if SameText(LName, ADefineName) then
    begin
      Result := LI;
      Exit;
    end;
  end;
end;

procedure TBuild.SetDefine(const ADefineName: string);
var
  LIndex: Integer;
begin
  if ADefineName = '' then
    Exit;

  // Update in place if already present, otherwise append
  LIndex := FindDefineIndex(ADefineName);
  if LIndex >= 0 then
    FDefines[LIndex] := ADefineName
  else
    FDefines.Add(ADefineName);
end;

procedure TBuild.SetDefine(const ADefineName: string; const AValue: string);
var
  LIndex: Integer;
  LEntry: string;
begin
  if ADefineName = '' then
    Exit;

  LEntry := ADefineName + '=' + AValue;

  // Update in place if already present, otherwise append
  LIndex := FindDefineIndex(ADefineName);
  if LIndex >= 0 then
    FDefines[LIndex] := LEntry
  else
    FDefines.Add(LEntry);
end;

procedure TBuild.RemoveDefine(const ADefineName: string);
var
  LIndex: Integer;
begin
  LIndex := FindDefineIndex(ADefineName);
  if LIndex >= 0 then
    FDefines.Delete(LIndex);
end;

procedure TBuild.ClearDefines();
begin
  FDefines.Clear();
end;

function TBuild.HasDefine(const ADefineName: string): Boolean;
begin
  Result := FindDefineIndex(ADefineName) >= 0;
end;

function TBuild.GetDefines(): TStringList;
begin
  Result := FDefines;
end;

// Undefines

procedure TBuild.UnsetDefine(const ADefineName: string);
begin
  if ADefineName = '' then
    Exit;

  if FUndefines.IndexOf(ADefineName) < 0 then
    FUndefines.Add(ADefineName);
end;

procedure TBuild.RemoveUndefine(const ADefineName: string);
var
  LIndex: Integer;
begin
  LIndex := FUndefines.IndexOf(ADefineName);
  if LIndex >= 0 then
    FUndefines.Delete(LIndex);
end;

procedure TBuild.ClearUndefines();
begin
  FUndefines.Clear();
end;

function TBuild.HasUndefine(const ADefineName: string): Boolean;
begin
  Result := FUndefines.IndexOf(ADefineName) >= 0;
end;

function TBuild.GetUndefines(): TStringList;
begin
  Result := FUndefines;
end;

// Copy DLLs

procedure TBuild.AddCopyDLL(const ADLLPath: string);
begin
  if (ADLLPath <> '') and (FCopyDLLs.IndexOf(ADLLPath) < 0) then
    FCopyDLLs.Add(ADLLPath);
end;

procedure TBuild.RemoveCopyDLL(const ADLLPath: string);
var
  LIndex: Integer;
begin
  LIndex := FCopyDLLs.IndexOf(ADLLPath);
  if LIndex >= 0 then
    FCopyDLLs.Delete(LIndex);
end;

procedure TBuild.ClearCopyDLLs();
begin
  FCopyDLLs.Clear();
end;

// Clear all

procedure TBuild.Clear();
begin
  ClearSourceFiles();
  ClearIncludePaths();
  ClearLibraryPaths();
  ClearLinkLibraries();
  ClearDefines();
  ClearUndefines();
  ClearCopyDLLs();
  ClearBreakpoints();
  FProjectName := DEFAULT_PROJECT_NAME;
  FBuildMode := bmExe;
  FOptimizeLevel := olDebug;
  FTarget := DEFAULT_TARGET;
  DoApplyTargetDefines();
  FSubsystem := stConsole;
  FLastExitCode := 0;

  // Reset version info
  FAddVersionInfo := False;
  FVIMajor := 0;
  FVIMinor := 0;
  FVIPatch := 0;
  FVIProductName := '';
  FVIDescription := '';
  FVIFilename := '';
  FVICompanyName := '';
  FVICopyright := '';
  FExeIcon := '';
end;

// State stack

procedure TBuild.PushState();
var
  LState: TBuildState;
begin
  LState.BuildMode := FBuildMode;
  LState.OptimizeLevel := FOptimizeLevel;
  LState.Target := FTarget;
  LState.Subsystem := FSubsystem;
  LState.ProjectName := FProjectName;
  LState.AddVersionInfo := FAddVersionInfo;
  LState.VIMajor := FVIMajor;
  LState.VIMinor := FVIMinor;
  LState.VIPatch := FVIPatch;
  LState.VIProductName := FVIProductName;
  LState.VIDescription := FVIDescription;
  LState.VIFilename := FVIFilename;
  LState.VICompanyName := FVICompanyName;
  LState.VICopyright := FVICopyright;
  LState.ExeIcon := FExeIcon;
  FStateStack.Push(LState);
end;

procedure TBuild.PopState();
var
  LState: TBuildState;
begin
  if FStateStack.Count = 0 then
    Exit;

  LState := FStateStack.Pop();
  FBuildMode := LState.BuildMode;
  FOptimizeLevel := LState.OptimizeLevel;
  FTarget := LState.Target;
  DoApplyTargetDefines();
  FSubsystem := LState.Subsystem;
  FProjectName := LState.ProjectName;
  FAddVersionInfo := LState.AddVersionInfo;
  FVIMajor := LState.VIMajor;
  FVIMinor := LState.VIMinor;
  FVIPatch := LState.VIPatch;
  FVIProductName := LState.VIProductName;
  FVIDescription := LState.VIDescription;
  FVIFilename := LState.VIFilename;
  FVICompanyName := LState.VICompanyName;
  FVICopyright := LState.VICopyright;
  FExeIcon := LState.ExeIcon;
end;

// Getters

function TBuild.GetLastExitCode(): DWORD;
begin
  Result := FLastExitCode;
end;

function TBuild.GetOutputPath(): string;
begin
  Result := FOutputPath;
end;

function TBuild.GetProjectName(): string;
begin
  Result := FProjectName;
end;

function TBuild.GetBuildMode(): TBuildMode;
begin
  Result := FBuildMode;
end;

function TBuild.GetOptimizeLevel(): TOptimizeLevel;
begin
  Result := FOptimizeLevel;
end;

function TBuild.GetSubsystem(): TSubsystemType;
begin
  Result := FSubsystem;
end;

function TBuild.GetSourceFileCount(): Integer;
begin
  Result := FSourceFiles.Count;
end;

function TBuild.GetSourceFile(const AIndex: Integer): string;
begin
  if (AIndex >= 0) and (AIndex < FSourceFiles.Count) then
    Result := FSourceFiles[AIndex]
  else
    Result := '';
end;

// Platform extension helpers

function TBuild.GetExeExtension(): string;
var
  LArch: string;
  LOS: string;
  LAbi: string;
begin
  if not DoSplitTarget(FTarget, LArch, LOS, LAbi) then
    DoSplitTarget(DEFAULT_TARGET, LArch, LOS, LAbi);

  if SameText(LArch, ARCH_WASM32) or SameText(LArch, ARCH_WASM64) then
    Result := '.wasm'
  else if SameText(LOS, OS_WINDOWS) then
    Result := '.exe'
  else if SameText(LOS, OS_UEFI) then
    Result := '.efi'
  else
    Result := '';
end;

function TBuild.GetDllExtension(): string;
var
  LArch: string;
  LOS: string;
  LAbi: string;
begin
  if not DoSplitTarget(FTarget, LArch, LOS, LAbi) then
    DoSplitTarget(DEFAULT_TARGET, LArch, LOS, LAbi);

  if SameText(LOS, OS_WINDOWS) then
    Result := '.dll'
  else if SameText(LOS, OS_MACOS) or SameText(LOS, OS_IOS)
       or SameText(LOS, OS_TVOS) or SameText(LOS, OS_WATCHOS)
       or SameText(LOS, OS_VISIONOS) or SameText(LOS, OS_DRIVERKIT)
       or SameText(LOS, OS_MACCATALYST) then
    Result := '.dylib'
  else if SameText(LArch, ARCH_WASM32) or SameText(LArch, ARCH_WASM64) then
    Result := '.wasm'
  else
    Result := '.so';
end;

function TBuild.GetLibExtension(): string;
var
  LArch: string;
  LOS: string;
  LAbi: string;
begin
  if not DoSplitTarget(FTarget, LArch, LOS, LAbi) then
    DoSplitTarget(DEFAULT_TARGET, LArch, LOS, LAbi);

  if SameText(LOS, OS_WINDOWS) then
    Result := '.lib'
  else
    Result := '.a';
end;

function TBuild.GetOutputFilename(): string;
var
  LExtension: string;
begin
  case FBuildMode of
    bmExe:
      LExtension := GetExeExtension();
    bmLib:
      LExtension := GetLibExtension();
    bmDll:
      LExtension := GetDllExtension();
  else
    LExtension := GetExeExtension();
  end;

  Result := FProjectName + LExtension;
end;

// Display names

function TBuild.GetTargetDisplayName(): string;
begin
  if FTarget = '' then
    Result := 'native'
  else
    Result := FTarget;
end;

function TBuild.GetOptimizeLevelDisplayName(): string;
begin
  case FOptimizeLevel of
    olDebug:
      Result := 'Debug';
    olReleaseSafe:
      Result := 'ReleaseSafe';
    olReleaseFast:
      Result := 'ReleaseFast';
    olReleaseSmall:
      Result := 'ReleaseSmall';
  else
    Result := 'Unknown';
  end;
end;

function TBuild.GetSubsystemDisplayName(): string;
begin
  if FSubsystem = stGUI then
    Result := 'GUI'
  else
    Result := 'Console';
end;

// build.zig generation

function TBuild.GetZigOptimizeString(): string;
begin
  case FOptimizeLevel of
    olDebug:
      Result := '.Debug';
    olReleaseSafe:
      Result := '.ReleaseSafe';
    olReleaseFast:
      Result := '.ReleaseFast';
    olReleaseSmall:
      Result := '.ReleaseSmall';
  else
    Result := '.Debug';
  end;
end;

function TBuild.BuildFlagsString(const AStdFlag: string): string;
var
  LFlags: TStringList;
  LI: Integer;
  LEntry: string;
  LMaxErrors: Integer;
  LIsCpp: Boolean;
begin
  // AStdFlag selects the language for this source group (C_STD_FLAG or
  // CPP_STD_FLAG). C++-only flags are omitted from C groups.
  LIsCpp := not SameText(AStdFlag, C_STD_FLAG);

  LFlags := TStringList.Create();
  try
    // Language standard for this group
    LFlags.Add(AStdFlag);

    // C++-only flags
    if LIsCpp then
    begin
      // Exceptions are a toolchain capability, not a preference. WebAssembly
      // has no __cxa_throw implementation, so requesting -fexceptions there
      // produces an undefined-symbol failure at link time.
      if TargetSupportsExceptions() then
        LFlags.Add('"-fexceptions"')
      else
        LFlags.Add('"-fno-exceptions"');
      LFlags.Add('"-frtti"');
      LFlags.Add('"-fexperimental-library"');
    end;

    // Required for hardware exception handling
    LFlags.Add('"-fno-sanitize=undefined"');
    // Suppress warning about ((a == b)) in if statements
    LFlags.Add('"-Wno-parentheses-equality"');
    // Suppress Zig-injected flags like -fno-rtlib-defaultlib
    LFlags.Add('"-Wno-unused-command-line-argument"');
    LFlags.Add('"-fdeclspec"');
    LFlags.Add('"-fms-extensions"');
    // Required for debugger stack unwinding via [RBP+8]
    LFlags.Add('"-fno-omit-frame-pointer"');

    // Hide symbols by default in DLLs to prevent runtime symbol conflicts
    if FBuildMode = bmDll then
      LFlags.Add('"-fvisibility=hidden"');

    // Add defines (-DNAME or -DNAME=VALUE)
    for LI := 0 to FDefines.Count - 1 do
    begin
      LEntry := FDefines[LI];
      LFlags.Add('"-D' + LEntry + '"');
    end;

    // Add undefines (-UNAME)
    for LI := 0 to FUndefines.Count - 1 do
    begin
      LEntry := FUndefines[LI];
      LFlags.Add('"-U' + LEntry + '"');
    end;

    // Error limit (default to 1); honor the shared error budget when set
    LMaxErrors := 1;
    if (FErrors <> nil) and (FErrors.GetMaxErrors() > 0) then
      LMaxErrors := FErrors.GetMaxErrors();
    LFlags.Add(Format('"-ferror-limit=%d"', [LMaxErrors]));

    // Join into a single comma-separated flag list
    Result := '';
    for LI := 0 to LFlags.Count - 1 do
    begin
      if LI > 0 then
        Result := Result + ', ';
      Result := Result + LFlags[LI];
    end;
  finally
    LFlags.Free();
  end;
end;

function TBuild.MakeRelativePath(const ABasePath: string;
  const ATargetPath: string): string;
var
  LBase: string;
  LTarget: string;
  LBaseParts: TArray<string>;
  LTargetParts: TArray<string>;
  LCommonCount: Integer;
  LIdx: Integer;
  LRelativeParts: TList<string>;
begin
  // Resolve both to absolute, forward-slash paths for a stable comparison
  LBase := TPath.GetFullPath(ABasePath).Replace('\', '/');
  LTarget := TPath.GetFullPath(ATargetPath).Replace('\', '/');

  if SameText(LBase, LTarget) then
    Exit('.');

  LBaseParts := LBase.Split(['/']);
  LTargetParts := LTarget.Split(['/']);

  // Count the shared leading path segments
  LCommonCount := 0;
  while (LCommonCount < Length(LBaseParts)) and
        (LCommonCount < Length(LTargetParts)) and
        SameText(LBaseParts[LCommonCount], LTargetParts[LCommonCount]) do
    Inc(LCommonCount);

  LRelativeParts := TList<string>.Create();
  try
    // One '..' for each remaining base segment, then the target remainder
    for LIdx := LCommonCount to High(LBaseParts) do
      LRelativeParts.Add('..');

    for LIdx := LCommonCount to High(LTargetParts) do
      LRelativeParts.Add(LTargetParts[LIdx]);

    Result := string.Join('/', LRelativeParts.ToArray());
  finally
    LRelativeParts.Free();
  end;
end;

function TBuild.IsCSource(const ASourceFile: string): Boolean;
begin
  // Only a bare .c extension compiles as C. Everything else (.cpp/.cc/.cxx)
  // compiles as C++.
  Result := SameText(TPath.GetExtension(ASourceFile), C_SOURCE_EXT);
end;

procedure TBuild.DoZigHeader(const ABuilder: TStringBuilder);
begin
  ABuilder.AppendLine('const std = @import("std");');
  ABuilder.AppendLine();
  ABuilder.AppendLine('pub fn build(b: *std.Build) void {');

  // Explicit target query derived from the raw triple string
  ABuilder.AppendLine('    const target = b.resolveTargetQuery(' +
    DoZigTargetQuery() + ');');
  ABuilder.AppendLine('    const optimize: std.builtin.OptimizeMode = ' +
    GetZigOptimizeString() + ';');
  ABuilder.AppendLine();
end;

procedure TBuild.DoZigArtifact(const ABuilder: TStringBuilder;
  out AArtifactVar: string);
var
  LLinkage: string;
begin
  // Executable vs library declaration
  if FBuildMode = bmExe then
  begin
    AArtifactVar := 'exe';
    ABuilder.AppendLine('    const exe = b.addExecutable(.{');
  end
  else
  begin
    AArtifactVar := 'lib';
    ABuilder.AppendLine('    const lib = b.addLibrary(.{');
    if FBuildMode = bmLib then
      LLinkage := '.static'
    else
      LLinkage := '.dynamic';
    ABuilder.AppendLine('        .linkage = ' + LLinkage + ',');
  end;

  // Name and root module
  ABuilder.AppendLine('        .name = "' + FProjectName + '",');
  ABuilder.AppendLine('        .root_module = b.createModule(.{');
  ABuilder.AppendLine('            .target = target,');
  ABuilder.AppendLine('            .optimize = optimize,');
  ABuilder.AppendLine('            .link_libc = true,');
  ABuilder.AppendLine('            .link_libcpp = true,');
  ABuilder.AppendLine('        }),');
  ABuilder.AppendLine('    });');

  // GUI subsystem: suppress the console window on Windows (executables only)
  if (FBuildMode = bmExe) and (FSubsystem = stGUI) then
  begin
    ABuilder.AppendLine();
    ABuilder.AppendLine('    // GUI subsystem: no console window');
    ABuilder.AppendLine('    if (target.result.os.tag == .windows) {');
    ABuilder.AppendLine('        exe.subsystem = .windows;');
    ABuilder.AppendLine('    }');
  end;

  ABuilder.AppendLine();
end;

procedure TBuild.DoZigSourceGroup(const ABuilder: TStringBuilder;
  const AArtifactVar: string; const AFiles: TStringList;
  const AFlagsStr: string);
var
  LI: Integer;
  LSourcePath: string;
begin
  if AFiles.Count = 0 then
    Exit;

  ABuilder.AppendLine('    ' + AArtifactVar +
    '.root_module.addCSourceFiles(.{');
  ABuilder.AppendLine('        .files = &.{');

  for LI := 0 to AFiles.Count - 1 do
  begin
    LSourcePath := MakeRelativePath(FOutputPath, AFiles[LI]);
    ABuilder.Append('            "' + LSourcePath + '"');
    if LI < AFiles.Count - 1 then
      ABuilder.AppendLine(',')
    else
      ABuilder.AppendLine();
  end;

  ABuilder.AppendLine('        },');
  ABuilder.AppendLine('        .flags = &.{ ' + AFlagsStr + ' },');
  ABuilder.AppendLine('    });');
end;

procedure TBuild.DoZigSources(const ABuilder: TStringBuilder;
  const AArtifactVar: string);
var
  LI: Integer;
  LArch: string;
  LOS: string;
  LAbi: string;
  LCFiles: TStringList;
  LCppFiles: TStringList;
begin
  // Include paths (relative to the output directory)
  for LI := 0 to FIncludePaths.Count - 1 do
    ABuilder.AppendLine('    ' + AArtifactVar +
      '.root_module.addIncludePath(b.path("' +
      MakeRelativePath(FOutputPath, FIncludePaths[LI]) + '"));');

  // The build's own artifact directories. A Myra module that links against
  // another Myra dll or lib resolves its import library from here. These are
  // always relative to the output directory by construction, so they follow
  // -o automatically and never need MakeRelativePath.
  ABuilder.AppendLine('    ' + AArtifactVar +
    '.root_module.addLibraryPath(b.path("zig-out/lib"));');
  ABuilder.AppendLine('    ' + AArtifactVar +
    '.root_module.addLibraryPath(b.path("zig-out/bin"));');

  // Library paths (relative to the output directory)
  for LI := 0 to FLibraryPaths.Count - 1 do
    ABuilder.AppendLine('    ' + AArtifactVar +
      '.root_module.addLibraryPath(b.path("' +
      MakeRelativePath(FOutputPath, FLibraryPaths[LI]) + '"));');

  // On Linux (executables only), add rpath $ORIGIN so the binary finds .so
  // files in its own directory
  if FBuildMode = bmExe then
  begin
    if not DoSplitTarget(FTarget, LArch, LOS, LAbi) then
      DoSplitTarget(DEFAULT_TARGET, LArch, LOS, LAbi);
    if SameText(LOS, OS_LINUX) then
      ABuilder.AppendLine('    ' + AArtifactVar +
        '.root_module.addRPathSpecial("$ORIGIN");');
  end;

  // Link libraries
  for LI := 0 to FLinkLibraries.Count - 1 do
    ABuilder.AppendLine('    ' + AArtifactVar +
      '.root_module.linkSystemLibrary("' + FLinkLibraries[LI] + '", .{});');

  // Source files, partitioned by language. Each group gets its own
  // addCSourceFiles block with its own std flag, so C libraries and C++23
  // sources can live in one artifact. A project with only .cpp sources emits
  // exactly one C++ group, as before.
  if FSourceFiles.Count > 0 then
  begin
    LCFiles := TStringList.Create();
    try
      LCppFiles := TStringList.Create();
      try
        for LI := 0 to FSourceFiles.Count - 1 do
        begin
          if IsCSource(FSourceFiles[LI]) then
            LCFiles.Add(FSourceFiles[LI])
          else
            LCppFiles.Add(FSourceFiles[LI]);
        end;

        DoZigSourceGroup(ABuilder, AArtifactVar, LCppFiles,
          BuildFlagsString(CPP_STD_FLAG));
        DoZigSourceGroup(ABuilder, AArtifactVar, LCFiles,
          BuildFlagsString(C_STD_FLAG));
      finally
        LCppFiles.Free();
      end;
    finally
      LCFiles.Free();
    end;
  end;

  ABuilder.AppendLine();
  ABuilder.AppendLine('    b.installArtifact(' + AArtifactVar + ');');
end;

function TBuild.GenerateBuildZig(): string;
var
  LBuilder: TStringBuilder;
  LArtifactVar: string;
begin
  LBuilder := TStringBuilder.Create();
  try
    DoZigHeader(LBuilder);
    DoZigArtifact(LBuilder, LArtifactVar);
    DoZigSources(LBuilder, LArtifactVar);

    LBuilder.AppendLine('}');

    Result := LBuilder.ToString();
  finally
    LBuilder.Free();
  end;
end;

procedure TBuild.ParseFlagsLine(const ALine: string);
var
  LStart: Integer;
  LEnd: Integer;
  LFlag: string;
  LDefineName: string;
  LEqualPos: Integer;
begin
  // Parse flags from a line like:
  //   .flags = &.{ "-std=c++23", "-DFOO", "-DBAR=1", "-UBAZ" },
  LStart := 1;
  while LStart <= Length(ALine) do
  begin
    // Find the start of the next quoted flag
    LStart := Pos('"-', ALine, LStart);
    if LStart = 0 then
      Break;

    // Find its closing quote
    LEnd := Pos('"', ALine, LStart + 1);
    if LEnd = 0 then
      Break;

    // Extract the flag text without the surrounding quotes
    LFlag := Copy(ALine, LStart + 1, LEnd - LStart - 1);

    // Reconstruct defines (-D) and undefines (-U); ignore other flags
    if LFlag.StartsWith('-D') then
    begin
      LDefineName := Copy(LFlag, 3, Length(LFlag) - 2);
      // Skip the standard language-version flag
      if not LDefineName.StartsWith('std=') then
      begin
        LEqualPos := Pos('=', LDefineName);
        if LEqualPos > 0 then
          SetDefine(Copy(LDefineName, 1, LEqualPos - 1),
            Copy(LDefineName, LEqualPos + 1, Length(LDefineName)))
        else
          SetDefine(LDefineName);
      end;
    end
    else if LFlag.StartsWith('-U') then
    begin
      LDefineName := Copy(LFlag, 3, Length(LFlag) - 2);
      UnsetDefine(LDefineName);
    end;

    LStart := LEnd + 1;
  end;
end;

// Diagnostics

function TBuild.FilterOutputBuffer(const ABuffer: string): string;
var
  LCleanLine: string;
  LFilePath: string;
  LLineNum: Integer;
  LColNum: Integer;
  LSeverity: string;
  LMessage: string;
  LErrorSeverity: TErrorSeverity;

  function TryParseCompilerMessage(const ALine: string; out AFilePath: string;
    out ALineNum: Integer; out AColNum: Integer; out ASeverity: string;
    out AMessage: string): Boolean;
  var
    LPos1: Integer;
    LPos2: Integer;
    LPos3: Integer;
    LLineStr: string;
    LColStr: string;
    LSevStr: string;
  begin
    Result := False;

    // Pattern: filepath:line:col: severity: message
    // Skip the drive-letter colon on Windows paths (e.g. C:\...)
    if (Length(ALine) > 2) and (ALine[2] = ':') then
      LPos1 := ALine.IndexOf(':', 2)
    else
      LPos1 := ALine.IndexOf(':');

    if LPos1 < 1 then
      Exit;

    LPos2 := ALine.IndexOf(':', LPos1 + 1);
    if LPos2 < 0 then
      Exit;

    LPos3 := ALine.IndexOf(':', LPos2 + 1);
    if LPos3 < 0 then
      Exit;

    LLineStr := ALine.Substring(LPos1 + 1, LPos2 - LPos1 - 1).Trim();
    if not TryStrToInt(LLineStr, ALineNum) then
      Exit;

    LColStr := ALine.Substring(LPos2 + 1, LPos3 - LPos2 - 1).Trim();
    if not TryStrToInt(LColStr, AColNum) then
      Exit;

    AFilePath := ALine.Substring(0, LPos1);

    LSevStr := ALine.Substring(LPos3 + 1).TrimLeft();

    if LSevStr.StartsWith('error:') then
    begin
      ASeverity := 'error';
      AMessage := LSevStr.Substring(6).Trim();
      Result := True;
    end
    else if LSevStr.StartsWith('warning:') then
    begin
      ASeverity := 'warning';
      AMessage := LSevStr.Substring(8).Trim();
      Result := True;
    end
    else if LSevStr.StartsWith('note:') then
    begin
      ASeverity := 'note';
      AMessage := LSevStr.Substring(5).Trim();
      Result := True;
    end;
  end;

begin
  // Strip ANSI codes for parsing only; the original line always passes through
  LCleanLine := TUtils.StripAnsi(ABuffer);

  // If this is a clang error/warning/note line, capture it in FErrors
  if Assigned(FErrors) and TryParseCompilerMessage(LCleanLine, LFilePath,
    LLineNum, LColNum, LSeverity, LMessage) then
  begin
    if LSeverity = 'error' then
      LErrorSeverity := esError
    else if LSeverity = 'warning' then
      LErrorSeverity := esWarning
    else
      LErrorSeverity := esHint;

    FErrors.Add(LFilePath, LLineNum, LColNum, LErrorSeverity,
      JB_ERR_BUILD_FAILED, LMessage.Trim());
  end;

  // Always return the original line unchanged
  Result := ABuffer;
end;

procedure TBuild.HandleOutputLine(const ALine: string;
  const AUserData: Pointer);
var
  LFiltered: string;
begin
  if not FOutput.IsAssigned() then
    Exit;

  if FRawOutput then
  begin
    FOutput.Callback(ALine, FOutput.UserData);
    Exit;
  end;

  LFiltered := FilterOutputBuffer(ALine);
  if LFiltered.Length > 0 then
    FOutput.Callback(LFiltered, FOutput.UserData);
end;

// Persistence

function TBuild.LoadBuildFile(const AFilename: string): Boolean;
var
  LLines: TStringList;
  LLine: string;
  LI: Integer;
  LIdx: Integer;
  LValue: string;
  LSourceName: string;
begin
  Result := False;

  if not TFile.Exists(AFilename) then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, JB_ERR_SAVE_FAILED, RSMyraBuildFileNotFound,
        [AFilename]);
    Exit;
  end;

  // Clear existing data and set the output path from the file location
  Clear();
  FOutputPath := TPath.GetDirectoryName(AFilename);

  LLines := TStringList.Create();
  try
    LLines.Text := TFile.ReadAllText(AFilename);

    for LI := 0 to LLines.Count - 1 do
    begin
      LLine := LLines[LI].Trim();

      // .name = "<projectname>"
      LIdx := LLine.IndexOf('.name = "');
      if LIdx >= 0 then
      begin
        LValue := LLine.Substring(LIdx + 9);
        LIdx := LValue.IndexOf('"');
        if LIdx >= 0 then
          FProjectName := LValue.Substring(0, LIdx);
        Continue;
      end;

      // addExecutable -> bmExe
      if LLine.Contains('addExecutable') then
      begin
        FBuildMode := bmExe;
        Continue;
      end;

      // addLibrary -> bmLib (refined to bmDll by the .linkage line below)
      if LLine.Contains('addLibrary') then
      begin
        FBuildMode := bmLib;
        Continue;
      end;

      // .linkage = .dynamic -> bmDll
      if LLine.Contains('.linkage = .dynamic') then
      begin
        FBuildMode := bmDll;
        Continue;
      end;

      // GUI subsystem
      if LLine.Contains('exe.subsystem = .windows') then
      begin
        FSubsystem := stGUI;
        Continue;
      end;

      // Target platform: reconstruct the raw triple string
      if LLine.Contains('.cpu_arch = .x86_64') and
         LLine.Contains('.os_tag = .windows') then
      begin
        SetTarget(DEFAULT_TARGET);
        Continue;
      end;

      if LLine.Contains('.cpu_arch = .x86_64') and
         LLine.Contains('.os_tag = .linux') then
      begin
        SetTarget('x86_64-linux-gnu');
        Continue;
      end;

      // addIncludePath
      LIdx := LLine.IndexOf('root_module.addIncludePath(b.path("');
      if LIdx >= 0 then
      begin
        LValue := LLine.Substring(LIdx + 35);
        LIdx := LValue.IndexOf('"');
        if LIdx >= 0 then
          FIncludePaths.Add(TPath.Combine(FOutputPath,
            LValue.Substring(0, LIdx)));
        Continue;
      end;

      // addLibraryPath
      LIdx := LLine.IndexOf('root_module.addLibraryPath(b.path("');
      if LIdx >= 0 then
      begin
        LValue := LLine.Substring(LIdx + 35);
        LIdx := LValue.IndexOf('"');
        if LIdx >= 0 then
          FLibraryPaths.Add(TPath.Combine(FOutputPath,
            LValue.Substring(0, LIdx)));
        Continue;
      end;

      // linkSystemLibrary
      LIdx := LLine.IndexOf('root_module.linkSystemLibrary("');
      if LIdx >= 0 then
      begin
        LValue := LLine.Substring(LIdx + 32);
        LIdx := LValue.IndexOf('"');
        if LIdx >= 0 then
          FLinkLibraries.Add(LValue.Substring(0, LIdx));
        Continue;
      end;

      // .flags line -> defines and undefines
      if LLine.Contains('.flags = &.{') then
      begin
        ParseFlagsLine(LLine);
        Continue;
      end;

      // Source files inside .files = &.{ (C and C++ groups alike)
      LIdx := LLine.IndexOf('"');
      if LIdx >= 0 then
      begin
        LValue := LLine.Substring(LIdx + 1);
        LIdx := LValue.IndexOf('"');
        if LIdx >= 0 then
        begin
          LSourceName := LValue.Substring(0, LIdx);
          if LSourceName.Contains('.cpp') or LSourceName.EndsWith(C_SOURCE_EXT,
            True) then
            FSourceFiles.Add(TPath.Combine(FOutputPath, LSourceName));
        end;
      end;
    end;

    Result := not FProjectName.IsEmpty;
  finally
    LLines.Free();
  end;
end;

function TBuild.SaveBuildFile(): Boolean;
var
  LBuildZigPath: string;
  LContent: string;
  LUTF8NoBOM: TEncoding;
begin
  Result := False;

  if FOutputPath = '' then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, JB_ERR_NO_OUTPUT_PATH, RSMyraBuildNoOutputPath);
    Exit;
  end;

  if FSourceFiles.Count = 0 then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, JB_ERR_NO_SOURCES, RSMyraBuildNoSources);
    Exit;
  end;

  // Generate build.zig and ensure the target directory exists
  LBuildZigPath := TPath.Combine(FOutputPath, 'build.zig');
  TUtils.CreateDirInPath(LBuildZigPath);
  LContent := GenerateBuildZig();

  // Write without a BOM - Zig does not accept a BOM in source files
  LUTF8NoBOM := TUTF8Encoding.Create(False);
  try
    try
      TFile.WriteAllText(LBuildZigPath, LContent, LUTF8NoBOM);
      Result := True;
    except
      on E: Exception do
      begin
        if Assigned(FErrors) then
          FErrors.Add(esError, JB_ERR_SAVE_FAILED, RSMyraBuildSaveFailed,
            [E.Message]);
      end;
    end;
  finally
    LUTF8NoBOM.Free();
  end;
end;

// Invocation

function TBuild.Process(const AAutoRun: Boolean): Boolean;
var
  LZigExe: string;
  LI: Integer;
  LSrcPath: string;
  LDestPath: string;
  LDestDir: string;
  LOutputFile: string;
  LArch: string;
  LOS: string;
  LAbi: string;
begin
  Result := False;

  // Status: target, optimize, and (Windows only) subsystem
  Status(RSMyraBuildTargetPlatform, [GetTargetDisplayName()]);
  Status(RSMyraBuildOptimizeLevel, [GetOptimizeLevelDisplayName()]);
  if not DoSplitTarget(FTarget, LArch, LOS, LAbi) then
    DoSplitTarget(DEFAULT_TARGET, LArch, LOS, LAbi);
  if SameText(LOS, OS_WINDOWS) then
    Status(RSMyraBuildSubsystem, [GetSubsystemDisplayName()]);

  // Always save the build file first
  Status(RSMyraBuildSaving);
  if not SaveBuildFile() then
    Exit;

  // Locate the zig executable
  LZigExe := GetZigPath('zig.exe');
  if (LZigExe = '') or (not TFile.Exists(LZigExe)) then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, JB_ERR_ZIG_NOT_FOUND, RSMyraBuildZigNotFound,
        [LZigExe]);
    Exit;
  end;

  // Force colored output from the toolchain
  TUtils.SetEnv('YES_COLOR', '1');
  TUtils.SetEnv('CLICOLOR_FORCE', '1');
  TUtils.SetEnv('TERM', 'xterm-256color');
  TUtils.SetEnv('ZIG_GLOBAL_CACHE_DIR',
    TPath.Combine(GetZigPath(), '.zig-cache'));

  // zig resolves addLibraryPath() EAGERLY at configure time. The generated
  // build.zig always adds zig-out/lib and zig-out/bin as library search paths
  // -- that is what lets one Myra module link against another Myra dll/lib.
  // On a CLEAN tree those dirs do not exist yet (zig creates them as it
  // installs artifacts), so zig warns:
  //   warning: unable to open library directory "zig-out\lib": FileNotFound
  // It only worked before because a previous build had left them behind.
  // Create them up front. Relative to FOutputPath, exactly as the generated
  // addLibraryPath() entries are, so this follows -o.
  TDirectory.CreateDirectory(
    TPath.Combine(FOutputPath, TPath.Combine('zig-out', 'lib')));
  TDirectory.CreateDirectory(
    TPath.Combine(FOutputPath, TPath.Combine('zig-out', 'bin')));

  // Run zig build
  Status(RSMyraBuildBuilding, [FProjectName]);
  TUtils.CaptureZigConsolePTY(
    PChar(LZigExe),
    'build --color auto --summary none --multiline-errors newline --error-style minimal',
    FOutputPath,
    FLastExitCode,
    nil,
    HandleOutputLine
  );

  if FLastExitCode <> 0 then
  begin
    Status(RSMyraBuildFailedWithCode, [FLastExitCode]);
    if Assigned(FErrors) then
      FErrors.Add(esError, JB_ERR_BUILD_FAILED, RSMyraBuildFailed,
        [FLastExitCode]);
    Exit;
  end;

  Status(RSMyraBuildSucceeded);

  // Resolve the built artifact path (lib -> zig-out/lib, else zig-out/bin)
  if FBuildMode = bmLib then
    LOutputFile := TPath.Combine(FOutputPath,
      TPath.Combine('zig-out', TPath.Combine('lib', GetOutputFilename())))
  else
    LOutputFile := TPath.Combine(FOutputPath,
      TPath.Combine('zig-out', TPath.Combine('bin', GetOutputFilename())));
  Status(RSMyraBuildOutput,
    [TUtils.NormalizePath(TPath.GetFullPath(LOutputFile))]);

  // Copy runtime DLLs into the output directory
  if FCopyDLLs.Count > 0 then
  begin
    LDestDir := TPath.Combine(FOutputPath, TPath.Combine('zig-out', 'bin'));
    for LI := 0 to FCopyDLLs.Count - 1 do
    begin
      LSrcPath := ResolvePath('', FCopyDLLs[LI]);

      // Skip if the source already sits in the destination directory
      if SameText(TPath.GetFullPath(TPath.GetDirectoryName(LSrcPath)),
        TPath.GetFullPath(LDestDir)) then
        Continue;

      if TFile.Exists(LSrcPath) then
      begin
        LDestPath := TPath.Combine(LDestDir, TPath.GetFileName(LSrcPath));
        Status(RSMyraBuildCopying, [TPath.GetFileName(LSrcPath)]);
        TFile.Copy(LSrcPath, LDestPath, True);
      end
      else if Assigned(FErrors) then
        FErrors.Add(esWarning, JB_WRN_CANNOT_RUN, RSMyraBuildDllNotFound,
          [LSrcPath]);
    end;
  end;

  // Apply post-build resources (manifest, icon, version info)
  ApplyPostBuildResources(LOutputFile);

  // A wasm module needs a host to run in. Emit the self-contained HTML runner.
  if (FBuildMode = bmExe) and DoIsWasmTarget() then
    DoWriteWasmShim();

  // Write the breakpoints file if any were collected
  WriteBreakpointsFile(LOutputFile);

  if AAutoRun then
    Result := Run()
  else
    Result := True;
end;

function TBuild.Run(): Boolean;
var
  LExePath: string;
  LWslPath: string;
  LArch: string;
  LOS: string;
  LAbi: string;
begin
  Result := False;

  // Only executables can be run
  if FBuildMode <> bmExe then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, JB_ERR_BUILD_FAILED, RSMyraBuildCannotRunLib);
    Exit;
  end;

  // Only x86_64-windows-gnu (native) and x86_64-linux-gnu (WSL) can be
  // launched here. Anything else is a successful build we simply cannot run,
  // so warn and report success -- never an error.
  if not DoSplitTarget(FTarget, LArch, LOS, LAbi) then
    DoSplitTarget(DEFAULT_TARGET, LArch, LOS, LAbi);

  // wasm does not execute natively. It runs in a browser via the emitted HTML.
  if DoIsWasmTarget() then
  begin
    Result := DoRunWasmHtml();
    Exit;
  end;

  if not CanAutoRun() then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esWarning, JB_WRN_CANNOT_RUN, RSMyraBuildCannotRunCross,
        [GetTargetDisplayName()]);
    Result := True;
    Exit;
  end;

  // A Linux artifact needs WSL on the Windows host. Absent WSL it is not
  // runnable here -- again a warning, not a build failure.
  if SameText(LOS, OS_LINUX) and (not DoWslInstalled()) then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esWarning, JB_WRN_CANNOT_RUN, RSMyraBuildWslNotFound,
        [GetTargetDisplayName()]);
    Result := True;
    Exit;
  end;

  // Validate the project name
  if FProjectName = '' then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esError, JB_ERR_NO_OUTPUT_PATH, RSMyraBuildNoProjectName);
    Exit;
  end;

  // Build the executable path
  LExePath := TPath.Combine(FOutputPath,
    TPath.Combine('zig-out', TPath.Combine('bin', GetOutputFilename())));

  if not TFile.Exists(LExePath) then
  begin
    FLastExitCode := 2;
    if Assigned(FErrors) then
      FErrors.Add(esError, JB_ERR_BUILD_FAILED, RSMyraBuildExeNotFound,
        [LExePath]);
    Exit;
  end;

  // Run and capture output
  Status(RSMyraBuildRunning, [GetOutputFilename()]);

  if SameText(LOS, OS_LINUX) then
  begin
    // Convert to a WSL path and mark executable before running
    LWslPath := TUtils.WindowsPathToWSL(LExePath);
    TUtils.CaptureZigConsolePTY('wsl.exe',
      PChar('chmod +x "' + LWslPath + '"'),
      TPath.GetDirectoryName(LExePath), FLastExitCode, nil, nil);
    TUtils.CaptureZigConsolePTY(
      'wsl.exe',
      PChar('"' + LWslPath + '"'),
      TPath.GetDirectoryName(LExePath),
      FLastExitCode,
      nil,
      HandleOutputLine
    );
  end
  else
  begin
    TUtils.CaptureZigConsolePTY(
      PChar(LExePath),
      '',
      TPath.GetDirectoryName(LExePath),
      FLastExitCode,
      nil,
      HandleOutputLine
    );
  end;

  // A non-zero exit code from the PROGRAM is NOT a build error. The build
  // succeeded, the exe exists, it launched, and it ran to completion -- it
  // simply returned a value. Whether that value is acceptable is the CALLER's
  // judgement: a unit-test runner that reports failing tests is SUPPOSED to
  // exit non-zero. The code is available via GetLastExitCode().
  //
  // Contrast the two sites above, which ARE genuine build errors: `zig build`
  // itself failing, and the exe not existing after a successful build.

  Result := True;
end;

function TBuild.ClearCache(): Boolean;
var
  LCachePath: string;
begin
  Result := True;
  LCachePath := TPath.Combine(FOutputPath, '.zig-cache');
  if TDirectory.Exists(LCachePath) then
    TDirectory.Delete(LCachePath, True);
end;

function TBuild.ClearOutput(): Boolean;
var
  LOutputDir: string;
begin
  Result := True;
  LOutputDir := TPath.Combine(FOutputPath, 'zig-out');
  if TDirectory.Exists(LOutputDir) then
    TDirectory.Delete(LOutputDir, True);
end;

// Post-build resources

procedure TBuild.ApplyPostBuildResources(const AExePath: string);
var
  LIsExe: Boolean;
  LIsDll: Boolean;
begin
  LIsExe := AExePath.EndsWith('.exe', True);
  LIsDll := AExePath.EndsWith('.dll', True);
  if not LIsExe and not LIsDll then
    Exit;

  // Manifest (executables only)
  if LIsExe then
  begin
    if TUtils.ResourceExist('EXE_MANIFEST') then
      if not TUtils.AddResManifestFromResource('EXE_MANIFEST', AExePath) then
        if Assigned(FErrors) then
          FErrors.Add(esWarning, JB_WRN_MANIFEST, RSMyraBuildManifestFailed);
  end;

  // Icon (executables only)
  if LIsExe and (FExeIcon <> '') then
  begin
    if TFile.Exists(FExeIcon) then
      TUtils.UpdateIconResource(AExePath, FExeIcon)
    else if Assigned(FErrors) then
      FErrors.Add(esWarning, JB_WRN_ICON, RSMyraBuildIconNotFound,
        [FExeIcon]);
  end;

  // Version info
  if FAddVersionInfo then
    TUtils.UpdateVersionInfoResource(AExePath,
      FVIMajor, FVIMinor, FVIPatch, FVIProductName,
      FVIDescription, FVIFilename, FVICompanyName, FVICopyright);
end;

// Version info / post-build resources

procedure TBuild.SetAddVersionInfo(const AValue: Boolean);
begin
  FAddVersionInfo := AValue;
end;

function TBuild.GetAddVersionInfo(): Boolean;
begin
  Result := FAddVersionInfo;
end;

procedure TBuild.SetVIMajor(const AValue: Word);
begin
  FVIMajor := AValue;
end;

function TBuild.GetVIMajor(): Word;
begin
  Result := FVIMajor;
end;

procedure TBuild.SetVIMinor(const AValue: Word);
begin
  FVIMinor := AValue;
end;

function TBuild.GetVIMinor(): Word;
begin
  Result := FVIMinor;
end;

procedure TBuild.SetVIPatch(const AValue: Word);
begin
  FVIPatch := AValue;
end;

function TBuild.GetVIPatch(): Word;
begin
  Result := FVIPatch;
end;

procedure TBuild.SetVIProductName(const AValue: string);
begin
  FVIProductName := AValue;
end;

function TBuild.GetVIProductName(): string;
begin
  Result := FVIProductName;
end;

procedure TBuild.SetVIDescription(const AValue: string);
begin
  FVIDescription := AValue;
end;

function TBuild.GetVIDescription(): string;
begin
  Result := FVIDescription;
end;

procedure TBuild.SetVIFilename(const AValue: string);
begin
  FVIFilename := AValue;
end;

function TBuild.GetVIFilename(): string;
begin
  Result := FVIFilename;
end;

procedure TBuild.SetVICompanyName(const AValue: string);
begin
  FVICompanyName := AValue;
end;

function TBuild.GetVICompanyName(): string;
begin
  Result := FVICompanyName;
end;

procedure TBuild.SetVICopyright(const AValue: string);
begin
  FVICopyright := AValue;
end;

function TBuild.GetVICopyright(): string;
begin
  Result := FVICopyright;
end;

procedure TBuild.SetExeIcon(const AValue: string);
begin
  FExeIcon := AValue;
end;

function TBuild.GetExeIcon(): string;
begin
  Result := FExeIcon;
end;

// Breakpoints

procedure TBuild.AddBreakpoint(const AFileName: string; const ALineNumber: Integer);
var
  LEntry: TBreakpointEntry;
begin
  LEntry.FileName := AFileName;
  LEntry.LineNumber := ALineNumber;
  FBreakpoints.Add(LEntry);
end;

procedure TBuild.ClearBreakpoints();
begin
  FBreakpoints.Clear();
end;

function TBuild.GetBreakpoints(): TArray<TBreakpointEntry>;
begin
  Result := FBreakpoints.ToArray();
end;

procedure TBuild.WriteBreakpointsFile(const AExePath: string);
var
  LBreakpointFile: string;
  LConfig: TConfig;
  LExeDir: string;
  LRelativePath: string;
  LI: Integer;
  LIndex: Integer;
begin
  if FBreakpoints.Count = 0 then
    Exit;

  LBreakpointFile := TUtils.AppBasedPath(
    TPath.ChangeExtension(AExePath, BREAKPOINT_EXT));
  LExeDir := TPath.GetDirectoryName(AExePath);

  LConfig := TConfig.Create();
  try
    for LI := 0 to FBreakpoints.Count - 1 do
    begin
      LIndex := LConfig.AddTableEntry('breakpoints');
      LRelativePath := ExtractRelativePath(LExeDir + PathDelim,
        FBreakpoints[LI].FileName);
      LRelativePath := LRelativePath.Replace('\', '/');
      LConfig.SetTableString('breakpoints', LIndex, 'file', LRelativePath);
      LConfig.SetTableInteger('breakpoints', LIndex, 'line',
        FBreakpoints[LI].LineNumber);
    end;
    LConfig.SaveToFile(LBreakpointFile);
  finally
    LConfig.Free();
  end;
end;

// Toolchain paths

procedure TBuild.SetToolchainPath(const APath: string);
begin
  if APath = '' then
    FToolchainPath := TPath.GetDirectoryName(ParamStr(0))
  else
  begin
    if not TPath.IsPathRooted(APath) then
      FToolchainPath := TPath.Combine(
        TPath.GetDirectoryName(ParamStr(0)), APath)
    else
      FToolchainPath := APath;
  end;

  // Persist the raw value (empty or user-provided)
  FBuildConfig.SetString('build.toolchain_path', APath);
end;

function TBuild.GetToolchainPath(): string;
begin
  Result := FToolchainPath;
end;

function TBuild.GetZigPath(const AFilename: string): string;
begin
  Result := TPath.Combine(FToolchainPath, 'zig');
  if AFilename <> '' then
    Result := TPath.Combine(Result, AFilename);
end;

function TBuild.GetRuntimePath(const AFilename: string): string;
begin
  Result := TPath.Combine(FToolchainPath, 'runtime');
  if AFilename <> '' then
    Result := TPath.Combine(Result, AFilename);
end;

function TBuild.GetLibsPath(const AFilename: string): string;
begin
  Result := TPath.Combine(FToolchainPath, 'libs');
  if AFilename <> '' then
    Result := TPath.Combine(Result, AFilename);
end;

function TBuild.GetAssetsPath(const AFilename: string): string;
begin
  Result := TPath.Combine(FToolchainPath, 'assets');
  if AFilename <> '' then
    Result := TPath.Combine(Result, AFilename);
end;

function TBuild.GetWasmPath(const AFilename: string): string;
begin
  Result := TPath.Combine(FToolchainPath, 'wasm');
  if AFilename <> '' then
    Result := TPath.Combine(Result, AFilename);
end;

function TBuild.GetWasmHtmlFilename(): string;
begin
  Result := FProjectName + '.html';
end;

function TBuild.DoIsWasmTarget(): Boolean;
var
  LArch: string;
begin
  LArch := GetTargetArch();
  Result := SameText(LArch, ARCH_WASM32) or SameText(LArch, ARCH_WASM64);
end;

{ Emits a self-contained HTML runner beside the .wasm. The module bytes and the
  WASI shim are both inlined, because a browser cannot fetch a .wasm nor import
  an external module over file:// -- an inline module, however, runs fine. The
  result is a single file that runs by double-click, with no web server. }
procedure TBuild.DoWriteWasmShim();
var
  LTemplateFile: string;
  LShimFile: string;
  LWasmFile: string;
  LHtmlFile: string;
  LTemplate: string;
  LShim: string;
  LWasmBytes: TBytes;
  LBase64: string;
  LEncoder: TBase64Encoding;
begin
  LTemplateFile := GetWasmPath('index.html');
  LShimFile := GetWasmPath('wasi_shim.bundle.js');

  if not TFile.Exists(LTemplateFile) then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esWarning, JB_WRN_WASM, RSMyraBuildWasmAssetNotFound,
        [LTemplateFile]);
    Exit;
  end;

  if not TFile.Exists(LShimFile) then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esWarning, JB_WRN_WASM, RSMyraBuildWasmAssetNotFound,
        [LShimFile]);
    Exit;
  end;

  LWasmFile := TPath.Combine(FOutputPath,
    TPath.Combine('zig-out', TPath.Combine('bin', GetOutputFilename())));

  if not TFile.Exists(LWasmFile) then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esWarning, JB_WRN_WASM, RSMyraBuildWasmAssetNotFound,
        [LWasmFile]);
    Exit;
  end;

  try
    LTemplate := TFile.ReadAllText(LTemplateFile, TEncoding.UTF8);
    LShim := TFile.ReadAllText(LShimFile, TEncoding.UTF8);
    LWasmBytes := TFile.ReadAllBytes(LWasmFile);

    // Line breaks must be suppressed: the base64 is spliced into a JavaScript
    // string literal, which cannot span raw newlines. TNetEncoding.Base64
    // wraps at 76 columns, so it cannot be used here.
    LEncoder := TBase64Encoding.Create(0);
    try
      LBase64 := LEncoder.EncodeBytesToString(LWasmBytes);
    finally
      LEncoder.Free();
    end;

    LTemplate := LTemplate.Replace('__MYRA_WASI_SHIM__', LShim, [rfReplaceAll]);
    LTemplate := LTemplate.Replace('__MYRA_WASM_BASE64__', LBase64, [rfReplaceAll]);
    LTemplate := LTemplate.Replace('__MYRA_WASM_MODULE__', GetOutputFilename(),
      [rfReplaceAll]);

    LHtmlFile := TPath.Combine(TPath.GetDirectoryName(LWasmFile),
      GetWasmHtmlFilename());

    TFile.WriteAllText(LHtmlFile, LTemplate, TEncoding.UTF8);

    Status(RSMyraBuildWasmRunnerWritten, [GetWasmHtmlFilename()]);
  except
    on E: Exception do
    begin
      if Assigned(FErrors) then
        FErrors.Add(esWarning, JB_WRN_WASM, RSMyraBuildWasmRunnerFailed,
          [E.Message]);
    end;
  end;
end;

{ Hands the generated HTML to the default browser. There is no process and
  therefore no exit code -- a wasm run is fire-and-forget. }
function TBuild.DoRunWasmHtml(): Boolean;
var
  LHtmlFile: string;
begin
  Result := False;

  // ShellExecute will not accept a relative path, so resolve it in full.
  LHtmlFile := TPath.GetFullPath(TPath.Combine(FOutputPath,
    TPath.Combine('zig-out', TPath.Combine('bin', GetWasmHtmlFilename()))));

  if not TFile.Exists(LHtmlFile) then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esWarning, JB_WRN_WASM, RSMyraBuildWasmAssetNotFound,
        [LHtmlFile]);
    Exit;
  end;

  Status(RSMyraBuildRunningWasm, [GetWasmHtmlFilename()]);

  FLastExitCode := 0;
  Result := TUtils.ShellOpen(LHtmlFile, TPath.GetDirectoryName(LHtmlFile));

  if not Result then
  begin
    if Assigned(FErrors) then
      FErrors.Add(esWarning, JB_WRN_WASM, RSMyraBuildWasmRunnerFailed,
        [LHtmlFile]);
    Result := True;  // The build succeeded; only the launch did not.
  end;
end;

function TBuild.ResolvePath(const AFilename: string;
  const ARelativePath: string; const ABasePath: string;
  const ABehavior: Integer): string;
var
  LBase: string;
begin
  // (a) Absolute path: use as-is
  if TPath.IsPathRooted(ARelativePath) then
  begin
    if AFilename <> '' then
      Result := TPath.Combine(ARelativePath, AFilename)
    else
      Result := ARelativePath;
    Exit;
  end;

  // (b) Relative path with an explicit base
  if ABasePath <> '' then
    LBase := ABasePath
  // (c) Relative path, no base: resolve per behavior
  else if ABehavior = 1 then
    LBase := TPath.GetDirectoryName(ParamStr(0))
  else
  begin
    // (d) Behavior 0 or unknown: raw passthrough
    if AFilename <> '' then
      Result := TPath.Combine(ARelativePath, AFilename)
    else
      Result := ARelativePath;
    Exit;
  end;

  // Combine base + relative (+ filename)
  Result := TPath.Combine(LBase, ARelativePath);
  if AFilename <> '' then
    Result := TPath.Combine(Result, AFilename);
end;

end.
