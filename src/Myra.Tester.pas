{===============================================================================
  Myra™ - Pascal. Refined.

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://myralang.org

  See LICENSE for license information
===============================================================================}

unit Myra.Tester;

{$I StdApp.Defines.inc}

{===============================================================================
  Test File Comment Directives
  ---------------------------------------------------------------------------
  These special comment tokens are embedded in .myra test source files and
  are parsed by TTester before invoking the engine.

  /* EXITCODE: <n> */
    Expected process exit code after running the compiled executable.
    Defaults to 0 if omitted. The test fails if the actual exit code differs.
    Only checked when the test actually runs -- see AUTO-RUN below.

  /* EXPECT:
    <text>
  */
    Expected stdout output. Displayed in the test runner output for manual
    comparison. Not automatically diffed -- for human review only.

  /* ALLOW_WARNINGS */
    Suppresses the "warnings present" failure. Use when a test intentionally
    produces compiler warnings.

  ---------------------------------------------------------------------------
  TARGETS
  ---------------------------------------------------------------------------
  The TESTER drives the target, not the test file. RunAllTargets() loops every
  alias in the Targets property (all six by default), building the whole
  registered suite against each and printing a pass/fail/skip matrix.

  A test that is not target-agnostic declares its targets AT REGISTRATION:

    RegisterTest(10, 'test_messagebox', rmExecute, [MYR_TARGET_WIN64]);

  An empty platform list (the short overload) means the test runs on every
  target. A restricted test is SKIPPED on the targets it excludes -- never
  failed, since it was never meant to build there.

  A test file that declares its own @target directive OVERRIDES the tester --
  that is what @target is for. Tester-guided tests carry no @target.

  ---------------------------------------------------------------------------
  AUTO-RUN
  ---------------------------------------------------------------------------
  Only win64 (native) and linux64 (via WSL) can auto-run a freshly built
  binary. For the other four targets a test registered as rmExecute is still
  BUILT and its build result still counts, but the binary is never launched,
  so the EXITCODE directive cannot be verified. Those tests report a warning
  instead of failing.
===============================================================================}

interface

uses
  System.Types,
  System.IOUtils,
  System.Classes,
  System.SysUtils,
  System.Generics.Collections,
  StdApp.Base,
  StdApp.JSON,
  StdApp.Console,
  StdApp.Console.Menu,
  Myra.Common,
  Myra.Build,
  Myra.Engine,
  Myra.Debug.REPL;

const
  { MYR_COMMENT_OPEN }
  MYR_COMMENT_OPEN = '/*';

  { MYR_COMMENT_CLOSE }
  MYR_COMMENT_CLOSE = '*/';

  { MYR_TESTS_JSON }
  MYR_TESTS_JSON = 'tests.json';

type
  { TTestRunMode }
  TTestRunMode = (
    rmNone,         // compile only
    rmExecute,      // compile + run (auto-run targets only)
    rmDebug         // compile + debug via REPL
  );

  { TOptLevelSet }
  TOptLevelSet = set of TOptimizeLevel;

  { TTestEntry }
  TTestEntry = record
    TestName:             string;
    Category:             string;
    Dependencies:         TArray<string>;
    Platforms:            TArray<string>;    // [] = every target
    RunMode:              TTestRunMode;
    DefineName:           string;
    DefineValue:          string;
    OptLevels:            TOptLevelSet;      // [] = use global default
    Subsystem:            TSubsystemType;
    HasSubsystemOverride: Boolean;           // false = use global default
  end;

  { TTester }
  TTester = class(TBaseObject)
  private
    FTestFolder:      string;
    FOutputPath:      string;
    FLangFile:        string;
    FTarget:          string;
    FTargets:         TArray<string>;
    FSourceExt:       string;
    FOptLevels:       TOptLevelSet;
    FSubsystem:       TSubsystemType;
    FShowStatus:      Boolean;
    FPassCount:       Integer;
    FFailCount:       Integer;
    FSkipCount:       Integer;
    FLastTestSkipped: Boolean;
    FFailedTests:     TList<string>;
    FRegisteredTests: TDictionary<Integer, TTestEntry>;
    FTargetPass:      TDictionary<string, Integer>;
    FTargetFail:      TDictionary<string, Integer>;
    FTargetSkip:      TDictionary<string, Integer>;
    FTargetOrder:     TList<string>;
    FOutputCallback:  TProc<string>;
    FCurrentCategory: string;

    function ExtractExpected(const ASource: string): string;
    function ExtractExpectedExitCode(const ASource: string): Integer;
    function ExtractAllowWarnings(const ASource: string): Boolean;
    function ResolveTargets(const APlatforms: TArray<string>): TArray<string>;
    function ResolveOptLevels(const AOptLevels: TOptLevelSet;
      const ARunMode: TTestRunMode): TOptLevelSet;
    function OptLevelName(const AOptLevel: TOptimizeLevel): string;
    function FindEntry(const ATestName: string;
      out AEntry: TTestEntry): Boolean;
    procedure DoTally(const ATarget: string; const APass: Integer;
      const AFail: Integer; const ASkip: Integer);
    procedure PrintMatrix();
    function ExtractTestName(const AFilePath: string): string;
    function GetSourceExt(): string;
    function NextFreeKey(const AIndex: Integer): Integer;
    procedure DoRegister(const AIndex: Integer;
      const ATestName: string;
      const ADependencies: array of string;
      const APlatforms: array of string;
      const ARunMode: TTestRunMode;
      const ADefine: string;
      const ADefineValue: string;
      const AOptLevels: TOptLevelSet);
    procedure DoConfigureEngine(const AEngine: TEngine;
      const AOptLevel: TOptimizeLevel;
      const ASubsystem: TSubsystemType;
      const ADefine: string;
      const ADefineValue: string);
    procedure DoRunDebugger(const AExePath: string);
    function DoRunDeps(const ADependencies: TArray<string>;
      const AOptLevel: TOptimizeLevel): Boolean;
    function RunTestFileAtLevel(const AFilePath: string;
      const ARunMode: TTestRunMode;
      const AOptLevel: TOptimizeLevel;
      const ASubsystem: TSubsystemType;
      const ADefine: string;
      const ADefineValue: string): Boolean;
    function RunTestFile(const AFilePath: string;
      const ADependencies: TArray<string>;
      const ARunMode: TTestRunMode = rmNone;
      const ADefine: string = '';
      const ADefineValue: string = '';
      const AOptLevels: TOptLevelSet = [];
      const ASubsystem: TSubsystemType = stConsole;
      const AHasSubsystemOverride: Boolean = False): Boolean;
    procedure PrintResults();
    procedure Print(const AText: string); overload;
    procedure Print(const AFormat: string;
      const AArgs: array of const); overload;
    function GetFailedTests(): TArray<string>;
    function GetRegisteredTestCount(): Integer;

  public
    constructor Create(); override;
    destructor Destroy(); override;

    // Registration (indexed, ordered execution)
    //
    // APlatforms is the test's TARGET LIST. Omit it (or pass []) and the test
    // runs on every target in the tester's Targets. Pass an explicit list to
    // pin it -- e.g. a test calling MessageBox is win64-only and would fail to
    // build anywhere else.
    //
    // AOptLevels is the test's OPTIMIZE LEVEL LIST. [] means "use the tester's
    // OptLevels". Every test is built once per (target x opt level) pair.
    procedure RegisterTest(const AIndex: Integer;
      const ATestName: string;
      const ARunMode: TTestRunMode = rmNone;
      const ADefine: string = '';
      const ADefineValue: string = '';
      const AOptLevels: TOptLevelSet = []); overload;
    procedure RegisterTest(const AIndex: Integer;
      const ATestName: string;
      const ARunMode: TTestRunMode;
      const APlatforms: array of string;
      const ADefine: string = '';
      const ADefineValue: string = '';
      const AOptLevels: TOptLevelSet = []); overload;
    procedure RegisterTests(const AIndex: Integer;
      const ATestName: string;
      const ADependencies: array of string;
      const ARunMode: TTestRunMode = rmNone;
      const ADefine: string = '';
      const ADefineValue: string = '';
      const AOptLevels: TOptLevelSet = []); overload;
    procedure RegisterTests(const AIndex: Integer;
      const ATestName: string;
      const ADependencies: array of string;
      const ARunMode: TTestRunMode;
      const APlatforms: array of string;
      const ADefine: string = '';
      const ADefineValue: string = '';
      const AOptLevels: TOptLevelSet = []); overload;
    procedure ClearRegisteredTests();

    // Per-test overrides (call after RegisterTest)
    procedure SetTestOptLevels(const AIndex: Integer;
      const AOptLevels: TOptLevelSet);
    procedure SetTestSubsystem(const AIndex: Integer;
      const ASubsystem: TSubsystemType);

    // Execution
    function RunTest(const ATestName: string;
      const ARunMode: TTestRunMode = rmNone;
      const ADefine: string = '';
      const ADefineValue: string = '';
      const AOptLevels: TOptLevelSet = [];
      const ASubsystem: TSubsystemType = stConsole;
      const AHasSubsystemOverride: Boolean = False): Boolean;
    function RunTestByIndex(const AIndex: Integer): Boolean;
    function RunAllTests(): Integer;

    // Run the registered suite. Each test loops its own target list, so this
    // is a full matrix run. Returns True when every target is green.
    function RunAllTargets(): Boolean;
    function RunTestsMatching(const APattern: string;
      const ARunMode: TTestRunMode = rmNone): Integer;

    // State
    procedure Reset();

    // Category
    procedure SetCategory(const ACategory: string);
    function GetTestCategory(const AIndex: Integer): string;

    // Menu builder
    class function CreateMenu(const ATester: TTester): TConsoleMenu;

    // JSON persistence
    procedure SaveTests(const AFilename: string = MYR_TESTS_JSON);
    function LoadTests(const AFilename: string = MYR_TESTS_JSON): Boolean;

    // Properties
    property TestFolder:      string         read FTestFolder      write FTestFolder;
    property OutputPath:      string         read FOutputPath      write FOutputPath;
    property LangFile:        string         read FLangFile        write FLangFile;

    // Default target list for tests registered WITHOUT a platform list.
    // A test's own platform list, when non-empty, wins over this.
    property Targets:         TArray<string> read FTargets         write FTargets;
    property OptLevels:       TOptLevelSet   read FOptLevels       write FOptLevels;
    property Subsystem:       TSubsystemType read FSubsystem       write FSubsystem;
    property ShowStatus:      Boolean        read FShowStatus      write FShowStatus;
    property OutputCallback:  TProc<string>  read FOutputCallback  write FOutputCallback;
    property PassCount:       Integer        read FPassCount;
    property FailCount:       Integer        read FFailCount;
    property SkipCount:       Integer        read FSkipCount;
    property FailedTests:     TArray<string> read GetFailedTests;
    property RegisteredTestCount: Integer    read GetRegisteredTestCount;
  end;

implementation

uses
  System.TypInfo,
  Myra.Interpreter;

{ TTester }

constructor TTester.Create();
begin
  inherited;
  FFailedTests     := TList<string>.Create();
  FRegisteredTests := TDictionary<Integer, TTestEntry>.Create();
  FTargetPass      := TDictionary<string, Integer>.Create();
  FTargetFail      := TDictionary<string, Integer>.Create();
  FTargetSkip      := TDictionary<string, Integer>.Create();
  FTargetOrder     := TList<string>.Create();
  FShowStatus      := False;
  FOutputPath      := 'output';
  FOptLevels       := [olDebug];
  FSubsystem       := stConsole;
  FTestFolder      := MYR_RES_TESTS_DIR;
  FLangFile        := MYR_RES_LANGDEF;
  FTarget          := MYR_TARGET_WIN64;
  FSourceExt       := '';

  // The full matrix by default. Narrow it by assigning Targets.
  FTargets := [
    MYR_TARGET_WIN64,
    MYR_TARGET_WINARM64,
    MYR_TARGET_LINUX64,
    MYR_TARGET_LINUXARM64,
    MYR_TARGET_MACOS64,
    MYR_TARGET_WASM32
  ];
end;

destructor TTester.Destroy();
begin
  FTargetOrder.Free();
  FTargetSkip.Free();
  FTargetFail.Free();
  FTargetPass.Free();
  FRegisteredTests.Free();
  FFailedTests.Free();
  inherited;
end;

procedure TTester.Reset();
begin
  FPassCount       := 0;
  FFailCount       := 0;
  FSkipCount       := 0;
  FLastTestSkipped := False;
  FFailedTests.Clear();
  FTargetPass.Clear();
  FTargetFail.Clear();
  FTargetSkip.Clear();
  FTargetOrder.Clear();
end;

procedure TTester.SetCategory(const ACategory: string);
begin
  FCurrentCategory := ACategory;
end;

function TTester.GetTestCategory(const AIndex: Integer): string;
var
  LEntry: TTestEntry;
begin
  Result := '';
  if FRegisteredTests.TryGetValue(AIndex, LEntry) then
    Result := LEntry.Category;
end;

// The source extension is owned by the langdef (setModuleExtension in
// myra.mld), not by this unit. Stand up an engine once, run language setup,
// and cache what the interpreter reports. Returns a dotted extension.
function TTester.GetSourceExt(): string;
var
  LEngine: TEngine;
  LExt:    string;
begin
  if FSourceExt <> '' then
    Exit(FSourceExt);

  LEngine := TEngine.Create();
  try
    if not LEngine.SetupLanguage(FLangFile) then
    begin
      Print(COLOR_RED + 'ERROR: Failed to load langdef: ' + FLangFile);
      LEngine.PrintErrors();
      Exit('');
    end;

    LExt := LEngine.GetInterpreter().GetModuleExtension();
  finally
    LEngine.Free();
  end;

  if LExt = '' then
  begin
    Print(COLOR_RED +
      'ERROR: Langdef declared no module extension: ' + FLangFile);
    Exit('');
  end;

  // The langdef reports a bare extension ("myra"); normalize to ".myra".
  if not LExt.StartsWith('.') then
    LExt := '.' + LExt;

  FSourceExt := LExt;
  Result := FSourceExt;
end;

// Resolve the dictionary key for a registration: explicit index, or one past
// the current maximum when AIndex is negative.
function TTester.NextFreeKey(const AIndex: Integer): Integer;
var
  LMax: Integer;
  LK:   Integer;
begin
  if AIndex >= 0 then
    Exit(AIndex);

  LMax := -1;
  for LK in FRegisteredTests.Keys do
  begin
    if LK > LMax then
      LMax := LK;
  end;
  Result := LMax + 1;
end;

class function TTester.CreateMenu(const ATester: TTester): TConsoleMenu;

  // Capture index by value for closure safety
  function MakeTestRunner(const AIdx: Integer): TMenuCallback;
  begin
    Result :=
      procedure
      begin
        ATester.RunTestByIndex(AIdx);
      end;
  end;

  // Capture category by value for closure safety
  function MakeCategoryRunner(const ACat: string): TMenuCallback;
  begin
    Result :=
      procedure
      var
        LSorted: TArray<Integer>;
        LK:      Integer;
        LEntry:  TTestEntry;
      begin
        ATester.Reset();
        LSorted := ATester.FRegisteredTests.Keys.ToArray();
        TArray.Sort<Integer>(LSorted);
        for LK := 0 to High(LSorted) do
        begin
          LEntry := ATester.FRegisteredTests[LSorted[LK]];
          if SameText(LEntry.Category, ACat) then
            ATester.RunTest(LEntry.TestName, LEntry.RunMode,
              LEntry.DefineName, LEntry.DefineValue,
              LEntry.OptLevels, LEntry.Subsystem,
              LEntry.HasSubsystemOverride);
        end;
        ATester.PrintResults();
      end;
  end;

var
  LCategories:  TStringList;
  LI:           Integer;
  LEntry:       TTestEntry;
  LCat:         string;
  LSubMenu:     TConsoleMenu;
  LCatIdx:      Integer;
  LSortedKeys:  TArray<Integer>;
begin
  Result := TConsoleMenu.Create();
  Result.Title(ATester.FTestFolder);
  Result.Pause := True;

  // Add "Run All Tests" at root level
  Result.Add('Run All Tests',
    procedure
    begin
      ATester.RunAllTests();
    end);

  // Build the whole suite against every configured target
  Result.Add('Run All Targets',
    procedure
    begin
      ATester.RunAllTargets();
    end);

  Result.AddSeparator();

  // Collect unique categories in registration order
  LCategories := TStringList.Create();
  try
    LCategories.Duplicates := dupIgnore;
    LCategories.CaseSensitive := False;

    LSortedKeys := ATester.FRegisteredTests.Keys.ToArray();
    TArray.Sort<Integer>(LSortedKeys);

    for LI := 0 to High(LSortedKeys) do
    begin
      LEntry := ATester.FRegisteredTests[LSortedKeys[LI]];
      if LEntry.Category <> '' then
      begin
        if LCategories.IndexOf(LEntry.Category) < 0 then
          LCategories.Add(LEntry.Category);
      end;
    end;

    // Create a submenu per category
    for LCatIdx := 0 to LCategories.Count - 1 do
    begin
      LCat := LCategories[LCatIdx];
      LSubMenu := Result.AddSubmenu(LCat);

      // Add "Run All" for this category
      LSubMenu.Add('Run All', MakeCategoryRunner(LCat));
      LSubMenu.AddSeparator();

      // Add individual tests for this category
      for LI := 0 to High(LSortedKeys) do
      begin
        LEntry := ATester.FRegisteredTests[LSortedKeys[LI]];
        if SameText(LEntry.Category, LCat) then
          LSubMenu.Add(Format('#%d %s', [LSortedKeys[LI], LEntry.TestName]),
            MakeTestRunner(LSortedKeys[LI]));
      end;
    end;
  finally
    LCategories.Free();
  end;
end;

// The single registration path. Every RegisterTest/RegisterTests overload
// funnels through here.
procedure TTester.DoRegister(const AIndex: Integer;
  const ATestName: string;
  const ADependencies: array of string;
  const APlatforms: array of string;
  const ARunMode: TTestRunMode;
  const ADefine: string;
  const ADefineValue: string;
  const AOptLevels: TOptLevelSet);
var
  LEntry: TTestEntry;
  LI:     Integer;
begin
  LEntry.TestName             := ATestName;
  LEntry.Category             := FCurrentCategory;
  LEntry.RunMode              := ARunMode;
  LEntry.DefineName           := ADefine;
  LEntry.DefineValue          := ADefineValue;
  LEntry.OptLevels            := AOptLevels;  // [] = use global default
  LEntry.Subsystem            := stConsole;
  LEntry.HasSubsystemOverride := False;       // use global default

  SetLength(LEntry.Dependencies, Length(ADependencies));
  for LI := 0 to High(ADependencies) do
    LEntry.Dependencies[LI] := ADependencies[LI];

  // [] means the test is target-agnostic and runs on every target.
  SetLength(LEntry.Platforms, Length(APlatforms));
  for LI := 0 to High(APlatforms) do
    LEntry.Platforms[LI] := APlatforms[LI];

  FRegisteredTests.AddOrSetValue(NextFreeKey(AIndex), LEntry);
end;

procedure TTester.RegisterTest(const AIndex: Integer;
  const ATestName: string; const ARunMode: TTestRunMode;
  const ADefine: string; const ADefineValue: string;
  const AOptLevels: TOptLevelSet);
begin
  DoRegister(AIndex, ATestName, [], [], ARunMode, ADefine, ADefineValue,
    AOptLevels);
end;

procedure TTester.RegisterTest(const AIndex: Integer;
  const ATestName: string; const ARunMode: TTestRunMode;
  const APlatforms: array of string;
  const ADefine: string; const ADefineValue: string;
  const AOptLevels: TOptLevelSet);
begin
  DoRegister(AIndex, ATestName, [], APlatforms, ARunMode, ADefine,
    ADefineValue, AOptLevels);
end;

procedure TTester.RegisterTests(const AIndex: Integer;
  const ATestName: string; const ADependencies: array of string;
  const ARunMode: TTestRunMode; const ADefine: string;
  const ADefineValue: string;
  const AOptLevels: TOptLevelSet);
begin
  DoRegister(AIndex, ATestName, ADependencies, [], ARunMode, ADefine,
    ADefineValue, AOptLevels);
end;

procedure TTester.RegisterTests(const AIndex: Integer;
  const ATestName: string; const ADependencies: array of string;
  const ARunMode: TTestRunMode;
  const APlatforms: array of string;
  const ADefine: string; const ADefineValue: string;
  const AOptLevels: TOptLevelSet);
begin
  DoRegister(AIndex, ATestName, ADependencies, APlatforms, ARunMode, ADefine,
    ADefineValue, AOptLevels);
end;

procedure TTester.ClearRegisteredTests();
begin
  FRegisteredTests.Clear();
end;

procedure TTester.SetTestOptLevels(const AIndex: Integer;
  const AOptLevels: TOptLevelSet);
var
  LEntry: TTestEntry;
begin
  if FRegisteredTests.TryGetValue(AIndex, LEntry) then
  begin
    LEntry.OptLevels := AOptLevels;
    FRegisteredTests[AIndex] := LEntry;
  end;
end;

procedure TTester.SetTestSubsystem(const AIndex: Integer;
  const ASubsystem: TSubsystemType);
var
  LEntry: TTestEntry;
begin
  if FRegisteredTests.TryGetValue(AIndex, LEntry) then
  begin
    LEntry.Subsystem := ASubsystem;
    LEntry.HasSubsystemOverride := True;
    FRegisteredTests[AIndex] := LEntry;
  end;
end;

function TTester.GetFailedTests(): TArray<string>;
begin
  Result := FFailedTests.ToArray();
end;

function TTester.GetRegisteredTestCount(): Integer;
begin
  Result := FRegisteredTests.Count;
end;

procedure TTester.Print(const AText: string);
begin
  if Assigned(FOutputCallback) then
    FOutputCallback(AText)
  else
    TConsole.PrintLn(AText);
end;

procedure TTester.Print(const AFormat: string;
  const AArgs: array of const);
var
  LText: string;
begin
  LText := Format(AFormat, AArgs);

  if Assigned(FOutputCallback) then
    FOutputCallback(LText)
  else
    TConsole.PrintLn(LText);
end;

function TTester.ExtractExpected(const ASource: string): string;
var
  LStart:  Integer;
  LEnd:    Integer;
  LBlock:  string;
  LPrefix: string;
begin
  Result  := '';
  LPrefix := MYR_COMMENT_OPEN + ' EXPECT:';

  LStart := ASource.IndexOf(LPrefix);
  if LStart < 0 then
    Exit;

  LStart := LStart + Length(LPrefix);
  LEnd   := ASource.IndexOf(MYR_COMMENT_CLOSE, LStart);
  if LEnd < 0 then
    Exit;

  LBlock := ASource.Substring(LStart, LEnd - LStart);
  Result := LBlock.Trim();
end;

function TTester.ExtractExpectedExitCode(
  const ASource: string): Integer;
var
  LStart:  Integer;
  LEnd:    Integer;
  LValue:  string;
  LPrefix: string;
begin
  Result  := 0;
  LPrefix := MYR_COMMENT_OPEN + ' EXITCODE:';

  LStart := ASource.IndexOf(LPrefix);
  if LStart < 0 then
    Exit;

  LStart := LStart + Length(LPrefix);
  LEnd   := ASource.IndexOf(MYR_COMMENT_CLOSE, LStart);
  if LEnd < 0 then
    Exit;

  LValue := ASource.Substring(LStart, LEnd - LStart).Trim();
  Result := StrToIntDef(LValue, 0);
end;

function TTester.ExtractAllowWarnings(
  const ASource: string): Boolean;
begin
  Result := ASource.Contains(
    MYR_COMMENT_OPEN + ' ALLOW_WARNINGS ' + MYR_COMMENT_CLOSE);
end;

// The targets a test will be built against.
//
// A test's own platform list IS its target list -- register with
// [MYR_TARGET_WIN64] and it builds win64 only, wherever it is run from. An
// EMPTY list means the test is target-agnostic and falls back to the tester's
// Targets (all six by default).
function TTester.ResolveTargets(
  const APlatforms: TArray<string>): TArray<string>;
begin
  if Length(APlatforms) > 0 then
    Result := APlatforms
  else
    Result := FTargets;
end;

// A test's own opt-level set IS its optimization matrix. [] falls back to the
// tester's OptLevels. Debug mode always forces olDebug -- stepping through
// optimized code is useless.
function TTester.ResolveOptLevels(const AOptLevels: TOptLevelSet;
  const ARunMode: TTestRunMode): TOptLevelSet;
begin
  if ARunMode = rmDebug then
    Result := [olDebug]
  else if AOptLevels <> [] then
    Result := AOptLevels
  else
    Result := FOptLevels;
end;

// 'Debug', 'ReleaseFast', ... -- used in the per-build header and in the
// failure list, so a failure names the exact (target, level) cell.
function TTester.OptLevelName(const AOptLevel: TOptimizeLevel): string;
begin
  Result := GetEnumName(TypeInfo(TOptimizeLevel), Ord(AOptLevel));

  // Strip the 'ol' enum prefix.
  if Result.StartsWith('ol') then
    Result := Result.Substring(2);
end;

function TTester.FindEntry(const ATestName: string;
  out AEntry: TTestEntry): Boolean;
var
  LEntry: TTestEntry;
begin
  Result := False;
  for LEntry in FRegisteredTests.Values do
  begin
    if SameText(LEntry.TestName, ATestName) then
    begin
      AEntry := LEntry;
      Exit(True);
    end;
  end;
end;

// Accumulate a per-target result. FTargetOrder preserves first-seen order so
// the matrix prints in the order the targets were actually exercised.
procedure TTester.DoTally(const ATarget: string; const APass: Integer;
  const AFail: Integer; const ASkip: Integer);
var
  LValue: Integer;
begin
  if not FTargetOrder.Contains(ATarget) then
    FTargetOrder.Add(ATarget);

  if not FTargetPass.TryGetValue(ATarget, LValue) then
    LValue := 0;
  FTargetPass.AddOrSetValue(ATarget, LValue + APass);

  if not FTargetFail.TryGetValue(ATarget, LValue) then
    LValue := 0;
  FTargetFail.AddOrSetValue(ATarget, LValue + AFail);

  if not FTargetSkip.TryGetValue(ATarget, LValue) then
    LValue := 0;
  FTargetSkip.AddOrSetValue(ATarget, LValue + ASkip);
end;

procedure TTester.PrintMatrix();
var
  LI:      Integer;
  LTarget: string;
  LPass:   Integer;
  LFail:   Integer;
  LSkip:   Integer;
  LColor:  string;
begin
  if FTargetOrder.Count = 0 then
    Exit;

  Print('');
  Print(COLOR_CYAN + '=== TARGET MATRIX ===');
  Print(COLOR_WHITE +
    Format('%-14s %6s %6s %6s', ['TARGET', 'PASS', 'FAIL', 'SKIP']));

  for LI := 0 to FTargetOrder.Count - 1 do
  begin
    LTarget := FTargetOrder[LI];

    if not FTargetPass.TryGetValue(LTarget, LPass) then
      LPass := 0;
    if not FTargetFail.TryGetValue(LTarget, LFail) then
      LFail := 0;
    if not FTargetSkip.TryGetValue(LTarget, LSkip) then
      LSkip := 0;

    if LFail = 0 then
      LColor := COLOR_GREEN
    else
      LColor := COLOR_RED;

    Print(LColor + Format('%-14s %6d %6d %6d',
      [LTarget, LPass, LFail, LSkip]));
  end;
end;

function TTester.ExtractTestName(const AFilePath: string): string;
begin
  Result := TPath.GetFileNameWithoutExtension(AFilePath);
end;

// Push every per-run setting onto a freshly created engine.
procedure TTester.DoConfigureEngine(const AEngine: TEngine;
  const AOptLevel: TOptimizeLevel;
  const ASubsystem: TSubsystemType;
  const ADefine: string;
  const ADefineValue: string);
begin
  AEngine.SetOutputPath(FOutputPath);

  // Curated alias -> full Zig triple. A test file carrying its own @target
  // directive overrides this during the emitter pre-scan.
  if not AEngine.SetTargetAlias(FTarget) then
    Print(COLOR_RED + 'ERROR: Unknown target: ' + FTarget);

  AEngine.SetOptimizeLevel(AOptLevel);
  AEngine.SetSubsystem(ASubsystem);

  if ADefine <> '' then
  begin
    if ADefineValue <> '' then
      AEngine.SetDefine(ADefine, ADefineValue)
    else
      AEngine.SetDefine(ADefine);
  end;

  // Build output (zig cc) is ALWAYS forwarded -- without it a failing build
  // reports nothing useful. Status is the chatty pipeline commentary and is
  // opt-in via ShowStatus.
  AEngine.SetOutputCallback(
    procedure(const ALine: string; const AUserData: Pointer)
    begin
      // Raw: build output already carries its own line breaks.
      if Assigned(FOutputCallback) then
        FOutputCallback(ALine)
      else
        TConsole.Print(ALine);
    end);

  if FShowStatus then
  begin
    AEngine.SetStatusCallback(
      procedure(const AText: string; const AUserData: Pointer)
      begin
        Print(AText);
      end);
  end;
end;

procedure TTester.DoRunDebugger(const AExePath: string);
var
  LREPL: TDebugREPL;
begin
  if not TFile.Exists(AExePath) then
  begin
    Print(COLOR_RED + 'Executable not found: ' + AExePath);
    Exit;
  end;

  Print(COLOR_CYAN + 'Launching debugger for: %s', [AExePath]);
  Print('');

  LREPL := TDebugREPL.Create();
  try
    LREPL.Run(AExePath);
  finally
    LREPL.Free();
  end;
end;

// Build every dependency of a test at the CURRENT (FTarget, AOptLevel) cell.
//
// A dep does NOT own a target list or an opt-level set -- it INHERITS both from
// the test consuming it. The build artifact is a single file on disk
// (output/zig-out/bin/<dep>.dll) and every build overwrites it, so the dep must
// be regenerated immediately before EACH parent build, not once up front.
//
// A dep is infrastructure for its parent, not a test result -- it is never
// tallied and never added to FFailedTests.
function TTester.DoRunDeps(const ADependencies: TArray<string>;
  const AOptLevel: TOptimizeLevel): Boolean;
var
  LDep:       string;
  LEntry:     TTestEntry;
  LFilePath:  string;
  LExt:       string;
  LSubsystem: TSubsystemType;
begin
  Result := True;

  if Length(ADependencies) = 0 then
    Exit;

  LExt := GetSourceExt();
  if LExt = '' then
    Exit(False);

  for LDep in ADependencies do
  begin
    // The dep's own registration supplies its define and subsystem. It does
    // NOT supply its target or opt level -- the consumer dictates those.
    LEntry := Default(TTestEntry);
    FindEntry(LDep, LEntry);

    if LEntry.HasSubsystemOverride then
      LSubsystem := LEntry.Subsystem
    else
      LSubsystem := FSubsystem;

    LFilePath := TPath.Combine(FTestFolder,
      TPath.ChangeExtension(LDep, LExt));

    if not TFile.Exists(LFilePath) then
    begin
      Print(COLOR_RED + 'ERROR: Dependency not found: ' + LFilePath);
      Exit(False);
    end;

    Print(COLOR_BLUE + '[dep] ' + LDep);

    // rmNone: a dependency is compiled, never run.
    if not RunTestFileAtLevel(LFilePath, rmNone, AOptLevel, LSubsystem,
      LEntry.DefineName, LEntry.DefineValue) then
    begin
      Print(COLOR_RED + 'Dependency build failed: ' + LDep);
      Exit(False);
    end;

    Print('');
  end;
end;

function TTester.RunTestFileAtLevel(const AFilePath: string;
  const ARunMode: TTestRunMode;
  const AOptLevel: TOptimizeLevel;
  const ASubsystem: TSubsystemType;
  const ADefine: string;
  const ADefineValue: string): Boolean;
var
  LEngine:           TEngine;
  LErrors:           TErrors;
  LExitCode:         Cardinal;
  LSource:           string;
  LExpected:         string;
  LExpectedExitCode: Integer;
  LAllowWarnings:    Boolean;
  LTestName:         string;
  LExePath:          string;
  LAutoRun:          Boolean;
  LDidRun:           Boolean;
  LHasWarnings:      Boolean;
begin
  LExitCode := 0;
  LExePath  := '';

  LSource           := TFile.ReadAllText(AFilePath);
  LExpected         := ExtractExpected(LSource);
  LExpectedExitCode := ExtractExpectedExitCode(LSource);
  LAllowWarnings    := ExtractAllowWarnings(LSource);
  LTestName         := ExtractTestName(AFilePath);

  Print(COLOR_CYAN + '[%s] [opt %s] %s',
    [FTarget, OptLevelName(AOptLevel), LTestName]);

  // rmExecute only actually launches on an auto-run target. The engine owns
  // that knowledge -- it is decided from the resolved triple, not the alias.
  LDidRun := False;

  LEngine := TEngine.Create();
  try
    DoConfigureEngine(LEngine, AOptLevel, ASubsystem, ADefine, ADefineValue);

    LAutoRun := (ARunMode = rmExecute) and LEngine.CanAutoRun();

    // Compile against the langdef on disk. Auto-run is folded into the
    // pipeline -- there is no separate Run step.
    LEngine.Compile(FLangFile, AFilePath, FOutputPath, LAutoRun);

    LErrors      := LEngine.GetErrors();
    Result       := not LErrors.HasErrors();
    LHasWarnings := LErrors.HasWarnings();

    if LAutoRun and Result then
    begin
      LExitCode := LEngine.GetLastExitCode();
      LDidRun   := True;
    end;

    // Capture the exe path before the engine goes away
    if ARunMode = rmDebug then
      LExePath := TPath.GetFullPath(
        TPath.Combine(FOutputPath, 'zig-out\bin\' +
          LEngine.GetProjectName() + '.exe'));

    // Print any errors/warnings/hints. PrintErrors() is inherited from
    // TBaseObject and labels each item by severity (HINT/WARNING/ERROR).
    LEngine.PrintErrors();
  finally
    LEngine.Free();
  end;

  // Exit if the build failed
  if not Result then
  begin
    // Tolerate a build "failure" when a non-zero exit code was expected
    // and the actual exit code matches
    if LDidRun and (LExpectedExitCode <> 0) and
       (LExitCode = Cardinal(LExpectedExitCode)) then
      Result := True
    else
    begin
      Print(COLOR_RED + 'Build failed.');
      Exit;
    end;
  end;

  // Check for warnings (fail unless allowed)
  if LHasWarnings and (not LAllowWarnings) then
  begin
    Print(COLOR_RED + 'Test failed: warnings present (use ' +
      MYR_COMMENT_OPEN + ' ALLOW_WARNINGS ' +
      MYR_COMMENT_CLOSE + ' to allow).');
    Result := False;
    Exit;
  end;

  Print(COLOR_GREEN + 'Build OK');

  if ARunMode = rmExecute then
  begin
    if not LDidRun then
    begin
      // Built fine, but this target cannot self-run, so EXITCODE is
      // unverifiable. Warn rather than fail.
      Print(COLOR_YELLOW +
        'Not run: target %s cannot auto-run. Exit code not verified.',
        [FTarget]);
      Exit;
    end;

    if LExitCode <> Cardinal(LExpectedExitCode) then
    begin
      Print(COLOR_RED +
        '  Test failed: expected exit code %d, got %d.',
        [LExpectedExitCode, LExitCode]);
      Result := False;
      Exit;
    end;

    if LExpected <> '' then
    begin
      Print(COLOR_YELLOW + '[EXPECTED]');
      Print(LExpected);
    end;
  end;

  // Launch the debug REPL only after the engine has been freed
  if (ARunMode = rmDebug) and Result then
    DoRunDebugger(LExePath);
end;

function TTester.RunTestFile(const AFilePath: string;
  const ADependencies: TArray<string>;
  const ARunMode: TTestRunMode;
  const ADefine: string;
  const ADefineValue: string;
  const AOptLevels: TOptLevelSet;
  const ASubsystem: TSubsystemType;
  const AHasSubsystemOverride: Boolean): Boolean;
var
  LEffectiveOptLevels: TOptLevelSet;
  LEffectiveSubsystem: TSubsystemType;
  LOpt:                TOptimizeLevel;
  LTestName:           string;
begin
  Result           := True;
  FLastTestSkipped := False;

  if not TFile.Exists(AFilePath) then
  begin
    Print(COLOR_RED + 'ERROR: File not found: ' + AFilePath);
    Result := False;
    Exit;
  end;

  LTestName := ExtractTestName(AFilePath);

  Print(COLOR_CYAN + '=== Test: ' + LTestName + ' ===');
  Print('');

  // Resolve effective settings: per-test overrides or global defaults.
  LEffectiveOptLevels := ResolveOptLevels(AOptLevels, ARunMode);

  if AHasSubsystemOverride then
    LEffectiveSubsystem := ASubsystem
  else
    LEffectiveSubsystem := FSubsystem;

  // Run at each optimization level
  for LOpt in LEffectiveOptLevels do
  begin
    // Regenerate every dependency at THIS (FTarget, LOpt) cell, immediately
    // before the parent build. A dep failure fails the parent for this cell
    // only -- continue to the next cell rather than aborting the run.
    if not DoRunDeps(ADependencies, LOpt) then
    begin
      Result := False;

      FFailedTests.Add(Format('%s [%s/%s] (dependency failed)',
        [LTestName, FTarget, OptLevelName(LOpt)]));

      Continue;
    end;

    if not RunTestFileAtLevel(AFilePath, ARunMode, LOpt,
      LEffectiveSubsystem, ADefine, ADefineValue) then
    begin
      Result := False;

      // Name the exact failing cell: test [target/level]
      FFailedTests.Add(Format('%s [%s/%s]',
        [LTestName, FTarget, OptLevelName(LOpt)]));

      // Continue to next opt level -- report all failures
    end;
  end;
end;

function TTester.RunTest(const ATestName: string;
  const ARunMode: TTestRunMode; const ADefine: string;
  const ADefineValue: string; const AOptLevels: TOptLevelSet;
  const ASubsystem: TSubsystemType;
  const AHasSubsystemOverride: Boolean): Boolean;
var
  LFilePath: string;
  LEntry:    TTestEntry;
  LExt:      string;
  LTargets:  TArray<string>;
  LI:        Integer;
begin
  LExt := GetSourceExt();
  if LExt = '' then
    Exit(False);

  FLastTestSkipped := False;

  // An unregistered test (run by file scan or pattern) has no entry, so it
  // has no platform list and falls back to the tester's Targets.
  LEntry := Default(TTestEntry);

  // An entry supplies the platform list and the dependency list. Dependencies
  // are NOT built here -- they are rebuilt per (target, opt level) cell inside
  // RunTestFile, immediately before each parent build.
  FindEntry(ATestName, LEntry);

  LFilePath := TPath.Combine(FTestFolder,
    TPath.ChangeExtension(ATestName, LExt));

  // The test's platform list IS its target list. Build it against each.
  LTargets := ResolveTargets(LEntry.Platforms);

  Result := True;
  for LI := 0 to High(LTargets) do
  begin
    FTarget := LTargets[LI];

    if not RunTestFile(LFilePath, LEntry.Dependencies, ARunMode, ADefine,
      ADefineValue, AOptLevels, ASubsystem, AHasSubsystemOverride) then
    begin
      // RunTestFile already named the failing (target/level) cells.
      Result := False;
      Inc(FFailCount);
      DoTally(FTarget, 0, 1, 0);
    end
    else
    begin
      Inc(FPassCount);
      DoTally(FTarget, 1, 0, 0);
    end;

    if LI < High(LTargets) then
    begin
      Print('');
      Print(COLOR_BLUE + '- - - - - - - - - - - - - - - - - - - - ');
      Print('');
    end;
  end;
end;

function TTester.RunTestByIndex(const AIndex: Integer): Boolean;
var
  LEntry: TTestEntry;
begin
  Result := True;
  if AIndex < 0 then
  begin
    RunAllTests();
    Exit(FFailCount = 0);
  end;

  if not FRegisteredTests.TryGetValue(AIndex, LEntry) then
  begin
    Print(COLOR_RED + 'ERROR: Test index %d not found', [AIndex]);
    Exit(False);
  end;

  Reset();
  Print(COLOR_CYAN + 'Running test #%d...', [AIndex]);
  Print('');

  if not RunTest(LEntry.TestName, LEntry.RunMode,
    LEntry.DefineName, LEntry.DefineValue,
    LEntry.OptLevels, LEntry.Subsystem,
    LEntry.HasSubsystemOverride) then
    Result := False;

  Print('');
  PrintResults();
  PrintMatrix();
end;

function TTester.RunAllTests(): Integer;
var
  LFiles:      TStringDynArray;
  LFile:       string;
  LTotal:      Integer;
  LEntry:      TTestEntry;
  LI:          Integer;
  LSortedKeys: TArray<Integer>;
  LExt:        string;
begin
  Reset();

  if not TDirectory.Exists(FTestFolder) then
  begin
    Print(COLOR_RED + 'ERROR: Test folder not found: ' + FTestFolder);
    Exit(0);
  end;

  // If tests have been registered, run them in key order
  if FRegisteredTests.Count > 0 then
  begin
    LTotal := FRegisteredTests.Count;
    Print(COLOR_CYAN +
      'Running %d registered test(s) in order...', [LTotal]);
    Print('');

    LSortedKeys := FRegisteredTests.Keys.ToArray();
    TArray.Sort<Integer>(LSortedKeys);

    for LI := 0 to High(LSortedKeys) do
    begin
      LEntry := FRegisteredTests[LSortedKeys[LI]];
      RunTest(LEntry.TestName, LEntry.RunMode,
        LEntry.DefineName, LEntry.DefineValue,
        LEntry.OptLevels, LEntry.Subsystem,
        LEntry.HasSubsystemOverride);
      Print('');
      Print(COLOR_BLUE + '----------------------------------------');
      Print('');
    end;
  end
  else
  begin
    // No registered tests -- scan directory (alphabetical)
    LExt := GetSourceExt();
    if LExt = '' then
      Exit(0);

    LFiles := TDirectory.GetFiles(FTestFolder, 'test_*' + LExt);
    TArray.Sort<string>(LFiles);
    LTotal := Length(LFiles);

    Print(COLOR_CYAN +
      'Found %d test(s) in %s', [LTotal, FTestFolder]);
    Print('');

    for LFile in LFiles do
    begin
      // Route through RunTest so the per-target loop and tally apply. An
      // unscanned file has no entry, so it runs on the tester's Targets.
      RunTest(TPath.GetFileNameWithoutExtension(LFile), rmNone);
      Print('');
      Print(COLOR_BLUE + '----------------------------------------');
      Print('');
    end;
  end;

  PrintResults();
  PrintMatrix();
  Result := FPassCount;
end;

// Run the registered suite. Each test loops its OWN target list (its platform
// list, or the tester's Targets when it declared none), so this is already a
// full matrix run -- there is no separate per-target pass.
function TTester.RunAllTargets(): Boolean;
begin
  if FRegisteredTests.Count = 0 then
  begin
    Print(COLOR_RED + 'ERROR: No registered tests.');
    Exit(False);
  end;

  RunAllTests();

  Print('');
  if FFailCount = 0 then
    Print(COLOR_GREEN + 'ALL TARGETS GREEN')
  else
    Print(COLOR_RED + 'ONE OR MORE TARGETS FAILED');

  Result := FFailCount = 0;
end;

function TTester.RunTestsMatching(const APattern: string;
  const ARunMode: TTestRunMode): Integer;
var
  LFiles:    TStringDynArray;
  LFile:     string;
  LTestName: string;
  LEntry:    TTestEntry;
  LRunMode:  TTestRunMode;
  LDefine:   string;
  LDefVal:   string;
  LOptLvls:  TOptLevelSet;
  LSubsys:   TSubsystemType;
  LHasSub:   Boolean;
  LKey:      Integer;
  LExt:      string;
begin
  Reset();

  if not TDirectory.Exists(FTestFolder) then
  begin
    Print(COLOR_RED + 'ERROR: Test folder not found: ' + FTestFolder);
    Exit(0);
  end;

  LExt := GetSourceExt();
  if LExt = '' then
    Exit(0);

  LFiles := TDirectory.GetFiles(FTestFolder, 'test_*' + LExt);
  TArray.Sort<string>(LFiles);

  for LFile in LFiles do
  begin
    if TPath.GetFileName(LFile).Contains(APattern) then
    begin
      LTestName := TPath.GetFileNameWithoutExtension(LFile);

      // Look up registered entry to use its settings
      LRunMode := ARunMode;
      LDefine  := '';
      LDefVal  := '';
      LOptLvls := [];
      LSubsys  := stConsole;
      LHasSub  := False;
      for LKey in FRegisteredTests.Keys do
      begin
        LEntry := FRegisteredTests[LKey];
        if SameText(LEntry.TestName, LTestName) then
        begin
          LRunMode := LEntry.RunMode;
          LDefine  := LEntry.DefineName;
          LDefVal  := LEntry.DefineValue;
          LOptLvls := LEntry.OptLevels;
          LSubsys  := LEntry.Subsystem;
          LHasSub  := LEntry.HasSubsystemOverride;
          Break;
        end;
      end;

      // Route through RunTest so the per-target loop and tally apply.
      RunTest(LTestName, LRunMode, LDefine, LDefVal,
        LOptLvls, LSubsys, LHasSub);

      Print('');
      Print(COLOR_BLUE + '----------------------------------------');
      Print('');
    end;
  end;

  Print('Pattern: ' + APattern);
  PrintResults();
  PrintMatrix();
  Result := FPassCount;
end;

procedure TTester.PrintResults();
var
  LTotal: Integer;
  LI:     Integer;
begin
  LTotal := FPassCount + FFailCount + FSkipCount;

  Print('');
  Print(COLOR_CYAN + '=== RESULTS ===');
  if FFailCount = 0 then
  begin
    Print(COLOR_GREEN + 'Passed: %d / %d', [FPassCount, LTotal]);
    if FSkipCount > 0 then
      Print(COLOR_YELLOW + 'Skipped: %d', [FSkipCount]);
  end
  else
  begin
    Print(COLOR_RED + 'Passed: %d / %d', [FPassCount, LTotal]);
    if FSkipCount > 0 then
      Print(COLOR_YELLOW + 'Skipped: %d', [FSkipCount]);
    Print('');
    Print(COLOR_RED + 'Failed tests:');
    for LI := 0 to FFailedTests.Count - 1 do
      Print(COLOR_RED + '  - ' + FFailedTests[LI]);
  end;
end;

procedure TTester.SaveTests(const AFilename: string);
var
  LPath:  string;
  LKeys:  TArray<Integer>;
  LI:     Integer;
  LEntry: TTestEntry;
  LJson:  TJSON;
  LJ:     Integer;
  LOpt:   TOptimizeLevel;
begin
  LPath := TPath.Combine(FTestFolder, AFilename);

  LKeys := FRegisteredTests.Keys.ToArray();
  TArray.Sort<Integer>(LKeys);

  LJson := TJSON.Create();
  try
    LJson.BeginArray('tests');

    for LI := 0 to High(LKeys) do
    begin
      LEntry := FRegisteredTests[LKeys[LI]];

      LJson.BeginObject();
      LJson.Add('index', LKeys[LI]);
      LJson.Add('name', LEntry.TestName);

      if LEntry.Category <> '' then
        LJson.Add('category', LEntry.Category);

      if Length(LEntry.Dependencies) > 0 then
      begin
        LJson.BeginArray('deps');
        for LJ := 0 to High(LEntry.Dependencies) do
          LJson.Add(LEntry.Dependencies[LJ]);
        LJson.EndArray();
      end;

      // Absent means: runs on every target.
      if Length(LEntry.Platforms) > 0 then
      begin
        LJson.BeginArray('platforms');
        for LJ := 0 to High(LEntry.Platforms) do
          LJson.Add(LEntry.Platforms[LJ]);
        LJson.EndArray();
      end;

      if LEntry.RunMode = rmNone then
        LJson.Add('run_mode', 'none')
      else if LEntry.RunMode = rmDebug then
        LJson.Add('run_mode', 'debug')
      else
        LJson.Add('run_mode', 'execute');

      if LEntry.DefineName <> '' then
        LJson.Add('define', LEntry.DefineName);

      if LEntry.DefineValue <> '' then
        LJson.Add('define_value', LEntry.DefineValue);

      // Save per-test opt levels (if overridden)
      if LEntry.OptLevels <> [] then
      begin
        LJson.BeginArray('opt_levels');
        for LOpt := Low(TOptimizeLevel) to High(TOptimizeLevel) do
        begin
          if LOpt in LEntry.OptLevels then
            LJson.Add(Ord(LOpt));
        end;
        LJson.EndArray();
      end;

      // Save per-test subsystem (if overridden)
      if LEntry.HasSubsystemOverride then
      begin
        if LEntry.Subsystem = stGUI then
          LJson.Add('subsystem', 'gui')
        else
          LJson.Add('subsystem', 'console');
      end;

      LJson.EndObject();
    end;

    LJson.EndArray();
    LJson.SaveToFile(LPath);
  finally
    LJson.Free();
  end;
end;

function TTester.LoadTests(const AFilename: string): Boolean;
var
  LPath:        string;
  LJson:        TJSON;
  LTests:       TJSON;
  LItem:        TJSON;
  LIndex:       Integer;
  LName:        string;
  LDeps:        TArray<string>;
  LPlatforms:   TArray<string>;
  LRunModeStr:  string;
  LRunMode:     TTestRunMode;
  LDefine:      string;
  LDefineValue: string;
  LEntry:       TTestEntry;
  LOptItem:     TJSON;
  LSubStr:      string;
begin
  Result := False;
  LPath := TPath.Combine(FTestFolder, AFilename);

  if not TFile.Exists(LPath) then
    Exit;

  LJson := TJSON.FromFile(LPath);
  try
    LTests := LJson.Get('tests');
    if LTests.IsNull() then
      Exit;

    ClearRegisteredTests();

    for LItem in LTests do
    begin
      LName := LItem.Get('name').AsString();
      if LName = '' then
        Continue;

      LIndex       := LItem.Get('index').AsInt32(0);
      LDefine      := LItem.Get('define').AsString();
      LDefineValue := LItem.Get('define_value').AsString();

      // Extract dependencies array
      if LItem.Has('deps') then
        LDeps := LItem.Get('deps').AsStringArray()
      else
        SetLength(LDeps, 0);

      // Absent means: runs on every target.
      if LItem.Has('platforms') then
        LPlatforms := LItem.Get('platforms').AsStringArray()
      else
        SetLength(LPlatforms, 0);

      // Determine run mode
      LRunModeStr := LItem.Get('run_mode').AsString();
      if SameText(LRunModeStr, 'none') then
        LRunMode := rmNone
      else if SameText(LRunModeStr, 'debug') then
        LRunMode := rmDebug
      else
        LRunMode := rmExecute;

      LEntry.TestName             := LName;
      LEntry.Category             := LItem.Get('category').AsString();
      LEntry.Dependencies         := LDeps;
      LEntry.Platforms            := LPlatforms;
      LEntry.RunMode              := LRunMode;
      LEntry.DefineName           := LDefine;
      LEntry.DefineValue          := LDefineValue;
      LEntry.OptLevels            := [];
      LEntry.Subsystem            := stConsole;
      LEntry.HasSubsystemOverride := False;

      // Load per-test opt levels (if present)
      if LItem.Has('opt_levels') then
      begin
        LEntry.OptLevels := [];
        for LOptItem in LItem.Get('opt_levels') do
          Include(LEntry.OptLevels, TOptimizeLevel(LOptItem.AsInt32(0)));
      end;

      // Load per-test subsystem (if present)
      if LItem.Has('subsystem') then
      begin
        LSubStr := LItem.Get('subsystem').AsString();
        if SameText(LSubStr, 'gui') then
          LEntry.Subsystem := stGUI
        else
          LEntry.Subsystem := stConsole;
        LEntry.HasSubsystemOverride := True;
      end;

      FRegisteredTests.Add(LIndex, LEntry);
    end;

    Result := FRegisteredTests.Count > 0;
  finally
    LJson.Free();
  end;
end;

end.
