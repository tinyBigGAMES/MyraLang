{===============================================================================
  Myra™ - Pascal. Refined.

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://myralang.org

  See LICENSE for license information
===============================================================================}

unit UMyra;

{$I StdApp.Defines.inc}

interface

procedure RunCLI();

implementation

uses
  System.SysUtils,
  System.IOUtils,
  StdApp.Console,
  StdApp.Utils,
  Myra.Engine,
  Myra.Build,
  Myra.CLI;

procedure RunCLI();
var
  LCLI: TMyrCLI;
begin
 try
    ExitCode := 0;
    LCLI := TMyrCLI.Create();
    try
      LCLI.Execute();
    finally
      LCLI.Free();
    end;
  except
    on E: Exception do
    begin
      TConsole.PrintLn();
      TConsole.PrintLn(COLOR_RED + 'EXCEPTION: ' + E.Message + COLOR_RESET);
    end;
  end;
end;

end.
