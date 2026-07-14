{===============================================================================
  NitroLISP - Lisp at the speed of thought.

  Copyright (c) 2026-present tinyBigGAMES LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit UTest.Import;

{$I StdApp.Defines.inc}

(*
  Import system tests. Verifies (import "path") and (export name ...) forms
  work correctly: basic import, private symbol rejection, nested imports,
  cycle detection, no-export modules, and missing files.
*)

interface

uses
  System.SysUtils,
  System.IOUtils,
  StdApp.TestCase,
  NitroLISP.Types,
  NitroLISP.SSA,
  NitroLISP.Compiler;

type
  { TImportTest }
  TImportTest = class(TTestCase)
  private
    // Create a compiler with the test fixture lib path configured
    function DoMakeCompiler(const AMode: TBuildMode): TCompiler;
    // Compile ASource with imports and run; returns True + result if ok
    function DoRunImport(const ASource: string; const AMode: TBuildMode;
      out AResult: TDatum): Boolean;
    // Compile ASource expecting failure; returns True if Build() returns False
    function DoExpectError(const ASource: string): Boolean;
    // Run both modes and check integer result
    procedure CheckImportInt(const ALabel: string; const ASource: string;
      const AExpected: Int64);
    procedure TestImportBasic();
    procedure TestImportPrivate();
    procedure TestImportNested();
    procedure TestImportCycle();
    procedure TestImportNoExport();
    procedure TestImportNotFound();
  public
    constructor Create(); override;
  end;

implementation

{ TImportTest }

constructor TImportTest.Create();
begin
  inherited;
  Title := 'Import System';

  RegisterTest('Basic Import', TestImportBasic);
  RegisterTest('Private Symbol Rejected', TestImportPrivate);
  RegisterTest('Nested Import', TestImportNested);
  RegisterTest('Cycle Detection', TestImportCycle);
  RegisterTest('No Export Module', TestImportNoExport);
  RegisterTest('File Not Found', TestImportNotFound);
end;

function TImportTest.DoMakeCompiler(const AMode: TBuildMode): TCompiler;
var
  LFixturePath: string;
begin
  Result := TCompiler.Create();
  Result.BuildMode := AMode;
  //LFixturePath := ExtractFilePath(ParamStr(0)) + 'res\tests';
  LFixturePath := TPath.Combine(TPath.GetDirectoryName(ParamStr(0)), 'res\tests');
  Result.AddLibPath(LFixturePath);
end;

function TImportTest.DoRunImport(const ASource: string;
  const AMode: TBuildMode; out AResult: TDatum): Boolean;
var
  LCompiler: TCompiler;
begin
  LCompiler := DoMakeCompiler(AMode);
  try
    LCompiler.LoadFromString(ASource);
    Result := LCompiler.Build();
    if Result then
      AResult := LCompiler.Run()
    else
      AResult := MakeNil();
  finally
    LCompiler.Free();
  end;
end;

function TImportTest.DoExpectError(const ASource: string): Boolean;
var
  LCompiler: TCompiler;
begin
  LCompiler := DoMakeCompiler(bmRelease);
  try
    LCompiler.LoadFromString(ASource);
    Result := not LCompiler.Build();
  finally
    LCompiler.Free();
  end;
end;

procedure TImportTest.CheckImportInt(const ALabel: string;
  const ASource: string; const AExpected: Int64);
var
  LDbg: TDatum;
  LRel: TDatum;
  LOkD: Boolean;
  LOkR: Boolean;
begin
  LOkD := DoRunImport(ASource, bmDebug, LDbg);
  LOkR := DoRunImport(ASource, bmRelease, LRel);
  Check(LOkD and LOkR and
        (LDbg.IntVal = AExpected) and (LRel.IntVal = AExpected) and
        (LDbg.IntVal = LRel.IntVal),
        '%s = %d', [ALabel, AExpected]);
end;

procedure TImportTest.TestImportBasic();
begin
  CheckImportInt('import math, square(5)',
    '(import "math") (square 5)', 25);
end;

procedure TImportTest.TestImportPrivate();
begin
  Check(DoExpectError('(import "math") (double 5)'),
    'private symbol rejected');
end;

procedure TImportTest.TestImportNested();
begin
  CheckImportInt('import util, quad(3)',
    '(import "util") (quad 3)', 36);
end;

procedure TImportTest.TestImportCycle();
begin
  Check(DoExpectError('(import "cycle_a")'),
    'circular import detected');
end;

procedure TImportTest.TestImportNoExport();
begin
  Check(DoExpectError('(import "noexport") (hidden 5)'),
    'no-export module rejected');
end;

procedure TImportTest.TestImportNotFound();
begin
  Check(DoExpectError('(import "nonexistent")'),
    'missing file detected');
end;

end.
