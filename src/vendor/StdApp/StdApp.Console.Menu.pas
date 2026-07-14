{===============================================================================
  StdApp Components™

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information

 -------------------------------------------------------------------------------

  StdApp.Console.Menu - Interactive console menu system

  Fluent-API menu builder for console applications. Supports nested
  submenus, color customization, multi-column layout, separator items,
  and automatic integration with TTestCase and TTestDemo classes.

  Key types:
  - TConsoleMenu: Menu builder with fluent configuration (Title, colors,
    layout), Add/AddSeparator/AddSubmenu, AddTestCase/AddTestDemo for
    automatic test registration, and Run for the interactive loop
  - TMenuItem / TMenuItemKind: Menu entry record (Action, Separator, Submenu)

  Dependencies: StdApp.Base, StdApp.Utils, StdApp.Console,
    StdApp.TestCase, StdApp.TestDemo
===============================================================================}

unit StdApp.Console.Menu;

{$I StdApp.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  StdApp.Base,
  StdApp.Utils,
  StdApp.Console,
  StdApp.TestCase,
  StdApp.TestDemo;

type

  TConsoleMenu = class;

  { TMenuCallback }
  TMenuCallback = reference to procedure;

  { TMenuItemKind }
  TMenuItemKind = (
    Action,
    Separator,
    Submenu
  );

  { TMenuItem }
  TMenuItem = record
    ItemName: string;
    Callback: TMenuCallback;
    SubMenu:  TConsoleMenu;
    Kind:     TMenuItemKind;
  end;

  { TConsoleMenu }
  TConsoleMenu = class(TBaseObject)
  private
    FTitle:           string;
    FExitLabel:       string;
    FItems:           TList<TMenuItem>;
    FChildren:        TObjectList<TConsoleMenu>;
    FIsRoot:          Boolean;
    FTitleColor:      string;
    FItemColor:       string;
    FItemNumberColor: string;
    FExitColor:       string;
    FErrorColor:      string;
    FPromptColor:     string;
    FSeparatorColor:  string;
    FPromptText:      string;
    FPause:           Boolean;
    FMaxRows:         Integer;
    FColumnGap:       Integer;

    // Propagate color settings to a child menu
    procedure PropagateColors(const AChild: TConsoleMenu);
  public
    property Pause: Boolean read FPause write FPause;
    property IsRoot: Boolean read FIsRoot write FIsRoot;

    constructor Create(); override;
    destructor Destroy(); override;

    // Configuration (fluent - returns Self)
    function Title(const ATitle: string): TConsoleMenu;
    function ExitLabel(const ALabel: string): TConsoleMenu;
    function PromptText(const AText: string): TConsoleMenu;
    function TitleColor(const AColor: string): TConsoleMenu;
    function ItemColor(const AColor: string): TConsoleMenu;
    function ItemNumberColor(const AColor: string): TConsoleMenu;
    function ExitColor(const AColor: string): TConsoleMenu;
    function ErrorColor(const AColor: string): TConsoleMenu;
    function PromptColor(const AColor: string): TConsoleMenu;
    function SeparatorColor(const AColor: string): TConsoleMenu;
    function MaxRows(const AValue: Integer): TConsoleMenu;
    function ColumnGap(const AValue: Integer): TConsoleMenu;

    // Add items
    function Add(const AItemName: string;
      const ACallback: TMenuCallback): TConsoleMenu;
    function AddSeparator(): TConsoleMenu;
    function AddSubmenu(const ATitle: string): TConsoleMenu;

    // Add a test case class as a submenu with Run All + individual tests
    function AddTestCase(const ATestClass: TTestCaseClass): TConsoleMenu;

    // Add a test demo class as a single menu item
    function AddTestDemo(const ADemoClass: TTestDemoClass): TConsoleMenu;

    // Run the menu loop (blocks until user selects exit/return)
    procedure Run();

    // Clear all items
    procedure Clear();

    // Item count (excluding separators)
    function ActionCount(): Integer;
  end;

implementation

{ TConsoleMenu }

constructor TConsoleMenu.Create();
begin
  inherited;
  FItems := TList<TMenuItem>.Create();
  FChildren := TObjectList<TConsoleMenu>.Create(True);
  FTitle := 'Menu';
  FExitLabel := 'Quit';
  FPromptText := 'Choose> ';
  FTitleColor := COLOR_CYAN + COLOR_BOLD;
  FItemColor := COLOR_WHITE;
  FItemNumberColor := COLOR_YELLOW;
  FExitColor := COLOR_WHITE;
  FErrorColor := COLOR_RED;
  FPromptColor := COLOR_GREEN;
  FSeparatorColor := COLOR_WHITE;
  FIsRoot := True;
  FPause := False;
  FMaxRows := 20;
  FColumnGap := 3;
end;

destructor TConsoleMenu.Destroy();
begin
  FChildren.Free();
  FItems.Free();
  inherited;
end;

procedure TConsoleMenu.PropagateColors(const AChild: TConsoleMenu);
begin
  AChild.FTitleColor := FTitleColor;
  AChild.FItemColor := FItemColor;
  AChild.FItemNumberColor := FItemNumberColor;
  AChild.FExitColor := FExitColor;
  AChild.FErrorColor := FErrorColor;
  AChild.FPromptColor := FPromptColor;
  AChild.FSeparatorColor := FSeparatorColor;
  AChild.FPromptText := FPromptText;
  AChild.FPause := FPause;
  AChild.FMaxRows := FMaxRows;
  AChild.FColumnGap := FColumnGap;
end;

function TConsoleMenu.Title(const ATitle: string): TConsoleMenu;
begin
  FTitle := ATitle;
  Result := Self;
end;

function TConsoleMenu.ExitLabel(const ALabel: string): TConsoleMenu;
begin
  FExitLabel := ALabel;
  Result := Self;
end;

function TConsoleMenu.PromptText(const AText: string): TConsoleMenu;
begin
  FPromptText := AText;
  Result := Self;
end;

function TConsoleMenu.TitleColor(const AColor: string): TConsoleMenu;
begin
  FTitleColor := AColor;
  Result := Self;
end;

function TConsoleMenu.ItemColor(const AColor: string): TConsoleMenu;
begin
  FItemColor := AColor;
  Result := Self;
end;

function TConsoleMenu.ItemNumberColor(const AColor: string): TConsoleMenu;
begin
  FItemNumberColor := AColor;
  Result := Self;
end;

function TConsoleMenu.ExitColor(const AColor: string): TConsoleMenu;
begin
  FExitColor := AColor;
  Result := Self;
end;

function TConsoleMenu.ErrorColor(const AColor: string): TConsoleMenu;
begin
  FErrorColor := AColor;
  Result := Self;
end;

function TConsoleMenu.PromptColor(const AColor: string): TConsoleMenu;
begin
  FPromptColor := AColor;
  Result := Self;
end;

function TConsoleMenu.SeparatorColor(const AColor: string): TConsoleMenu;
begin
  FSeparatorColor := AColor;
  Result := Self;
end;

function TConsoleMenu.MaxRows(const AValue: Integer): TConsoleMenu;
begin
  FMaxRows := AValue;
  Result := Self;
end;

function TConsoleMenu.ColumnGap(const AValue: Integer): TConsoleMenu;
begin
  FColumnGap := AValue;
  Result := Self;
end;

function TConsoleMenu.Add(const AItemName: string;
  const ACallback: TMenuCallback): TConsoleMenu;
var
  LItem: TMenuItem;
begin
  LItem.ItemName := AItemName;
  LItem.Callback := ACallback;
  LItem.SubMenu  := nil;
  LItem.Kind     := TMenuItemKind.Action;
  FItems.Add(LItem);
  Result := Self;
end;

function TConsoleMenu.AddSeparator(): TConsoleMenu;
var
  LItem: TMenuItem;
begin
  LItem.ItemName := '';
  LItem.Callback := nil;
  LItem.SubMenu  := nil;
  LItem.Kind     := TMenuItemKind.Separator;
  FItems.Add(LItem);
  Result := Self;
end;

function TConsoleMenu.AddSubmenu(const ATitle: string): TConsoleMenu;
var
  LItem:  TMenuItem;
  LChild: TConsoleMenu;
begin
  LChild := TConsoleMenu.Create();
  LChild.FIsRoot := False;
  LChild.FTitle := ATitle;
  LChild.FExitLabel := 'Return';
  PropagateColors(LChild);
  FChildren.Add(LChild);

  LItem.ItemName := ATitle;
  LItem.Callback := nil;
  LItem.SubMenu  := LChild;
  LItem.Kind     := TMenuItemKind.Submenu;
  FItems.Add(LItem);

  Result := LChild;
end;

{ TConsoleMenu.AddTestCase }

function TConsoleMenu.AddTestCase(const ATestClass: TTestCaseClass): TConsoleMenu;

  // Nested helpers to safely capture values for closures
  function MakeRunAll(const AClass: TTestCaseClass): TMenuCallback;
  begin
    Result := procedure
    begin
      TTestCase.Run(AClass);
    end;
  end;

  function MakeRunOne(const AClass: TTestCaseClass;
    const AName: string): TMenuCallback;
  begin
    Result := procedure
    begin
      TTestCase.RunTest(AClass, AName);
    end;
  end;

var
  LTemp: TTestCase;
  LNames: TArray<string>;
  LI: Integer;
  LSub: TConsoleMenu;
begin
  // Create a temp instance to read registered test names and title
  LTemp := ATestClass.Create();
  try
    LNames := LTemp.GetTestNames();
    LSub := AddSubmenu(LTemp.Title);

    // First item: Run All
    LSub.Add('Run All', MakeRunAll(ATestClass));
    LSub.AddSeparator();

    // Individual tests
    for LI := 0 to High(LNames) do
      LSub.Add(LNames[LI], MakeRunOne(ATestClass, LNames[LI]));
  finally
    LTemp.Free();
  end;

  Result := Self;
end;

{ TConsoleMenu.AddTestDemo }

function TConsoleMenu.AddTestDemo(const ADemoClass: TTestDemoClass): TConsoleMenu;

  function MakeRunner(const AClass: TTestDemoClass): TMenuCallback;
  begin
    Result := procedure
    begin
      TTestDemo.Run(AClass);
    end;
  end;

var
  LTemp: TTestDemo;
  LTitle: string;
begin
  // Create a temp instance to read its title
  LTemp := ADemoClass.Create();
  try
    LTitle := LTemp.Title;
  finally
    LTemp.Free();
  end;

  Add(LTitle, MakeRunner(ADemoClass));
  Result := Self;
end;

procedure TConsoleMenu.Clear();
begin
  FItems.Clear();
  FChildren.Clear();
end;

function TConsoleMenu.ActionCount(): Integer;
var
  LI: Integer;
begin
  Result := 0;
  for LI := 0 to FItems.Count - 1 do
  begin
    if FItems[LI].Kind <> TMenuItemKind.Separator then
      Inc(Result);
  end;
end;

procedure TConsoleMenu.Run();
var
  LInput:          string;
  LChoice:         Integer;
  LI:              Integer;
  LRow:            Integer;
  LCol:            Integer;
  LIdx:            Integer;
  LNumber:         Integer;
  LRowCount:       Integer;
  LNumCols:        Integer;
  LDisplayCount:   Integer;
  LMaxRowsEff:     Integer;
  LHasContent:     Boolean;
  LActionMap:      TList<Integer>;
  LDisplayNumbers: TArray<Integer>;
  LItem:           TMenuItem;
  LColWidths:      TArray<Integer>;
  LLine:           string;
  LPadded:         string;
begin
  LActionMap := TList<Integer>.Create();
  try
    // Guard: MaxRows must be at least 1.
    LMaxRowsEff := FMaxRows;
    if LMaxRowsEff < 1 then
      LMaxRowsEff := 20;

    while True do
    begin
      // Build action map and display numbers.
      // Display list = all FItems (including separators).
      // Actions get sequential numbers; separators get 0.
      LActionMap.Clear();
      LDisplayCount := FItems.Count;
      SetLength(LDisplayNumbers, LDisplayCount);
      LNumber := 0;
      for LI := 0 to FItems.Count - 1 do
      begin
        if FItems[LI].Kind = TMenuItemKind.Separator then
          LDisplayNumbers[LI] := 0
        else
        begin
          Inc(LNumber);
          LDisplayNumbers[LI] := LNumber;
          LActionMap.Add(LI);
        end;
      end;

      // Calculate column layout (separators count as rows).
      if LDisplayCount > LMaxRowsEff then
        LNumCols := (LDisplayCount + LMaxRowsEff - 1) div LMaxRowsEff
      else
        LNumCols := 1;

      if LDisplayCount <= LMaxRowsEff then
        LRowCount := LDisplayCount
      else
        LRowCount := LMaxRowsEff;

      // Pass 1: max item name width per column (separators contribute 0).
      SetLength(LColWidths, LNumCols);
      for LCol := 0 to LNumCols - 1 do
      begin
        LColWidths[LCol] := 0;
        for LRow := 0 to LRowCount - 1 do
        begin
          LIdx := LCol * LMaxRowsEff + LRow;
          if LIdx >= LDisplayCount then
            Break;
          if FItems[LIdx].Kind <> TMenuItemKind.Separator then
          begin
            if FItems[LIdx].ItemName.Length > LColWidths[LCol] then
              LColWidths[LCol] := FItems[LIdx].ItemName.Length;
          end;
        end;
      end;

      // Clear screen.
      TConsole.ClearScreen();

      // Title.
      TConsole.PrintLn('');
      TConsole.PrintLn(FTitleColor + '  [ ' + FTitle + ' ]');
      TConsole.PrintLn('');

      // Pass 2: display row by row, column by column.
      for LRow := 0 to LRowCount - 1 do
      begin
        LLine := '  ';
        LHasContent := False;
        for LCol := 0 to LNumCols - 1 do
        begin
          LIdx := LCol * LMaxRowsEff + LRow;
          if LIdx >= LDisplayCount then
            Break;
          LHasContent := True;
          if FItems[LIdx].Kind = TMenuItemKind.Separator then
          begin
            // Blank space matching [NNN] (6 chars) + column name width.
            LLine := LLine + StringOfChar(' ', 6 + LColWidths[LCol]);
          end
          else
          begin
            LPadded := FItems[LIdx].ItemName;
            while LPadded.Length < LColWidths[LCol] do
              LPadded := LPadded + ' ';
            LLine := LLine + FItemNumberColor +
              Format('[%.3d] ', [LDisplayNumbers[LIdx]]) + FItemColor + LPadded;
          end;
          if LCol < LNumCols - 1 then
            LLine := LLine + StringOfChar(' ', FColumnGap);
        end;
        if LHasContent then
          TConsole.PrintLn(LLine);
      end;

      // Exit/return option.
      TConsole.PrintLn('');
      TConsole.PrintLn('  ' + FItemNumberColor + '[000] ' +
        FExitColor + '%s', [FExitLabel]);
      TConsole.PrintLn('');

      // Prompt.
      TConsole.Print(FPromptColor + '  ' + FPromptText);
      ReadLn(LInput);

      LChoice := StrToIntDef(LInput.Trim(), -1);

      // Exit/Return.
      if LChoice = 0 then
        Break;

      // Execute action or enter submenu.
      if (LChoice >= 1) and (LChoice <= LActionMap.Count) then
      begin
        LItem := FItems[LActionMap[LChoice - 1]];

        if LItem.Kind = TMenuItemKind.Submenu then
        begin
          if LItem.SubMenu <> nil then
            LItem.SubMenu.Run();
        end
        else if Assigned(LItem.Callback) then
        begin
          TConsole.ClearScreen();
          LItem.Callback();
          if FPause then
            TConsole.Pause();
        end;
      end
      else
        TConsole.PrintLn(FErrorColor + '  Invalid choice.');
    end;
  finally
    LActionMap.Free();
  end;
end;

end.
