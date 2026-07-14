{===============================================================================
  Myra™ - Pascal. Refined.

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://myralang.org

  See LICENSE for license information
===============================================================================}

unit Myra.Common;

{$I StdApp.Defines.inc}

interface

uses
  System.SysUtils,
  StdApp.Base,
  Myra.AST;

const
  // File extension for breakpoint sidecar files (e.g. hello_debug.mbp).
  // Shared by Myra.Build (writes the sidecar) and Myra.Debug.REPL (reads it),
  // so it lives here -- a second copy in either unit would shadow this one by
  // uses-order and silently split the writer from the reader.
  BREAKPOINT_EXT = 'mbp';
  LANGDEF_EXT = 'mld';
  TOOLCHAIN_PATH = 'res';

  MYR_RES_TESTS_DIR = 'res\tests';

  { MYR_RES_LANGDEF }
  // Root language definition. The tester compiles against the .mld on disk
  // (not the baked AST) so that langdef edits take effect immediately.
  MYR_RES_LANGDEF = 'res\language\myra.mld';

  // Baked compiler resource name and AST stream format identifiers
  AST_BAKED_RES = 'MYR_BAKED_AST';
  AST_MAGIC     = $314D4F52; // 'MOR1' as DWORD (little-endian: R, O, M, 1)
  AST_VERSION   = 1;

  // ResolvePath behavior when no explicit base path is provided
  // 0 = raw passthrough (no resolution)
  // 1 = resolve relative to exe directory (ParamStr(0))
  // 2 = resolve relative to source file directory (FSourceDir)
  RESOLVEPATH_BEHAVIOR = 1;

type
  { TRunMode }
  TRunMode = (
    rmNone,
    rmExecute,
    rmDebug
  );

  { TBuildObject }
  TBuildObject = class(TBaseObject)
  protected
    FBuild: TObject;
  public
    procedure SetBuild(const ABuild: TObject); virtual;
    function GetBuild(): TObject;
  end;

// Report an error with position info extracted from an AST node's token.
procedure ReportNodeError(
  const AErrors: TErrors;
  const ANode: TASTNode;
  const ACode: string;
  const AFmt: string;
  const AArgs: array of const
);

implementation

procedure ReportNodeError(
  const AErrors: TErrors;
  const ANode: TASTNode;
  const ACode: string;
  const AFmt: string;
  const AArgs: array of const
);
var
  LToken: TToken;
begin
  if not Assigned(AErrors) then
    Exit;
  LToken.Filename := '';
  LToken.Line := 0;
  LToken.Col := 0;
  if Assigned(ANode) then
    LToken := ANode.GetToken();
  AErrors.Add(LToken.Filename, LToken.Line, LToken.Col, esError, ACode,
    AFmt, AArgs, nil);
end;

{ TMyrBuildObject }

procedure TBuildObject.SetBuild(const ABuild: TObject);
begin
  FBuild := ABuild;
end;

function TBuildObject.GetBuild(): TObject;
begin
  Result := FBuild;
end;

end.
