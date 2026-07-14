{===============================================================================
  Myra™ - Pascal. Refined.

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  https://myralang.org

  See LICENSE for license information
===============================================================================}

unit Myra.AST;

{$I StdApp.Defines.inc}

interface

uses
  System.SysUtils,
  System.Classes,
  System.Rtti,
  System.TypInfo,
  System.Generics.Collections,
  StdApp.Resources,
  StdApp.Base,
  StdApp.Utils;

type

  { TMyrToken }
  TToken = record
    Kind: string;
    Text: string;
    Filename: string;
    Line: Integer;
    Col: Integer;
  end;

  { TMyrASTNode }
  TASTNode = class(TBaseObject)
  private
    FKind: string;
    FToken: TToken;
    FAttrs: TDictionary<string, string>;
    FChildren: TObjectList<TASTNode>;
    FNamedChildren: TDictionary<string, TASTNode>;
    FRange: TSourceRange;
    FParented: Boolean;

  public
    constructor Create(); override;
    destructor Destroy(); override;
    function Dump(const AId: Integer = 0): string; override;

    // Orphan tracking: True once this node has been added to a parent.
    function IsParented(): Boolean;

    // Kind
    function GetKind(): string;
    procedure SetKind(const AKind: string);

    // Token
    function GetToken(): TToken;
    procedure SetToken(const AToken: TToken);

    // Attribute access
    function GetAttr(const AKey: string): string;
    procedure SetAttr(const AKey: string; const AValue: string);
    function HasAttr(const AKey: string): Boolean;

    // Child management
    function ChildCount(): Integer;
    function GetChild(const AIndex: Integer): TASTNode;
    procedure AddChild(const AChild: TASTNode);
    // Replace the child at AIndex with AChild. The child list owns its items,
    // so the displaced node is freed; only ever pass a fresh (unaliased) node.
    procedure SetChild(const AIndex: Integer; const AChild: TASTNode);
    // Detach the child at AIndex WITHOUT freeing it (extract), so it can be
    // reparented elsewhere. The caller takes ownership of the detached node.
    procedure RemoveChild(const AIndex: Integer);

    // Named child access
    function GetNamedChild(const AName: string): TASTNode;
    procedure SetNamedChild(const AName: string; const AChild: TASTNode);
    function HasNamedChild(const AName: string): Boolean;

    // Source range
    function GetRange(): TSourceRange;
    procedure SetRange(const ARange: TSourceRange);

    // Deep copy: returns a fully independent clone of this node and its entire
    // subtree (kind, token, attrs, range, positional children). Implemented as
    // a round-trip through SaveToStream/LoadFromStream so it stays correct as
    // node state evolves. Note: FNamedChildren is not copied (not serialized,
    // and unused by the NitroLISP langdef, which is positional + attrs only).
    function Clone(): TASTNode;

    // AST serialization
    procedure SaveToStream(const AStream: TStream);
    class function LoadFromStream(const AStream: TStream): TASTNode; static;
    class procedure SaveASTToStream(const ARoot: TASTNode; const AStream: TStream); static;
    class function LoadASTFromStream(const AStream: TStream): TASTNode; static;
  end;

// Helper functions for TValue operations
function ValueIsTrue(const AValue: TValue): Boolean;
function ValueToString(const AValue: TValue): string;

// Factory helper
function MyrMakeToken(const AKind: string; const AText: string;
  const ALine: Integer; const ACol: Integer): TToken;

implementation

uses
  Myra.Common;

{ TMyrToken }

function MyrMakeToken(const AKind: string; const AText: string;
  const ALine: Integer; const ACol: Integer): TToken;
begin
  Result.Kind := AKind;
  Result.Text := AText;
  Result.Filename := '';
  Result.Line := ALine;
  Result.Col := ACol;
end;

{ TValue helpers }

function ValueIsTrue(const AValue: TValue): Boolean;
begin
  if AValue.IsEmpty then
    Exit(False);

  if AValue.IsType<Boolean>() then
    Exit(AValue.AsBoolean());

  if (AValue.Kind = tkInt64) then
    Exit(AValue.AsInt64() <> 0);

  if (AValue.Kind = tkInteger) then
    Exit(AValue.AsInteger() <> 0);

  if (AValue.Kind = tkFloat) then
    Exit(AValue.AsExtended() <> 0.0);

  if AValue.IsType<string>() then
    Exit(AValue.AsString() <> '');

  if AValue.IsObject() then
    Exit(AValue.AsObject() <> nil);

  Result := False;
end;

function ValueToString(const AValue: TValue): string;
begin
  if AValue.IsEmpty then
    Exit('nil');

  if AValue.IsType<string>() then
    Exit(AValue.AsString());

  if (AValue.Kind = tkInt64) then
    Exit(IntToStr(AValue.AsInt64()));

  if (AValue.Kind = tkInteger) then
    Exit(IntToStr(AValue.AsInteger()));

  if (AValue.Kind = tkFloat) then
    Exit(FloatToStr(AValue.AsExtended()));

  if AValue.IsType<Boolean>() then
  begin
    if AValue.AsBoolean() then
      Exit('true')
    else
      Exit('false');
  end;

  if AValue.IsObject() then
  begin
    if AValue.AsObject() = nil then
      Exit('nil');
    if AValue.AsObject() is TASTNode then
      Exit('<node:' + TASTNode(AValue.AsObject()).GetKind() + '>');
    Exit('<object>');
  end;

  Result := '<unknown>';
end;

{ TMyrASTNode }

constructor TASTNode.Create();
begin
  inherited;
  FKind := '';
  FToken.Kind := '';
  FToken.Text := '';
  FToken.Filename := '';
  FToken.Line := 0;
  FToken.Col := 0;
  FAttrs := TDictionary<string, string>.Create();
  FChildren := TObjectList<TASTNode>.Create(True);
  FNamedChildren := TDictionary<string, TASTNode>.Create();
  FRange.Clear();
  FParented := False;
end;

destructor TASTNode.Destroy();
begin
  FreeAndNil(FNamedChildren);
  FreeAndNil(FChildren);
  FreeAndNil(FAttrs);
  inherited;
end;

function TASTNode.Dump(const AId: Integer): string;
var
  LIndent: string;
  LPair: TPair<string, string>;
  LI: Integer;
begin
  LIndent := StringOfChar(' ', AId * 2);
  Result := LIndent + FKind;

  // Append attributes inline
  for LPair in FAttrs do
    Result := Result + ' ' + LPair.Key + '="' + LPair.Value + '"';

  Result := Result + sLineBreak;

  // Dump children recursively
  for LI := 0 to FChildren.Count - 1 do
    Result := Result + FChildren[LI].Dump(AId + 1);
end;

function TASTNode.GetKind(): string;
begin
  Result := FKind;
end;

procedure TASTNode.SetKind(const AKind: string);
begin
  FKind := AKind;
  {$IFDEF MYR_LEAK_TRACK}
  LeakTrackUpdateLabel('kind=' + AKind);
  {$ENDIF}
end;

function TASTNode.GetToken(): TToken;
begin
  Result := FToken;
end;

procedure TASTNode.SetToken(const AToken: TToken);
begin
  FToken := AToken;
  {$IFDEF MYR_LEAK_TRACK}
  LeakTrackUpdateLabel('token=' + AToken.Text + ' @' +
    AToken.Filename + ':' + AToken.Line.ToString());
  {$ENDIF}
end;

function TASTNode.GetAttr(const AKey: string): string;
begin
  if not FAttrs.TryGetValue(AKey, Result) then
    Result := '';
end;

procedure TASTNode.SetAttr(const AKey: string; const AValue: string);
begin
  FAttrs.AddOrSetValue(AKey, AValue);
end;

function TASTNode.HasAttr(const AKey: string): Boolean;
begin
  Result := FAttrs.ContainsKey(AKey);
end;

function TASTNode.ChildCount(): Integer;
begin
  Result := FChildren.Count;
end;

function TASTNode.GetChild(const AIndex: Integer): TASTNode;
begin
  Result := FChildren[AIndex];
end;

procedure TASTNode.AddChild(const AChild: TASTNode);
begin
  FChildren.Add(AChild);
  if Assigned(AChild) then
    AChild.FParented := True;
  {$IFDEF MYR_LEAK_TRACK}
  if Assigned(AChild) then
    AChild.LeakTrackUpdateLabel('parented');
  {$ENDIF}
end;

procedure TASTNode.SetChild(const AIndex: Integer; const AChild: TASTNode);
begin
  if (AIndex >= 0) and (AIndex < FChildren.Count) then
  begin
    // FChildren owns its items: assigning frees the displaced node.
    FChildren[AIndex] := AChild;
    if Assigned(AChild) then
      AChild.FParented := True;
  end;
end;

procedure TASTNode.RemoveChild(const AIndex: Integer);
var
  LChild: TASTNode;
begin
  if (AIndex >= 0) and (AIndex < FChildren.Count) then
  begin
    // Extract (not Delete): detach without freeing, so the node can be
    // reparented. Ownership passes to the caller; the node is no longer
    // parented, so clear the flag (a later AddChild sets it True again). This
    // keeps IsParented() truthful for the compilation-scoped orphan sweep.
    LChild := FChildren[AIndex];
    FChildren.Extract(LChild);
    LChild.FParented := False;
  end;
end;

function TASTNode.IsParented(): Boolean;
begin
  Result := FParented;
end;

function TASTNode.GetNamedChild(const AName: string): TASTNode;
begin
  if not FNamedChildren.TryGetValue(AName, Result) then
    Result := nil;
end;

procedure TASTNode.SetNamedChild(const AName: string; const AChild: TASTNode);
begin
  FNamedChildren.AddOrSetValue(AName, AChild);
end;

function TASTNode.HasNamedChild(const AName: string): Boolean;
begin
  Result := FNamedChildren.ContainsKey(AName);
end;

function TASTNode.GetRange(): TSourceRange;
begin
  Result := FRange;
end;

procedure TASTNode.SetRange(const ARange: TSourceRange);
begin
  FRange := ARange;
end;

function TASTNode.Clone(): TASTNode;
var
  LStream: TMemoryStream;
begin
  LStream := TMemoryStream.Create();
  try
    SaveToStream(LStream);
    LStream.Position := 0;
    Result := LoadFromStream(LStream);
  finally
    LStream.Free();
  end;
end;

{ AST Serialization Helpers }

procedure WriteString(const AStream: TStream; const AValue: string);
var
  LBytes: TBytes;
  LLen: Integer;
begin
  LBytes := TEncoding.UTF8.GetBytes(AValue);
  LLen := Length(LBytes);
  AStream.WriteData<Integer>(LLen);
  if LLen > 0 then
    AStream.WriteBuffer(LBytes[0], LLen);
end;

function ReadString(const AStream: TStream): string;
var
  LBytes: TBytes;
  LLen: Integer;
begin
  AStream.ReadData<Integer>(LLen);
  if LLen > 0 then
  begin
    SetLength(LBytes, LLen);
    AStream.ReadBuffer(LBytes[0], LLen);
    Result := TEncoding.UTF8.GetString(LBytes);
  end
  else
    Result := '';
end;

{ AST Serialization Methods }

procedure TASTNode.SaveToStream(const AStream: TStream);
var
  LI: Integer;
  LCount: Integer;
  LPair: TPair<string, string>;
begin
  // 1. FKind
  WriteString(AStream, FKind);

  // 2-4. FToken fields
  WriteString(AStream, FToken.Kind);
  WriteString(AStream, FToken.Text);
  WriteString(AStream, FToken.Filename);

  // 5-6. FToken integer fields
  AStream.WriteData<Integer>(FToken.Line);
  AStream.WriteData<Integer>(FToken.Col);

  // 7. FAttrs: count then key+value pairs
  LCount := FAttrs.Count;
  AStream.WriteData<Integer>(LCount);
  for LPair in FAttrs do
  begin
    WriteString(AStream, LPair.Key);
    WriteString(AStream, LPair.Value);
  end;

  // 8. FRange.Filename
  WriteString(AStream, FRange.Filename);

  // 9. FRange integer fields (6x)
  AStream.WriteData<Integer>(FRange.StartLine);
  AStream.WriteData<Integer>(FRange.StartColumn);
  AStream.WriteData<Integer>(FRange.EndLine);
  AStream.WriteData<Integer>(FRange.EndColumn);
  AStream.WriteData<Integer>(FRange.StartByteOffset);
  AStream.WriteData<Integer>(FRange.EndByteOffset);

  // 10. FChildren: count then recurse
  LCount := FChildren.Count;
  AStream.WriteData<Integer>(LCount);
  for LI := 0 to LCount - 1 do
    FChildren[LI].SaveToStream(AStream);
end;

class function TASTNode.LoadFromStream(const AStream: TStream): TASTNode;
var
  LI: Integer;
  LCount: Integer;
  LKey: string;
  LValue: string;
  LChild: TASTNode;
begin
  Result := TASTNode.Create();
  try
    // 1. FKind
    Result.FKind := ReadString(AStream);

    // 2-4. FToken fields
    Result.FToken.Kind := ReadString(AStream);
    Result.FToken.Text := ReadString(AStream);
    Result.FToken.Filename := ReadString(AStream);

    // 5-6. FToken integer fields
    AStream.ReadData<Integer>(Result.FToken.Line);
    AStream.ReadData<Integer>(Result.FToken.Col);

    // 7. FAttrs
    AStream.ReadData<Integer>(LCount);
    for LI := 0 to LCount - 1 do
    begin
      LKey := ReadString(AStream);
      LValue := ReadString(AStream);
      Result.FAttrs.AddOrSetValue(LKey, LValue);
    end;

    // 8. FRange.Filename
    Result.FRange.Filename := ReadString(AStream);

    // 9. FRange integer fields (6x)
    AStream.ReadData<Integer>(Result.FRange.StartLine);
    AStream.ReadData<Integer>(Result.FRange.StartColumn);
    AStream.ReadData<Integer>(Result.FRange.EndLine);
    AStream.ReadData<Integer>(Result.FRange.EndColumn);
    AStream.ReadData<Integer>(Result.FRange.StartByteOffset);
    AStream.ReadData<Integer>(Result.FRange.EndByteOffset);

    // 10. FChildren
    AStream.ReadData<Integer>(LCount);
    for LI := 0 to LCount - 1 do
    begin
      LChild := TASTNode.LoadFromStream(AStream);
      Result.FChildren.Add(LChild);
    end;
  except
    Result.Free();
    raise;
  end;
end;

class procedure TASTNode.SaveASTToStream(const ARoot: TASTNode; const AStream: TStream);
var
  LReserved: Integer;
begin
  // Write header: magic + format version + reserved
  AStream.WriteData<Cardinal>(AST_MAGIC);
  AStream.WriteData<Integer>(AST_VERSION);
  LReserved := 0;
  AStream.WriteData<Integer>(LReserved);

  // Write the AST tree
  ARoot.SaveToStream(AStream);
end;

class function TASTNode.LoadASTFromStream(const AStream: TStream): TASTNode;
var
  LMagic: Cardinal;
  LVersion: Integer;
  LReserved: Integer;
begin
  // Read and validate header
  AStream.ReadData<Cardinal>(LMagic);
  if LMagic <> AST_MAGIC then
    raise Exception.Create('Invalid AST stream: bad magic number');

  AStream.ReadData<Integer>(LVersion);
  if LVersion > AST_VERSION then
    raise Exception.CreateFmt('Unsupported AST format version %d (max supported: %d)',
      [LVersion, AST_VERSION]);

  AStream.ReadData<Integer>(LReserved);

  // Load the AST tree
  Result := TASTNode.LoadFromStream(AStream);
end;

end.
