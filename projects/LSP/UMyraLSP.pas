{===============================================================================
  Myra™ - Pascal. Refined.

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://myralang.org

  See LICENSE for license information
===============================================================================}

unit UMyraLSP;

interface

procedure RunLSP();

implementation

uses
  System.SysUtils,
  StdApp.Console,
  StdApp.Utils,
  Myra.Common,
  Myra.LSP;

procedure RunLSP();
var
  LServer: TLSPServer;
begin
  try
    LServer := TLSPServer.Create();
    try
      // The langdef path must be ABSOLUTE. The LSP server is launched by the
      // editor, so the process CWD is the workspace, not bin\. AppBasedPath
      // anchors the relative MYR_RES_LANGDEF to the exe's directory.
      LServer.SetMLDFile(TUtils.AppBasedPath(MYR_RES_LANGDEF));
      LServer.Run();
    finally
      LServer.Free();
    end;

  except
    on E: Exception do
    begin
      TConsole.PrintLn('');
      TConsole.PrintLn(COLOR_RED + 'EXCEPTION: %s', [E.Message]);
    end;
  end;
end;

end.
