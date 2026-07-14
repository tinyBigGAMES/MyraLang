{===============================================================================
  Myra™ - Pascal. Refined.

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://myralang.org

  See LICENSE for license information
===============================================================================}

program Testbed;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  UTestbed in 'UTestbed.pas',
  Myra.AST in '..\..\src\Myra.AST.pas',
  Myra.Build in '..\..\src\Myra.Build.pas',
  Myra.Build.Targets in '..\..\src\Myra.Build.Targets.pas',
  Myra.CLI in '..\..\src\Myra.CLI.pas',
  Myra.CodeGen in '..\..\src\Myra.CodeGen.pas',
  Myra.Common in '..\..\src\Myra.Common.pas',
  Myra.Cpp in '..\..\src\Myra.Cpp.pas',
  Myra.Debug.Client in '..\..\src\Myra.Debug.Client.pas',
  Myra.Debug.DAP in '..\..\src\Myra.Debug.DAP.pas',
  Myra.Debug.PDB in '..\..\src\Myra.Debug.PDB.pas',
  Myra.Debug.REPL in '..\..\src\Myra.Debug.REPL.pas',
  Myra.Debug.Runtime in '..\..\src\Myra.Debug.Runtime.pas',
  Myra.Debug.Server in '..\..\src\Myra.Debug.Server.pas',
  Myra.Debug.Target in '..\..\src\Myra.Debug.Target.pas',
  Myra.Engine.API in '..\..\src\Myra.Engine.API.pas',
  Myra.Engine in '..\..\src\Myra.Engine.pas',
  Myra.Environment in '..\..\src\Myra.Environment.pas',
  Myra.GenericLexer in '..\..\src\Myra.GenericLexer.pas',
  Myra.GenericParser in '..\..\src\Myra.GenericParser.pas',
  Myra.Interpreter in '..\..\src\Myra.Interpreter.pas',
  Myra.Lexer in '..\..\src\Myra.Lexer.pas',
  Myra.LSP in '..\..\src\Myra.LSP.pas',
  Myra.Parser in '..\..\src\Myra.Parser.pas',
  Myra.Scopes in '..\..\src\Myra.Scopes.pas',
  Myra.Tester in '..\..\src\Myra.Tester.pas',
  StdApp.Resources in '..\..\src\StdApp.Resources.pas',
  UDemo.LSPInProcess in 'UDemo.LSPInProcess.pas',
  UDemo.LSPOutProcess in 'UDemo.LSPOutProcess.pas';

begin
  RunTestbed();
end.
