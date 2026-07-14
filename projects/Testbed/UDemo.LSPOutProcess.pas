{===============================================================================
  Myra™ - Pascal. Refined.

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://myralang.org

  See LICENSE for license information
===============================================================================}

unit UDemo.LSPOutProcess;

(*
  LSP OUT-OF-PROCESS demo.

  Spawns the real MyraLSP.exe as a child process and talks JSON-RPC to it over
  real pipes -- exactly the way a code editor does. This is the transport that
  actually ships.

  It runs the SAME script as the in-process demo (TLSPDemoDriver is reused
  verbatim), so the two can be compared directly. If a capability works
  in-process and fails here, the fault is in the process/framing layer, not in
  the engine.

  This demo is also the only thing that genuinely proves the langdef path fix:
  the child is spawned with a working directory that is NOT bin\, so a relative
  langdef path would fail to resolve -- which is precisely the bug that
  UMyraaLSP.pas's AppBasedPath() call exists to prevent.
*)

interface

uses
  System.Classes,
  StdApp.TestDemo;

type
  { TLSPOutProcessDemo }
  TLSPOutProcessDemo = class(TTestDemo)
  private
    // Blast the prepared session at the child's stdin, then close the handle so
    // the server sees EOF and its message loop can terminate.
    procedure DoWriteToChild(const AHandle: THandle; const ASession: TStream);
    // Drain the child's stdout until the pipe closes.
    procedure DoReadFromChild(const AHandle: THandle; const AReplies: TStream);
  public
    constructor Create(); override;
    procedure OnRender(); override;
  end;

implementation

uses
  WinApi.Windows,
  System.SysUtils,
  System.IOUtils,
  StdApp.Console,
  StdApp.Utils,
  UDemo.LSPInProcess;

{ TLSPOutProcessDemo }

constructor TLSPOutProcessDemo.Create();
begin
  inherited;
  Title := 'LSP - Out-of-Process (real pipes to MyraLSP.exe)';
end;

procedure TLSPOutProcessDemo.DoWriteToChild(const AHandle: THandle;
  const ASession: TStream);
var
  LBuffer: TBytes;
  LWritten: DWORD;
begin
  SetLength(LBuffer, ASession.Size);
  ASession.Position := 0;
  if ASession.Size > 0 then
    ASession.ReadBuffer(LBuffer[0], ASession.Size);

  LWritten := 0;
  if Length(LBuffer) > 0 then
    WriteFile(AHandle, LBuffer[0], Length(LBuffer), LWritten, nil);

  // EOF. Without this the server would block forever waiting for more input.
  CloseHandle(AHandle);
end;

procedure TLSPOutProcessDemo.DoReadFromChild(const AHandle: THandle;
  const AReplies: TStream);
var
  LChunk: array[0..4095] of Byte;
  LRead: DWORD;
begin
  while True do
  begin
    LRead := 0;
    // ReadFile on a pipe blocks until data arrives, and returns False (or zero
    // bytes) once the write end is closed and the buffer is drained.
    if not ReadFile(AHandle, LChunk[0], SizeOf(LChunk), LRead, nil) then
      Break;
    if LRead = 0 then
      Break;
    AReplies.WriteBuffer(LChunk[0], LRead);
  end;
end;

procedure TLSPOutProcessDemo.OnRender();
var
  LDriver: TLSPDemoDriver;
  LSession: TMemoryStream;
  LReplies: TMemoryStream;
  LExe: string;
  LWorkDir: string;
  LStdinWrite: THandle;
  LStdoutRead: THandle;
  LProcess: THandle;
  LThread: THandle;
begin
  TConsole.PrintLn('');
  TConsole.PrintLn(COLOR_WHITE + COLOR_BOLD +
    '=== Myra LSP -- OUT-OF-PROCESS ===' + COLOR_RESET);
  TConsole.PrintLn(
    'Spawns MyraLSP.exe and speaks JSON-RPC over pipes, like a real editor.');

  LExe := TUtils.AppBasedPath('MyraLSP.exe');
  TConsole.PrintLn('Server:  ' + LExe);

  if not TFile.Exists(LExe) then
  begin
    TConsole.PrintLn('');
    TConsole.PrintLn(COLOR_RED +
      'ABORT: MyraLSP.exe has not been built.' + COLOR_RESET);
    TConsole.PrintLn(COLOR_YELLOW +
      'Build projects\LSP\MyraLSP.dproj in the IDE, then run this demo again.' +
      COLOR_RESET);
    Exit;
  end;

  // DELIBERATELY not bin\. The child must locate its langdef relative to its
  // own executable, not relative to whatever directory it happened to start in.
  // This is what a real editor does, and it is what breaks a relative path.
  LWorkDir := TPath.GetTempPath();
  TConsole.PrintLn('Workdir: ' + LWorkDir +
    '   (deliberately NOT bin\ -- this is the langdef path test)');

  LSession := TMemoryStream.Create();
  LReplies := TMemoryStream.Create();
  try
    LDriver := TLSPDemoDriver.Create();
    try
      // Build the session into memory. A pipe cannot be rewound, so the driver
      // composes into a seekable buffer and the buffer is shipped to the child.
      LDriver.Input := LSession;
      LDriver.Output := LReplies;

      TConsole.PrintLn('');
      TConsole.PrintLn(COLOR_WHITE + 'Document under test:' + COLOR_RESET);
      TConsole.PrintLn(LDriver.Source);

      LDriver.BuildSession();

      LStdinWrite := 0;
      LStdoutRead := 0;
      LProcess := 0;
      LThread := 0;

      if not TUtils.CreateProcessWithPipes(LExe, '', LWorkDir,
        LStdinWrite, LStdoutRead, LProcess, LThread) then
      begin
        TConsole.PrintLn(COLOR_RED +
          'ABORT: could not spawn MyraLSP.exe.' + COLOR_RESET);
        Exit;
      end;

      try
        DoWriteToChild(LStdinWrite, LSession);
        DoReadFromChild(LStdoutRead, LReplies);
        WaitForSingleObject(LProcess, 10000);
      finally
        CloseHandle(LStdoutRead);
        CloseHandle(LThread);
        CloseHandle(LProcess);
      end;

      if LReplies.Size = 0 then
      begin
        TConsole.PrintLn('');
        TConsole.PrintLn(COLOR_RED +
          'The server produced NO output at all.' + COLOR_RESET);
        TConsole.PrintLn(COLOR_YELLOW +
          'TLSPServer.Run() exits silently when the langdef fails to load. ' +
          'If the in-process demo passed and this one did not, the langdef ' +
          'path is being resolved against the CWD instead of the exe.' +
          COLOR_RESET);
        Exit;
      end;

      LDriver.RenderReplies();

      TConsole.PrintLn(COLOR_GREEN + COLOR_BOLD +
        '=== OUT-OF-PROCESS SESSION COMPLETE ===' + COLOR_RESET);
    finally
      LDriver.Free();
    end;
  finally
    LReplies.Free();
    LSession.Free();
  end;
end;

end.
