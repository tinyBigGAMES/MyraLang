{===============================================================================
  Myra™ - Pascal. Refined.

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://myralang.org

  See LICENSE for license information
===============================================================================}

unit Myra.CLI;

{$I StdApp.Defines.inc}

interface

uses
  System.IOUtils,
  StdApp.Base,
  StdApp.Utils,
  StdApp.Console,
  Myra.Common,
  Myra.Engine;

type
  { TMyrCLI }
  TMyrCLI = class
  private
    FEngine:     TEngine;
    FSourceFile: string;
    FOutputPath: string;
    FAutoRun:    Boolean;
    FDebug:      Boolean;
    procedure ShowBanner();
    procedure ShowHelp();
    procedure ShowErrors();
    procedure SetupCallbacks();
    function  ParseArgs(): Boolean;
    procedure RunCompile();
    procedure RunDebug();
  public
    constructor Create(); virtual;
    destructor Destroy(); override;
    procedure Execute();
  end;

implementation

uses
  System.SysUtils,
  Myra.Build,
  StdApp.Resources,
  Myra.Debug.REPL;

{ TMyrCLI }

constructor TMyrCLI.Create();
begin
  inherited Create();
  FEngine     := TEngine.Create();
  FSourceFile := '';
  FOutputPath := 'output';
  FAutoRun    := False;
  FDebug      := False;
end;

destructor TMyrCLI.Destroy();
begin
  FreeAndNil(FEngine);
  inherited Destroy();
end;

procedure TMyrCLI.ShowBanner();
var
  LVersion: TVersionInfo;
begin
  if TUtils.GetVersionInfo(LVersion, '') then
  begin
    TConsole.PrintLn(COLOR_WHITE + COLOR_BOLD + LVersion.ProductName + ' v' + LVersion.VersionString);
    TConsole.PrintLn(COLOR_WHITE + LVersion.Copyright);
    if LVersion.URL <> '' then
      TConsole.PrintLn(COLOR_YELLOW + LVersion.URL);
  end
  else
  begin
    TConsole.PrintLn(COLOR_WHITE + COLOR_BOLD + 'Myra™ Compiler v0.0.0');
    TConsole.PrintLn(COLOR_WHITE + 'Copyright © 2025-present tinyBigGAMES™ LLC, All Rights Reserved.');
  end;
  TConsole.PrintLn('');
end;

procedure TMyrCLI.ShowHelp();
var
  LExeName: string;
begin
  LExeName := TPath.GetFileNameWithoutExtension(ParamStr(0));

  TConsole.PrintLn(COLOR_WHITE +
    'Syntax: ' + LExeName + ' -s <file> [options]');
  TConsole.PrintLn('');
  TConsole.PrintLn(COLOR_BOLD + 'REQUIRED:');
  TConsole.PrintLn('  ' + COLOR_CYAN + '-s, --source  <file>' + COLOR_RESET +
    '   Source file to compile');
  TConsole.PrintLn('');
  TConsole.PrintLn(COLOR_BOLD + 'OPTIONS:');
  TConsole.PrintLn('  ' + COLOR_CYAN + '-o, --output  <path>' + COLOR_RESET +
    '   Output path (default: output)');
  TConsole.PrintLn('  ' + COLOR_CYAN + '-r, --autorun       ' + COLOR_RESET +
    '   Build and run the compiled binary');
  TConsole.PrintLn('  ' + COLOR_CYAN + '-d, --debug         ' + COLOR_RESET +
    '   Build and debug the compiled binary');
  TConsole.PrintLn('  ' + COLOR_CYAN + '-h, --help          ' + COLOR_RESET +
    '   Display this help message');
  TConsole.PrintLn('');
  TConsole.PrintLn(COLOR_BOLD + 'EXAMPLES:');
  TConsole.PrintLn('  ' + COLOR_CYAN +
    LExeName + ' -s hello.myra');
  TConsole.PrintLn('  ' + COLOR_CYAN +
    LExeName + ' -s hello.myra -o build');
  TConsole.PrintLn('  ' + COLOR_CYAN +
    LExeName + ' -s hello.myra -r');
  TConsole.PrintLn('');
end;

procedure TMyrCLI.ShowErrors();
begin
  FEngine.PrintErrors();
end;

procedure TMyrCLI.SetupCallbacks();
begin
  FEngine.SetStatusCallback(
    procedure(const AText: string; const AUserData: Pointer)
    begin
      TConsole.PrintLn(AText);
    end);

  FEngine.SetOutputCallback(
    procedure(const ALine: string; const AUserData: Pointer)
    begin
      TConsole.Print(ALine);
    end);
end;

function TMyrCLI.ParseArgs(): Boolean;
var
  LI:    Integer;
  LFlag: string;
begin
  Result := True;

  if ParamCount() = 0 then
  begin
    ShowHelp();
    Result := False;
    Exit;
  end;

  LI := 1;
  while LI <= ParamCount() do
  begin
    LFlag := ParamStr(LI).Trim();

    if (LFlag = '-h') or (LFlag = '--help') then
    begin
      ShowHelp();
      Result := False;
      Exit;
    end
    else if (LFlag = '-s') or (LFlag = '--source') then
    begin
      Inc(LI);
      if LI > ParamCount() then
      begin
        TConsole.PrintLn(COLOR_RED + 'Error: ' + LFlag +
          ' requires a file argument');
        TConsole.PrintLn('');
        ExitCode := 2;
        Result := False;
        Exit;
      end;
      FSourceFile := ParamStr(LI).Trim();
    end
    else if (LFlag = '-o') or (LFlag = '--output') then
    begin
      Inc(LI);
      if LI > ParamCount() then
      begin
        TConsole.PrintLn(COLOR_RED + 'Error: ' + LFlag +
          ' requires a path argument');
        TConsole.PrintLn('');
        ExitCode := 2;
        Result := False;
        Exit;
      end;
      FOutputPath := ParamStr(LI).Trim();
    end
    else if (LFlag = '-r') or (LFlag = '--autorun') then
    begin
      FAutoRun := True;
    end
    else if (LFlag = '-d') or (LFlag = '--debug') then
    begin
      FDebug := True;
    end
    else
    begin
      TConsole.PrintLn(COLOR_RED + 'Error: Unknown flag: ' +
        COLOR_YELLOW + LFlag);
      TConsole.PrintLn('');
      TConsole.PrintLn('Run ' + COLOR_CYAN + 'Myra -h' +
        COLOR_RESET + ' to see available options');
      TConsole.PrintLn('');
      ExitCode := 2;
      Result := False;
      Exit;
    end;

    Inc(LI);
  end;

  // Validate required arguments
  if FSourceFile = '' then
  begin
    TConsole.PrintLn(COLOR_RED +
      'Error: Source file is required (-s <file>)');
    TConsole.PrintLn('');
    TConsole.PrintLn('Run ' + COLOR_CYAN + 'Myra -h' +
      COLOR_RESET + ' to see available options');
    TConsole.PrintLn('');
    ExitCode := 2;
    Result := False;
    Exit;
  end;

  if FAutoRun and FDebug then
  begin
    TConsole.PrintLn(COLOR_RED +
      'Error: -r and -d cannot be used together');
    TConsole.PrintLn('');
    ExitCode := 2;
    Result := False;
    Exit;
  end;
end;

procedure TMyrCLI.RunCompile();
begin
  SetupCallbacks();

  FEngine.SetToolchainPath(TUtils.AppBasedPath(TOOLCHAIN_PATH));
  FEngine.Compile(MYR_RES_LANGDEF, FSourceFile, FOutputPath, FAutoRun);

  ShowErrors();

  if FEngine.GetErrors().HasErrors() then
  begin
    TConsole.PrintLn(COLOR_RED + 'Build failed.');
    ExitCode := 1;
  end
  else
  begin
    TConsole.PrintLn(COLOR_GREEN + 'Build OK');

    // The build succeeded. If the program was auto-run, ITS exit code becomes
    // the CLI's exit code. TBuild deliberately does NOT treat a non-zero
    // program exit as a build error -- the program merely returned a value --
    // so the CLI must surface that value here, or a failing program would
    // silently report success to the shell.
    if FAutoRun then
      ExitCode := FEngine.GetLastExitCode();
  end;
end;

procedure TMyrCLI.RunDebug();
var
  LExePath: string;
  LREPL: TDebugREPL;
begin
  // The debugger is win64 only. GetTarget() returns the resolved TRIPLE
  // ('x86_64-windows-gnu'), never the alias ('win64'), so compare against the
  // triple -- comparing against MYR_TARGET_WIN64 is always unequal and would
  // reject every target, win64 included.
  if not SameText(FEngine.GetTarget(), DEFAULT_TARGET) then
  begin
    TConsole.PrintLn(COLOR_RED + 'Error: ' + RSEngineAPIDebugWin64);
    ExitCode := 1;
    Exit;
  end;

  LExePath := TPath.GetFullPath(
    TPath.Combine(FOutputPath, 'zig-out\bin\' +
      FEngine.GetProjectName() + '.exe'));

  if not FileExists(LExePath) then
  begin
    TConsole.PrintLn(COLOR_RED + 'Executable not found: ' + LExePath);
    ExitCode := 1;
    Exit;
  end;

  LREPL := TDebugREPL.Create();
  try
    LREPL.Run(LExePath);
  finally
    LREPL.Free();
  end;
end;

procedure TMyrCLI.Execute();
begin
  ShowBanner();

  if not ParseArgs() then
    Exit;

  FOutputPath := TPath.GetFullPath(FOutputPath);

  try
    RunCompile();

    if FDebug and (not FEngine.GetErrors().HasErrors()) then
      RunDebug();
  except
    on E: Exception do
    begin
      TConsole.PrintLn('');
      TConsole.PrintLn(COLOR_RED + COLOR_BOLD + 'Fatal Error: %s', [E.Message]);
      TConsole.PrintLn('');
      ExitCode := 1;
    end;
  end;
end;

end.