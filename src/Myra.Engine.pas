{===============================================================================
  Myra™ - Pascal. Refined.

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://myralang.org

  See LICENSE for license information
===============================================================================}

unit Myra.Engine;

{$I StdApp.Defines.inc}

interface

uses
  WinApi.Windows,
  System.SysUtils,
  System.IOUtils,
  System.Classes,
  System.Generics.Collections,
  StdApp.Resources,
  StdApp.Base,
  StdApp.Utils,
  StdApp.Console,
  Myra.Common,
  Myra.Build,
  Myra.Build.Targets,
  Myra.AST,
  Myra.Lexer,
  Myra.Parser,
  Myra.Interpreter,
  Myra.Scopes,
  Myra.CodeGen,
  Myra.GenericLexer,
  Myra.GenericParser,
  Myra.Cpp;

const
  // Engine Error Codes (E001-E099)
  ERR_ENGINE_FILE_NOT_FOUND   = 'E001';
  ERR_ENGINE_MODULE_NOT_FOUND = 'E002';

type

  { TEngine }
  TEngine = class(TBaseObject)
  private
    FBuild: TBuild;
    FMorLexer: TLexer;
    FMorParser: TParser;
    FInterp: TInterpreter;
    FProcessedFiles: TDictionary<string, Boolean>;
    FImportedMorFiles: TDictionary<string, Boolean>;
    FMasterRoot: TASTNode;
    FMorMasterRoot: TASTNode;
    FSourceDir: string;
    FMorFileDir: string;
    FOutputPath: string;

    // Module compilation callback (called by interpreter during semantics)
    function CompileModule(const AModuleName: string): Boolean;

    // .mor import callback (called by interpreter during setup)
    function ImportMorFile(const AMorPath: string): TASTNode;

    // Shared user source compilation (phases 3-7)
    procedure CompileUserSource(const ASourceFile: string;
      const AOutputPath: string; const AAutoRun: Boolean);

  public
    constructor Create(); override;
    destructor Destroy(); override;

    // Full compilation pipeline: .mor + user source -> native binary
    procedure Compile(const AMorFile: string;
      const ASourceFile: string; const AOutputPath: string;
      const AAutoRun: Boolean = False);

    // Setup .mor language only (lex, parse, setup, resolve imports).
    // Returns True on success. After success, GetMorMasterRoot() holds
    // the complete validated AST including all imported subtrees.
    function SetupLanguage(const AMorFile: string): Boolean;

    // Compile user source using a baked (embedded) AST resource.
    // Loads the AST from RT_RCDATA, runs setup, then compiles user source.
    procedure CompileBaked(const ASourceFile: string;
      const AOutputPath: string; const AAutoRun: Boolean);

    // Build configuration wrappers
    function SetTargetAlias(const ATarget: string): Boolean;
    procedure SetTarget(const ATarget: string); overload;
    procedure SetTarget(const AArch: string; const AOS: string;
      const AAbi: string); overload;
    function GetTarget(): string;
    function GetTargetOS(): string;
    function GetTargetDisplayName(): string;
    procedure SetOptimizeLevel(const AOptimizeLevel: TOptimizeLevel);
    function GetOptimizeLevel(): TOptimizeLevel;
    procedure SetSubsystem(const ASubsystem: TSubsystemType);
    function GetSubsystem(): TSubsystemType;
    procedure SetBuildMode(const ABuildMode: TBuildMode);
    function GetBuildMode(): TBuildMode;
    function GetBuild(): TObject;
    procedure SetOutputCallback(const ACallback: TCaptureConsoleCallback;
      const AUserData: Pointer = nil);
    procedure SetStatusCallback(const ACallback: TStatusCallback;
      const AUserData: Pointer = nil); override;
    procedure SetOutputPath(const APath: string);
    function GetOutputPath(): string;
    procedure SetProjectName(const AProjectName: string);
    function GetProjectName(): string;

    // Defines
    procedure SetDefine(const ADefineName: string); overload;
    procedure SetDefine(const ADefineName: string;
      const AValue: string); overload;

    // Source/include management
    procedure AddSourceFile(const ASourceFile: string);
    procedure ClearSourceFiles();
    procedure AddIncludePath(const APath: string);

    // Build actions
    function CanAutoRun(): Boolean;
    function Process(const AAutoRun: Boolean = True): Boolean;
    function GetLastExitCode(): DWORD;

    // Access to subcomponents
    function GetInterpreter(): TInterpreter;
    function GetMorMasterRoot(): TASTNode;

    // Toolchain paths
    procedure SetToolchainPath(const APath: string);
    function GetToolchainPath(): string;
    function GetZigPath(const AFilename: string = ''): string;
    function GetRuntimePath(const AFilename: string = ''): string;
    function GetLibsPath(const AFilename: string = ''): string;
    function GetAssetsPath(const AFilename: string = ''): string;
  end;

implementation

{$R Myra.ResData.res}

{ TEngine }

constructor TEngine.Create();
begin
  inherited;

  FBuild := TBuild.Create();
  FBuild.SetErrors(FErrors);

  FMorLexer := TLexer.Create();
  FMorLexer.SetErrors(FErrors);

  FMorParser := TParser.Create();
  FMorParser.SetErrors(FErrors);

  FInterp := TInterpreter.Create();
  FInterp.SetErrors(FErrors);
  FInterp.SetBuild(FBuild);

  FProcessedFiles := TDictionary<string, Boolean>.Create();
  FImportedMorFiles := TDictionary<string, Boolean>.Create();
end;

destructor TEngine.Destroy();
begin
  FreeAndNil(FMorMasterRoot);
  FreeAndNil(FImportedMorFiles);
  FreeAndNil(FProcessedFiles);
  FreeAndNil(FInterp);
  FreeAndNil(FMorParser);
  FreeAndNil(FMorLexer);
  FreeAndNil(FBuild);
  inherited;
end;

procedure TEngine.Compile(const AMorFile: string;
  const ASourceFile: string; const AOutputPath: string;
  const AAutoRun: Boolean);
var
  LMorSource: string;
  LMorTokens: TList<TToken>;
  LMorAST: TASTNode;
  LMorDisplay: string;
  LMorFile: string;
begin
  FErrors.Clear();
  FProcessedFiles.Clear();
  FImportedMorFiles.Clear();

  LMorFile := TUtils.AppBasedPath(TPath.ChangeExtension(AMorFile, LANGDEF_EXT));

  LMorDisplay := TUtils.DisplayPath(LMorFile);

  // --- Phase 1: Read and parse .mor file ---
  if not TFile.Exists(LMorFile) then
  begin
    FErrors.Add(esFatal, ERR_ENGINE_FILE_NOT_FOUND,
      RSFatalFileNotFound, [LMorDisplay], nil);
    Exit;
  end;

  LMorSource := TFile.ReadAllText(LMorFile, TEncoding.UTF8);

  // Lex .mor source
  //Status(RSMorLexerTokenizing, [LMorDisplay]);
  LMorTokens := FMorLexer.Tokenize(LMorSource, LMorDisplay);
  if FErrors.HasErrors() then
  begin
    LMorTokens.Free();
    Exit;
  end;

  // Parse .mor source
  //Status(RSMorParserParsing, [LMorDisplay]);
  LMorAST := FMorParser.Parse(LMorTokens, LMorDisplay);
  LMorTokens.Free();
  if FErrors.HasErrors() then
  begin
    LMorAST.Free();
    Exit;
  end;

  // --- Phase 2: Setup interpreter tables ---
  Status(RSMorInterpSetup);
  FMorFileDir := TPath.GetDirectoryName(TPath.GetFullPath(LMorFile));
  FImportedMorFiles.Add(TPath.GetFullPath(LMorFile), True);

  // Build .mor master root -- owns all .mor ASTs (main + imports)
  FMorMasterRoot := TASTNode.Create();
  FMorMasterRoot.SetKind('mor.master');
  FMorMasterRoot.AddChild(LMorAST);
  try
    FInterp.SetImportMorFunc(ImportMorFile);
    FInterp.RunSetup(LMorAST);
    FInterp.SetImportMorFunc(nil);
    if FErrors.HasErrors() then Exit;

    // Register C++ passthrough (AFTER custom lang setup)
    ConfigCpp(FInterp);
    Status(RSEngineCppPassthrough);

    CompileUserSource(ASourceFile, AOutputPath, AAutoRun);
  finally
    FreeAndNil(FMorMasterRoot);
  end;
end;

procedure TEngine.CompileUserSource(const ASourceFile: string;
  const AOutputPath: string; const AAutoRun: Boolean);
var
  LUserSource: string;
  LUserTokens: TList<TToken>;
  LGenLexer: TGenericLexer;
  LGenParser: TMyrGenericParser;
  LMasterRoot: TASTNode;
  LUserBranch: TASTNode;
  LScopes: TScopeManager;
  LOutput: TCodeOutput;
  LBranchOutput: TCodeOutput;
  LBranch: TASTNode;
  LGeneratedPath: string;
  LHeaderPath: string;
  LSourcePath: string;
  LProjectName: string;
  LBranchName: string;
  LSrcDisplay: string;
  LI: Integer;
  LSourceFile: string;
begin
  LSourceFile := TPath.ChangeExtension(ASourceFile, FInterp.GetModuleExtension());

  LSrcDisplay := TUtils.DisplayPath(LSourceFile);

  // --- Phase 3: Read and process user source ---
  if not TFile.Exists(LSourceFile) then
  begin
    FErrors.Add(esFatal, ERR_ENGINE_FILE_NOT_FOUND,
      RSFatalFileNotFound, [LSrcDisplay], nil);
    Exit;
  end;

  LUserSource := TFile.ReadAllText(LSourceFile, TEncoding.UTF8);

  // Lex user source via table-driven lexer
  Status(RSUserLexerTokenizing, [TPath.GetFileName(LSrcDisplay)]);
  LGenLexer := TGenericLexer.Create();
  try
    LGenLexer.SetErrors(FErrors);
    LGenLexer.SetBuild(FBuild);
    LGenLexer.Configure(FInterp);
    LUserTokens := LGenLexer.Tokenize(LUserSource, LSrcDisplay);
  finally
    LGenLexer.Free();
  end;
  if FErrors.HasErrors() then
  begin
    LUserTokens.Free();
    Exit;
  end;

  // Parse user source into a branch
  Status(RSUserParserParsing, [TPath.GetFileName(LSrcDisplay)]);
  LGenParser := TMyrGenericParser.Create();
  try
    LGenParser.SetErrors(FErrors);
    LGenParser.Configure(FInterp);
    LUserBranch := LGenParser.ParseProgram(LUserTokens, LSrcDisplay);
  finally
    LGenParser.Free();
  end;
  LUserTokens.Free();
  if FErrors.HasErrors() then
  begin
    LUserBranch.Free();
    Exit;
  end;

  // Assemble master AST: single root, one branch per file
  LMasterRoot := TASTNode.Create();
  LMasterRoot.SetKind('master.root');
  LMasterRoot.AddChild(LUserBranch);
  LUserBranch.SetAttr('source_name', TPath.GetFileNameWithoutExtension(ASourceFile));
  FProcessedFiles.Add(TPath.GetFullPath(ASourceFile), True);
  FMasterRoot := LMasterRoot;
  FSourceDir := TPath.GetDirectoryName(TPath.GetFullPath(ASourceFile));
  FOutputPath := AOutputPath;

  // Wire scopes and output into interpreter
  LScopes := TScopeManager.Create();
  LScopes.SetErrors(FErrors);
  LOutput := TCodeOutput.Create();
  try
    FInterp.SetScopes(LScopes);
    FInterp.SetOutput(LOutput);
    FInterp.SetCompileModuleFunc(CompileModule);

    // --- Phase 4: Semantic analysis ---
    Status(RSUserSemanticAnalyzing, [TPath.GetFileName(LSrcDisplay)]);
    FInterp.RunSemantics(LMasterRoot);
    if FErrors.HasErrors() then Exit;

    // --- Phase 5-6: Code generation and output per branch ---
    // Emit module branches first (index 1+), then main program (index 0)
    // so the main program's build settings (exe mode) stick on FBuild.
    LProjectName := TPath.GetFileNameWithoutExtension(ASourceFile);
    LGeneratedPath := TPath.Combine(AOutputPath, 'generated');
    TDirectory.CreateDirectory(LGeneratedPath);
    FBuild.SetOutputPath(AOutputPath);
    FBuild.SetProjectName(LProjectName);
    FBuild.ClearSourceFiles();
    FBuild.AddIncludePath(LGeneratedPath);
    FBuild.AddIncludePath(FBuild.GetRuntimePath());
    FBuild.AddSourceFile(FBuild.GetRuntimePath('myr_runtime.cpp'));

    // Pass 1: module branches (index 1+)
    for LI := 1 to LMasterRoot.ChildCount() - 1 do
    begin
      LBranch := LMasterRoot.GetChild(LI);
      LBranchName := LBranch.GetAttr('source_name');
      if LBranchName = '' then
        LBranchName := 'module_' + IntToStr(LI);

      LBranchOutput := TCodeOutput.Create();
      try
        FInterp.SetOutput(LBranchOutput);
        Status(RSUserCodeGenEmitting, [LBranchName]);
        FInterp.RunEmitHandler(LBranch);
        if FErrors.HasErrors() then Exit;

        LHeaderPath := TPath.Combine(LGeneratedPath, LBranchName + '.h');
        LSourcePath := TPath.Combine(LGeneratedPath, LBranchName + '.cpp');
        LBranchOutput.SaveToFiles(LHeaderPath, LSourcePath);
        FBuild.AddSourceFile(LSourcePath);
      finally
        LBranchOutput.Free();
      end;
    end;

    // Pass 2: main program branch (index 0) -- sets exe build mode last
    if LMasterRoot.ChildCount() > 0 then
    begin
      LBranch := LMasterRoot.GetChild(0);
      LBranchName := LBranch.GetAttr('source_name');
      if LBranchName = '' then
        LBranchName := LProjectName;

      LBranchOutput := TCodeOutput.Create();
      try
        FInterp.SetOutput(LBranchOutput);
        Status(RSUserCodeGenEmitting, [LBranchName]);
        FInterp.RunEmitHandler(LBranch);
        if FErrors.HasErrors() then Exit;

        LHeaderPath := TPath.Combine(LGeneratedPath, LBranchName + '.h');
        LSourcePath := TPath.Combine(LGeneratedPath, LBranchName + '.cpp');
        LBranchOutput.SaveToFiles(LHeaderPath, LSourcePath);
        FBuild.AddSourceFile(LSourcePath);
      finally
        LBranchOutput.Free();
      end;
    end;

    // --- Phase 7: Build via Zig/Clang ---
    // The target is an arbitrary Zig/Clang triple, so report it verbatim.
    // Subsystem is a Windows-only concept and is only appended there.
    if SameText(FBuild.GetTargetOS(), OS_WINDOWS) then
    begin
      if FBuild.GetSubsystem() = stGUI then
        Status(RSEngineTargetPlatform,
          [COLOR_CYAN + FBuild.GetTargetDisplayName() + ' (GUI)'])
      else
        Status(RSEngineTargetPlatform,
          [COLOR_CYAN + FBuild.GetTargetDisplayName() + ' (Console)']);
    end
    else
      Status(RSEngineTargetPlatform,
        [COLOR_CYAN + FBuild.GetTargetDisplayName()]);

    if FBuild.GetBuildMode() = bmExe then
      Status(RSEngineBuildMode, [COLOR_CYAN + 'Executable'])
    else if FBuild.GetBuildMode() = bmDll then
      Status(RSEngineBuildMode, [COLOR_CYAN + 'DLL'])
    else
      Status(RSEngineBuildMode, [COLOR_CYAN + 'Library']);

    if FBuild.GetOptimizeLevel() = olDebug then
      Status(RSEngineOptimizeLevel, [COLOR_CYAN + 'Debug'])
    else if FBuild.GetOptimizeLevel() = olReleaseSafe then
      Status(RSEngineOptimizeLevel, [COLOR_CYAN + 'ReleaseSafe'])
    else if FBuild.GetOptimizeLevel() = olReleaseFast then
      Status(RSEngineOptimizeLevel, [COLOR_CYAN + 'ReleaseFast'])
    else
      Status(RSEngineOptimizeLevel, [COLOR_CYAN + 'ReleaseSmall']);

    FBuild.Process(AAutoRun);
  finally
    FInterp.SetCompileModuleFunc(nil);
    FInterp.SetScopes(nil);
    FInterp.SetOutput(nil);
    FMasterRoot := nil;
    LOutput.Free();
    LScopes.Free();
    // Free semantics/emit-phase orphans + the compilation-scoped macro registry
    // BEFORE the master tree: kept (parented) nodes are still valid here for the
    // IsParented() check and are then freed by the tree below. Disjoint sets, no
    // double-free.
    FInterp.SweepCreatedNodes();
    LMasterRoot.Free();
  end;
end;

procedure TEngine.CompileBaked(const ASourceFile: string;
  const AOutputPath: string; const AAutoRun: Boolean);
var
  LResStream: TResourceStream;
  LI: Integer;
begin
  FErrors.Clear();
  FProcessedFiles.Clear();
  FImportedMorFiles.Clear();

  // Load baked AST from embedded resource
  LResStream := TResourceStream.Create(HInstance, AST_BAKED_RES, RT_RCDATA);
  try
    FMorMasterRoot := TASTNode.LoadASTFromStream(LResStream);
  finally
    LResStream.Free();
  end;

  // Run setup on each child AST to rebuild interpreter dispatch tables
  for LI := 0 to FMorMasterRoot.ChildCount() - 1 do
  begin
    FInterp.RunSetup(FMorMasterRoot.GetChild(LI));
    if FErrors.HasErrors() then
    begin
      FreeAndNil(FMorMasterRoot);
      Exit;
    end;
  end;

  // Register C++ passthrough
  ConfigCpp(FInterp);

  // Compile user source using shared pipeline
  try
    CompileUserSource(ASourceFile, AOutputPath, AAutoRun);
  finally
    FreeAndNil(FMorMasterRoot);
  end;
end;


function TEngine.CompileModule(const AModuleName: string): Boolean;
var
  LModuleFile: string;
  LModulePath: string;
  LModuleDisplay: string;
  LSource: string;
  LGenLexer: TGenericLexer;
  LGenParser: TMyrGenericParser;
  LTokens: TList<TToken>;
  LBranch: TASTNode;
  LI: Integer;
begin
  // Resolve filename using module extension
  LModuleFile := AModuleName + '.' + FInterp.GetModuleExtension();
  LModulePath := TPath.Combine(FSourceDir, LModuleFile);

  // Search module paths if not found in source dir
  if not TFile.Exists(LModulePath) then
  begin
    for LI := 0 to FInterp.GetModulePaths().Count - 1 do
    begin
      LModulePath := TPath.Combine(
        FInterp.GetModulePaths()[LI],
        LModuleFile);
      if TFile.Exists(LModulePath) then
        Break;
    end;
  end;

  LModuleDisplay := TUtils.DisplayPath(LModulePath);

  // Check dedup
  if FProcessedFiles.ContainsKey(TPath.GetFullPath(LModulePath)) then
    Exit(True);

  // Check existence
  if not TFile.Exists(LModulePath) then
  begin
    FErrors.Add(esError, ERR_ENGINE_MODULE_NOT_FOUND,
      RSFatalFileNotFound, [LModuleDisplay], nil);
    Exit(False);
  end;

  LSource := TFile.ReadAllText(LModulePath, TEncoding.UTF8);

  // Lex module source
  Status(RSUserLexerTokenizing, [TPath.GetFileName(LModuleDisplay)]);
  LGenLexer := TGenericLexer.Create();
  try
    LGenLexer.SetErrors(FErrors);
    LGenLexer.SetBuild(FBuild);
    LGenLexer.Configure(FInterp);
    LTokens := LGenLexer.Tokenize(LSource, LModuleDisplay);
  finally
    LGenLexer.Free();
  end;
  if FErrors.HasErrors() then
  begin
    LTokens.Free();
    Exit(False);
  end;

  // Parse module source into a branch
  Status(RSUserParserParsing, [TPath.GetFileName(LModuleDisplay)]);
  LGenParser := TMyrGenericParser.Create();
  try
    LGenParser.SetErrors(FErrors);
    LGenParser.Configure(FInterp);
    LBranch := LGenParser.ParseProgram(LTokens, LModuleDisplay);
  finally
    LGenParser.Free();
  end;
  LTokens.Free();
  if FErrors.HasErrors() then
  begin
    LBranch.Free();
    Exit(False);
  end;

  // Attach branch to master root and mark processed
  LBranch.SetAttr('source_name', AModuleName);
  FMasterRoot.AddChild(LBranch);
  FProcessedFiles.Add(TPath.GetFullPath(LModulePath), True);

  // Run semantics on the new branch (may trigger further compileModule calls)
  FInterp.RunSemanticHandler(LBranch);

  Result := True;
end;

function TEngine.ImportMorFile(const AMorPath: string): TASTNode;
var
  LFullPath: string;
  LDisplay: string;
  LSource: string;
  LTokens: TList<TToken>;
  LAST: TASTNode;
begin
  Result := nil;

  // Resolve relative to .mor file directory
  if TPath.IsRelativePath(AMorPath) then
    LFullPath := TPath.GetFullPath(TPath.Combine(FMorFileDir, AMorPath))
  else
    LFullPath := TPath.GetFullPath(AMorPath);

  // Force language definition extension
  LFullPath := TUtils.AppBasedPath(TPath.ChangeExtension(LFullPath, LANGDEF_EXT));

  LDisplay := TUtils.DisplayPath(LFullPath);

  // Dedup check
  if FImportedMorFiles.ContainsKey(LFullPath) then
    Exit;

  // Check existence
  if not TFile.Exists(LFullPath) then
  begin
    FErrors.Add(esError, ERR_ENGINE_FILE_NOT_FOUND,
      RSFatalFileNotFound, [LDisplay], nil);
    Exit;
  end;

  // Mark as imported
  FImportedMorFiles.Add(LFullPath, True);

  LSource := TFile.ReadAllText(LFullPath, TEncoding.UTF8);

  // Lex imported .mor file
  //Status(RSMorLexerTokenizing, [LDisplay]);
  LTokens := FMorLexer.Tokenize(LSource, LDisplay);
  if FErrors.HasErrors() then
  begin
    LTokens.Free();
    Exit;
  end;

  // Parse imported .mor file
  //Status(RSMorParserParsing, [LDisplay]);
  LAST := FMorParser.Parse(LTokens, LDisplay);
  LTokens.Free();
  if FErrors.HasErrors() then
  begin
    LAST.Free();
    Exit;
  end;

  // Add to .mor master root for lifetime management
  FMorMasterRoot.AddChild(LAST);

  Result := LAST;
end;

// Resolve a curated target alias (win64, wasm32, ...) to a full Zig triple
// and set it. Returns False when the name is not a known alias or raw triple.
function TEngine.SetTargetAlias(const ATarget: string): Boolean;
begin
  Result := FBuild.SetTargetAlias(ATarget);
end;

procedure TEngine.SetTarget(const ATarget: string);
begin
  FBuild.SetTarget(ATarget);
end;

procedure TEngine.SetTarget(const AArch: string; const AOS: string;
  const AAbi: string);
begin
  FBuild.SetTarget(AArch, AOS, AAbi);
end;

function TEngine.GetTarget(): string;
begin
  Result := FBuild.GetTarget();
end;

function TEngine.GetTargetOS(): string;
begin
  Result := FBuild.GetTargetOS();
end;

function TEngine.GetTargetDisplayName(): string;
begin
  Result := FBuild.GetTargetDisplayName();
end;

procedure TEngine.SetOptimizeLevel(const AOptimizeLevel: TOptimizeLevel);
begin
  FBuild.SetOptimizeLevel(AOptimizeLevel);
end;

function TEngine.GetOptimizeLevel(): TOptimizeLevel;
begin
  Result := FBuild.GetOptimizeLevel();
end;

procedure TEngine.SetSubsystem(const ASubsystem: TSubsystemType);
begin
  FBuild.SetSubsystem(ASubsystem);
end;

function TEngine.GetSubsystem(): TSubsystemType;
begin
  Result := FBuild.GetSubsystem();
end;

procedure TEngine.SetBuildMode(const ABuildMode: TBuildMode);
begin
  FBuild.SetBuildMode(ABuildMode);
end;

function TEngine.GetBuildMode(): TBuildMode;
begin
  Result := FBuild.GetBuildMode();
end;

function TEngine.GetBuild(): TObject;
begin
  Result := FBuild;
end;

procedure TEngine.SetOutputCallback(const ACallback: TCaptureConsoleCallback;
  const AUserData: Pointer);
begin
  FBuild.SetOutputCallback(ACallback, AUserData);
end;

procedure TEngine.SetStatusCallback(const ACallback: TStatusCallback;
  const AUserData: Pointer);
begin
  inherited;
  FBuild.SetStatusCallback(ACallback, AUserData);
end;

procedure TEngine.SetOutputPath(const APath: string);
begin
  FBuild.SetOutputPath(APath);
end;

function TEngine.GetOutputPath(): string;
begin
  Result := FBuild.GetOutputPath();
end;

procedure TEngine.SetProjectName(const AProjectName: string);
begin
  FBuild.SetProjectName(AProjectName);
end;

function TEngine.GetProjectName(): string;
begin
  Result := FBuild.GetProjectName();
end;

procedure TEngine.SetDefine(const ADefineName: string);
begin
  FBuild.SetDefine(ADefineName);
end;

procedure TEngine.SetDefine(const ADefineName: string;
  const AValue: string);
begin
  FBuild.SetDefine(ADefineName, AValue);
end;

procedure TEngine.AddSourceFile(const ASourceFile: string);
begin
  FBuild.AddSourceFile(ASourceFile);
end;

procedure TEngine.ClearSourceFiles();
begin
  FBuild.ClearSourceFiles();
end;

procedure TEngine.AddIncludePath(const APath: string);
begin
  FBuild.AddIncludePath(APath);
end;

function TEngine.Process(const AAutoRun: Boolean): Boolean;
begin
  Result := FBuild.Process(AAutoRun);
end;

// True when the CURRENT target can be launched from this host. Only
// x86_64-windows-gnu (native) and x86_64-linux-gnu (WSL) qualify.
function TEngine.CanAutoRun(): Boolean;
begin
  Result := FBuild.CanAutoRun();
end;

function TEngine.GetLastExitCode(): DWORD;
begin
  Result := FBuild.GetLastExitCode();
end;

function TEngine.GetInterpreter(): TInterpreter;
begin
  Result := FInterp;
end;

function TEngine.GetMorMasterRoot(): TASTNode;
begin
  Result := FMorMasterRoot;
end;

function TEngine.SetupLanguage(const AMorFile: string): Boolean;
var
  LMorSource: string;
  LMorTokens: TList<TToken>;
  LMorAST: TASTNode;
  LMorDisplay: string;
  LMorFile: string;
begin
  Result := False;

  FErrors.Clear();
  FProcessedFiles.Clear();
  FImportedMorFiles.Clear();

  LMorFile := TUtils.AppBasedPath(TPath.ChangeExtension(AMorFile, LANGDEF_EXT));
  LMorDisplay := TUtils.DisplayPath(LMorFile);

  // Read .mor file
  if not TFile.Exists(LMorFile) then
  begin
    FErrors.Add(esFatal, ERR_ENGINE_FILE_NOT_FOUND,
      RSFatalFileNotFound, [LMorDisplay], nil);
    Exit;
  end;

  LMorSource := TFile.ReadAllText(LMorFile, TEncoding.UTF8);

  // Lex .mor source
  //Status(RSMorLexerTokenizing, [LMorDisplay]);
  LMorTokens := FMorLexer.Tokenize(LMorSource, LMorDisplay);
  if FErrors.HasErrors() then
  begin
    LMorTokens.Free();
    Exit;
  end;

  // Parse .mor source
  //Status(RSMorParserParsing, [LMorDisplay]);
  LMorAST := FMorParser.Parse(LMorTokens, LMorDisplay);
  LMorTokens.Free();
  if FErrors.HasErrors() then
  begin
    LMorAST.Free();
    Exit;
  end;

  // Setup interpreter tables
  Status(RSMorInterpSetup);
  FMorFileDir := TPath.GetDirectoryName(TPath.GetFullPath(LMorFile));
  FImportedMorFiles.Add(TPath.GetFullPath(LMorFile), True);

  // Build .mor master root -- owns all .mor ASTs (main + imports)
  FMorMasterRoot := TASTNode.Create();
  FMorMasterRoot.SetKind('mor.master');
  FMorMasterRoot.AddChild(LMorAST);

  FInterp.SetImportMorFunc(ImportMorFile);
  FInterp.RunSetup(LMorAST);
  FInterp.SetImportMorFunc(nil);
  if FErrors.HasErrors() then Exit;

  // Register C++ passthrough
  ConfigCpp(FInterp);
  Status(RSEngineCppPassthrough);

  Result := True;
end;

// -- Toolchain path wrappers --------------------------------------------------

procedure TEngine.SetToolchainPath(const APath: string);
begin
  FBuild.SetToolchainPath(APath);
end;

function TEngine.GetToolchainPath(): string;
begin
  Result := FBuild.GetToolchainPath();
end;

function TEngine.GetZigPath(const AFilename: string): string;
begin
  Result := FBuild.GetZigPath(AFilename);
end;

function TEngine.GetRuntimePath(const AFilename: string): string;
begin
  Result := FBuild.GetRuntimePath(AFilename);
end;

function TEngine.GetLibsPath(const AFilename: string): string;
begin
  Result := FBuild.GetLibsPath(AFilename);
end;

function TEngine.GetAssetsPath(const AFilename: string): string;
begin
  Result := FBuild.GetAssetsPath(AFilename);
end;

end.

