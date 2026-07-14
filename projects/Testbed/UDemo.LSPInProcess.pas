{===============================================================================
  Myra™ - Pascal. Refined.

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://myralang.org

  See LICENSE for license information
===============================================================================}

unit UDemo.LSPInProcess;

(*
  LSP IN-PROCESS demo.

  Stands up a TLSPServer inside the Testbed and drives it over MEMORY STREAMS
  via SetStreams(). No child process, no pipes, no editor. The server does not
  know the difference -- Run() only falls back to stdin/stdout when SetStreams
  was never called.

  This exercises every LSP capability the server implements against a real
  .myra document and PRINTS WHAT THE SERVER ANSWERS: the hover text, the
  completion list, the symbol tree, the rename edit set, the diagnostics.

  TLSPDemoDriver is the whole show and is deliberately transport-agnostic --
  hand it any input/output stream pair. UDemo.LSPOutProcess reuses it verbatim
  over real pipes to a spawned MyraLSP.exe. Same script, both transports: if a
  feature works here and fails there, the bug is in the framing, not the engine.
*)

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  StdApp.TestDemo;

type
  { TLSPDemoDriver }
  // Speaks LSP over a stream pair. Builds the request script, then renders
  // every response the server sent back.
  TLSPDemoDriver = class(TObject)
  private
    FInput: TStream;
    FOutput: TStream;
    FSource: string;
    FUri: string;
    FNextId: Integer;
    FSent: TStringList;

    // -- wire --
    procedure DoSend(const AJson: TJSONObject);
    procedure DoSendRequest(const AMethod: string; const AParams: TJSONObject);
    procedure DoSendNotify(const AMethod: string; const AParams: TJSONObject);
    function  DoReadFrame(): TJSONObject;

    // -- position helpers: locate by TEXT, never by hardcoded line number, so
    //    editing the fixture cannot silently break the demo --
    procedure DoLocate(const ANeedle: string; const AOccurrence: Integer;
      out ALine: Integer; out ACharacter: Integer);
    function  DoPos(const ALine: Integer; const ACharacter: Integer): TJSONObject;
    function  DoDocId(): TJSONObject;
    function  DoDocPos(const ANeedle: string;
      const AOccurrence: Integer = 1): TJSONObject;

    // -- rendering --
    procedure DoRule(const ATitle: string);
    procedure DoRenderResponse(const AMethod: string; const AResult: TJSONValue);
    procedure DoRenderDiagnostics(const AParams: TJSONObject);
    procedure DoRenderHover(const AResult: TJSONValue);
    procedure DoRenderCompletion(const AResult: TJSONValue);
    procedure DoRenderLocations(const AResult: TJSONValue);
    procedure DoRenderSymbols(const AResult: TJSONValue);
    procedure DoRenderSignature(const AResult: TJSONValue);
    procedure DoRenderRename(const AResult: TJSONValue);
    procedure DoRenderCount(const AResult: TJSONValue; const ANoun: string);

    // -- the script --
    procedure DoScriptHandshake();
    procedure DoScriptNavigation();
    procedure DoScriptCompletionAndSignature();
    procedure DoScriptStructure();
    procedure DoScriptRefactor();
    procedure DoScriptDiagnostics();
    procedure DoScriptTeardown();
  public
    constructor Create();
    destructor Destroy(); override;

    // Fill the input stream with the whole LSP session.
    procedure BuildSession();

    // Drain the output stream and print everything the server said.
    procedure RenderReplies();

    property Input: TStream read FInput write FInput;
    property Output: TStream read FOutput write FOutput;
    property Uri: string read FUri write FUri;
    property Source: string read FSource;
  end;

  { TLSPInProcessDemo }
  TLSPInProcessDemo = class(TTestDemo)
  public
    constructor Create(); override;
    procedure OnRender(); override;
  end;

// The demo fixture. A real, compilable Myra module -- every construct here is
// lifted from a green test in bin/res/tests.
function LSPDemoSource(): string;

implementation

uses
  System.IOUtils,
  StdApp.Console,
  StdApp.Utils,
  Myra.Common,
  Myra.LSP;

function LSPDemoSource(): string;
begin
  Result :=
    '''
    module exe lspdemo;

    import Maths;

    type
      TPoint = record
        X: int32;
        Y: int32;
      end;

    var
      LOrigin: TPoint;
      LTotal: int32;

    routine add(const A: int32; const B: int32): int32;
    begin
      return A + B;
    end;

    routine scale(const P: TPoint; const F: int32): TPoint;
    var
      LR: TPoint;
    begin
      LR.X := P.X * F;
      LR.Y := P.Y * F;
      return LR;
    end;

    begin
      LOrigin.X := 3;
      LOrigin.Y := 4;
      LTotal := add(LOrigin.X, LOrigin.Y);
      println("total = {}", LTotal);
      println("sqrt  = {}", Maths.Sqrt(16.0));
    end.
    ''';
end;

{ TLSPDemoDriver }

constructor TLSPDemoDriver.Create();
begin
  inherited Create();
  FInput := nil;
  FOutput := nil;
  FSource := LSPDemoSource();
  FUri := 'file:///c:/myra/lspdemo.myra';
  FNextId := 1;
  FSent := TStringList.Create();
end;

destructor TLSPDemoDriver.Destroy();
begin
  FreeAndNil(FSent);
  inherited Destroy();
end;

//------------------------------------------------------------------------------
// Wire
//------------------------------------------------------------------------------

// Frame a JSON message the way LSP requires: a Content-Length header, a blank
// line, then the UTF-8 body. This is exactly what TLSPServer.ReadMessage parses.
procedure TLSPDemoDriver.DoSend(const AJson: TJSONObject);
var
  LBody: TBytes;
  LHeader: TBytes;
begin
  try
    LBody := TEncoding.UTF8.GetBytes(AJson.ToJSON());
    LHeader := TEncoding.ASCII.GetBytes(
      Format('Content-Length: %d'#13#10#13#10, [Length(LBody)]));

    FInput.WriteBuffer(LHeader[0], Length(LHeader));
    FInput.WriteBuffer(LBody[0], Length(LBody));
  finally
    AJson.Free();
  end;
end;

// A request carries an id and expects a response. Remember the method against
// the id so the reply can be rendered with the right formatter.
procedure TLSPDemoDriver.DoSendRequest(const AMethod: string;
  const AParams: TJSONObject);
var
  LMsg: TJSONObject;
begin
  LMsg := TJSONObject.Create();
  LMsg.AddPair('jsonrpc', '2.0');
  LMsg.AddPair('id', TJSONNumber.Create(FNextId));
  LMsg.AddPair('method', AMethod);
  if AParams <> nil then
    LMsg.AddPair('params', AParams);

  FSent.AddObject(IntToStr(FNextId), TObject(nil));
  FSent.Values[IntToStr(FNextId)] := AMethod;
  Inc(FNextId);

  DoSend(LMsg);
end;

// A notification has no id and gets no response.
procedure TLSPDemoDriver.DoSendNotify(const AMethod: string;
  const AParams: TJSONObject);
var
  LMsg: TJSONObject;
begin
  LMsg := TJSONObject.Create();
  LMsg.AddPair('jsonrpc', '2.0');
  LMsg.AddPair('method', AMethod);
  if AParams <> nil then
    LMsg.AddPair('params', AParams);
  DoSend(LMsg);
end;

// Read one framed message off the output stream. Returns nil at end of stream.
function TLSPDemoDriver.DoReadFrame(): TJSONObject;
var
  LLine: string;
  LContentLength: Integer;
  LByte: Byte;
  LBodyBytes: TBytes;
  LParsed: TJSONValue;
begin
  Result := nil;
  LContentLength := -1;
  LLine := '';

  while True do
  begin
    if FOutput.Read(LByte, 1) <> 1 then
      Exit;

    if LByte = 13 then
    begin
      FOutput.Read(LByte, 1);
      if LLine = '' then
        Break;

      if LLine.StartsWith('Content-Length: ') then
        LContentLength := StrToIntDef(
          Copy(LLine, Length('Content-Length: ') + 1, MaxInt), -1);

      LLine := '';
    end
    else if LByte <> 10 then
      LLine := LLine + Chr(LByte);
  end;

  if LContentLength <= 0 then
    Exit;

  SetLength(LBodyBytes, LContentLength);
  FOutput.ReadBuffer(LBodyBytes[0], LContentLength);

  LParsed := TJSONObject.ParseJSONValue(TEncoding.UTF8.GetString(LBodyBytes));
  if LParsed is TJSONObject then
    Result := TJSONObject(LParsed)
  else
    LParsed.Free();
end;

//------------------------------------------------------------------------------
// Position helpers
//------------------------------------------------------------------------------

// Find the Nth occurrence of ANeedle in the fixture and convert its offset to
// a zero-based LSP line/character. Positions are derived from the TEXT, never
// hardcoded -- edit the fixture and the demo still points at the right token.
procedure TLSPDemoDriver.DoLocate(const ANeedle: string;
  const AOccurrence: Integer; out ALine: Integer; out ACharacter: Integer);
var
  LIndex: Integer;
  LFound: Integer;
  LI: Integer;
  LLine: Integer;
  LCol: Integer;
begin
  ALine := 0;
  ACharacter := 0;

  LIndex := 0;
  LFound := 0;
  repeat
    LIndex := Pos(ANeedle, FSource, LIndex + 1);
    if LIndex = 0 then
      Exit;
    Inc(LFound);
  until LFound >= AOccurrence;

  // Walk to the offset counting lines. sLineBreak is CRLF on Windows; the LF
  // is what advances the line, and the CR is simply not counted as a column.
  LLine := 0;
  LCol := 0;
  for LI := 1 to LIndex - 1 do
  begin
    if FSource[LI] = #10 then
    begin
      Inc(LLine);
      LCol := 0;
    end
    else if FSource[LI] <> #13 then
      Inc(LCol);
  end;

  ALine := LLine;
  ACharacter := LCol;
end;

function TLSPDemoDriver.DoPos(const ALine: Integer;
  const ACharacter: Integer): TJSONObject;
begin
  Result := TJSONObject.Create();
  Result.AddPair('line', TJSONNumber.Create(ALine));
  Result.AddPair('character', TJSONNumber.Create(ACharacter));
end;

function TLSPDemoDriver.DoDocId(): TJSONObject;
begin
  Result := TJSONObject.Create();
  Result.AddPair('uri', FUri);
end;

// { textDocument, position } -- the shape every navigation request wants.
function TLSPDemoDriver.DoDocPos(const ANeedle: string;
  const AOccurrence: Integer): TJSONObject;
var
  LLine: Integer;
  LChar: Integer;
begin
  DoLocate(ANeedle, AOccurrence, LLine, LChar);
  Result := TJSONObject.Create();
  Result.AddPair('textDocument', DoDocId());
  Result.AddPair('position', DoPos(LLine, LChar));
end;

//------------------------------------------------------------------------------
// The session script
//------------------------------------------------------------------------------

procedure TLSPDemoDriver.BuildSession();
begin
  DoScriptHandshake();
  DoScriptNavigation();
  DoScriptCompletionAndSignature();
  DoScriptStructure();
  DoScriptRefactor();
  DoScriptDiagnostics();
  DoScriptTeardown();

  // Rewind so the server reads from the top.
  FInput.Position := 0;
end;

// initialize -> initialized -> didOpen. After didOpen the server has analyzed
// the document and every later request has something to answer with.
procedure TLSPDemoDriver.DoScriptHandshake();
var
  LParams: TJSONObject;
  LDoc: TJSONObject;
begin
  LParams := TJSONObject.Create();
  LParams.AddPair('processId', TJSONNull.Create());
  LParams.AddPair('rootUri', TJSONNull.Create());
  LParams.AddPair('capabilities', TJSONObject.Create());
  DoSendRequest('initialize', LParams);

  DoSendNotify('initialized', TJSONObject.Create());

  LDoc := TJSONObject.Create();
  LDoc.AddPair('uri', FUri);
  LDoc.AddPair('languageId', 'myra');
  LDoc.AddPair('version', TJSONNumber.Create(1));
  LDoc.AddPair('text', FSource);

  LParams := TJSONObject.Create();
  LParams.AddPair('textDocument', LDoc);
  DoSendNotify('textDocument/didOpen', LParams);
end;

// Hover / go-to-definition / find-all-references, all aimed at the SAME symbol
// (the `add` call inside the module body) so the three answers can be compared.
procedure TLSPDemoDriver.DoScriptNavigation();
var
  LParams: TJSONObject;
begin
  // 'add(' occurs twice: the declaration, then the call site. Aim at the call.
  DoSendRequest('textDocument/hover', DoDocPos('add(', 2));
  DoSendRequest('textDocument/definition', DoDocPos('add(', 2));

  LParams := DoDocPos('add(', 2);
  LParams.AddPair('context',
    TJSONObject.Create(TJSONPair.Create('includeDeclaration',
      TJSONBool.Create(True))));
  DoSendRequest('textDocument/references', LParams);

  // Hover a type, not a routine -- proves the symbol table, not a special case.
  DoSendRequest('textDocument/hover', DoDocPos('TPoint', 2));
end;

// Completion after `Maths.` and signature help inside `add(`.
procedure TLSPDemoDriver.DoScriptCompletionAndSignature();
var
  LParams: TJSONObject;
  LLine: Integer;
  LChar: Integer;
begin
  // Sit the cursor immediately AFTER the dot in `Maths.Sqrt`.
  DoLocate('Maths.Sqrt', 1, LLine, LChar);
  LParams := TJSONObject.Create();
  LParams.AddPair('textDocument', DoDocId());
  LParams.AddPair('position', DoPos(LLine, LChar + Length('Maths.')));
  DoSendRequest('textDocument/completion', LParams);

  // Cursor immediately AFTER the dot in `LOrigin.X`. This is the OTHER member
  // path: not a module, a RECORD. Must answer with TPoint's fields and nothing
  // else. Nothing in the symbol table maps a type to its members -- the answer
  // comes out of the AST type_decl.
  DoLocate('LOrigin.X', 1, LLine, LChar);
  LParams := TJSONObject.Create();
  LParams.AddPair('textDocument', DoDocId());
  LParams.AddPair('position', DoPos(LLine, LChar + Length('LOrigin.')));
  DoSendRequest('textDocument/completion', LParams);

  // Cursor on a line with NO dot before it -- the plain, non-member path. This
  // is the one that must still return the whole visible scope plus keywords.
  // If member completion ever swallows this case, the dropdown goes empty
  // everywhere and the demo above would not catch it.
  DoLocate('LTotal := add', 1, LLine, LChar);
  LParams := TJSONObject.Create();
  LParams.AddPair('textDocument', DoDocId());
  LParams.AddPair('position', DoPos(LLine, LChar));
  DoSendRequest('textDocument/completion', LParams);

  // Sit the cursor INSIDE the parens of the `add(...)` call.
  DoLocate('add(', 2, LLine, LChar);
  LParams := TJSONObject.Create();
  LParams.AddPair('textDocument', DoDocId());
  LParams.AddPair('position', DoPos(LLine, LChar + Length('add(')));
  DoSendRequest('textDocument/signatureHelp', LParams);
end;

// Everything an editor draws in the gutter and the outline pane.
procedure TLSPDemoDriver.DoScriptStructure();
var
  LParams: TJSONObject;
begin
  DoSendRequest('textDocument/documentSymbol',
    TJSONObject.Create(TJSONPair.Create('textDocument', DoDocId())));

  DoSendRequest('textDocument/foldingRange',
    TJSONObject.Create(TJSONPair.Create('textDocument', DoDocId())));

  DoSendRequest('textDocument/semanticTokens/full',
    TJSONObject.Create(TJSONPair.Create('textDocument', DoDocId())));

  LParams := TJSONObject.Create();
  LParams.AddPair('textDocument', DoDocId());
  LParams.AddPair('range',
    TJSONObject.Create()
      .AddPair('start', DoPos(0, 0))
      .AddPair('end', DoPos(999, 0)));
  DoSendRequest('textDocument/inlayHint', LParams);

  DoSendRequest('workspace/symbol',
    TJSONObject.Create(TJSONPair.Create('query', 'add')));
end;

// Rename, formatting, code actions.
procedure TLSPDemoDriver.DoScriptRefactor();
var
  LParams: TJSONObject;
begin
  // Rename the `add` routine at its DECLARATION. The server should come back
  // with an edit for every occurrence, declaration and call site alike.
  LParams := DoDocPos('add(', 1);
  LParams.AddPair('newName', 'sum');
  DoSendRequest('textDocument/rename', LParams);

  LParams := TJSONObject.Create();
  LParams.AddPair('textDocument', DoDocId());
  LParams.AddPair('options',
    TJSONObject.Create()
      .AddPair('tabSize', TJSONNumber.Create(2))
      .AddPair('insertSpaces', TJSONBool.Create(True)));
  DoSendRequest('textDocument/formatting', LParams);

  LParams := TJSONObject.Create();
  LParams.AddPair('textDocument', DoDocId());
  LParams.AddPair('range',
    TJSONObject.Create()
      .AddPair('start', DoPos(0, 0))
      .AddPair('end', DoPos(0, 0)));
  LParams.AddPair('context',
    TJSONObject.Create(TJSONPair.Create('diagnostics', TJSONArray.Create())));
  DoSendRequest('textDocument/codeAction', LParams);
end;

// The live-editing story. Break the document, watch the diagnostic arrive.
// Fix it, watch the diagnostic clear. This is the one that proves the server
// is really re-analyzing and not just replaying a cached parse.
procedure TLSPDemoDriver.DoScriptDiagnostics();
var
  LParams: TJSONObject;
  LDoc: TJSONObject;
  LChanges: TJSONArray;
  LBroken: string;
begin
  // Introduce a REAL syntax error -- a dangling operator with no right operand.
  // NOTE: do NOT just drop the semicolon off `return A + B;`. The semicolon
  // before `end` is OPTIONAL in Myra, so that edit produces a still-valid file
  // and the server correctly reports CLEAN -- which looks like a broken server
  // and is not.
  LBroken := StringReplace(FSource, 'return A + B;', 'return A + ;',
    [rfReplaceAll]);

  LDoc := TJSONObject.Create();
  LDoc.AddPair('uri', FUri);
  LDoc.AddPair('version', TJSONNumber.Create(2));

  LChanges := TJSONArray.Create();
  LChanges.AddElement(
    TJSONObject.Create(TJSONPair.Create('text', LBroken)));

  LParams := TJSONObject.Create();
  LParams.AddPair('textDocument', LDoc);
  LParams.AddPair('contentChanges', LChanges);
  DoSendNotify('textDocument/didChange', LParams);

  // Put it back exactly as it was. The diagnostics should go quiet again.
  LDoc := TJSONObject.Create();
  LDoc.AddPair('uri', FUri);
  LDoc.AddPair('version', TJSONNumber.Create(3));

  LChanges := TJSONArray.Create();
  LChanges.AddElement(
    TJSONObject.Create(TJSONPair.Create('text', FSource)));

  LParams := TJSONObject.Create();
  LParams.AddPair('textDocument', LDoc);
  LParams.AddPair('contentChanges', LChanges);
  DoSendNotify('textDocument/didChange', LParams);
end;

procedure TLSPDemoDriver.DoScriptTeardown();
var
  LParams: TJSONObject;
begin
  LParams := TJSONObject.Create();
  LParams.AddPair('textDocument', DoDocId());
  DoSendNotify('textDocument/didClose', LParams);

  DoSendRequest('shutdown', nil);
  DoSendNotify('exit', nil);
end;

//------------------------------------------------------------------------------
// Rendering -- print what the server actually said
//------------------------------------------------------------------------------

procedure TLSPDemoDriver.DoRule(const ATitle: string);
begin
  TConsole.PrintLn('');
  TConsole.PrintLn(COLOR_CYAN + '  --- ' + ATitle + ' ' +
    StringOfChar('-', 58 - Length(ATitle)) + COLOR_RESET);
end;

// Walk every frame the server emitted, in order, and hand each to the right
// formatter. Notifications (no id) are diagnostics; responses carry the id we
// stamped on the request, which tells us which method they answer.
procedure TLSPDemoDriver.RenderReplies();
var
  LFrame: TJSONObject;
  LId: TJSONValue;
  LMethod: string;
  LResult: TJSONValue;
  LError: TJSONValue;
begin
  FOutput.Position := 0;

  while True do
  begin
    LFrame := DoReadFrame();
    if LFrame = nil then
      Break;

    try
      // Server -> client notification. The only one that matters here is
      // publishDiagnostics.
      LMethod := LFrame.GetValue<string>('method', '');
      if LMethod <> '' then
      begin
        if LMethod = 'textDocument/publishDiagnostics' then
          DoRenderDiagnostics(LFrame.GetValue<TJSONObject>('params', nil));
        Continue;
      end;

      LId := LFrame.GetValue<TJSONValue>('id', nil);
      if LId = nil then
        Continue;

      LMethod := FSent.Values[LId.Value];
      if LMethod = '' then
        Continue;

      LError := LFrame.GetValue<TJSONValue>('error', nil);
      if LError <> nil then
      begin
        DoRule(LMethod);
        TConsole.PrintLn(COLOR_RED + '  ERROR: ' + LError.ToJSON() +
          COLOR_RESET);
        Continue;
      end;

      LResult := LFrame.GetValue<TJSONValue>('result', nil);
      DoRenderResponse(LMethod, LResult);
    finally
      LFrame.Free();
    end;
  end;

  TConsole.PrintLn('');
end;

procedure TLSPDemoDriver.DoRenderResponse(const AMethod: string;
  const AResult: TJSONValue);
begin
  DoRule(AMethod);

  // shutdown's result is SPECIFIED to be null. Check it before the null guard,
  // or a correct server looks like a broken one.
  if AMethod = 'shutdown' then
  begin
    TConsole.PrintLn(COLOR_GREEN + '  Server acknowledged shutdown.' +
      COLOR_RESET);
    Exit;
  end;

  if (AResult = nil) or (AResult is TJSONNull) then
  begin
    TConsole.PrintLn(COLOR_YELLOW + '  (null -- server had no answer)' +
      COLOR_RESET);
    Exit;
  end;

  // No strings in case statements -- if/else if by project rule.
  if AMethod = 'initialize' then
    TConsole.PrintLn(COLOR_GREEN +
      '  Server is up. Capabilities advertised.' + COLOR_RESET)
  else if AMethod = 'textDocument/hover' then
    DoRenderHover(AResult)
  else if AMethod = 'textDocument/completion' then
    DoRenderCompletion(AResult)
  else if AMethod = 'textDocument/definition' then
    DoRenderLocations(AResult)
  else if AMethod = 'textDocument/references' then
    DoRenderLocations(AResult)
  else if AMethod = 'textDocument/documentSymbol' then
    DoRenderSymbols(AResult)
  else if AMethod = 'workspace/symbol' then
    DoRenderSymbols(AResult)
  else if AMethod = 'textDocument/signatureHelp' then
    DoRenderSignature(AResult)
  else if AMethod = 'textDocument/rename' then
    DoRenderRename(AResult)
  else if AMethod = 'textDocument/foldingRange' then
    DoRenderCount(AResult, 'foldable region')
  else if AMethod = 'textDocument/inlayHint' then
    DoRenderCount(AResult, 'inlay hint')
  else if AMethod = 'textDocument/formatting' then
    DoRenderCount(AResult, 'text edit')
  else if AMethod = 'textDocument/codeAction' then
    DoRenderCount(AResult, 'code action')
  else if AMethod = 'textDocument/semanticTokens/full' then
    DoRenderCount(AResult, 'semantic token')
  else if AMethod = 'shutdown' then
    TConsole.PrintLn(COLOR_GREEN + '  Server acknowledged shutdown.' +
      COLOR_RESET)
  else
    TConsole.PrintLn('  ' + AResult.ToJSON());
end;

// This is the one an editor shows in a tooltip. Print the real markup.
procedure TLSPDemoDriver.DoRenderHover(const AResult: TJSONValue);
var
  LObj: TJSONObject;
  LContents: TJSONValue;
  LText: string;
  LLine: string;
begin
  if not (AResult is TJSONObject) then
  begin
    TConsole.PrintLn('  ' + AResult.ToJSON());
    Exit;
  end;

  LObj := TJSONObject(AResult);
  LContents := LObj.GetValue<TJSONValue>('contents', nil);
  if LContents = nil then
  begin
    TConsole.PrintLn(COLOR_YELLOW + '  (no hover text)' + COLOR_RESET);
    Exit;
  end;

  LText := '';
  if LContents is TJSONObject then
    LText := TJSONObject(LContents).GetValue<string>('value', '')
  else
    LText := LContents.Value;

  if LText = '' then
  begin
    TConsole.PrintLn(COLOR_YELLOW + '  (empty hover)' + COLOR_RESET);
    Exit;
  end;

  for LLine in LText.Split([sLineBreak, #10]) do
    TConsole.PrintLn(COLOR_WHITE + '  | ' + LLine + COLOR_RESET);
end;

// The dropdown the editor pops after a dot.
procedure TLSPDemoDriver.DoRenderCompletion(const AResult: TJSONValue);
var
  LItems: TJSONArray;
  LItem: TJSONValue;
  LObj: TJSONObject;
  LCount: Integer;
begin
  LItems := nil;
  if AResult is TJSONArray then
    LItems := TJSONArray(AResult)
  else if AResult is TJSONObject then
    LItems := TJSONObject(AResult).GetValue<TJSONArray>('items', nil);

  if (LItems = nil) or (LItems.Count = 0) then
  begin
    TConsole.PrintLn(COLOR_YELLOW + '  (no completions offered)' + COLOR_RESET);
    Exit;
  end;

  TConsole.PrintLn(Format('  %d completion(s):', [LItems.Count]));

  LCount := 0;
  for LItem in LItems do
  begin
    if not (LItem is TJSONObject) then
      Continue;
    LObj := TJSONObject(LItem);

    TConsole.PrintLn(COLOR_WHITE + '    ' +
      LObj.GetValue<string>('label', '?') + COLOR_RESET +
      '   ' + LObj.GetValue<string>('detail', ''));

    Inc(LCount);
    if LCount >= 20 then
    begin
      TConsole.PrintLn(Format('    ... and %d more', [LItems.Count - LCount]));
      Break;
    end;
  end;
end;

// Definition and references both answer with Location objects.
procedure TLSPDemoDriver.DoRenderLocations(const AResult: TJSONValue);
var
  LArr: TJSONArray;
  LItem: TJSONValue;
  LObj: TJSONObject;
  LRange: TJSONObject;
  LStart: TJSONObject;

  procedure PrintOne(const ALoc: TJSONObject);
  begin
    LRange := ALoc.GetValue<TJSONObject>('range', nil);
    if LRange = nil then
      Exit;
    LStart := LRange.GetValue<TJSONObject>('start', nil);
    if LStart = nil then
      Exit;

    // LSP is zero-based; editors show one-based. Print what a human reads.
    TConsole.PrintLn(Format(COLOR_WHITE + '    line %d, col %d' + COLOR_RESET,
      [LStart.GetValue<Integer>('line', 0) + 1,
       LStart.GetValue<Integer>('character', 0) + 1]));
  end;

begin
  if AResult is TJSONObject then
  begin
    TConsole.PrintLn('  resolved to:');
    PrintOne(TJSONObject(AResult));
    Exit;
  end;

  if not (AResult is TJSONArray) then
  begin
    TConsole.PrintLn('  ' + AResult.ToJSON());
    Exit;
  end;

  LArr := TJSONArray(AResult);
  if LArr.Count = 0 then
  begin
    TConsole.PrintLn(COLOR_YELLOW + '  (none found)' + COLOR_RESET);
    Exit;
  end;

  TConsole.PrintLn(Format('  %d location(s):', [LArr.Count]));
  for LItem in LArr do
  begin
    if LItem is TJSONObject then
    begin
      LObj := TJSONObject(LItem);
      PrintOne(LObj);
    end;
  end;
end;

// The outline pane.
procedure TLSPDemoDriver.DoRenderSymbols(const AResult: TJSONValue);
var
  LArr: TJSONArray;
  LItem: TJSONValue;
  LObj: TJSONObject;
begin
  if not (AResult is TJSONArray) then
  begin
    TConsole.PrintLn('  ' + AResult.ToJSON());
    Exit;
  end;

  LArr := TJSONArray(AResult);
  if LArr.Count = 0 then
  begin
    TConsole.PrintLn(COLOR_YELLOW + '  (no symbols)' + COLOR_RESET);
    Exit;
  end;

  TConsole.PrintLn(Format('  %d symbol(s):', [LArr.Count]));
  for LItem in LArr do
  begin
    if not (LItem is TJSONObject) then
      Continue;
    LObj := TJSONObject(LItem);
    TConsole.PrintLn(COLOR_WHITE + '    ' +
      LObj.GetValue<string>('name', '?') + COLOR_RESET +
      Format('   (kind %d)  %s',
        [LObj.GetValue<Integer>('kind', 0),
         LObj.GetValue<string>('detail', '')]));
  end;
end;

// The little popup showing which parameter you are currently typing.
procedure TLSPDemoDriver.DoRenderSignature(const AResult: TJSONValue);
var
  LObj: TJSONObject;
  LSigs: TJSONArray;
  LSig: TJSONValue;
  LActive: Integer;
begin
  if not (AResult is TJSONObject) then
  begin
    TConsole.PrintLn(COLOR_YELLOW + '  (no signature help)' + COLOR_RESET);
    Exit;
  end;

  LObj := TJSONObject(AResult);
  LSigs := LObj.GetValue<TJSONArray>('signatures', nil);
  if (LSigs = nil) or (LSigs.Count = 0) then
  begin
    TConsole.PrintLn(COLOR_YELLOW + '  (no signature help)' + COLOR_RESET);
    Exit;
  end;

  LActive := LObj.GetValue<Integer>('activeParameter', 0);

  for LSig in LSigs do
  begin
    if LSig is TJSONObject then
      TConsole.PrintLn(COLOR_WHITE + '    ' +
        TJSONObject(LSig).GetValue<string>('label', '?') + COLOR_RESET);
  end;
  TConsole.PrintLn(Format('    active parameter: %d', [LActive]));
end;

// The full edit set a rename would apply across the file.
procedure TLSPDemoDriver.DoRenderRename(const AResult: TJSONValue);
var
  LObj: TJSONObject;
  LChanges: TJSONObject;
  LPair: TJSONPair;
  LEdits: TJSONArray;
  LEdit: TJSONValue;
  LRange: TJSONObject;
  LStart: TJSONObject;
begin
  if not (AResult is TJSONObject) then
  begin
    TConsole.PrintLn(COLOR_YELLOW + '  (rename not supported here)' +
      COLOR_RESET);
    Exit;
  end;

  LObj := TJSONObject(AResult);
  LChanges := LObj.GetValue<TJSONObject>('changes', nil);
  if LChanges = nil then
  begin
    TConsole.PrintLn(COLOR_YELLOW + '  (no edits produced)' + COLOR_RESET);
    Exit;
  end;

  for LPair in LChanges do
  begin
    if not (LPair.JsonValue is TJSONArray) then
      Continue;
    LEdits := TJSONArray(LPair.JsonValue);

    TConsole.PrintLn(Format('  %d edit(s) in %s:',
      [LEdits.Count, LPair.JsonString.Value]));

    for LEdit in LEdits do
    begin
      if not (LEdit is TJSONObject) then
        Continue;
      LRange := TJSONObject(LEdit).GetValue<TJSONObject>('range', nil);
      if LRange = nil then
        Continue;
      LStart := LRange.GetValue<TJSONObject>('start', nil);
      if LStart = nil then
        Continue;

      TConsole.PrintLn(Format(
        COLOR_WHITE + '    line %d, col %d  ->  "%s"' + COLOR_RESET,
        [LStart.GetValue<Integer>('line', 0) + 1,
         LStart.GetValue<Integer>('character', 0) + 1,
         TJSONObject(LEdit).GetValue<string>('newText', '')]));
    end;
  end;
end;

// For the capabilities whose payload is bulk data, the interesting fact is
// "did the server produce any" -- so say so plainly instead of dumping JSON.
procedure TLSPDemoDriver.DoRenderCount(const AResult: TJSONValue;
  const ANoun: string);
var
  LCount: Integer;
  LData: TJSONArray;
begin
  LCount := 0;

  if AResult is TJSONArray then
    LCount := TJSONArray(AResult).Count
  else if AResult is TJSONObject then
  begin
    // semanticTokens answers { data: [ ... ] }, 5 integers per token.
    LData := TJSONObject(AResult).GetValue<TJSONArray>('data', nil);
    if LData <> nil then
      LCount := LData.Count div 5;
  end;

  if LCount = 0 then
    TConsole.PrintLn(COLOR_YELLOW + Format('  (no %ss produced)', [ANoun]) +
      COLOR_RESET)
  else
    TConsole.PrintLn(COLOR_GREEN + Format('  %d %s(s) produced.',
      [LCount, ANoun]) + COLOR_RESET);
end;

// The server pushes these unprompted whenever a document is analyzed.
procedure TLSPDemoDriver.DoRenderDiagnostics(const AParams: TJSONObject);
var
  LDiags: TJSONArray;
  LItem: TJSONValue;
  LObj: TJSONObject;
  LRange: TJSONObject;
  LStart: TJSONObject;
begin
  if AParams = nil then
    Exit;

  DoRule('publishDiagnostics (pushed by server)');

  LDiags := AParams.GetValue<TJSONArray>('diagnostics', nil);
  if (LDiags = nil) or (LDiags.Count = 0) then
  begin
    TConsole.PrintLn(COLOR_GREEN + '  CLEAN -- no diagnostics.' + COLOR_RESET);
    Exit;
  end;

  TConsole.PrintLn(Format(COLOR_RED + '  %d diagnostic(s):' + COLOR_RESET,
    [LDiags.Count]));

  for LItem in LDiags do
  begin
    if not (LItem is TJSONObject) then
      Continue;
    LObj := TJSONObject(LItem);

    LRange := LObj.GetValue<TJSONObject>('range', nil);
    if LRange = nil then
      Continue;
    LStart := LRange.GetValue<TJSONObject>('start', nil);
    if LStart = nil then
      Continue;

    TConsole.PrintLn(Format('    line %d, col %d: %s',
      [LStart.GetValue<Integer>('line', 0) + 1,
       LStart.GetValue<Integer>('character', 0) + 1,
       LObj.GetValue<string>('message', '')]));
  end;
end;

//------------------------------------------------------------------------------
// TLSPInProcessDemo
//------------------------------------------------------------------------------

constructor TLSPInProcessDemo.Create();
begin
  inherited;
  Title := 'LSP - In-Process (memory streams)';
end;

procedure TLSPInProcessDemo.OnRender();
var
  LServer: TLSPServer;
  LDriver: TLSPDemoDriver;
  LIn: TMemoryStream;
  LOut: TMemoryStream;
  LLangDef: string;
begin
  TConsole.PrintLn('');
  TConsole.PrintLn(COLOR_WHITE + COLOR_BOLD +
    '=== Myra LSP -- IN-PROCESS ===' + COLOR_RESET);
  TConsole.PrintLn(
    'A real TLSPServer, driven over memory streams. No child process.');

  // The langdef path must be ABSOLUTE. TEngineAPI.LoadMor resolves against the
  // process CWD, not the exe -- see UMyraaLSP.pas, which does the same thing.
  LLangDef := TUtils.AppBasedPath(MYR_RES_LANGDEF);
  TConsole.PrintLn('Langdef: ' + LLangDef);

  if not TFile.Exists(LLangDef) then
  begin
    TConsole.PrintLn('');
    TConsole.PrintLn(COLOR_RED +
      'ABORT: langdef not found. The LSP cannot analyze anything without it.' +
      COLOR_RESET);
    Exit;
  end;

  LIn := TMemoryStream.Create();
  LOut := TMemoryStream.Create();
  try
    LDriver := TLSPDemoDriver.Create();
    try
      LDriver.Input := LIn;
      LDriver.Output := LOut;

      TConsole.PrintLn('');
      TConsole.PrintLn(COLOR_WHITE + 'Document under test:' + COLOR_RESET);
      TConsole.PrintLn(LDriver.Source);

      // Write the entire session into the input stream up front. The server's
      // message loop reads until EOF, so the whole conversation is queued and
      // then consumed in one Run().
      LDriver.BuildSession();

      LServer := TLSPServer.Create();
      try
        LServer.SetMLDFile(LLangDef);
        LServer.SetStreams(LIn, LOut);

        // Run() drains the input stream and writes every reply to LOut.
        LServer.Run();
      finally
        LServer.Free();
      end;

      if LOut.Size = 0 then
      begin
        TConsole.PrintLn('');
        TConsole.PrintLn(COLOR_RED +
          'The server produced NO output at all.' + COLOR_RESET);
        TConsole.PrintLn(COLOR_YELLOW +
          'TLSPServer.Run() exits silently when the langdef fails to load ' +
          '-- that is the most likely cause.' + COLOR_RESET);
        Exit;
      end;

      LDriver.RenderReplies();

      TConsole.PrintLn(COLOR_GREEN + COLOR_BOLD +
        '=== IN-PROCESS SESSION COMPLETE ===' + COLOR_RESET);
    finally
      LDriver.Free();
    end;
  finally
    LOut.Free();
    LIn.Free();
  end;
end;

end.
