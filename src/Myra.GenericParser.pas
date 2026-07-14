{===============================================================================
  Myra™ - Pascal. Refined.

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://myralang.org

  See LICENSE for license information
===============================================================================}

unit Myra.GenericParser;

{$I StdApp.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  StdApp.Resources,
  StdApp.Base,
  Myra.AST,
  Myra.Interpreter;

const
  // User Parser Error Codes (UP001-UP099)
  MYR_ERR_USERPARSER_EXPECTED_TOKEN  = 'UP001';
  MYR_ERR_USERPARSER_NO_PREFIX       = 'UP002';
  MYR_ERR_USERPARSER_EXPECTED_IDENT  = 'UP003';
  MYR_ERR_USERPARSER_UNEXPECTED_STMT = 'UP004';

type

  { TMyrGenericParser }
  TMyrGenericParser = class(TBaseObject)
  private
    FTokens: TList<TToken>;
    FPos: Integer;
    FFilename: string;
    FInterp: TInterpreter;
    FNodePool: TList<TASTNode>;

  public
    constructor Create(); override;
    destructor Destroy(); override;

    procedure Configure(const AInterp: TInterpreter);

    // Orphan tracking: the interpreter registers every node it creates while
    // this parser is active; nodes never parented into the AST are freed when
    // ParseProgram finishes (success or aborted parse).
    procedure RegisterNode(const ANode: TASTNode);

    // Token navigation (public so interpreter can call them)
    function Current(): TToken;
    function Peek(): TToken;
    function PeekAt(const AOffset: Integer): TToken;
    function AtEnd(): Boolean;
    function Check(const AKind: string): Boolean;
    function Match(const AKind: string): Boolean;
    procedure DoAdvance();
    procedure Expect(const AKind: string);

    // Position save/restore (for optional backtracking)
    function GetPos(): Integer;
    procedure SetPos(const APos: Integer);

    // Parsing entry points
    function ParseExpression(const AMinPower: Integer): TASTNode;
    function ParseExpressionFrom(const ALeft: TASTNode;
      const AMinPower: Integer): TASTNode;
    function ParseStatement(): TASTNode;
    function ParseProgram(const ATokens: TList<TToken>;
      const AFilename: string = ''): TASTNode;
  end;

implementation

{ TMyrGenericParser }

constructor TMyrGenericParser.Create();
begin
  inherited;
  FTokens := nil;
  FPos := 0;
  FFilename := '';
  FInterp := nil;
  FNodePool := TList<TASTNode>.Create();
end;

destructor TMyrGenericParser.Destroy();
begin
  FNodePool.Free();
  inherited;
end;

procedure TMyrGenericParser.RegisterNode(const ANode: TASTNode);
begin
  if Assigned(ANode) then
    FNodePool.Add(ANode);
end;

procedure TMyrGenericParser.Configure(const AInterp: TInterpreter);
begin
  FInterp := AInterp;
end;

function TMyrGenericParser.Current(): TToken;
begin
  if (FPos >= 0) and (FPos < FTokens.Count) then
    Result := FTokens[FPos]
  else
  begin
    Result.Kind := 'eof';
    Result.Text := '';
    Result.Line := 0;
    Result.Col := 0;
  end;
end;

function TMyrGenericParser.Peek(): TToken;
begin
  if (FPos + 1 >= 0) and (FPos + 1 < FTokens.Count) then
    Result := FTokens[FPos + 1]
  else
  begin
    Result.Kind := 'eof';
    Result.Text := '';
    Result.Line := 0;
    Result.Col := 0;
  end;
end;

function TMyrGenericParser.PeekAt(const AOffset: Integer): TToken;
var
  LIndex: Integer;
begin
  LIndex := FPos + AOffset;
  if (LIndex >= 0) and (LIndex < FTokens.Count) then
    Result := FTokens[LIndex]
  else
  begin
    Result.Kind := 'eof';
    Result.Text := '';
    Result.Line := 0;
    Result.Col := 0;
  end;
end;

function TMyrGenericParser.AtEnd(): Boolean;
begin
  Result := Current().Kind = 'eof';
end;

function TMyrGenericParser.Check(const AKind: string): Boolean;
begin
  Result := Current().Kind = AKind;
end;

function TMyrGenericParser.Match(const AKind: string): Boolean;
begin
  if Current().Kind = AKind then
  begin
    DoAdvance();
    Result := True;
  end
  else
    Result := False;
end;

procedure TMyrGenericParser.DoAdvance();
begin
  if FPos < FTokens.Count then
    Inc(FPos);
end;

procedure TMyrGenericParser.Expect(const AKind: string);
begin
  if Current().Kind = AKind then
    DoAdvance()
  else if Assigned(FErrors) then
    FErrors.Add(FFilename, Current().Line, Current().Col,
      esError, MYR_ERR_USERPARSER_EXPECTED_TOKEN,
      RSUserParserExpectedToken, [AKind, Current().Text], nil);
end;

function TMyrGenericParser.GetPos(): Integer;
begin
  Result := FPos;
end;

procedure TMyrGenericParser.SetPos(const APos: Integer);
begin
  FPos := APos;
end;

function TMyrGenericParser.ParseExpression(const AMinPower: Integer): TASTNode;
var
  LPrefixRule: TASTNode;
  LInfixEntry: TInfixEntry;
  LNativePrefixHandler: TNativePrefixHandler;
  LNativeInfixEntry: TNativeInfixEntry;
  LLeft: TASTNode;
  LPrefixRules: TDictionary<string, TASTNode>;
  LInfixRules: TDictionary<string, TInfixEntry>;
  LNativePrefixRules: TDictionary<string, TNativePrefixHandler>;
  LNativeInfixRules: TDictionary<string, TNativeInfixEntry>;
  LCurrentKind: string;
  LSavedParser: TObject;
  LSavedPos: Integer;
begin
  LPrefixRules := FInterp.GetPrefixRules();
  LInfixRules := FInterp.GetInfixRules();
  LNativePrefixRules := FInterp.GetNativePrefixRules();
  LNativeInfixRules := FInterp.GetNativeInfixRules();

  // Set active parser so interpreter/native handlers can access us
  LSavedParser := FInterp.GetActiveParser();
  FInterp.SetActiveParser(Self);
  try
    // Prefix dispatch
    LCurrentKind := Current().Kind;

    // Check native prefix handlers first (C++ passthrough)
    if LNativePrefixRules.TryGetValue(LCurrentKind, LNativePrefixHandler) then
      LLeft := LNativePrefixHandler()
    // Then check interpreted prefix rules
    else if LPrefixRules.TryGetValue(LCurrentKind, LPrefixRule) then
      LLeft := FInterp.ExecuteGrammarRule(LPrefixRule)
    else
    begin
      if Assigned(FErrors) then
        FErrors.Add(FFilename, Current().Line, Current().Col,
          esError, MYR_ERR_USERPARSER_NO_PREFIX,
          RSUserParserNoPrefixHandler, [Current().Text], nil);
      Result := TASTNode.Create();
      Result.SetKind('error');
      DoAdvance();
      Exit;
    end;

    // Infix loop
    while not AtEnd() do
    begin
      LCurrentKind := Current().Kind;

      // Check native infix handlers first
      if LNativeInfixRules.TryGetValue(LCurrentKind, LNativeInfixEntry) then
      begin
        // Power check
        if LNativeInfixEntry.Assoc = 'right' then
        begin
          if LNativeInfixEntry.Power < AMinPower then Break;
        end
        else
        begin
          if LNativeInfixEntry.Power <= AMinPower then Break;
        end;
        LSavedPos := FPos;
        LLeft := LNativeInfixEntry.Handler(LLeft);
        if FPos = LSavedPos then Break; // stuck protection
      end
      // Then check interpreted infix rules
      else if LInfixRules.TryGetValue(LCurrentKind, LInfixEntry) then
      begin
        // Power check
        if LInfixEntry.Assoc = 'right' then
        begin
          if LInfixEntry.Power < AMinPower then Break;
        end
        else
        begin
          if LInfixEntry.Power <= AMinPower then Break;
        end;
        LSavedPos := FPos;
        FInterp.SetCurrentInfixPower(LInfixEntry.Power);
        LLeft := FInterp.ExecuteGrammarRule(LInfixEntry.RuleAST, LLeft);
        FInterp.SetCurrentInfixPower(0);
        if FPos = LSavedPos then Break; // stuck protection
      end
      else
        Break;
    end;

    Result := LLeft;
  finally
    FInterp.SetActiveParser(LSavedParser);
  end;
end;

function TMyrGenericParser.ParseExpressionFrom(const ALeft: TASTNode;
  const AMinPower: Integer): TASTNode;
var
  LInfixEntry: TInfixEntry;
  LNativeInfixEntry: TNativeInfixEntry;
  LLeft: TASTNode;
  LInfixRules: TDictionary<string, TInfixEntry>;
  LNativeInfixRules: TDictionary<string, TNativeInfixEntry>;
  LCurrentKind: string;
  LSavedParser: TObject;
  LSavedPos: Integer;
begin
  LInfixRules := FInterp.GetInfixRules();
  LNativeInfixRules := FInterp.GetNativeInfixRules();
  LLeft := ALeft;

  // Set active parser so interpreter/native handlers can access us
  LSavedParser := FInterp.GetActiveParser();
  FInterp.SetActiveParser(Self);
  try
    // Infix loop (same as ParseExpression, but prefix already handled)
    while not AtEnd() do
    begin
      LCurrentKind := Current().Kind;

      // Check native infix handlers first
      if LNativeInfixRules.TryGetValue(LCurrentKind, LNativeInfixEntry) then
      begin
        if LNativeInfixEntry.Assoc = 'right' then
        begin
          if LNativeInfixEntry.Power < AMinPower then Break;
        end
        else
        begin
          if LNativeInfixEntry.Power <= AMinPower then Break;
        end;
        LSavedPos := FPos;
        LLeft := LNativeInfixEntry.Handler(LLeft);
        if FPos = LSavedPos then Break;
      end
      else if LInfixRules.TryGetValue(LCurrentKind, LInfixEntry) then
      begin
        if LInfixEntry.Assoc = 'right' then
        begin
          if LInfixEntry.Power < AMinPower then Break;
        end
        else
        begin
          if LInfixEntry.Power <= AMinPower then Break;
        end;
        LSavedPos := FPos;
        FInterp.SetCurrentInfixPower(LInfixEntry.Power);
        LLeft := FInterp.ExecuteGrammarRule(LInfixEntry.RuleAST, LLeft);
        FInterp.SetCurrentInfixPower(0);
        if FPos = LSavedPos then Break;
      end
      else
        Break;
    end;

    Result := LLeft;
  finally
    FInterp.SetActiveParser(LSavedParser);
  end;
end;

function TMyrGenericParser.ParseStatement(): TASTNode;
var
  LStmtRules: TDictionary<string, TList<TASTNode>>;
  LNativeStmtRules: TDictionary<string, TNativeStmtHandler>;
  LStmtRuleList: TList<TASTNode>;
  LNativeStmtHandler: TNativeStmtHandler;
  LCurrentKind: string;
  LSavedParser: TObject;
  LI: Integer;
  LSavedPos: Integer;
  LSavedItemCount: Integer;
  LSavedErrorCount: Integer;
begin
  LStmtRules := FInterp.GetStmtRules();
  LNativeStmtRules := FInterp.GetNativeStmtRules();
  LCurrentKind := Current().Kind;

  // Set active parser so interpreter/native handlers can access us
  LSavedParser := FInterp.GetActiveParser();
  FInterp.SetActiveParser(Self);
  try
    // Check native statement handlers first (C++ passthrough)
    if LNativeStmtRules.TryGetValue(LCurrentKind, LNativeStmtHandler) then
      Result := LNativeStmtHandler()
    // Then check interpreted statement rules
    else if LStmtRules.TryGetValue(LCurrentKind, LStmtRuleList) then
    begin
      if LStmtRuleList.Count = 1 then
        // Fast path: single rule, same as before
        Result := FInterp.ExecuteGrammarRule(LStmtRuleList[0])
      else
      begin
        // Try each rule in registration order, restore on failure
        Result := nil;
        for LI := 0 to LStmtRuleList.Count - 1 do
        begin
          LSavedPos := GetPos();
          LSavedItemCount := FErrors.Count();
          LSavedErrorCount := FErrors.ErrorCount();
          Result := FInterp.ExecuteGrammarRule(LStmtRuleList[LI]);
          if FErrors.ErrorCount() = LSavedErrorCount then
            Break;  // success — no new errors or fatals
          // Failed: restore position, remove all items from failed attempt
          SetPos(LSavedPos);
          FErrors.TruncateTo(LSavedItemCount);
          Result.Free();
          Result := nil;
        end;
        // All failed: re-run last to produce the error naturally
        if Result = nil then
          Result := FInterp.ExecuteGrammarRule(
            LStmtRuleList[LStmtRuleList.Count - 1]);
      end;
    end
    else
    begin
      // Fall through to expression statement
      Result := ParseExpression(0);
    end;
  finally
    FInterp.SetActiveParser(LSavedParser);
  end;
end;

function TMyrGenericParser.ParseProgram(const ATokens: TList<TToken>;
  const AFilename: string): TASTNode;
var
  LRoot: TASTNode;
  LSavedPos: Integer;
  LToken: TToken;
  LNode: TASTNode;
  LOrphans: TList<TASTNode>;
begin
  FTokens := ATokens;
  FPos := 0;
  FFilename := AFilename;

  LRoot := TASTNode.Create();
  LRoot.SetKind('program.root');
  LToken.Kind := 'program.root';
  LToken.Text := '';
  LToken.Filename := AFilename;
  LToken.Line := 1;
  LToken.Col := 1;
  LRoot.SetToken(LToken);

  try
    while not AtEnd() do
    begin
      if Assigned(FErrors) and FErrors.ReachedMaxErrors() then
        Break;
      LSavedPos := FPos;
      LRoot.AddChild(ParseStatement());
      // Safety: if no tokens were consumed, skip one to prevent infinite loop
      if FPos = LSavedPos then
      begin
        if Assigned(FErrors) then
          FErrors.Add(FFilename, Current().Line, Current().Col,
            esError, MYR_ERR_USERPARSER_UNEXPECTED_STMT,
            'Parser stuck at token: ''%s''', [Current().Text], nil);
        DoAdvance();
      end;
    end;
  finally
    // Free every interpreter-created node that never got parented into the
    // AST (orphans left behind by an aborted parse). Collect first so the
    // cascade-free of an orphan's subtree cannot dangle a later pool entry.
    LOrphans := TList<TASTNode>.Create();
    try
      for LNode in FNodePool do
        if not LNode.IsParented() then
          LOrphans.Add(LNode);
      for LNode in LOrphans do
        LNode.Free();
    finally
      LOrphans.Free();
    end;
    FNodePool.Clear();
  end;

  Result := LRoot;
end;

end.
