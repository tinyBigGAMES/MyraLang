{===============================================================================
  Myra™ - Pascal. Refined.

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://myralang.org

  See LICENSE for license information
===============================================================================}

unit Myra.LSP;

{$I StdApp.Defines.inc}

interface

uses
  WinApi.Windows,
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Generics.Collections,
  System.IOUtils,
  System.Math,
  System.StrUtils,
  StdApp.Base,
  Myra.Common,
  Myra.AST,
  Myra.Interpreter,
  Myra.Scopes,
  Myra.GenericLexer,
  Myra.GenericParser,
  Myra.CodeGen,
  Myra.Engine.API,
  StdApp.Resources;

const
  // LSP Error Codes (L001-L099)
  ERR_LSP_MODULE_NOT_FOUND = 'L001';
  ERR_LSP_LANGDEF_FAILED   = 'L002';

type

  { Forward declarations }
  TLSPDocument = class;
  TLSPService  = class;

  { TLSPPosition }
  TLSPPosition = record
    Line: Integer;
    Character: Integer;

    procedure Clear();
    function ToJSON(): TJSONObject;
    class function FromJSON(const AObj: TJSONObject): TLSPPosition; static;
  end;

  { TLSPRange }
  TLSPRange = record
    StartPos: TLSPPosition;
    EndPos: TLSPPosition;

    procedure Clear();
    function ToJSON(): TJSONObject;
    class function FromJSON(const AObj: TJSONObject): TLSPRange; static;
    class function FromSourceRange(
      const ARange: TSourceRange): TLSPRange; static;
  end;

  { TLSPLocation }
  TLSPLocation = record
    Uri: string;
    Range: TLSPRange;

    function IsEmpty(): Boolean;
    function ToJSON(): TJSONObject;
  end;

  { TLSPDiagnosticRelated }
  TLSPDiagnosticRelated = record
    Location: TLSPLocation;
    Message: string;

    function ToJSON(): TJSONObject;
  end;

  { TLSPDiagnostic }
  TLSPDiagnostic = record
    Range: TLSPRange;
    Severity: Integer;       // 1=Error, 2=Warning, 3=Info, 4=Hint
    Code: string;
    Source: string;
    Message: string;
    Related: TArray<TLSPDiagnosticRelated>;

    function ToJSON(): TJSONObject;
  end;

  { TLSPCompletionItem }
  TLSPCompletionItem = record
    LabelText: string;
    Kind: Integer;
    Detail: string;
    Documentation: string;
    InsertText: string;
    InsertTextFormat: Integer;  // 1=PlainText, 2=Snippet
    SortText: string;

    function ToJSON(): TJSONObject;
  end;

  { TLSPParameterInfo }
  TLSPParameterInfo = record
    LabelText: string;
    Documentation: string;

    function ToJSON(): TJSONObject;
  end;

  { TLSPSignatureInfo }
  TLSPSignatureInfo = record
    LabelText: string;
    Documentation: string;
    Parameters: TArray<TLSPParameterInfo>;

    function ToJSON(): TJSONObject;
  end;

  { TLSPSignatureHelp }
  TLSPSignatureHelp = record
    Signatures: TArray<TLSPSignatureInfo>;
    ActiveSignature: Integer;
    ActiveParameter: Integer;

    function ToJSON(): TJSONObject;
  end;

  { TLSPHover }
  TLSPHover = record
    Contents: string;
    Range: TLSPRange;
    HasRange: Boolean;

    function IsEmpty(): Boolean;
    function ToJSON(): TJSONObject;
  end;

  { TLSPDocumentSymbol }
  TLSPDocumentSymbol = record
    SymbolName: string;
    Detail: string;
    Kind: Integer;
    Range: TLSPRange;
    SelectionRange: TLSPRange;
    Children: TArray<TLSPDocumentSymbol>;

    function ToJSON(): TJSONObject;
  end;

  { TLSPFoldingRange }
  TLSPFoldingRange = record
    StartLine: Integer;
    EndLine: Integer;
    Kind: string;

    function ToJSON(): TJSONObject;
  end;

  { TLSPInlayHint }
  TLSPInlayHint = record
    Position: TLSPPosition;
    LabelText: string;
    Kind: Integer;   // 1=Type, 2=Parameter

    function ToJSON(): TJSONObject;
  end;

  { TLSPTextEdit }
  TLSPTextEdit = record
    Range: TLSPRange;
    NewText: string;

    function ToJSON(): TJSONObject;
  end;

  { TLSPWorkspaceEdit }
  TLSPWorkspaceEdit = record
    Uri: string;
    Edits: TArray<TLSPTextEdit>;

    function ToJSON(): TJSONObject;
  end;

  { TLSPSymbolInformation }
  TLSPSymbolInformation = record
    SymbolName: string;
    Kind: Integer;
    Uri: string;
    Range: TLSPRange;

    function ToJSON(): TJSONObject;
  end;

  { TLSPCallHierarchyItem }
  TLSPCallHierarchyItem = record
    ItemName: string;
    Kind: Integer;
    Uri: string;
    Range: TLSPRange;
    SelectionRange: TLSPRange;

    function ToJSON(): TJSONObject;
  end;

  { TLSPCallHierarchyCall }
  TLSPCallHierarchyCall = record
    Item: TLSPCallHierarchyItem;
    FromRanges: TArray<TLSPRange>;

    function ToJSON(const ADirection: string): TJSONObject;
  end;

  { TLSPDocument }
  TLSPDocument = class(TBaseObject)
  private
    FUri: string;
    FContent: string;
    FVersion: Integer;
    FLines: TStringList;
    FAST: TASTNode;
    FTokens: TList<TToken>;
    FScopes: TScopeManager;
    FInterp: TInterpreter;  // shared, NOT owned
    FProcessedModules: TDictionary<string, Boolean>;

    procedure UpdateLines();

    // Import resolution. The .mld's `on stmt.import_item` handler calls the
    // engine builtin compileModule(name), which is a NO-OP unless a host
    // callback is installed. TEngine installs one; the LSP never did, so every
    // imported module silently failed to load and its symbols never existed.
    function CompileModule(const AModuleName: string): Boolean;

  public
    constructor Create(); override;
    destructor Destroy(); override;

    function GetUri(): string;
    procedure SetUri(const AValue: string);
    function GetContent(): string;
    procedure SetContent(const AValue: string);
    function GetVersion(): Integer;
    procedure SetVersion(const AValue: Integer);

    procedure SetInterpreter(const AInterp: TInterpreter);
    procedure Parse();

    function GetAST(): TASTNode;
    function GetTokens(): TList<TToken>;
    function GetScopes(): TScopeManager;

    function OffsetToPosition(const AOffset: Integer): TLSPPosition;
    function PositionToOffset(const APosition: TLSPPosition): Integer;
    function GetLineCount(): Integer;
    function GetLine(const AIndex: Integer): string;

    function FindNodeAtPosition(
      const APosition: TLSPPosition): TASTNode;
    function FindTokenAtPosition(
      const APosition: TLSPPosition): TToken;
  end;

  { TLSPService }
  TLSPService = class(TBaseObject)
  private
    FDocuments: TObjectDictionary<string, TLSPDocument>;
    FInterp: TInterpreter;  // shared, NOT owned

    function GetDocument(const AUri: string): TLSPDocument;

    // Internal helpers
    function GetIdentifierFromNode(const ANode: TASTNode): string;

    // -- Compiler-internal symbol names are NOT user-facing names. ------------
    // The scopes layer keys routines by their MANGLED signature
    // ("add(int32,int32)") and synthesizes a "__rettype:add" symbol to carry
    // the return type. Both are load-bearing for overload resolution and must
    // stay. But an editor must never see either of them: an outline pane would
    // literally print "add(int32,int32)", and go-to-definition would look up
    // "add" and miss. Translating between the compiler's names and the user's
    // names is the LSP's job, and these two helpers are where it happens.

    // "add(int32,int32)" -> "add".  "TPoint" -> "TPoint".
    function SymBaseName(const ASymName: string): string;
    // "add(int32,int32)" -> "(int32,int32)".  "TPoint" -> ''.
    function SymSignature(const ASymName: string): string;
    // True for compiler bookkeeping symbols that must never reach the editor.
    function SymIsInternal(const ASymName: string): Boolean;
    // Depth-first search of the scope TREE for a symbol whose base name matches.
    function FindSymbolByBaseName(const AScope: TScope;
      const AName: string): TSymbol;

    function ResolveIdentifierAtPosition(
      const ADoc: TLSPDocument;
      const APosition: TLSPPosition;
      out ANode: TASTNode): string;
    function LookupSymbolByName(const ADoc: TLSPDocument;
      const AName: string): TSymbol;
    procedure CollectFoldingRangesFromNode(const ANode: TASTNode;
      var ARanges: TArray<TLSPFoldingRange>);
    procedure CollectReferencesInNode(const ANode: TASTNode;
      const ATargetName: string; const AUri: string;
      var ALocations: TArray<TLSPLocation>);
    procedure CollectReferencesFromTokens(
      const ADoc: TLSPDocument;
      const ATargetName: string; const AUri: string;
      var ALocations: TArray<TLSPLocation>);
    // A symbol belongs to THIS document if its declaration node lives in
    // branch 0 of the master AST. Filename is NOT a usable discriminator --
    // plenty of decl nodes carry an empty range.
    //
    // ACursorLine (0-based, -1 = none) makes the set CURSOR-AWARE: a routine's
    // params and locals are only visible while the cursor is inside THAT
    // routine. The routine's own name always stays visible. Pass -1 for the
    // outline, which wants top-level declarations only.
    procedure BuildDocNodeSet(const ANode: TASTNode;
      const ACursorLine: Integer;
      const ASet: TDictionary<Pointer, Boolean>);
    function NodeContainsLine(const ANode: TASTNode;
      const ACursorLine: Integer): Boolean;
    function SymIsFromDocument(const ASym: TSymbol;
      const ASet: TDictionary<Pointer, Boolean>): Boolean;

    function FindRoutineDeclNode(const ADoc: TLSPDocument;
      const AName: string; const AArgCount: Integer): TASTNode;
    procedure CollectInlayHintsFromNode(const ADoc: TLSPDocument;
      const ANode: TASTNode;
      const AStartLine: Integer; const AEndLine: Integer;
      var AHints: TArray<TLSPInlayHint>);

    procedure CollectDocSymbolsFromScope(const AScope: TScope;
      const ADocNodes: TDictionary<Pointer, Boolean>;
      var ASymbols: TArray<TLSPDocumentSymbol>);
    procedure CollectCompletionsFromScope(const AScope: TScope;
      const ADocNodes: TDictionary<Pointer, Boolean>;
      var AItems: TArray<TLSPCompletionItem>);
    procedure CollectWorkspaceSymbolsFromScope(const AScope: TScope;
      const AQuery: string; const AUri: string;
      var ASymbols: TArray<TLSPSymbolInformation>);

    // Member access (qualifier '.' member).
    // Semantics NEVER resolves a member: `on expr.field_access` only decides
    // '->' vs '.'. There is no member table in the symbol table, so the AST is
    // the ONLY place a module's or record's member list exists.
    function ResolveQualifierBeforeDot(const ADoc: TLSPDocument;
      const APosition: TLSPPosition): string;
    function FindModuleBranch(const ADoc: TLSPDocument;
      const AModuleName: string): TASTNode;
    function FindTypeDeclNode(const ANode: TASTNode;
      const ATypeName: string): TASTNode;
    function ResolveQualifierTypeName(const ADoc: TLSPDocument;
      const AQualifier: string): string;
    procedure CollectMembersFromBranch(const ABranch: TASTNode;
      const AExported: Boolean;
      var AItems: TArray<TLSPCompletionItem>);
    procedure CollectFieldsFromTypeDecl(const ATypeDecl: TASTNode;
      var AItems: TArray<TLSPCompletionItem>);
    function AddCompletion(const AName: string; const AKind: Integer;
      const ADetail: string;
      var AItems: TArray<TLSPCompletionItem>): Boolean;

    // Return type lives in the synthesized "__rettype:<routine>" symbol, which
    // is (correctly) hidden from every user-facing list. Read it back out so
    // hover and signature help can show `: int32`.
    function SymReturnType(const ADoc: TLSPDocument;
      const ABaseName: string): string;

    // Kind mapping
    function NodeKindToSymbolKind(const AKind: string): Integer;
    function SymKindToCompletionKind(const ASymKind: string): Integer;
    function TokenKindToSemanticType(const AKind: string): Integer;
    function ErrorSeverityToLSPSeverity(
      const ASeverity: TErrorSeverity): Integer;

  public
    constructor Create(); override;
    destructor Destroy(); override;

    procedure SetInterpreter(const AInterp: TInterpreter);

    // Document management
    procedure OpenDocument(const AUri: string; const AContent: string);
    procedure UpdateDocument(const AUri: string; const AContent: string;
      const AVersion: Integer);
    procedure CloseDocument(const AUri: string);
    function HasDocument(const AUri: string): Boolean;

    // LSP features
    function GetDiagnostics(const AUri: string): TArray<TLSPDiagnostic>;
    function GetCompletions(const AUri: string; const ALine: Integer;
      const ACharacter: Integer): TArray<TLSPCompletionItem>;
    function GetHover(const AUri: string; const ALine: Integer;
      const ACharacter: Integer): TLSPHover;
    function GetDefinition(const AUri: string; const ALine: Integer;
      const ACharacter: Integer): TLSPLocation;
    function GetReferences(const AUri: string; const ALine: Integer;
      const ACharacter: Integer;
      const AIncludeDeclaration: Boolean): TArray<TLSPLocation>;
    function GetDocumentSymbols(
      const AUri: string): TArray<TLSPDocumentSymbol>;
    function GetFoldingRanges(
      const AUri: string): TArray<TLSPFoldingRange>;
    function GetSemanticTokens(const AUri: string): TArray<Integer>;
    function GetRenameEdits(const AUri: string; const ALine: Integer;
      const ACharacter: Integer;
      const ANewName: string): TLSPWorkspaceEdit;
    function GetWorkspaceSymbols(const AQuery: string;
      const AUri: string): TArray<TLSPSymbolInformation>;
    function GetSignatureHelp(const AUri: string; const ALine: Integer;
      const ACharacter: Integer): TLSPSignatureHelp;
    function GetInlayHints(const AUri: string; const AStartLine: Integer;
      const AStartChar: Integer; const AEndLine: Integer;
      const AEndChar: Integer): TArray<TLSPInlayHint>;
    function GetDocumentFormatting(const AUri: string;
      const ATabSize: Integer;
      const AInsertSpaces: Boolean): TArray<TLSPTextEdit>;
    function GetCodeActions(const AUri: string;
      const AStartLine: Integer; const AStartChar: Integer;
      const AEndLine: Integer;
      const AEndChar: Integer): TArray<TJSONObject>;

    // Utility
    class function FilePathToUri(const APath: string): string; static;
    class function UriToFilePath(const AUri: string): string; static;
  end;

  { TLSPServer }
  TLSPServer = class(TBaseObject)
  private
    FService: TLSPService;
    FEngineAPI: TEngineAPI;
    FMLDFile: string;
    FInitialized: Boolean;
    FShutdownRequested: Boolean;
    FInputStream: TStream;
    FOutputStream: TStream;
    FOwnsStreams: Boolean;

    function ReadMessage(): TJSONObject;
    procedure WriteMessage(const AMessage: TJSONObject);
    procedure SendResponse(const AId: TJSONValue;
      const AResult: TJSONValue);
    procedure SendError(const AId: TJSONValue; const ACode: Integer;
      const AMessage: string);
    procedure SendNotification(const AMethod: string;
      const AParams: TJSONValue);
    procedure DispatchMessage(const AMessage: TJSONObject);
    procedure PublishDiagnostics(const AUri: string);

    // LSP method handlers
    procedure HandleInitialize(const AId: TJSONValue;
      const AParams: TJSONObject);
    procedure HandleShutdown(const AId: TJSONValue);
    procedure HandleInitialized(const AParams: TJSONObject);
    procedure HandleExit();
    procedure HandleTextDocumentDidOpen(const AParams: TJSONObject);
    procedure HandleTextDocumentDidChange(const AParams: TJSONObject);
    procedure HandleTextDocumentDidClose(const AParams: TJSONObject);
    procedure HandleTextDocumentCompletion(const AId: TJSONValue;
      const AParams: TJSONObject);
    procedure HandleTextDocumentHover(const AId: TJSONValue;
      const AParams: TJSONObject);
    procedure HandleTextDocumentDefinition(const AId: TJSONValue;
      const AParams: TJSONObject);
    procedure HandleTextDocumentReferences(const AId: TJSONValue;
      const AParams: TJSONObject);
    procedure HandleTextDocumentDocumentSymbol(const AId: TJSONValue;
      const AParams: TJSONObject);
    procedure HandleTextDocumentSignatureHelp(const AId: TJSONValue;
      const AParams: TJSONObject);
    procedure HandleTextDocumentFoldingRange(const AId: TJSONValue;
      const AParams: TJSONObject);
    procedure HandleTextDocumentSemanticTokensFull(const AId: TJSONValue;
      const AParams: TJSONObject);
    procedure HandleTextDocumentInlayHint(const AId: TJSONValue;
      const AParams: TJSONObject);
    procedure HandleTextDocumentRename(const AId: TJSONValue;
      const AParams: TJSONObject);
    procedure HandleWorkspaceSymbol(const AId: TJSONValue;
      const AParams: TJSONObject);
    procedure HandleTextDocumentCodeAction(const AId: TJSONValue;
      const AParams: TJSONObject);
    procedure HandleTextDocumentFormatting(const AId: TJSONValue;
      const AParams: TJSONObject);

  public
    constructor Create(); override;
    destructor Destroy(); override;

    procedure SetMLDFile(const AMLDFile: string);
    procedure SetStreams(const AInput: TStream; const AOutput: TStream);
    function GetService(): TLSPService;
    procedure Run();
  end;

implementation


{ TLSPPosition }

procedure TLSPPosition.Clear();
begin
  Line := 0;
  Character := 0;
end;

function TLSPPosition.ToJSON(): TJSONObject;
begin
  Result := TJSONObject.Create();
  Result.AddPair('line', TJSONNumber.Create(Line));
  Result.AddPair('character', TJSONNumber.Create(Character));
end;

class function TLSPPosition.FromJSON(
  const AObj: TJSONObject): TLSPPosition;
begin
  Result.Line := AObj.GetValue<Integer>('line', 0);
  Result.Character := AObj.GetValue<Integer>('character', 0);
end;

procedure TLSPRange.Clear();
begin
  StartPos.Clear();
  EndPos.Clear();
end;

function TLSPRange.ToJSON(): TJSONObject;
begin
  Result := TJSONObject.Create();
  Result.AddPair('start', StartPos.ToJSON());
  Result.AddPair('end', EndPos.ToJSON());
end;

class function TLSPRange.FromJSON(
  const AObj: TJSONObject): TLSPRange;
var
  LStart: TJSONObject;
  LEnd: TJSONObject;
begin
  Result.Clear();
  LStart := AObj.GetValue<TJSONObject>('start', nil);
  if LStart <> nil then
    Result.StartPos := TLSPPosition.FromJSON(LStart);
  LEnd := AObj.GetValue<TJSONObject>('end', nil);
  if LEnd <> nil then
    Result.EndPos := TLSPPosition.FromJSON(LEnd);
end;

class function TLSPRange.FromSourceRange(
  const ARange: TSourceRange): TLSPRange;
begin
  // LSP is 0-based; Myra source ranges are 1-based
  Result.StartPos.Line := Max(0, ARange.StartLine - 1);
  Result.StartPos.Character := Max(0, ARange.StartColumn - 1);
  Result.EndPos.Line := Max(0, ARange.EndLine - 1);
  Result.EndPos.Character := Max(0, ARange.EndColumn - 1);
end;

function TLSPLocation.IsEmpty(): Boolean;
begin
  Result := Uri = '';
end;

function TLSPLocation.ToJSON(): TJSONObject;
begin
  Result := TJSONObject.Create();
  Result.AddPair('uri', Uri);
  Result.AddPair('range', Range.ToJSON());
end;

function TLSPDiagnosticRelated.ToJSON(): TJSONObject;
begin
  Result := TJSONObject.Create();
  Result.AddPair('location', Location.ToJSON());
  Result.AddPair('message', Message);
end;

function TLSPDiagnostic.ToJSON(): TJSONObject;
var
  LRelatedArray: TJSONArray;
  LI: Integer;
begin
  Result := TJSONObject.Create();
  Result.AddPair('range', Range.ToJSON());
  Result.AddPair('severity', TJSONNumber.Create(Severity));
  if Code <> '' then
    Result.AddPair('code', Code);
  if Source <> '' then
    Result.AddPair('source', Source);
  Result.AddPair('message', Message);
  if Length(Related) > 0 then
  begin
    LRelatedArray := TJSONArray.Create();
    for LI := 0 to High(Related) do
      LRelatedArray.AddElement(Related[LI].ToJSON());
    Result.AddPair('relatedInformation', LRelatedArray);
  end;
end;

function TLSPCompletionItem.ToJSON(): TJSONObject;
begin
  Result := TJSONObject.Create();
  Result.AddPair('label', LabelText);
  Result.AddPair('kind', TJSONNumber.Create(Kind));
  if Detail <> '' then
    Result.AddPair('detail', Detail);
  if Documentation <> '' then
    Result.AddPair('documentation', Documentation);
  if InsertText <> '' then
    Result.AddPair('insertText', InsertText);
  if InsertTextFormat <> 0 then
    Result.AddPair('insertTextFormat',
      TJSONNumber.Create(InsertTextFormat));
  if SortText <> '' then
    Result.AddPair('sortText', SortText);
end;

function TLSPParameterInfo.ToJSON(): TJSONObject;
begin
  Result := TJSONObject.Create();
  Result.AddPair('label', LabelText);
  if Documentation <> '' then
    Result.AddPair('documentation', Documentation);
end;

function TLSPSignatureInfo.ToJSON(): TJSONObject;
var
  LParamsArray: TJSONArray;
  LI: Integer;
begin
  Result := TJSONObject.Create();
  Result.AddPair('label', LabelText);
  if Documentation <> '' then
    Result.AddPair('documentation', Documentation);
  if Length(Parameters) > 0 then
  begin
    LParamsArray := TJSONArray.Create();
    for LI := 0 to High(Parameters) do
      LParamsArray.AddElement(Parameters[LI].ToJSON());
    Result.AddPair('parameters', LParamsArray);
  end;
end;

function TLSPSignatureHelp.ToJSON(): TJSONObject;
var
  LSigsArray: TJSONArray;
  LI: Integer;
begin
  Result := TJSONObject.Create();
  LSigsArray := TJSONArray.Create();
  for LI := 0 to High(Signatures) do
    LSigsArray.AddElement(Signatures[LI].ToJSON());
  Result.AddPair('signatures', LSigsArray);
  Result.AddPair('activeSignature',
    TJSONNumber.Create(ActiveSignature));
  Result.AddPair('activeParameter',
    TJSONNumber.Create(ActiveParameter));
end;

function TLSPHover.IsEmpty(): Boolean;
begin
  Result := Contents = '';
end;

function TLSPHover.ToJSON(): TJSONObject;
var
  LContents: TJSONObject;
begin
  Result := TJSONObject.Create();
  LContents := TJSONObject.Create();
  LContents.AddPair('kind', 'markdown');
  LContents.AddPair('value', Contents);
  Result.AddPair('contents', LContents);
  if HasRange then
    Result.AddPair('range', Range.ToJSON());
end;

function TLSPDocumentSymbol.ToJSON(): TJSONObject;
var
  LChildArray: TJSONArray;
  LI: Integer;
begin
  Result := TJSONObject.Create();
  Result.AddPair('name', SymbolName);
  if Detail <> '' then
    Result.AddPair('detail', Detail);
  Result.AddPair('kind', TJSONNumber.Create(Kind));
  Result.AddPair('range', Range.ToJSON());
  Result.AddPair('selectionRange', SelectionRange.ToJSON());
  if Length(Children) > 0 then
  begin
    LChildArray := TJSONArray.Create();
    for LI := 0 to High(Children) do
      LChildArray.AddElement(Children[LI].ToJSON());
    Result.AddPair('children', LChildArray);
  end;
end;

function TLSPFoldingRange.ToJSON(): TJSONObject;
begin
  Result := TJSONObject.Create();
  Result.AddPair('startLine', TJSONNumber.Create(StartLine));
  Result.AddPair('endLine', TJSONNumber.Create(EndLine));
  if Kind <> '' then
    Result.AddPair('kind', Kind);
end;

function TLSPInlayHint.ToJSON(): TJSONObject;
begin
  Result := TJSONObject.Create();
  Result.AddPair('position', Position.ToJSON());
  Result.AddPair('label', LabelText);
  Result.AddPair('kind', TJSONNumber.Create(Kind));
end;

function TLSPTextEdit.ToJSON(): TJSONObject;
begin
  Result := TJSONObject.Create();
  Result.AddPair('range', Range.ToJSON());
  Result.AddPair('newText', NewText);
end;

function TLSPWorkspaceEdit.ToJSON(): TJSONObject;
var
  LEditsArray: TJSONArray;
  LI: Integer;
begin
  Result := TJSONObject.Create();
  Result.AddPair('uri', Uri);
  LEditsArray := TJSONArray.Create();
  for LI := 0 to High(Edits) do
    LEditsArray.AddElement(Edits[LI].ToJSON());
  Result.AddPair('edits', LEditsArray);
end;

function TLSPSymbolInformation.ToJSON(): TJSONObject;
var
  LLocation: TJSONObject;
begin
  Result := TJSONObject.Create();
  Result.AddPair('name', SymbolName);
  Result.AddPair('kind', TJSONNumber.Create(Kind));
  LLocation := TJSONObject.Create();
  LLocation.AddPair('uri', Uri);
  LLocation.AddPair('range', Range.ToJSON());
  Result.AddPair('location', LLocation);
end;

function TLSPCallHierarchyItem.ToJSON(): TJSONObject;
begin
  Result := TJSONObject.Create();
  Result.AddPair('name', ItemName);
  Result.AddPair('kind', TJSONNumber.Create(Kind));
  Result.AddPair('uri', Uri);
  Result.AddPair('range', Range.ToJSON());
  Result.AddPair('selectionRange', SelectionRange.ToJSON());
end;

function TLSPCallHierarchyCall.ToJSON(
  const ADirection: string): TJSONObject;
var
  LRangesArray: TJSONArray;
  LI: Integer;
begin
  Result := TJSONObject.Create();
  Result.AddPair(ADirection, Item.ToJSON());
  LRangesArray := TJSONArray.Create();
  for LI := 0 to High(FromRanges) do
    LRangesArray.AddElement(FromRanges[LI].ToJSON());
  Result.AddPair('fromRanges', LRangesArray);
end;

{ TLSPDocument }
constructor TLSPDocument.Create();
begin
  inherited Create();
  FUri := '';
  FContent := '';
  FVersion := 0;
  FLines := TStringList.Create();
  FAST := nil;
  FTokens := nil;
  FScopes := nil;
  FInterp := nil;
  FProcessedModules := TDictionary<string, Boolean>.Create();
end;

destructor TLSPDocument.Destroy();
begin
  FreeAndNil(FProcessedModules);
  FreeAndNil(FScopes);
  FreeAndNil(FAST);
  FreeAndNil(FTokens);
  FreeAndNil(FLines);
  inherited Destroy();
end;

procedure TLSPDocument.UpdateLines();
begin
  FLines.Clear();
  FLines.Text := FContent;
end;

function TLSPDocument.GetUri(): string;
begin
  Result := FUri;
end;

procedure TLSPDocument.SetUri(const AValue: string);
begin
  FUri := AValue;
end;

function TLSPDocument.GetContent(): string;
begin
  Result := FContent;
end;

procedure TLSPDocument.SetContent(const AValue: string);
begin
  FContent := AValue;
end;

function TLSPDocument.GetVersion(): Integer;
begin
  Result := FVersion;
end;

procedure TLSPDocument.SetVersion(const AValue: Integer);
begin
  FVersion := AValue;
end;

procedure TLSPDocument.SetInterpreter(
  const AInterp: TInterpreter);
begin
  FInterp := AInterp;
end;

function TLSPDocument.CompileModule(const AModuleName: string): Boolean;
var
  LModuleFile: string;
  LModulePath: string;
  LCandidate: string;
  LSource: string;
  LGenLexer: TGenericLexer;
  LGenParser: TMyrGenericParser;
  LTokens: TList<TToken>;
  LBranch: TASTNode;
  LI: Integer;
begin
  Result := False;
  if (FInterp = nil) or (FAST = nil) or (AModuleName = '') then Exit;

  // Resolve <name>.<module ext> against the document's own directory first,
  // then the interpreter's module search paths (this is what makes the std
  // library resolve). Same resolution order as TEngine.CompileModule.
  LModuleFile := AModuleName + '.' + FInterp.GetModuleExtension();
  LModulePath := TPath.Combine(
    TPath.GetDirectoryName(TLSPService.UriToFilePath(FUri)), LModuleFile);

  if not TFile.Exists(LModulePath) then
  begin
    for LI := 0 to FInterp.GetModulePaths().Count - 1 do
    begin
      LCandidate := TPath.Combine(FInterp.GetModulePaths()[LI], LModuleFile);
      if TFile.Exists(LCandidate) then
      begin
        LModulePath := LCandidate;
        Break;
      end;
    end;
  end;

  // Dedup: a module imported by two files must not be compiled twice into the
  // same scope tree.
  if FProcessedModules.ContainsKey(TPath.GetFullPath(LModulePath)) then
    Exit(True);

  if not TFile.Exists(LModulePath) then
  begin
    // An unresolvable import is a real error and now surfaces as a diagnostic.
    FErrors.Add(esError, ERR_LSP_MODULE_NOT_FOUND,
      RSLSPModuleNotFound, [AModuleName], nil);
    Exit(False);
  end;

  try
    LSource := TFile.ReadAllText(LModulePath, TEncoding.UTF8);
  except
    on E: Exception do
    begin
      FErrors.Add(esError, ERR_LSP_MODULE_NOT_FOUND,
        RSLSPModuleNotFound, [AModuleName], nil);
      Exit(False);
    end;
  end;

  LGenLexer := TGenericLexer.Create();
  try
    LGenLexer.SetErrors(FErrors);
    LGenLexer.Configure(FInterp);
    LTokens := LGenLexer.Tokenize(LSource, LModulePath);
  finally
    LGenLexer.Free();
  end;

  if LTokens = nil then Exit(False);

  LGenParser := TMyrGenericParser.Create();
  try
    LGenParser.SetErrors(FErrors);
    LGenParser.Configure(FInterp);
    LBranch := LGenParser.ParseProgram(LTokens, LModulePath);
  finally
    LGenParser.Free();
  end;
  LTokens.Free();

  if LBranch = nil then Exit(False);

  // Attach the module branch to this document's master root. Member completion
  // reads the branch back out of the AST -- the symbol table has no notion of
  // "members of module X", so the AST is the only place that mapping exists.
  LBranch.SetAttr('source_name', AModuleName);
  FAST.AddChild(LBranch);
  FProcessedModules.Add(TPath.GetFullPath(LModulePath), True);

  // Semantics on the new branch. May recurse into further compileModule calls.
  FInterp.RunSemanticHandler(LBranch);

  Result := True;
end;

procedure TLSPDocument.Parse();
var
  LGenLexer: TGenericLexer;
  LGenParser: TMyrGenericParser;
  LOutput: TCodeOutput;
  LMasterRoot: TASTNode;
  LBranch: TASTNode;
begin
  // Free previous results
  FreeAndNil(FScopes);
  FreeAndNil(FAST);
  FreeAndNil(FTokens);
  FProcessedModules.Clear();

  FErrors.Clear();
  FErrors.SetMaxErrors(100);

  // Lex user source via table-driven lexer
  LGenLexer := TGenericLexer.Create();
  try
    LGenLexer.SetErrors(FErrors);
    LGenLexer.Configure(FInterp);
    FTokens := LGenLexer.Tokenize(FContent, FUri);
  finally
    LGenLexer.Free();
  end;

  if FErrors.HasErrors() then
  begin
    UpdateLines();
    Exit;
  end;

  // Parse user source into a branch
  LGenParser := TMyrGenericParser.Create();
  try
    LGenParser.SetErrors(FErrors);
    LGenParser.Configure(FInterp);
    LBranch := LGenParser.ParseProgram(FTokens, FUri);
  finally
    LGenParser.Free();
  end;

  if LBranch = nil then
  begin
    UpdateLines();
    Exit;
  end;

  // Assemble master AST (single branch for this document)
  LMasterRoot := TASTNode.Create();
  LMasterRoot.SetKind('master.root');
  LMasterRoot.AddChild(LBranch);
  FAST := LMasterRoot;

  // Run semantic analysis with per-document scopes
  FScopes := TScopeManager.Create();
  FScopes.SetErrors(FErrors);
  LOutput := TCodeOutput.Create();
  try
    FInterp.SetScopes(FScopes);
    FInterp.SetOutput(LOutput);
    // THE import fix: without this the compileModule builtin returns False and
    // every `import Maths;` loads nothing at all.
    FInterp.SetCompileModuleFunc(CompileModule);
    FInterp.RunSemantics(FAST);
  finally
    FInterp.SetCompileModuleFunc(nil);
    FInterp.SetScopes(nil);
    FInterp.SetOutput(nil);
    LOutput.Free();
  end;

  UpdateLines();
end;

function TLSPDocument.GetAST(): TASTNode;
begin
  Result := FAST;
end;

function TLSPDocument.GetTokens(): TList<TToken>;
begin
  Result := FTokens;
end;

function TLSPDocument.GetScopes(): TScopeManager;
begin
  Result := FScopes;
end;

function TLSPDocument.OffsetToPosition(
  const AOffset: Integer): TLSPPosition;
var
  LLine: Integer;
  LPos: Integer;
  LLineLen: Integer;
begin
  Result.Clear();
  LPos := 0;
  LLine := 0;

  while LLine < FLines.Count do
  begin
    LLineLen := Length(FLines[LLine]) + 1;
    if LPos + LLineLen > AOffset then
    begin
      Result.Line := LLine;
      Result.Character := AOffset - LPos;
      Exit;
    end;
    LPos := LPos + LLineLen;
    Inc(LLine);
  end;

  if FLines.Count > 0 then
  begin
    Result.Line := FLines.Count - 1;
    Result.Character := Length(FLines[FLines.Count - 1]);
  end;
end;

function TLSPDocument.PositionToOffset(
  const APosition: TLSPPosition): Integer;
var
  LLine: Integer;
  LI: Integer;
begin
  LLine := 0;
  LI := 1;

  while LI <= Length(FContent) do
  begin
    if LLine = APosition.Line then
    begin
      Result := LI - 1 + APosition.Character;
      Exit;
    end;
    if FContent[LI] = #13 then
    begin
      Inc(LLine);
      Inc(LI);
      if (LI <= Length(FContent)) and (FContent[LI] = #10) then
        Inc(LI);
    end
    else if FContent[LI] = #10 then
    begin
      Inc(LLine);
      Inc(LI);
    end
    else
      Inc(LI);
  end;

  if LLine = APosition.Line then
    Result := Length(FContent) + APosition.Character
  else
    Result := Length(FContent);
end;

function TLSPDocument.GetLineCount(): Integer;
begin
  Result := FLines.Count;
end;

function TLSPDocument.GetLine(const AIndex: Integer): string;
begin
  if (AIndex >= 0) and (AIndex < FLines.Count) then
    Result := FLines[AIndex]
  else
    Result := '';
end;

function TLSPDocument.FindNodeAtPosition(
  const APosition: TLSPPosition): TASTNode;

  function ContainsPosition(const ARange: TSourceRange): Boolean;
  var
    LLine: Integer;
    LChar: Integer;
  begin
    LLine := APosition.Line + 1;
    LChar := APosition.Character + 1;

    if ARange.IsEmpty() then
      Exit(False);

    if (LLine < ARange.StartLine) or (LLine > ARange.EndLine) then
      Exit(False);
    if ARange.StartLine = ARange.EndLine then
    begin
      Result := (LChar >= ARange.StartColumn) and
        (LChar <= ARange.EndColumn);
      Exit;
    end;
    if LLine = ARange.StartLine then
      Result := LChar >= ARange.StartColumn
    else if LLine = ARange.EndLine then
      Result := LChar <= ARange.EndColumn
    else
      Result := True;
  end;

  function SearchNode(const ANode: TASTNode): TASTNode;
  var
    LI: Integer;
    LChild: TASTNode;
    LFound: TASTNode;
    LContains: Boolean;
  begin
    Result := nil;
    if ANode = nil then Exit;

    LContains := ContainsPosition(ANode.GetRange());

    // Skip if node has a range that doesn't contain the position.
    // Nodes with empty ranges (e.g. master.root) always recurse.
    if (not ANode.GetRange().IsEmpty()) and (not LContains) then Exit;

    for LI := 0 to ANode.ChildCount() - 1 do
    begin
      LChild := ANode.GetChild(LI);
      LFound := SearchNode(LChild);
      if LFound <> nil then
        Exit(LFound);
    end;

    // Only return this node if its range actually contains the position
    if LContains then
      Result := ANode;
  end;

begin
  Result := SearchNode(FAST);
end;

function TLSPDocument.FindTokenAtPosition(
  const APosition: TLSPPosition): TToken;
var
  LLine: Integer;
  LCol: Integer;
  LLow: Integer;
  LHigh: Integer;
  LMid: Integer;
  LToken: TToken;
  LTokenEnd: Integer;
begin
  Result.Kind := '';
  Result.Text := '';
  Result.Filename := '';
  Result.Line := 0;
  Result.Col := 0;

  if (FTokens = nil) or (FTokens.Count = 0) then Exit;

  // Convert LSP 0-indexed position to 1-indexed token coordinates
  LLine := APosition.Line + 1;
  LCol := APosition.Character + 1;

  // Binary search: tokens are sorted by (Line, Col) in source order
  LLow := 0;
  LHigh := FTokens.Count - 1;
  while LLow <= LHigh do
  begin
    LMid := (LLow + LHigh) div 2;
    LToken := FTokens[LMid];

    if LToken.Line < LLine then
      LLow := LMid + 1
    else if LToken.Line > LLine then
      LHigh := LMid - 1
    else
    begin
      // Same line: check column range
      LTokenEnd := LToken.Col + Length(LToken.Text) - 1;
      if LCol < LToken.Col then
        LHigh := LMid - 1
      else if LCol > LTokenEnd then
        LLow := LMid + 1
      else
      begin
        // Position is within this token
        Result := LToken;
        Exit;
      end;
    end;
  end;
end;

{ TLSPService }
constructor TLSPService.Create();
begin
  inherited Create();
  FDocuments := TObjectDictionary<string, TLSPDocument>.Create(
    [doOwnsValues]);
  FInterp := nil;
end;

destructor TLSPService.Destroy();
begin
  FreeAndNil(FDocuments);
  inherited Destroy();
end;

procedure TLSPService.SetInterpreter(
  const AInterp: TInterpreter);
begin
  FInterp := AInterp;
end;

function TLSPService.GetDocument(
  const AUri: string): TLSPDocument;
begin
  if not FDocuments.TryGetValue(AUri, Result) then
    Result := nil;
end;

procedure TLSPService.OpenDocument(const AUri: string;
  const AContent: string);
var
  LDoc: TLSPDocument;
begin
  LDoc := TLSPDocument.Create();
  LDoc.SetUri(AUri);
  LDoc.SetContent(AContent);
  LDoc.SetVersion(1);
  LDoc.SetInterpreter(FInterp);
  LDoc.Parse();
  FDocuments.AddOrSetValue(AUri, LDoc);
end;

procedure TLSPService.UpdateDocument(const AUri: string;
  const AContent: string; const AVersion: Integer);
var
  LDoc: TLSPDocument;
begin
  LDoc := GetDocument(AUri);
  if LDoc = nil then
  begin
    OpenDocument(AUri, AContent);
    Exit;
  end;
  LDoc.SetContent(AContent);
  LDoc.SetVersion(AVersion);
  LDoc.Parse();
end;

procedure TLSPService.CloseDocument(const AUri: string);
begin
  FDocuments.Remove(AUri);
end;

function TLSPService.HasDocument(const AUri: string): Boolean;
begin
  Result := FDocuments.ContainsKey(AUri);
end;

function TLSPService.GetIdentifierFromNode(
  const ANode: TASTNode): string;
begin
  Result := '';
  if ANode = nil then Exit;

  // Language-agnostic: if the node's token is an identifier, use its text.
  // This works because FindNodeAtPosition returns the deepest node,
  // so identifier tokens resolve directly without attribute guessing.
  if ANode.GetToken().Kind = 'identifier' then
    Result := ANode.GetToken().Text;
end;

function TLSPService.ResolveIdentifierAtPosition(
  const ADoc: TLSPDocument;
  const APosition: TLSPPosition;
  out ANode: TASTNode): string;
var
  LToken: TToken;
begin
  Result := '';
  ANode := nil;
  if ADoc = nil then Exit;

  // First pass: AST-based lookup (deepest node at position)
  ANode := ADoc.FindNodeAtPosition(APosition);
  if ANode <> nil then
  begin
    Result := GetIdentifierFromNode(ANode);
    if Result <> '' then Exit;
  end;

  // Second pass: token-based lookup via binary search on the token list.
  // This handles identifiers consumed as attributes on parent nodes
  // (e.g. function names, variable names in declarations) which have
  // no dedicated AST node of their own.
  LToken := ADoc.FindTokenAtPosition(APosition);
  if LToken.Kind = 'identifier' then
    Result := LToken.Text;
end;

function TLSPService.SymBaseName(const ASymName: string): string;
var
  LPos: Integer;
begin
  Result := ASymName;
  LPos := Pos('(', Result);
  if LPos > 0 then
    Result := Copy(Result, 1, LPos - 1);
end;

function TLSPService.SymSignature(const ASymName: string): string;
var
  LPos: Integer;
begin
  Result := '';
  LPos := Pos('(', ASymName);
  if LPos > 0 then
    Result := Copy(ASymName, LPos, MaxInt);
end;

function TLSPService.SymIsInternal(const ASymName: string): Boolean;
begin
  // The scopes layer synthesizes "__rettype:<routine>" to carry a routine's
  // return type. It is bookkeeping, not a symbol the user ever wrote.
  Result := ASymName.StartsWith('__');
end;

function TLSPService.FindSymbolByBaseName(const AScope: TScope;
  const AName: string): TSymbol;
var
  LPair: TPair<string, TSymbol>;
  LI: Integer;
begin
  Result := nil;
  if (AScope = nil) or (AName = '') then Exit;

  for LPair in AScope.GetSymbols() do
  begin
    if LPair.Value = nil then Continue;
    if SymIsInternal(LPair.Value.GetSymName()) then Continue;
    if SameText(SymBaseName(LPair.Value.GetSymName()), AName) then
      Exit(LPair.Value);
  end;

  // Routines are NOT declared in the scope GetCurrent() returns -- they live in
  // child scopes. Scanning only the current scope is why go-to-definition still
  // missed after the base-name fix. CollectDocSymbolsFromScope recurses, which
  // is exactly why documentSymbol could see `add` when definition could not.
  for LI := 0 to AScope.GetChildren().Count - 1 do
  begin
    Result := FindSymbolByBaseName(AScope.GetChildren()[LI], AName);
    if Result <> nil then Exit;
  end;
end;

function TLSPService.LookupSymbolByName(
  const ADoc: TLSPDocument;
  const AName: string): TSymbol;
var
  LScopes: TScopeManager;
begin
  Result := nil;
  if (ADoc = nil) or (AName = '') then Exit;
  LScopes := ADoc.GetScopes();
  if LScopes = nil then Exit;

  // Fast path: a plain symbol (variable, type, constant) is keyed by its own
  // name and resolves directly.
  Result := LScopes.LookupGlobal(AName);
  if Result <> nil then Exit;

  // Slow path: a ROUTINE is keyed by its mangled signature, so a lookup of the
  // bare name the user clicked on ("add") can never match ("add(int32,int32)").
  // This is why go-to-definition returned null while find-references -- which
  // matches raw token text and never consults the symbol table -- worked fine.
  Result := FindSymbolByBaseName(LScopes.GetCurrent(), AName);
end;

function TLSPService.NodeKindToSymbolKind(
  const AKind: string): Integer;
begin
  // Language-agnostic: maps TSymbol.GetSymKind() strings
  // (set by .mor `declare @name as kind` statements) to LSP SymbolKind
  if (AKind = 'routine') or (AKind = 'function') or
     (AKind = 'procedure') or (AKind = 'method') then
    Result := 12   // Function
  else if (AKind = 'variable') or (AKind = 'parameter') then
    Result := 13   // Variable
  else if (AKind = 'type') or (AKind = 'class') or
          (AKind = 'record') or (AKind = 'struct') then
    Result := 5    // Class
  else if AKind = 'constant' then
    Result := 14   // Constant
  else if (AKind = 'module') or (AKind = 'unit') or
          (AKind = 'program') or (AKind = 'package') then
    Result := 2    // Module
  else if AKind = 'field' then
    Result := 8    // Field
  else if (AKind = 'enum') or (AKind = 'enum_value') then
    Result := 10   // Enum
  else
    Result := 13;  // Variable (fallback)
end;

function TLSPService.SymKindToCompletionKind(
  const ASymKind: string): Integer;
begin
  if ASymKind = 'variable' then
    Result := 6
  else if ASymKind = 'routine' then
    Result := 3
  else if ASymKind = 'type' then
    Result := 7
  else if ASymKind = 'parameter' then
    Result := 6
  else if ASymKind = 'field' then
    Result := 5
  else if ASymKind = 'constant' then
    Result := 21
  else
    Result := 1;
end;

function TLSPService.TokenKindToSemanticType(
  const AKind: string): Integer;
begin
  if AKind.StartsWith('kw.') then
    Result := 10   // keyword
  else if AKind.StartsWith('op.') then
    Result := 11   // operator
  else if AKind.StartsWith('num.') then
    Result := 12   // number
  else if AKind.StartsWith('str.') then
    Result := 13   // string
  else if AKind.StartsWith('comment.') then
    Result := 14   // comment
  else if AKind = 'identifier' then
    Result := 7    // variable
  else
    Result := -1;  // skip
end;

function TLSPService.ErrorSeverityToLSPSeverity(
  const ASeverity: TErrorSeverity): Integer;
begin
  if ASeverity = esHint then
    Result := 4
  else if ASeverity = esWarning then
    Result := 2
  else
    Result := 1;
end;

class function TLSPService.FilePathToUri(const APath: string): string;
var
  LNormalized: string;
begin
  LNormalized := StringReplace(APath, '\', '/', [rfReplaceAll]);
  Result := 'file:///' + LNormalized;
end;

class function TLSPService.UriToFilePath(const AUri: string): string;
begin
  Result := AUri;
  if Result.StartsWith('file:///') then
    Result := Copy(Result, 9, MaxInt);
  Result := StringReplace(Result, '/', PathDelim, [rfReplaceAll]);
end;

function TLSPService.GetDiagnostics(
  const AUri: string): TArray<TLSPDiagnostic>;
var
  LDoc: TLSPDocument;
  LErrors: TErrors;
  LItems: TList<TError>;
  LI: Integer;
  LJ: Integer;
  LError: TError;
  LDiag: TLSPDiagnostic;
  LRelated: TLSPDiagnosticRelated;
begin
  SetLength(Result, 0);
  LDoc := GetDocument(AUri);
  if LDoc = nil then Exit;
  LErrors := LDoc.GetErrors();
  if LErrors = nil then Exit;

  LItems := LErrors.GetItems();
  SetLength(Result, LItems.Count);
  for LI := 0 to LItems.Count - 1 do
  begin
    LError := LItems[LI];
    LDiag.Range := TLSPRange.FromSourceRange(LError.Range);
    LDiag.Severity := ErrorSeverityToLSPSeverity(LError.Severity);
    LDiag.Code := LError.Code;
    LDiag.Source := 'myra';
    LDiag.Message := LError.Message;
    SetLength(LDiag.Related, Length(LError.Related));
    for LJ := 0 to High(LError.Related) do
    begin
      LRelated.Location.Uri := AUri;
      LRelated.Location.Range := TLSPRange.FromSourceRange(
        LError.Related[LJ].Range);
      LRelated.Message := LError.Related[LJ].Msg;
      LDiag.Related[LJ] := LRelated;
    end;
    Result[LI] := LDiag;
  end;
end;

function TLSPService.SymReturnType(const ADoc: TLSPDocument;
  const ABaseName: string): string;
var
  LSym: TSymbol;
begin
  Result := '';
  if (ADoc = nil) or (ABaseName = '') then Exit;
  if ADoc.GetScopes() = nil then Exit;

  LSym := ADoc.GetScopes().LookupGlobal('__rettype:' + ABaseName);
  if LSym = nil then
    LSym := FindSymbolByBaseName(
      ADoc.GetScopes().GetCurrent(), '__rettype:' + ABaseName);
  if LSym <> nil then
    Result := LSym.GetTypeName();
end;

function TLSPService.AddCompletion(const AName: string; const AKind: Integer;
  const ADetail: string;
  var AItems: TArray<TLSPCompletionItem>): Boolean;
var
  LItem: TLSPCompletionItem;
  LI: Integer;
begin
  Result := False;
  if AName = '' then Exit;

  // Overloads share one name ("Abs" exists three times in Maths). The user
  // picks a NAME from this list, not a signature -- signature help resolves the
  // overload once they type '('. One entry per name.
  for LI := 0 to High(AItems) do
    if SameText(AItems[LI].LabelText, AName) then Exit;

  LItem.LabelText := AName;
  LItem.Kind := AKind;
  LItem.Detail := ADetail;
  LItem.Documentation := '';
  LItem.InsertText := AName;
  LItem.InsertTextFormat := 1;
  LItem.SortText := '0' + AName;

  SetLength(AItems, Length(AItems) + 1);
  AItems[High(AItems)] := LItem;
  Result := True;
end;

function TLSPService.ResolveQualifierBeforeDot(const ADoc: TLSPDocument;
  const APosition: TLSPPosition): string;
var
  LContent: string;
  LOffset: Integer;
  LI: Integer;
  LNameEnd: Integer;
  LNameStart: Integer;
begin
  Result := '';
  if ADoc = nil then Exit;

  LContent := ADoc.GetContent();

  // PositionToOffset is ZERO-BASED while Delphi strings are ONE-BASED, so the
  // character immediately BEFORE the cursor is LContent[LOffset].
  LOffset := ADoc.PositionToOffset(APosition);
  if LOffset > Length(LContent) then
    LOffset := Length(LContent);
  if LOffset < 1 then Exit;

  // Skip a partially typed member ("Maths.Sq|" must still complete on Maths).
  LI := LOffset;
  while (LI >= 1) and
        CharInSet(LContent[LI], ['a'..'z', 'A'..'Z', '0'..'9', '_']) do
    Dec(LI);

  if (LI < 1) or (LContent[LI] <> '.') then Exit;

  // The identifier immediately before the '.' is the qualifier.
  LNameEnd := LI - 1;
  while (LNameEnd >= 1) and CharInSet(LContent[LNameEnd], [' ', #9]) do
    Dec(LNameEnd);

  LNameStart := LNameEnd;
  while (LNameStart >= 1) and
        CharInSet(LContent[LNameStart],
          ['a'..'z', 'A'..'Z', '0'..'9', '_']) do
    Dec(LNameStart);
  Inc(LNameStart);

  if LNameStart > LNameEnd then Exit;
  Result := Copy(LContent, LNameStart, LNameEnd - LNameStart + 1);
end;

function TLSPService.FindModuleBranch(const ADoc: TLSPDocument;
  const AModuleName: string): TASTNode;
var
  LRoot: TASTNode;
  LI: Integer;
  LBranch: TASTNode;
begin
  Result := nil;
  if (ADoc = nil) or (AModuleName = '') then Exit;

  LRoot := ADoc.GetAST();
  if LRoot = nil then Exit;

  // Branch index 0 is the document itself. Imported modules are the branches
  // TLSPDocument.CompileModule attached, tagged with 'source_name'.
  for LI := 1 to LRoot.ChildCount() - 1 do
  begin
    LBranch := LRoot.GetChild(LI);
    if LBranch = nil then Continue;
    if SameText(LBranch.GetAttr('source_name'), AModuleName) then
      Exit(LBranch);
  end;
end;

function TLSPService.FindTypeDeclNode(const ANode: TASTNode;
  const ATypeName: string): TASTNode;
var
  LI: Integer;
  LChild: TASTNode;
begin
  Result := nil;
  if (ANode = nil) or (ATypeName = '') then Exit;

  if (ANode.GetKind() = 'stmt.type_decl') and
     SameText(ANode.GetAttr('decl.name'), ATypeName) then
    Exit(ANode);

  for LI := 0 to ANode.ChildCount() - 1 do
  begin
    LChild := ANode.GetChild(LI);
    Result := FindTypeDeclNode(LChild, ATypeName);
    if Result <> nil then Exit;
  end;
end;

function TLSPService.ResolveQualifierTypeName(const ADoc: TLSPDocument;
  const AQualifier: string): string;
var
  LSym: TSymbol;
begin
  // The declared type of the qualifier, with pointer decoration stripped:
  // `p: pointer to TPoint` and `p: TPoint` must both complete to TPoint's
  // fields -- the LSP does not care that one emits '->' and the other '.'.
  Result := '';
  LSym := LookupSymbolByName(ADoc, AQualifier);
  if LSym = nil then Exit;

  Result := LSym.GetTypeName().Trim();
  if Result.StartsWith('pointer to ', True) then
    Result := Copy(Result, Length('pointer to ') + 1, MaxInt).Trim();
end;

procedure TLSPService.CollectMembersFromBranch(const ABranch: TASTNode;
  const AExported: Boolean;
  var AItems: TArray<TLSPCompletionItem>);
var
  LI: Integer;
  LChild: TASTNode;
  LKind: string;
  LExported: Boolean;
begin
  if ABranch = nil then Exit;

  LKind := ABranch.GetKind();

  // `exported` is a WRAPPER node: its child is the actual decl. Only what a
  // module exports is reachable as `Module.Member` -- the compiler enforces
  // exactly this (ERR_SCOPES_NOT_EXPORTED), so completion must agree. Without
  // this filter the list leaks module-private state like myra_maths_rng.
  LExported := AExported or (LKind = 'stmt.exported');

  if LExported then
  begin
    if LKind = 'stmt.routine_decl' then
      AddCompletion(ABranch.GetAttr('decl.name'), 3, 'routine', AItems)
    else if LKind = 'stmt.type_decl' then
      AddCompletion(ABranch.GetAttr('decl.name'), 7, 'type', AItems)
    else if LKind = 'stmt.var_decl' then
      AddCompletion(ABranch.GetAttr('var.name'),
        6, ABranch.GetAttr('var.type_text'), AItems)
    else if LKind = 'stmt.const_decl' then
      AddCompletion(ABranch.GetAttr('const.name'), 21, 'constant', AItems);
  end;

  // Do not descend into a routine body -- its locals and parameters are not
  // members of the module.
  if LKind = 'stmt.routine_decl' then Exit;

  for LI := 0 to ABranch.ChildCount() - 1 do
  begin
    LChild := ABranch.GetChild(LI);
    CollectMembersFromBranch(LChild, LExported, AItems);
  end;
end;

procedure TLSPService.CollectFieldsFromTypeDecl(const ATypeDecl: TASTNode;
  var AItems: TArray<TLSPCompletionItem>);
var
  LI: Integer;
  LChild: TASTNode;
begin
  if ATypeDecl = nil then Exit;

  if ATypeDecl.GetKind() = 'stmt.field_decl' then
    AddCompletion(ATypeDecl.GetAttr('field.name'),
      5, ATypeDecl.GetAttr('field.type_text'), AItems);

  // Recurse: anonymous records and overlays nest their fields one level down,
  // and their members are reachable on the parent record.
  for LI := 0 to ATypeDecl.ChildCount() - 1 do
  begin
    LChild := ATypeDecl.GetChild(LI);
    CollectFieldsFromTypeDecl(LChild, AItems);
  end;
end;

function TLSPService.GetCompletions(const AUri: string;
  const ALine: Integer;
  const ACharacter: Integer): TArray<TLSPCompletionItem>;
var
  LDoc: TLSPDocument;
  LScopes: TScopeManager;
  LScope: TScope;
  LItem: TLSPCompletionItem;
  LKwPair: TPair<string, string>;
  LPosition: TLSPPosition;
  LQualifier: string;
  LBranch: TASTNode;
  LTypeName: string;
  LTypeDecl: TASTNode;
  LDocNodes: TDictionary<Pointer, Boolean>;
begin
  SetLength(Result, 0);
  LDoc := GetDocument(AUri);

  // MEMBER ACCESS. If the cursor sits after a '.', the answer is that ONE
  // qualifier's members -- not every global plus every keyword. Returning early
  // is the whole point: a cursor after `Maths.` used to dump 154 items.
  if LDoc <> nil then
  begin
    LPosition.Line := ALine;
    LPosition.Character := ACharacter;
    LQualifier := ResolveQualifierBeforeDot(LDoc, LPosition);

    if LQualifier <> '' then
    begin
      // 1) Module qualifier: `Maths.` -> the routines/types/consts that module
      //    declares. Only reachable because CompileModule now attaches the
      //    module's branch to the AST.
      LBranch := FindModuleBranch(LDoc, LQualifier);
      if LBranch <> nil then
      begin
        CollectMembersFromBranch(LBranch, False, Result);
        Exit;
      end;

      // 2) Record/object qualifier: `p.` -> that type's fields.
      LTypeName := ResolveQualifierTypeName(LDoc, LQualifier);
      if LTypeName <> '' then
      begin
        LTypeDecl := FindTypeDeclNode(LDoc.GetAST(), LTypeName);
        if LTypeDecl <> nil then
        begin
          CollectFieldsFromTypeDecl(LTypeDecl, Result);
          Exit;
        end;
      end;

      // Unresolvable qualifier: return NOTHING rather than the full global
      // dump. An empty list is honest; 154 irrelevant items is noise.
      Exit;
    end;
  end;

  // Add scope symbols from entire scope tree, this document only
  if LDoc <> nil then
  begin
    LScopes := LDoc.GetScopes();
    if (LScopes <> nil) and (LDoc.GetAST() <> nil) and
       (LDoc.GetAST().ChildCount() > 0) then
    begin
      LScope := LScopes.GetCurrent();
      LDocNodes := TDictionary<Pointer, Boolean>.Create();
      try
        BuildDocNodeSet(LDoc.GetAST().GetChild(0), ALine, LDocNodes);
        CollectCompletionsFromScope(LScope, LDocNodes, Result);
      finally
        LDocNodes.Free();
      end;
    end;
  end;

  // Add keyword completions from interpreter
  if FInterp <> nil then
  begin
    for LKwPair in FInterp.GetKeywords() do
    begin
      LItem.LabelText := LKwPair.Key;
      LItem.Kind := 14;  // Keyword
      LItem.Detail := 'keyword';
      LItem.Documentation := '';
      LItem.InsertText := LKwPair.Key;
      LItem.InsertTextFormat := 1;
      LItem.SortText := '9' + LKwPair.Key;
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := LItem;
    end;
  end;
end;

function TLSPService.GetHover(const AUri: string;
  const ALine: Integer;
  const ACharacter: Integer): TLSPHover;
var
  LDoc: TLSPDocument;
  LPosition: TLSPPosition;
  LNode: TASTNode;
  LName: string;
  LSym: TSymbol;
  LContent: string;
  LRetType: string;
begin
  Result.Contents := '';
  Result.HasRange := False;

  LDoc := GetDocument(AUri);
  if LDoc = nil then Exit;

  LPosition.Line := ALine;
  LPosition.Character := ACharacter;
  LName := ResolveIdentifierAtPosition(LDoc, LPosition, LNode);
  if LName = '' then Exit;

  LSym := LookupSymbolByName(LDoc, LName);
  if LSym <> nil then
  begin
    LContent := '**' + LSym.GetSymKind() + '** `' + LSym.GetSymName() + '`';

    // A routine's own TypeName is empty -- its return type lives in the
    // synthesized "__rettype:<name>" symbol. Read it back out so hover shows
    // `add(int32,int32): int32` instead of stopping at the parameter list.
    LRetType := SymReturnType(LDoc, SymBaseName(LSym.GetSymName()));
    if LRetType <> '' then
      LContent := LContent + ': `' + LRetType + '`'
    else if LSym.GetTypeName() <> '' then
      LContent := LContent + ': `' + LSym.GetTypeName() + '`';

    Result.Contents := LContent;
    if (LNode <> nil) and (not LNode.GetRange().IsEmpty()) then
    begin
      Result.Range := TLSPRange.FromSourceRange(LNode.GetRange());
      Result.HasRange := True;
    end;
    Exit;
  end;

  // Fallback: show resolved identifier name
  Result.Contents := '`' + LName + '`';
end;

function TLSPService.GetDefinition(const AUri: string;
  const ALine: Integer;
  const ACharacter: Integer): TLSPLocation;
var
  LDoc: TLSPDocument;
  LPosition: TLSPPosition;
  LNode: TASTNode;
  LName: string;
  LSym: TSymbol;
  LDeclNode: TASTNode;
  LDeclRange: TSourceRange;
begin
  Result.Uri := '';
  Result.Range.Clear();

  LDoc := GetDocument(AUri);
  if LDoc = nil then Exit;

  LPosition.Line := ALine;
  LPosition.Character := ACharacter;
  LName := ResolveIdentifierAtPosition(LDoc, LPosition, LNode);
  if LName = '' then Exit;

  LSym := LookupSymbolByName(LDoc, LName);
  if (LSym <> nil) and (LSym.GetDeclNode() <> nil) then
  begin
    LDeclNode := TASTNode(LSym.GetDeclNode());
    LDeclRange := LDeclNode.GetRange();
    if not LDeclRange.IsEmpty() then
    begin
      Result.Uri := AUri;
      Result.Range := TLSPRange.FromSourceRange(LDeclRange);
    end
    else
    begin
      // Fall back to token position
      Result.Uri := AUri;
      Result.Range.StartPos.Line := Max(0, LDeclNode.GetToken().Line - 1);
      Result.Range.StartPos.Character := Max(0, LDeclNode.GetToken().Col - 1);
      Result.Range.EndPos := Result.Range.StartPos;
    end;
  end;
end;

procedure TLSPService.CollectReferencesInNode(
  const ANode: TASTNode;
  const ATargetName: string; const AUri: string;
  var ALocations: TArray<TLSPLocation>);
var
  LI: Integer;
  LName: string;
  LLocation: TLSPLocation;
begin
  if ANode = nil then Exit;

  LName := GetIdentifierFromNode(ANode);
  if SameText(LName, ATargetName) then
  begin
    LLocation.Uri := AUri;
    if not ANode.GetRange().IsEmpty() then
      LLocation.Range := TLSPRange.FromSourceRange(ANode.GetRange())
    else if ANode.GetToken().Line > 0 then
    begin
      LLocation.Range.StartPos.Line := ANode.GetToken().Line - 1;
      LLocation.Range.StartPos.Character := ANode.GetToken().Col - 1;
      LLocation.Range.EndPos.Line := LLocation.Range.StartPos.Line;
      LLocation.Range.EndPos.Character :=
        LLocation.Range.StartPos.Character + Length(ANode.GetToken().Text);
    end
    else
    begin
      // No usable position — skip this node entirely
      LLocation.Uri := '';
    end;
    if LLocation.Uri <> '' then
    begin
      SetLength(ALocations, Length(ALocations) + 1);
      ALocations[High(ALocations)] := LLocation;
    end;
  end;

  for LI := 0 to ANode.ChildCount() - 1 do
    CollectReferencesInNode(ANode.GetChild(LI), ATargetName, AUri,
      ALocations);
end;

procedure TLSPService.CollectReferencesFromTokens(
  const ADoc: TLSPDocument;
  const ATargetName: string; const AUri: string;
  var ALocations: TArray<TLSPLocation>);
var
  LTokens: TList<TToken>;
  LI: Integer;
  LJ: Integer;
  LToken: TToken;
  LLocation: TLSPLocation;
  LAlreadyFound: Boolean;
  LLine: Integer;
  LCol: Integer;
begin
  if ADoc = nil then Exit;
  LTokens := ADoc.GetTokens();
  if LTokens = nil then Exit;

  for LI := 0 to LTokens.Count - 1 do
  begin
    LToken := LTokens[LI];
    if LToken.Kind <> 'identifier' then Continue;
    if not SameText(LToken.Text, ATargetName) then Continue;

    // Convert from 1-based token position to 0-based LSP position
    LLine := LToken.Line - 1;
    LCol := LToken.Col - 1;

    // Deduplicate: skip if already found at this position by AST walk
    LAlreadyFound := False;
    for LJ := 0 to High(ALocations) do
    begin
      if (ALocations[LJ].Range.StartPos.Line = LLine) and
         (ALocations[LJ].Range.StartPos.Character = LCol) then
      begin
        LAlreadyFound := True;
        Break;
      end;
    end;

    if not LAlreadyFound then
    begin
      LLocation.Uri := AUri;
      LLocation.Range.StartPos.Line := LLine;
      LLocation.Range.StartPos.Character := LCol;
      LLocation.Range.EndPos.Line := LLine;
      LLocation.Range.EndPos.Character := LCol + Length(LToken.Text);
      SetLength(ALocations, Length(ALocations) + 1);
      ALocations[High(ALocations)] := LLocation;
    end;
  end;
end;

function TLSPService.GetReferences(const AUri: string;
  const ALine: Integer; const ACharacter: Integer;
  const AIncludeDeclaration: Boolean): TArray<TLSPLocation>;
var
  LDoc: TLSPDocument;
  LPosition: TLSPPosition;
  LNode: TASTNode;
  LName: string;
  LI: Integer;
  LJ: Integer;
  LDup: Boolean;
begin
  SetLength(Result, 0);
  LDoc := GetDocument(AUri);
  if LDoc = nil then Exit;

  LPosition.Line := ALine;
  LPosition.Character := ACharacter;
  LName := ResolveIdentifierAtPosition(LDoc, LPosition, LNode);
  if LName = '' then Exit;

  // Branch 0 ONLY. An imported module's branch hangs off the same root, and its
  // nodes carry ITS line numbers -- scanning it would report references at
  // Maths' coordinates but tagged with THIS document's uri.
  if (LDoc.GetAST() <> nil) and (LDoc.GetAST().ChildCount() > 0) then
    CollectReferencesInNode(LDoc.GetAST().GetChild(0), LName, AUri, Result);

  // Token-based scan for identifiers not represented in the AST
  // (e.g. inside collectUntil regions like stmt.writeln/stmt.write)
  CollectReferencesFromTokens(LDoc, LName, AUri, Result);

  // Deduplicate by start position
  LI := 0;
  while LI < Length(Result) do
  begin
    LDup := False;
    for LJ := 0 to LI - 1 do
    begin
      if (Result[LI].Range.StartPos.Line = Result[LJ].Range.StartPos.Line) and
         (Result[LI].Range.StartPos.Character = Result[LJ].Range.StartPos.Character) then
      begin
        LDup := True;
        Break;
      end;
    end;
    if LDup then
    begin
      for LJ := LI to High(Result) - 1 do
        Result[LJ] := Result[LJ + 1];
      SetLength(Result, Length(Result) - 1);
    end
    else
      Inc(LI);
  end;
end;

function TLSPService.NodeContainsLine(const ANode: TASTNode;
  const ACursorLine: Integer): Boolean;
var
  LRange: TSourceRange;
  LLine: Integer;
begin
  Result := False;
  if (ANode = nil) or (ACursorLine < 0) then Exit;

  LRange := ANode.GetRange();
  if LRange.IsEmpty() then Exit;

  // LSP lines are 0-based; TSourceRange lines are 1-based.
  LLine := ACursorLine + 1;
  Result := (LLine >= LRange.StartLine) and (LLine <= LRange.EndLine);
end;

procedure TLSPService.BuildDocNodeSet(const ANode: TASTNode;
  const ACursorLine: Integer;
  const ASet: TDictionary<Pointer, Boolean>);
var
  LI: Integer;
  LKind: string;
begin
  if (ANode = nil) or (ASet = nil) then Exit;

  ASet.AddOrSetValue(Pointer(ANode), True);

  // A routine is a scope wall. Its params and locals are NOT visible from
  // outside it, so do not descend unless the cursor is actually in there.
  // The routine's own decl node is already in the set above, which is what
  // keeps `add` and `scale` completable from anywhere in the module.
  LKind := ANode.GetKind();
  if (LKind = 'stmt.routine_decl') or (LKind = 'stmt.method_decl') then
  begin
    if not NodeContainsLine(ANode, ACursorLine) then Exit;
  end;

  for LI := 0 to ANode.ChildCount() - 1 do
    BuildDocNodeSet(ANode.GetChild(LI), ACursorLine, ASet);
end;

function TLSPService.SymIsFromDocument(const ASym: TSymbol;
  const ASet: TDictionary<Pointer, Boolean>): Boolean;
begin
  Result := False;
  if (ASym = nil) or (ASet = nil) then Exit;
  if ASym.GetDeclNode() = nil then Exit;
  Result := ASet.ContainsKey(Pointer(ASym.GetDeclNode()));
end;

procedure TLSPService.CollectDocSymbolsFromScope(
  const AScope: TScope;
  const ADocNodes: TDictionary<Pointer, Boolean>;
  var ASymbols: TArray<TLSPDocumentSymbol>);
var
  LPair: TPair<string, TSymbol>;
  LSym: TLSPDocumentSymbol;
  LDeclNode: TASTNode;
  LI: Integer;
  LChildScope: TScope;
begin
  if AScope = nil then Exit;

  // Emit a document symbol for each declared symbol in this scope
  for LPair in AScope.GetSymbols() do
  begin
    if LPair.Value = nil then Continue;

    // Compiler bookkeeping ("__rettype:add") is not a user symbol.
    if SymIsInternal(LPair.Value.GetSymName()) then Continue;

    // documentSymbol is THIS FILE's outline. Now that imports actually load,
    // the scope tree also holds every symbol of every imported module.
    if not SymIsFromDocument(LPair.Value, ADocNodes) then Continue;

    LDeclNode := TASTNode(LPair.Value.GetDeclNode());

    // The outline pane shows the NAME. The mangled signature belongs in the
    // detail column, not welded onto the name.
    LSym.SymbolName := SymBaseName(LPair.Value.GetSymName());
    LSym.Detail := (SymSignature(LPair.Value.GetSymName()) + ' ' +
      LPair.Value.GetTypeName()).Trim();
    LSym.Kind := NodeKindToSymbolKind(LPair.Value.GetSymKind());
    LSym.Range.Clear();
    LSym.SelectionRange.Clear();
    SetLength(LSym.Children, 0);

    if not LDeclNode.GetRange().IsEmpty() then
      LSym.Range := TLSPRange.FromSourceRange(LDeclNode.GetRange())
    else
    begin
      LSym.Range.StartPos.Line := Max(0, LDeclNode.GetToken().Line - 1);
      LSym.Range.StartPos.Character := Max(0, LDeclNode.GetToken().Col - 1);
      LSym.Range.EndPos := LSym.Range.StartPos;
    end;
    LSym.SelectionRange := LSym.Range;

    SetLength(ASymbols, Length(ASymbols) + 1);
    ASymbols[High(ASymbols)] := LSym;
  end;

  // Recurse into child scopes
  for LI := 0 to AScope.GetChildren().Count - 1 do
  begin
    LChildScope := AScope.GetChildren()[LI];
    CollectDocSymbolsFromScope(LChildScope, ADocNodes, ASymbols);
  end;
end;

procedure TLSPService.CollectCompletionsFromScope(const AScope: TScope;
  const ADocNodes: TDictionary<Pointer, Boolean>;
  var AItems: TArray<TLSPCompletionItem>);
var
  LPair: TPair<string, TSymbol>;
  LItem: TLSPCompletionItem;
  LI: Integer;
  LJ: Integer;
  LName: string;
  LDup: Boolean;
  LChildScope: TScope;
begin
  if AScope = nil then Exit;

  for LPair in AScope.GetSymbols() do
  begin
    if LPair.Value = nil then Continue;

    // Never offer compiler bookkeeping as a completion.
    if SymIsInternal(LPair.Value.GetSymName()) then Continue;

    // An imported module's members are NOT in scope unqualified -- Myra
    // requires `Maths.Sqrt`. Offering a bare `Sqrt` here would complete to code
    // that does not compile. Those names belong to the `Maths.` member list.
    if not SymIsFromDocument(LPair.Value, ADocNodes) then Continue;

    // Complete the NAME. Inserting "add(int32,int32)" into the editor would be
    // nonsense -- that is a signature, not code.
    LName := SymBaseName(LPair.Value.GetSymName());

    // Overloads collapse to one entry -- the user picks a name, and signature
    // help resolves the overload once they type '('.
    LDup := False;
    for LJ := 0 to High(AItems) do
      if SameText(AItems[LJ].LabelText, LName) then
      begin
        LDup := True;
        Break;
      end;
    if LDup then Continue;

    LItem.LabelText := LName;
    LItem.Kind := SymKindToCompletionKind(LPair.Value.GetSymKind());
    LItem.SortText := '1' + LName;
    LItem.InsertTextFormat := 1;
    LItem.Documentation := '';
    LItem.Detail := (SymSignature(LPair.Value.GetSymName()) + ' ' +
      LPair.Value.GetTypeName()).Trim();
    LItem.InsertText := LName;
    SetLength(AItems, Length(AItems) + 1);
    AItems[High(AItems)] := LItem;
  end;

  for LI := 0 to AScope.GetChildren().Count - 1 do
  begin
    LChildScope := AScope.GetChildren()[LI];
    CollectCompletionsFromScope(LChildScope, ADocNodes, AItems);
  end;
end;

function TLSPService.GetDocumentSymbols(
  const AUri: string): TArray<TLSPDocumentSymbol>;
var
  LDoc: TLSPDocument;
  LScopes: TScopeManager;
  LDocNodes: TDictionary<Pointer, Boolean>;
begin
  SetLength(Result, 0);
  LDoc := GetDocument(AUri);
  if LDoc = nil then Exit;
  LScopes := LDoc.GetScopes();
  if LScopes = nil then Exit;
  if (LDoc.GetAST() = nil) or (LDoc.GetAST().ChildCount() = 0) then Exit;

  // Walk the scope tree, keeping only symbols declared in THIS document.
  // The tree also holds every imported module's symbols now that imports
  // resolve; those belong to their own files, not this outline.
  LDocNodes := TDictionary<Pointer, Boolean>.Create();
  try
    // -1: the outline is top-level declarations, never another routine's
    // params and locals.
    BuildDocNodeSet(LDoc.GetAST().GetChild(0), -1, LDocNodes);
    CollectDocSymbolsFromScope(LScopes.GetCurrent(), LDocNodes, Result);
  finally
    LDocNodes.Free();
  end;
end;

procedure TLSPService.CollectFoldingRangesFromNode(
  const ANode: TASTNode;
  var ARanges: TArray<TLSPFoldingRange>);
var
  LI: Integer;
  LRange: TLSPFoldingRange;
  LSrcRange: TSourceRange;
begin
  if ANode = nil then Exit;

  LSrcRange := ANode.GetRange();

  // Language-agnostic: any node spanning multiple lines is foldable.
  // No node kind checks needed — the AST structure determines folding.
  if (not LSrcRange.IsEmpty()) and
     (LSrcRange.EndLine - LSrcRange.StartLine > 0) then
  begin
    LRange.StartLine := LSrcRange.StartLine - 1;
    LRange.EndLine := LSrcRange.EndLine - 1;
    LRange.Kind := 'region';
    SetLength(ARanges, Length(ARanges) + 1);
    ARanges[High(ARanges)] := LRange;
  end;

  for LI := 0 to ANode.ChildCount() - 1 do
    CollectFoldingRangesFromNode(ANode.GetChild(LI), ARanges);
end;

function TLSPService.GetFoldingRanges(
  const AUri: string): TArray<TLSPFoldingRange>;
var
  LDoc: TLSPDocument;
begin
  SetLength(Result, 0);
  LDoc := GetDocument(AUri);
  if (LDoc = nil) or (LDoc.GetAST() = nil) then Exit;
  if LDoc.GetAST().ChildCount() = 0 then Exit;

  // Fold ONLY this document's branch (index 0). Branches 1+ are imported
  // modules -- folding their line ranges into this file's editor is nonsense,
  // and it is what pushed the count to 321.
  CollectFoldingRangesFromNode(LDoc.GetAST().GetChild(0), Result);
end;

function TLSPService.GetSemanticTokens(
  const AUri: string): TArray<Integer>;
var
  LDoc: TLSPDocument;
  LTokens: TList<TToken>;
  LI: Integer;
  LToken: TToken;
  LType: Integer;
  LPrevLine: Integer;
  LPrevChar: Integer;
  LLine: Integer;
  LChar: Integer;
  LLength: Integer;
begin
  SetLength(Result, 0);
  LDoc := GetDocument(AUri);
  if LDoc = nil then Exit;

  LTokens := LDoc.GetTokens();
  if LTokens = nil then Exit;

  LPrevLine := 0;
  LPrevChar := 0;

  for LI := 0 to LTokens.Count - 1 do
  begin
    LToken := LTokens[LI];
    LType := TokenKindToSemanticType(LToken.Kind);
    if LType < 0 then Continue;

    LLine := LToken.Line - 1;
    LChar := LToken.Col - 1;
    LLength := Length(LToken.Text);

    if LLine < 0 then Continue;
    if LChar < 0 then Continue;
    if LLength <= 0 then Continue;

    SetLength(Result, Length(Result) + 5);
    Result[High(Result) - 4] := LLine - LPrevLine;
    if LLine = LPrevLine then
      Result[High(Result) - 3] := LChar - LPrevChar
    else
      Result[High(Result) - 3] := LChar;
    Result[High(Result) - 2] := LLength;
    Result[High(Result) - 1] := LType;
    Result[High(Result)]     := 0;

    LPrevLine := LLine;
    LPrevChar := LChar;
  end;
end;

function TLSPService.GetRenameEdits(const AUri: string;
  const ALine: Integer; const ACharacter: Integer;
  const ANewName: string): TLSPWorkspaceEdit;
var
  LDoc: TLSPDocument;
  LPosition: TLSPPosition;
  LNode: TASTNode;
  LName: string;
  LLocations: TArray<TLSPLocation>;
  LEdit: TLSPTextEdit;
  LI: Integer;
  LJ: Integer;
  LDup: Boolean;
begin
  Result.Uri := '';
  SetLength(Result.Edits, 0);

  LDoc := GetDocument(AUri);
  if LDoc = nil then Exit;

  LPosition.Line := ALine;
  LPosition.Character := ACharacter;
  LName := ResolveIdentifierAtPosition(LDoc, LPosition, LNode);
  if LName = '' then Exit;

  SetLength(LLocations, 0);
  // Branch 0 ONLY -- see GetReferences. A rename must never emit edits into
  // this file at an imported module's line numbers.
  if (LDoc.GetAST() <> nil) and (LDoc.GetAST().ChildCount() > 0) then
    CollectReferencesInNode(
      LDoc.GetAST().GetChild(0), LName, AUri, LLocations);

  // Token-based scan for identifiers not in the AST
  CollectReferencesFromTokens(LDoc, LName, AUri, LLocations);

  // Deduplicate by start position
  LI := 0;
  while LI < Length(LLocations) do
  begin
    LDup := False;
    for LJ := 0 to LI - 1 do
    begin
      if (LLocations[LI].Range.StartPos.Line = LLocations[LJ].Range.StartPos.Line) and
         (LLocations[LI].Range.StartPos.Character = LLocations[LJ].Range.StartPos.Character) then
      begin
        LDup := True;
        Break;
      end;
    end;
    if LDup then
    begin
      for LJ := LI to High(LLocations) - 1 do
        LLocations[LJ] := LLocations[LJ + 1];
      SetLength(LLocations, Length(LLocations) - 1);
    end
    else
      Inc(LI);
  end;

  Result.Uri := AUri;
  SetLength(Result.Edits, Length(LLocations));
  for LI := 0 to High(LLocations) do
  begin
    LEdit.Range := LLocations[LI].Range;
    LEdit.NewText := ANewName;
    Result.Edits[LI] := LEdit;
  end;
end;

procedure TLSPService.CollectWorkspaceSymbolsFromScope(
  const AScope: TScope; const AQuery: string; const AUri: string;
  var ASymbols: TArray<TLSPSymbolInformation>);
var
  LPair: TPair<string, TSymbol>;
  LInfo: TLSPSymbolInformation;
  LDeclNode: TASTNode;
  LI: Integer;
  LChildScope: TScope;
begin
  if AScope = nil then Exit;

  // Emit workspace symbols from this scope's declared symbols
  for LPair in AScope.GetSymbols() do
  begin
    if LPair.Value = nil then Continue;

    // Compiler bookkeeping ("__rettype:add") is not a user symbol.
    if SymIsInternal(LPair.Value.GetSymName()) then Continue;

    // Match the query against the BASE name. Matching the mangled form would
    // let a search for "int32" hit every routine that merely takes one.
    if (AQuery <> '') and
       not ContainsText(SymBaseName(LPair.Value.GetSymName()), AQuery) then
      Continue;

    LInfo.SymbolName := SymBaseName(LPair.Value.GetSymName());
    LInfo.Kind := NodeKindToSymbolKind(LPair.Value.GetSymKind());
    LInfo.Uri := AUri;
    LInfo.Range.Clear();

    if LPair.Value.GetDeclNode() <> nil then
    begin
      LDeclNode := TASTNode(LPair.Value.GetDeclNode());
      if not LDeclNode.GetRange().IsEmpty() then
        LInfo.Range := TLSPRange.FromSourceRange(LDeclNode.GetRange())
      else
      begin
        LInfo.Range.StartPos.Line := Max(0, LDeclNode.GetToken().Line - 1);
        LInfo.Range.StartPos.Character := Max(0, LDeclNode.GetToken().Col - 1);
        LInfo.Range.EndPos := LInfo.Range.StartPos;
      end;
    end;

    SetLength(ASymbols, Length(ASymbols) + 1);
    ASymbols[High(ASymbols)] := LInfo;
  end;

  // Recurse into child scopes
  for LI := 0 to AScope.GetChildren().Count - 1 do
  begin
    LChildScope := AScope.GetChildren()[LI];
    CollectWorkspaceSymbolsFromScope(LChildScope, AQuery, AUri, ASymbols);
  end;
end;

function TLSPService.GetWorkspaceSymbols(const AQuery: string;
  const AUri: string): TArray<TLSPSymbolInformation>;
var
  LDoc: TLSPDocument;
  LScopes: TScopeManager;
  LPair: TPair<string, TLSPDocument>;
begin
  SetLength(Result, 0);

  // If a specific URI is given, search only that document
  if AUri <> '' then
  begin
    LDoc := GetDocument(AUri);
    if LDoc = nil then Exit;
    LScopes := LDoc.GetScopes();
    if LScopes = nil then Exit;
    CollectWorkspaceSymbolsFromScope(LScopes.GetCurrent(), AQuery, AUri,
      Result);
  end
  else
  begin
    // Search all open documents (workspace-wide)
    for LPair in FDocuments do
    begin
      LDoc := LPair.Value;
      if LDoc = nil then Continue;
      LScopes := LDoc.GetScopes();
      if LScopes = nil then Continue;
      CollectWorkspaceSymbolsFromScope(LScopes.GetCurrent(), AQuery,
        LPair.Key, Result);
    end;
  end;
end;

function TLSPService.GetSignatureHelp(const AUri: string;
  const ALine: Integer;
  const ACharacter: Integer): TLSPSignatureHelp;
var
  LDoc: TLSPDocument;
  LPosition: TLSPPosition;
  LContent: string;
  LOffset: Integer;
  LI: Integer;
  LDepth: Integer;
  LOpenParen: Integer;
  LNameEnd: Integer;
  LNameStart: Integer;
  LName: string;
  LSym: TSymbol;
  LSig: TLSPSignatureInfo;
  LParam: TLSPParameterInfo;
  LParamText: string;
  LParts: TArray<string>;
  LActive: Integer;
  LRetType: string;
begin
  Result.ActiveSignature := 0;
  Result.ActiveParameter := 0;
  SetLength(Result.Signatures, 0);

  LDoc := GetDocument(AUri);
  if LDoc = nil then Exit;

  LPosition.Line := ALine;
  LPosition.Character := ACharacter;
  LOffset := LDoc.PositionToOffset(LPosition);

  LContent := LDoc.GetContent();

  // PositionToOffset returns a ZERO-BASED offset (`LI - 1 + Character`), but
  // Delphi strings are ONE-BASED. So the character immediately BEFORE the
  // cursor is LContent[LOffset] -- not LContent[LOffset - 1]. Getting this
  // wrong lands the scan on 'd' instead of '(' and the open paren is never
  // found, which is exactly why this returned null.
  if LOffset > Length(LContent) then
    LOffset := Length(LContent);
  if LOffset < 1 then Exit;

  // Walk BACKWARDS from the cursor to find the '(' of the call we are inside.
  // Nested calls are skipped by tracking depth: a ')' seen on the way back
  // means an inner call already closed, so its matching '(' is not ours.
  LDepth := 0;
  LOpenParen := 0;
  LActive := 0;
  for LI := LOffset downto 1 do
  begin
    if LContent[LI] = ')' then
      Inc(LDepth)
    else if LContent[LI] = '(' then
    begin
      if LDepth = 0 then
      begin
        LOpenParen := LI;
        Break;
      end;
      Dec(LDepth);
    end
    else if (LContent[LI] = ',') and (LDepth = 0) then
      // A comma at OUR nesting level means the cursor sits on a later argument.
      Inc(LActive)
    else if (LContent[LI] = ';') or (LContent[LI] = #10) then
      // Statement boundary -- we were never inside a call.
      Break;
  end;

  if LOpenParen = 0 then Exit;

  // The identifier immediately before the '(' is the routine being called.
  LNameEnd := LOpenParen - 1;
  while (LNameEnd >= 1) and CharInSet(LContent[LNameEnd], [' ', #9]) do
    Dec(LNameEnd);

  LNameStart := LNameEnd;
  while (LNameStart >= 1) and
        CharInSet(LContent[LNameStart],
          ['a'..'z', 'A'..'Z', '0'..'9', '_']) do
    Dec(LNameStart);
  Inc(LNameStart);

  if LNameStart > LNameEnd then Exit;
  LName := Copy(LContent, LNameStart, LNameEnd - LNameStart + 1);
  if LName = '' then Exit;

  LSym := LookupSymbolByName(LDoc, LName);
  if LSym = nil then Exit;

  // The scopes layer keys routines by their mangled signature, so the symbol
  // name ITSELF carries the parameter types: "add(int32,int32)". That is
  // exactly what signature help needs -- no extra metadata required.
  LParamText := SymSignature(LSym.GetSymName());
  if LParamText = '' then Exit;

  LSig.LabelText := SymBaseName(LSym.GetSymName()) + LParamText;

  // Return type comes from the synthesized "__rettype:<name>" symbol, not from
  // the routine symbol itself (whose TypeName is empty).
  LRetType := SymReturnType(LDoc, SymBaseName(LSym.GetSymName()));
  if LRetType <> '' then
    LSig.LabelText := LSig.LabelText + ': ' + LRetType
  else if LSym.GetTypeName() <> '' then
    LSig.LabelText := LSig.LabelText + ': ' + LSym.GetTypeName();

  LSig.Documentation := '';

  // Strip the outer parens, then split on commas to get one entry per param.
  LParamText := Copy(LParamText, 2, Length(LParamText) - 2).Trim();

  SetLength(LSig.Parameters, 0);
  if LParamText <> '' then
  begin
    LParts := LParamText.Split([',']);
    SetLength(LSig.Parameters, Length(LParts));
    for LI := 0 to High(LParts) do
    begin
      LParam.LabelText := LParts[LI].Trim();
      LParam.Documentation := '';
      LSig.Parameters[LI] := LParam;
    end;

    // Do not point past the last parameter on a trailing comma.
    if LActive > High(LParts) then
      LActive := High(LParts);
  end;

  SetLength(Result.Signatures, 1);
  Result.Signatures[0] := LSig;
  Result.ActiveSignature := 0;
  Result.ActiveParameter := LActive;
end;

function TLSPService.FindRoutineDeclNode(const ADoc: TLSPDocument;
  const AName: string; const AArgCount: Integer): TASTNode;
var
  LRoot: TASTNode;
  LI: Integer;

  function DoScan(const ANode: TASTNode): TASTNode;
  var
    LJ: Integer;
    LKind: string;
    LParams: Integer;
    LChild: TASTNode;
  begin
    Result := nil;
    if ANode = nil then Exit;

    LKind := ANode.GetKind();
    if ((LKind = 'stmt.routine_decl') or (LKind = 'stmt.method_decl')) and
       SameText(ANode.GetAttr('decl.name'), AName) then
    begin
      // Overloads share a name -- pick the one whose arity matches the call.
      LParams := 0;
      for LJ := 0 to ANode.ChildCount() - 1 do
        if ANode.GetChild(LJ).GetKind() = 'stmt.param_decl' then
          Inc(LParams);
      if LParams = AArgCount then
        Exit(ANode);
    end;

    for LJ := 0 to ANode.ChildCount() - 1 do
    begin
      LChild := ANode.GetChild(LJ);
      Result := DoScan(LChild);
      if Result <> nil then Exit;
    end;
  end;

begin
  Result := nil;
  if (ADoc = nil) or (AName = '') then Exit;

  LRoot := ADoc.GetAST();
  if LRoot = nil then Exit;

  // This document first, then imported module branches -- a call to
  // `Maths.Clamp(...)` must find Clamp's parameter names too.
  for LI := 0 to LRoot.ChildCount() - 1 do
  begin
    Result := DoScan(LRoot.GetChild(LI));
    if Result <> nil then Exit;
  end;
end;

procedure TLSPService.CollectInlayHintsFromNode(const ADoc: TLSPDocument;
  const ANode: TASTNode;
  const AStartLine: Integer; const AEndLine: Integer;
  var AHints: TArray<TLSPInlayHint>);
var
  LI: Integer;
  LArgIndex: Integer;
  LName: string;
  LCallee: TASTNode;
  LDecl: TASTNode;
  LArg: TASTNode;
  LParams: TArray<TASTNode>;
  LArgs: TArray<TASTNode>;
  LChild: TASTNode;
  LRange: TSourceRange;
  LHint: TLSPInlayHint;
begin
  if (ANode = nil) or (ADoc = nil) then Exit;

  if ANode.GetKind() = 'expr.call' then
  begin
    LName := ANode.GetAttr('call.name');
    if LName = '' then
    begin
      // Child 0 is the callee. For `Maths.Sqrt(x)` it is a field_access, and
      // the member name is what names the routine.
      if ANode.ChildCount() > 0 then
      begin
        LCallee := ANode.GetChild(0);
        if LCallee.GetKind() = 'expr.field_access' then
          LName := LCallee.GetAttr('field.name')
        else
          LName := LCallee.GetAttr('name');
      end;
    end;

    // Child 0 is the callee; children 1..n are the arguments.
    SetLength(LArgs, 0);
    for LI := 1 to ANode.ChildCount() - 1 do
    begin
      SetLength(LArgs, Length(LArgs) + 1);
      LArgs[High(LArgs)] := ANode.GetChild(LI);
    end;

    if (LName <> '') and (Length(LArgs) > 0) then
    begin
      LDecl := FindRoutineDeclNode(ADoc, LName, Length(LArgs));
      if LDecl <> nil then
      begin
        SetLength(LParams, 0);
        for LI := 0 to LDecl.ChildCount() - 1 do
        begin
          LChild := LDecl.GetChild(LI);
          if LChild.GetKind() = 'stmt.param_decl' then
          begin
            SetLength(LParams, Length(LParams) + 1);
            LParams[High(LParams)] := LChild;
          end;
        end;

        for LArgIndex := 0 to High(LArgs) do
        begin
          if LArgIndex > High(LParams) then Break;

          LArg := LArgs[LArgIndex];
          LRange := LArg.GetRange();
          if LRange.IsEmpty() then Continue;

          // Only hint inside the range the editor asked about.
          if (LRange.StartLine - 1 < AStartLine) or
             (LRange.StartLine - 1 > AEndLine) then Continue;

          // `add(A, B)` needs no hint -- the argument already reads as the
          // parameter. Hinting it is pure noise.
          if SameText(GetIdentifierFromNode(LArg),
                      LParams[LArgIndex].GetAttr('param.name')) then Continue;

          LHint.Position.Line := LRange.StartLine - 1;
          LHint.Position.Character := LRange.StartColumn - 1;
          LHint.LabelText := LParams[LArgIndex].GetAttr('param.name') + ':';
          LHint.Kind := 2;  // Parameter

          SetLength(AHints, Length(AHints) + 1);
          AHints[High(AHints)] := LHint;
        end;
      end;
    end;
  end;

  for LI := 0 to ANode.ChildCount() - 1 do
    CollectInlayHintsFromNode(ADoc, ANode.GetChild(LI),
      AStartLine, AEndLine, AHints);
end;

function TLSPService.GetInlayHints(const AUri: string;
  const AStartLine: Integer; const AStartChar: Integer;
  const AEndLine: Integer;
  const AEndChar: Integer): TArray<TLSPInlayHint>;
var
  LDoc: TLSPDocument;
begin
  SetLength(Result, 0);
  LDoc := GetDocument(AUri);
  if LDoc = nil then Exit;
  if (LDoc.GetAST() = nil) or (LDoc.GetAST().ChildCount() = 0) then Exit;

  // Parameter-name hints at call sites. The names live on the routine's
  // stmt.param_decl nodes -- the symbol table only keeps types, so the AST is
  // the only source for this. Branch 0 only: hints are drawn in THIS file.
  CollectInlayHintsFromNode(LDoc, LDoc.GetAST().GetChild(0),
    AStartLine, AEndLine, Result);
end;

function TLSPService.GetDocumentFormatting(const AUri: string;
  const ATabSize: Integer;
  const AInsertSpaces: Boolean): TArray<TLSPTextEdit>;
var
  LDoc: TLSPDocument;
  LContent: string;
  LLines: TArray<string>;
  LI: Integer;
  LTrimmed: string;
  LOut: string;
  LEol: string;
  LEdit: TLSPTextEdit;
begin
  SetLength(Result, 0);
  LDoc := GetDocument(AUri);
  if LDoc = nil then Exit;

  LContent := LDoc.GetContent();
  if LContent = '' then Exit;

  // Whitespace normalization ONLY: strip trailing whitespace per line, and
  // guarantee a final newline.
  //
  // Deliberately NOT a reindenter. Myra passes unrecognized tokens through to
  // C++ verbatim, so a structural formatter would have to understand C++ too --
  // and a formatter that guesses is a formatter that corrupts source. This pass
  // provably cannot change a single token.

  // PRESERVE the document's existing line ending. Joining with sLineBreak
  // (CRLF) after splitting an LF file rewrites EVERY line ending and reports a
  // whole-document edit on a file that needed nothing at all.
  if LContent.Contains(#13#10) then
    LEol := #13#10
  else
    LEol := #10;

  LLines := LContent.Replace(#13#10, #10).Split([#10]);

  LOut := '';
  for LI := 0 to High(LLines) do
  begin
    LTrimmed := LLines[LI].TrimRight();
    // Drop the artifact of a trailing newline in the split.
    if (LI = High(LLines)) and (LTrimmed = '') then Break;
    LOut := LOut + LTrimmed + LEol;
  end;

  if LOut = LContent then Exit;

  // One whole-document replacement. The end position is deliberately past the
  // last line -- the LSP spec clamps it, and this avoids an off-by-one on the
  // final line's length.
  LEdit.Range.StartPos.Line := 0;
  LEdit.Range.StartPos.Character := 0;
  LEdit.Range.EndPos.Line := Length(LLines) + 1;
  LEdit.Range.EndPos.Character := 0;
  LEdit.NewText := LOut;

  SetLength(Result, 1);
  Result[0] := LEdit;
end;

function TLSPService.GetCodeActions(const AUri: string;
  const AStartLine: Integer; const AStartChar: Integer;
  const AEndLine: Integer;
  const AEndChar: Integer): TArray<TJSONObject>;
var
  LDoc: TLSPDocument;
  LEdits: TArray<TLSPTextEdit>;
  LAction: TJSONObject;
  LWorkspaceEdit: TJSONObject;
  LChanges: TJSONObject;
  LEditArray: TJSONArray;
  LI: Integer;
begin
  SetLength(Result, 0);
  LDoc := GetDocument(AUri);
  if LDoc = nil then Exit;

  // Quick fix: whitespace cleanup, offered only when there is actually
  // something to clean. An action that does nothing is worse than no action --
  // the editor shows a lightbulb that lies.
  LEdits := GetDocumentFormatting(AUri, 2, True);
  if Length(LEdits) = 0 then Exit;

  LEditArray := TJSONArray.Create();
  for LI := 0 to High(LEdits) do
    LEditArray.AddElement(LEdits[LI].ToJSON());

  LChanges := TJSONObject.Create();
  LChanges.AddPair(AUri, LEditArray);

  LWorkspaceEdit := TJSONObject.Create();
  LWorkspaceEdit.AddPair('changes', LChanges);

  LAction := TJSONObject.Create();
  LAction.AddPair('title', 'Clean up whitespace');
  LAction.AddPair('kind', 'source.fixAll');
  LAction.AddPair('edit', LWorkspaceEdit);

  SetLength(Result, 1);
  Result[0] := LAction;
end;

{ TLSPServer }
constructor TLSPServer.Create();
begin
  inherited Create();
  FService := TLSPService.Create();
  FEngineAPI := nil;
  FMLDFile := '';
  FInitialized := False;
  FShutdownRequested := False;
  FInputStream := nil;
  FOutputStream := nil;
  FOwnsStreams := False;
end;

destructor TLSPServer.Destroy();
begin
  if FOwnsStreams then
  begin
    FreeAndNil(FInputStream);
    FreeAndNil(FOutputStream);
  end;
  FreeAndNil(FEngineAPI);
  FreeAndNil(FService);
  inherited Destroy();
end;

procedure TLSPServer.SetMLDFile(const AMLDFile: string);
begin
  FMLDFile := TPath.ChangeExtension(AMLDFile, LANGDEF_EXT);
end;

procedure TLSPServer.SetStreams(const AInput: TStream;
  const AOutput: TStream);
begin
  FInputStream := AInput;
  FOutputStream := AOutput;
  FOwnsStreams := False;
end;

function TLSPServer.GetService(): TLSPService;
begin
  Result := FService;
end;

function TLSPServer.ReadMessage(): TJSONObject;
var
  LLine: string;
  LHeader: string;
  LContentLength: Integer;
  LByte: Byte;
  LBodyBytes: TBytes;
  LBodyStr: string;
  LParsed: TJSONValue;
begin
  Result := nil;
  LContentLength := -1;

  // Read headers line by line until blank line
  LLine := '';
  while True do
  begin
    if FInputStream.Read(LByte, 1) <> 1 then
      Exit;

    if LByte = 13 then  // CR
    begin
      FInputStream.Read(LByte, 1);  // Read LF
      if LLine = '' then
        Break;  // Blank line = end of headers

      LHeader := LLine;
      if LHeader.StartsWith('Content-Length: ') then
        LContentLength := StrToIntDef(
          Copy(LHeader, Length('Content-Length: ') + 1, MaxInt), -1);

      LLine := '';
    end
    else if LByte <> 10 then
      LLine := LLine + Chr(LByte);
  end;

  if LContentLength <= 0 then
    Exit;

  // Read exactly LContentLength bytes
  SetLength(LBodyBytes, LContentLength);
  FInputStream.ReadBuffer(LBodyBytes[0], LContentLength);
  LBodyStr := TEncoding.UTF8.GetString(LBodyBytes);

  LParsed := TJSONObject.ParseJSONValue(LBodyStr);
  if LParsed is TJSONObject then
    Result := TJSONObject(LParsed)
  else
    LParsed.Free();
end;

procedure TLSPServer.WriteMessage(const AMessage: TJSONObject);
var
  LBody: string;
  LBodyBytes: TBytes;
  LHeader: string;
  LHeaderBytes: TBytes;
begin
  LBody := AMessage.ToString();
  LBodyBytes := TEncoding.UTF8.GetBytes(LBody);
  LHeader := 'Content-Length: ' + IntToStr(Length(LBodyBytes)) + #13#10 +
    'Content-Type: application/vscode-jsonrpc; charset=utf-8' + #13#10 +
    #13#10;
  LHeaderBytes := TEncoding.ASCII.GetBytes(LHeader);
  FOutputStream.WriteBuffer(LHeaderBytes[0], Length(LHeaderBytes));
  FOutputStream.WriteBuffer(LBodyBytes[0], Length(LBodyBytes));
end;

procedure TLSPServer.SendResponse(const AId: TJSONValue;
  const AResult: TJSONValue);
var
  LMsg: TJSONObject;
begin
  LMsg := TJSONObject.Create();
  try
    LMsg.AddPair('jsonrpc', '2.0');
    if AId <> nil then
      LMsg.AddPair('id', AId.Clone() as TJSONValue)
    else
      LMsg.AddPair('id', TJSONNull.Create());
    LMsg.AddPair('result', AResult);
    WriteMessage(LMsg);
  finally
    LMsg.Free();
  end;
end;

procedure TLSPServer.SendError(const AId: TJSONValue;
  const ACode: Integer; const AMessage: string);
var
  LMsg: TJSONObject;
  LError: TJSONObject;
begin
  LError := TJSONObject.Create();
  LError.AddPair('code', TJSONNumber.Create(ACode));
  LError.AddPair('message', AMessage);

  LMsg := TJSONObject.Create();
  try
    LMsg.AddPair('jsonrpc', '2.0');
    if AId <> nil then
      LMsg.AddPair('id', AId.Clone() as TJSONValue)
    else
      LMsg.AddPair('id', TJSONNull.Create());
    LMsg.AddPair('error', LError);
    WriteMessage(LMsg);
  finally
    LMsg.Free();
  end;
end;

procedure TLSPServer.SendNotification(const AMethod: string;
  const AParams: TJSONValue);
var
  LMsg: TJSONObject;
begin
  LMsg := TJSONObject.Create();
  try
    LMsg.AddPair('jsonrpc', '2.0');
    LMsg.AddPair('method', AMethod);
    LMsg.AddPair('params', AParams);
    WriteMessage(LMsg);
  finally
    LMsg.Free();
  end;
end;

procedure TLSPServer.PublishDiagnostics(const AUri: string);
var
  LDiags: TArray<TLSPDiagnostic>;
  LParams: TJSONObject;
  LDiagsArray: TJSONArray;
  LI: Integer;
begin
  LDiags := FService.GetDiagnostics(AUri);
  LDiagsArray := TJSONArray.Create();
  for LI := 0 to High(LDiags) do
    LDiagsArray.AddElement(LDiags[LI].ToJSON());

  LParams := TJSONObject.Create();
  LParams.AddPair('uri', AUri);
  LParams.AddPair('diagnostics', LDiagsArray);

  SendNotification('textDocument/publishDiagnostics', LParams);
end;

procedure TLSPServer.HandleInitialize(const AId: TJSONValue;
  const AParams: TJSONObject);
var
  LResult: TJSONObject;
  LCapabilities: TJSONObject;
  LCompletionProvider: TJSONObject;
  LTriggerCharsComp: TJSONArray;
  LSigHelpProvider: TJSONObject;
  LTriggerCharsSig: TJSONArray;
  LSemanticProvider: TJSONObject;
  LLegend: TJSONObject;
  LTokenTypes: TJSONArray;
  LTokenMods: TJSONArray;
  LServerInfo: TJSONObject;
begin
  // Semantic tokens legend (indices match GetSemanticTokens output)
  LTokenTypes := TJSONArray.Create();
  LTokenTypes.Add('namespace');    // 0
  LTokenTypes.Add('type');         // 1
  LTokenTypes.Add('class');        // 2
  LTokenTypes.Add('enum');         // 3
  LTokenTypes.Add('function');     // 4
  LTokenTypes.Add('method');       // 5
  LTokenTypes.Add('property');     // 6
  LTokenTypes.Add('variable');     // 7
  LTokenTypes.Add('parameter');    // 8
  LTokenTypes.Add('enumMember');   // 9
  LTokenTypes.Add('keyword');      // 10
  LTokenTypes.Add('operator');     // 11
  LTokenTypes.Add('number');       // 12
  LTokenTypes.Add('string');       // 13
  LTokenTypes.Add('comment');      // 14

  LTokenMods := TJSONArray.Create();
  LTokenMods.Add('declaration');
  LTokenMods.Add('definition');
  LTokenMods.Add('readonly');

  LLegend := TJSONObject.Create();
  LLegend.AddPair('tokenTypes', LTokenTypes);
  LLegend.AddPair('tokenModifiers', LTokenMods);

  LSemanticProvider := TJSONObject.Create();
  LSemanticProvider.AddPair('legend', LLegend);
  LSemanticProvider.AddPair('full', TJSONBool.Create(True));

  LTriggerCharsComp := TJSONArray.Create();
  LTriggerCharsComp.Add('.');
  LCompletionProvider := TJSONObject.Create();
  LCompletionProvider.AddPair('triggerCharacters', LTriggerCharsComp);

  LTriggerCharsSig := TJSONArray.Create();
  LTriggerCharsSig.Add('(');
  LTriggerCharsSig.Add(',');
  LSigHelpProvider := TJSONObject.Create();
  LSigHelpProvider.AddPair('triggerCharacters', LTriggerCharsSig);

  LCapabilities := TJSONObject.Create();
  LCapabilities.AddPair('textDocumentSync', TJSONNumber.Create(1));
  LCapabilities.AddPair('completionProvider', LCompletionProvider);
  LCapabilities.AddPair('hoverProvider', TJSONBool.Create(True));
  LCapabilities.AddPair('definitionProvider', TJSONBool.Create(True));
  LCapabilities.AddPair('referencesProvider', TJSONBool.Create(True));
  LCapabilities.AddPair('documentSymbolProvider', TJSONBool.Create(True));
  LCapabilities.AddPair('signatureHelpProvider', LSigHelpProvider);
  LCapabilities.AddPair('foldingRangeProvider', TJSONBool.Create(True));
  LCapabilities.AddPair('semanticTokensProvider', LSemanticProvider);
  LCapabilities.AddPair('inlayHintProvider', TJSONBool.Create(True));
  LCapabilities.AddPair('renameProvider', TJSONBool.Create(True));
  LCapabilities.AddPair('workspaceSymbolProvider', TJSONBool.Create(True));
  LCapabilities.AddPair('documentFormattingProvider', TJSONBool.Create(True));
  LCapabilities.AddPair('codeActionProvider', TJSONBool.Create(True));

  LServerInfo := TJSONObject.Create();
  LServerInfo.AddPair('name', 'myra-lsp');
  LServerInfo.AddPair('version', '1.0.0');

  LResult := TJSONObject.Create();
  LResult.AddPair('capabilities', LCapabilities);
  LResult.AddPair('serverInfo', LServerInfo);

  SendResponse(AId, LResult);
end;

procedure TLSPServer.HandleInitialized(const AParams: TJSONObject);
begin
  FInitialized := True;
end;

procedure TLSPServer.HandleShutdown(const AId: TJSONValue);
begin
  FShutdownRequested := True;
  SendResponse(AId, TJSONNull.Create());
end;

procedure TLSPServer.HandleExit();
begin
  if FShutdownRequested then
    Halt(0)
  else
    Halt(1);
end;

procedure TLSPServer.HandleTextDocumentDidOpen(
  const AParams: TJSONObject);
var
  LTextDocument: TJSONObject;
  LUri: string;
  LText: string;
begin
  LTextDocument := AParams.GetValue<TJSONObject>('textDocument', nil);
  if LTextDocument = nil then Exit;
  LUri := LTextDocument.GetValue<string>('uri', '');
  LText := LTextDocument.GetValue<string>('text', '');
  if LUri = '' then Exit;

  FService.OpenDocument(LUri, LText);
  PublishDiagnostics(LUri);
end;

procedure TLSPServer.HandleTextDocumentDidChange(
  const AParams: TJSONObject);
var
  LTextDocument: TJSONObject;
  LChanges: TJSONArray;
  LFirstChange: TJSONObject;
  LUri: string;
  LVersion: Integer;
  LText: string;
begin
  LTextDocument := AParams.GetValue<TJSONObject>('textDocument', nil);
  if LTextDocument = nil then Exit;
  LUri := LTextDocument.GetValue<string>('uri', '');
  LVersion := LTextDocument.GetValue<Integer>('version', 0);
  if LUri = '' then Exit;

  // Full sync (textDocumentSync: 1) - take first change's full text
  LChanges := AParams.GetValue<TJSONArray>('contentChanges', nil);
  if (LChanges = nil) or (LChanges.Count = 0) then Exit;
  LFirstChange := LChanges.Items[0] as TJSONObject;
  LText := LFirstChange.GetValue<string>('text', '');

  FService.UpdateDocument(LUri, LText, LVersion);
  PublishDiagnostics(LUri);
end;

procedure TLSPServer.HandleTextDocumentDidClose(
  const AParams: TJSONObject);
var
  LTextDocument: TJSONObject;
  LUri: string;
  LParams: TJSONObject;
  LEmptyDiags: TJSONArray;
begin
  LTextDocument := AParams.GetValue<TJSONObject>('textDocument', nil);
  if LTextDocument = nil then Exit;
  LUri := LTextDocument.GetValue<string>('uri', '');
  if LUri = '' then Exit;

  FService.CloseDocument(LUri);

  // Clear diagnostics for closed file
  LEmptyDiags := TJSONArray.Create();
  LParams := TJSONObject.Create();
  LParams.AddPair('uri', LUri);
  LParams.AddPair('diagnostics', LEmptyDiags);
  SendNotification('textDocument/publishDiagnostics', LParams);
end;

procedure TLSPServer.HandleTextDocumentCompletion(
  const AId: TJSONValue; const AParams: TJSONObject);
var
  LTextDocument: TJSONObject;
  LPosition: TJSONObject;
  LUri: string;
  LItems: TArray<TLSPCompletionItem>;
  LResultArray: TJSONArray;
  LI: Integer;
begin
  LTextDocument := AParams.GetValue<TJSONObject>('textDocument', nil);
  LPosition := AParams.GetValue<TJSONObject>('position', nil);
  if (LTextDocument = nil) or (LPosition = nil) then
  begin
    SendResponse(AId, TJSONArray.Create());
    Exit;
  end;

  LUri := LTextDocument.GetValue<string>('uri', '');
  LItems := FService.GetCompletions(LUri,
    LPosition.GetValue<Integer>('line', 0),
    LPosition.GetValue<Integer>('character', 0));

  LResultArray := TJSONArray.Create();
  for LI := 0 to High(LItems) do
    LResultArray.AddElement(LItems[LI].ToJSON());
  SendResponse(AId, LResultArray);
end;

procedure TLSPServer.HandleTextDocumentHover(
  const AId: TJSONValue; const AParams: TJSONObject);
var
  LTextDocument: TJSONObject;
  LPosition: TJSONObject;
  LHover: TLSPHover;
begin
  LTextDocument := AParams.GetValue<TJSONObject>('textDocument', nil);
  LPosition := AParams.GetValue<TJSONObject>('position', nil);
  if (LTextDocument = nil) or (LPosition = nil) then
  begin
    SendResponse(AId, TJSONNull.Create());
    Exit;
  end;

  LHover := FService.GetHover(
    LTextDocument.GetValue<string>('uri', ''),
    LPosition.GetValue<Integer>('line', 0),
    LPosition.GetValue<Integer>('character', 0));

  if LHover.IsEmpty() then
    SendResponse(AId, TJSONNull.Create())
  else
    SendResponse(AId, LHover.ToJSON());
end;

procedure TLSPServer.HandleTextDocumentDefinition(
  const AId: TJSONValue; const AParams: TJSONObject);
var
  LTextDocument: TJSONObject;
  LPosition: TJSONObject;
  LLocation: TLSPLocation;
begin
  LTextDocument := AParams.GetValue<TJSONObject>('textDocument', nil);
  LPosition := AParams.GetValue<TJSONObject>('position', nil);
  if (LTextDocument = nil) or (LPosition = nil) then
  begin
    SendResponse(AId, TJSONNull.Create());
    Exit;
  end;

  LLocation := FService.GetDefinition(
    LTextDocument.GetValue<string>('uri', ''),
    LPosition.GetValue<Integer>('line', 0),
    LPosition.GetValue<Integer>('character', 0));

  if LLocation.IsEmpty() then
    SendResponse(AId, TJSONNull.Create())
  else
    SendResponse(AId, LLocation.ToJSON());
end;

procedure TLSPServer.HandleTextDocumentReferences(
  const AId: TJSONValue; const AParams: TJSONObject);
var
  LTextDocument: TJSONObject;
  LPosition: TJSONObject;
  LContext: TJSONObject;
  LIncludeDecl: Boolean;
  LLocations: TArray<TLSPLocation>;
  LResultArray: TJSONArray;
  LI: Integer;
begin
  LTextDocument := AParams.GetValue<TJSONObject>('textDocument', nil);
  LPosition := AParams.GetValue<TJSONObject>('position', nil);
  LContext := AParams.GetValue<TJSONObject>('context', nil);
  if (LTextDocument = nil) or (LPosition = nil) then
  begin
    SendResponse(AId, TJSONArray.Create());
    Exit;
  end;

  LIncludeDecl := False;
  if LContext <> nil then
    LIncludeDecl := LContext.GetValue<Boolean>('includeDeclaration', False);

  LLocations := FService.GetReferences(
    LTextDocument.GetValue<string>('uri', ''),
    LPosition.GetValue<Integer>('line', 0),
    LPosition.GetValue<Integer>('character', 0),
    LIncludeDecl);

  LResultArray := TJSONArray.Create();
  for LI := 0 to High(LLocations) do
    LResultArray.AddElement(LLocations[LI].ToJSON());
  SendResponse(AId, LResultArray);
end;

procedure TLSPServer.HandleTextDocumentDocumentSymbol(
  const AId: TJSONValue; const AParams: TJSONObject);
var
  LTextDocument: TJSONObject;
  LSymbols: TArray<TLSPDocumentSymbol>;
  LResultArray: TJSONArray;
  LI: Integer;
begin
  LTextDocument := AParams.GetValue<TJSONObject>('textDocument', nil);
  if LTextDocument = nil then
  begin
    SendResponse(AId, TJSONArray.Create());
    Exit;
  end;

  LSymbols := FService.GetDocumentSymbols(
    LTextDocument.GetValue<string>('uri', ''));
  LResultArray := TJSONArray.Create();
  for LI := 0 to High(LSymbols) do
    LResultArray.AddElement(LSymbols[LI].ToJSON());
  SendResponse(AId, LResultArray);
end;

procedure TLSPServer.HandleTextDocumentSignatureHelp(
  const AId: TJSONValue; const AParams: TJSONObject);
var
  LTextDocument: TJSONObject;
  LPosition: TJSONObject;
  LSigHelp: TLSPSignatureHelp;
begin
  LTextDocument := AParams.GetValue<TJSONObject>('textDocument', nil);
  LPosition := AParams.GetValue<TJSONObject>('position', nil);
  if (LTextDocument = nil) or (LPosition = nil) then
  begin
    SendResponse(AId, TJSONNull.Create());
    Exit;
  end;

  LSigHelp := FService.GetSignatureHelp(
    LTextDocument.GetValue<string>('uri', ''),
    LPosition.GetValue<Integer>('line', 0),
    LPosition.GetValue<Integer>('character', 0));

  if Length(LSigHelp.Signatures) = 0 then
    SendResponse(AId, TJSONNull.Create())
  else
    SendResponse(AId, LSigHelp.ToJSON());
end;

procedure TLSPServer.HandleTextDocumentFoldingRange(
  const AId: TJSONValue; const AParams: TJSONObject);
var
  LTextDocument: TJSONObject;
  LRanges: TArray<TLSPFoldingRange>;
  LResultArray: TJSONArray;
  LI: Integer;
begin
  LTextDocument := AParams.GetValue<TJSONObject>('textDocument', nil);
  if LTextDocument = nil then
  begin
    SendResponse(AId, TJSONArray.Create());
    Exit;
  end;

  LRanges := FService.GetFoldingRanges(
    LTextDocument.GetValue<string>('uri', ''));
  LResultArray := TJSONArray.Create();
  for LI := 0 to High(LRanges) do
    LResultArray.AddElement(LRanges[LI].ToJSON());
  SendResponse(AId, LResultArray);
end;

procedure TLSPServer.HandleTextDocumentSemanticTokensFull(
  const AId: TJSONValue; const AParams: TJSONObject);
var
  LTextDocument: TJSONObject;
  LTokenData: TArray<Integer>;
  LDataArray: TJSONArray;
  LResultObj: TJSONObject;
  LI: Integer;
begin
  LTextDocument := AParams.GetValue<TJSONObject>('textDocument', nil);
  if LTextDocument = nil then
  begin
    SendResponse(AId, TJSONObject.Create());
    Exit;
  end;

  LTokenData := FService.GetSemanticTokens(
    LTextDocument.GetValue<string>('uri', ''));
  LDataArray := TJSONArray.Create();
  for LI := 0 to High(LTokenData) do
    LDataArray.Add(LTokenData[LI]);

  LResultObj := TJSONObject.Create();
  LResultObj.AddPair('data', LDataArray);
  SendResponse(AId, LResultObj);
end;

procedure TLSPServer.HandleTextDocumentInlayHint(
  const AId: TJSONValue; const AParams: TJSONObject);
var
  LTextDocument: TJSONObject;
  LRangeObj: TJSONObject;
  LLSPRange: TLSPRange;
  LHints: TArray<TLSPInlayHint>;
  LResultArray: TJSONArray;
  LI: Integer;
begin
  LTextDocument := AParams.GetValue<TJSONObject>('textDocument', nil);
  if LTextDocument = nil then
  begin
    SendResponse(AId, TJSONArray.Create());
    Exit;
  end;

  LRangeObj := AParams.GetValue<TJSONObject>('range', nil);
  if LRangeObj <> nil then
    LLSPRange := TLSPRange.FromJSON(LRangeObj)
  else
    LLSPRange.Clear();

  LHints := FService.GetInlayHints(
    LTextDocument.GetValue<string>('uri', ''),
    LLSPRange.StartPos.Line, LLSPRange.StartPos.Character,
    LLSPRange.EndPos.Line, LLSPRange.EndPos.Character);

  LResultArray := TJSONArray.Create();
  for LI := 0 to High(LHints) do
    LResultArray.AddElement(LHints[LI].ToJSON());
  SendResponse(AId, LResultArray);
end;

procedure TLSPServer.HandleTextDocumentRename(
  const AId: TJSONValue; const AParams: TJSONObject);
var
  LTextDocument: TJSONObject;
  LPosition: TJSONObject;
  LNewName: string;
  LEdit: TLSPWorkspaceEdit;
  LChanges: TJSONObject;
  LEditsArray: TJSONArray;
  LResultObj: TJSONObject;
  LUri: string;
  LI: Integer;
begin
  LTextDocument := AParams.GetValue<TJSONObject>('textDocument', nil);
  LPosition := AParams.GetValue<TJSONObject>('position', nil);
  if (LTextDocument = nil) or (LPosition = nil) then
  begin
    SendResponse(AId, TJSONNull.Create());
    Exit;
  end;

  LUri := LTextDocument.GetValue<string>('uri', '');
  LNewName := AParams.GetValue<string>('newName', '');
  if LNewName = '' then
  begin
    SendResponse(AId, TJSONNull.Create());
    Exit;
  end;

  LEdit := FService.GetRenameEdits(LUri,
    LPosition.GetValue<Integer>('line', 0),
    LPosition.GetValue<Integer>('character', 0),
    LNewName);

  if Length(LEdit.Edits) = 0 then
  begin
    SendResponse(AId, TJSONNull.Create());
    Exit;
  end;

  LEditsArray := TJSONArray.Create();
  for LI := 0 to High(LEdit.Edits) do
    LEditsArray.AddElement(LEdit.Edits[LI].ToJSON());

  LChanges := TJSONObject.Create();
  LChanges.AddPair(LUri, LEditsArray);

  LResultObj := TJSONObject.Create();
  LResultObj.AddPair('changes', LChanges);
  SendResponse(AId, LResultObj);
end;

procedure TLSPServer.HandleWorkspaceSymbol(
  const AId: TJSONValue; const AParams: TJSONObject);
var
  LQuery: string;
  LSymbols: TArray<TLSPSymbolInformation>;
  LResultArray: TJSONArray;
  LI: Integer;
begin
  LQuery := AParams.GetValue<string>('query', '');
  LSymbols := FService.GetWorkspaceSymbols(LQuery, '');

  LResultArray := TJSONArray.Create();
  for LI := 0 to High(LSymbols) do
    LResultArray.AddElement(LSymbols[LI].ToJSON());
  SendResponse(AId, LResultArray);
end;

procedure TLSPServer.HandleTextDocumentCodeAction(
  const AId: TJSONValue; const AParams: TJSONObject);
var
  LTextDocument: TJSONObject;
  LRange: TJSONObject;
  LUri: string;
  LStart: TLSPPosition;
  LEnd: TLSPPosition;
  LActions: TArray<TJSONObject>;
  LResultArray: TJSONArray;
  LI: Integer;
begin
  LTextDocument := AParams.GetValue<TJSONObject>('textDocument', nil);
  if LTextDocument = nil then
  begin
    SendResponse(AId, TJSONArray.Create());
    Exit;
  end;
  LUri := LTextDocument.GetValue<string>('uri', '');

  LStart.Clear();
  LEnd.Clear();
  LRange := AParams.GetValue<TJSONObject>('range', nil);
  if LRange <> nil then
  begin
    // TLSPPosition.FromJSON dereferences its argument -- never hand it nil.
    if LRange.GetValue<TJSONObject>('start', nil) <> nil then
      LStart := TLSPPosition.FromJSON(
        LRange.GetValue<TJSONObject>('start', nil));
    if LRange.GetValue<TJSONObject>('end', nil) <> nil then
      LEnd := TLSPPosition.FromJSON(
        LRange.GetValue<TJSONObject>('end', nil));
  end;

  LActions := FService.GetCodeActions(LUri,
    LStart.Line, LStart.Character, LEnd.Line, LEnd.Character);

  LResultArray := TJSONArray.Create();
  for LI := 0 to High(LActions) do
    LResultArray.AddElement(LActions[LI]);
  SendResponse(AId, LResultArray);
end;

procedure TLSPServer.HandleTextDocumentFormatting(
  const AId: TJSONValue; const AParams: TJSONObject);
var
  LTextDocument: TJSONObject;
  LOptions: TJSONObject;
  LTabSize: Integer;
  LInsertSpaces: Boolean;
  LEdits: TArray<TLSPTextEdit>;
  LResultArray: TJSONArray;
  LI: Integer;
begin
  LTextDocument := AParams.GetValue<TJSONObject>('textDocument', nil);
  if LTextDocument = nil then
  begin
    SendResponse(AId, TJSONArray.Create());
    Exit;
  end;

  LOptions := AParams.GetValue<TJSONObject>('options', nil);
  LTabSize := 2;
  LInsertSpaces := True;
  if LOptions <> nil then
  begin
    LTabSize := LOptions.GetValue<Integer>('tabSize', 2);
    LInsertSpaces := LOptions.GetValue<Boolean>('insertSpaces', True);
  end;

  LEdits := FService.GetDocumentFormatting(
    LTextDocument.GetValue<string>('uri', ''),
    LTabSize, LInsertSpaces);

  LResultArray := TJSONArray.Create();
  for LI := 0 to High(LEdits) do
    LResultArray.AddElement(LEdits[LI].ToJSON());
  SendResponse(AId, LResultArray);
end;

procedure TLSPServer.DispatchMessage(const AMessage: TJSONObject);
var
  LMethod: string;
  LId: TJSONValue;
  LParams: TJSONObject;
begin
  LMethod := AMessage.GetValue<string>('method', '');
  LId := AMessage.GetValue<TJSONValue>('id', nil);
  LParams := AMessage.GetValue<TJSONObject>('params', nil);

  if LMethod = '' then Exit;

  // Notifications (no id)
  if LMethod = 'initialized' then
    HandleInitialized(LParams)
  else if LMethod = 'exit' then
    HandleExit()
  else if LMethod = 'textDocument/didOpen' then
    HandleTextDocumentDidOpen(LParams)
  else if LMethod = 'textDocument/didChange' then
    HandleTextDocumentDidChange(LParams)
  else if LMethod = 'textDocument/didClose' then
    HandleTextDocumentDidClose(LParams)

  // Requests (have id)
  else if LMethod = 'initialize' then
    HandleInitialize(LId, LParams)
  else if LMethod = 'shutdown' then
    HandleShutdown(LId)
  else if LMethod = 'textDocument/completion' then
    HandleTextDocumentCompletion(LId, LParams)
  else if LMethod = 'textDocument/hover' then
    HandleTextDocumentHover(LId, LParams)
  else if LMethod = 'textDocument/definition' then
    HandleTextDocumentDefinition(LId, LParams)
  else if LMethod = 'textDocument/references' then
    HandleTextDocumentReferences(LId, LParams)
  else if LMethod = 'textDocument/documentSymbol' then
    HandleTextDocumentDocumentSymbol(LId, LParams)
  else if LMethod = 'textDocument/signatureHelp' then
    HandleTextDocumentSignatureHelp(LId, LParams)
  else if LMethod = 'textDocument/foldingRange' then
    HandleTextDocumentFoldingRange(LId, LParams)
  else if LMethod = 'textDocument/semanticTokens/full' then
    HandleTextDocumentSemanticTokensFull(LId, LParams)
  else if LMethod = 'textDocument/inlayHint' then
    HandleTextDocumentInlayHint(LId, LParams)
  else if LMethod = 'textDocument/rename' then
    HandleTextDocumentRename(LId, LParams)
  else if LMethod = 'workspace/symbol' then
    HandleWorkspaceSymbol(LId, LParams)
  else if LMethod = 'textDocument/codeAction' then
    HandleTextDocumentCodeAction(LId, LParams)
  else if LMethod = 'textDocument/formatting' then
    HandleTextDocumentFormatting(LId, LParams)
  else
  begin
    // Unknown method: only send error for requests (those with an id)
    if LId <> nil then
      SendError(LId, -32601, 'Method not found: ' + LMethod);
  end;
end;

procedure TLSPServer.Run();
var
  LMessage: TJSONObject;
  LStdinStream: THandleStream;
  LStdoutStream: THandleStream;
  LStdErr: TStreamWriter;
begin
  // If no streams set, default to stdin/stdout
  if FInputStream = nil then
  begin
    LStdinStream := THandleStream.Create(GetStdHandle(STD_INPUT_HANDLE));
    LStdoutStream := THandleStream.Create(GetStdHandle(STD_OUTPUT_HANDLE));
    FInputStream := LStdinStream;
    FOutputStream := LStdoutStream;
    FOwnsStreams := True;
  end;

  // Load the language definition.
  // A failure here used to `Exit` in total silence: nothing on the wire, no
  // message, no log -- the editor just saw a process that died. Report it on
  // stderr (stdout is the JSON-RPC channel and must not be polluted) so the
  // failure is diagnosable instead of invisible.
  if FMLDFile <> '' then
  begin
    FEngineAPI := TEngineAPI.Create();
    FEngineAPI.LoadMor(FMLDFile);
    if FEngineAPI.GetErrors().HasErrors() then
    begin
      LStdErr := TStreamWriter.Create(
        THandleStream.Create(GetStdHandle(STD_ERROR_HANDLE)), TEncoding.UTF8);
      try
        LStdErr.OwnStream();
        LStdErr.WriteLine(Format(RSLSPLangDefFailed, [FMLDFile]));
        LStdErr.WriteLine(FEngineAPI.GetErrors().ToString());
      finally
        LStdErr.Free();
      end;
      Exit;
    end;
    FService.SetInterpreter(FEngineAPI.GetInterpreter());
  end;

  // Message loop
  while True do
  begin
    LMessage := ReadMessage();
    if LMessage = nil then
      Break;

    try
      DispatchMessage(LMessage);
    finally
      LMessage.Free();
    end;

    if FShutdownRequested then
      Break;
  end;
end;

end.
