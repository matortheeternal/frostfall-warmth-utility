{
  This is a temporary library with lots of functions that will need to
  be incorporated into mteFunctions soon.
}

unit roslib;

procedure SetFormAttributes(f: TForm; c: String; w, h: Integer);
begin
  f.Caption := c;
  f.Width := w;
  f.Height := h;
  f.Position := poScreenCenter;
  f.BorderStyle := bsDialog;
end;

function CreateStickyPanel(f: TForm; h: Integer; b: Boolean): TPanel;
var
  pnl: TPanel;
  btnOk, btnCancel: TButton;
begin
  pnl := TPanel.Create(f);
  pnl.Parent := f;
  pnl.BevelOuter := bvNone;
  pnl.Align := alBottom;
  pnl.Height := h;
  
  if b then begin
    btnOk := TButton.Create(f);
    btnOk.Parent := pnl;
    btnOk.Caption := 'OK';
    btnOk.ModalResult := mrOk;
    btnOk.Left := f.Width div 2 - 80;
    btnOk.Top := h - 40;
    
    btnCancel := TButton.Create(f);
    btnCancel.Parent := pnl;
    btnCancel.Caption := 'Cancel';
    btnCancel.ModalResult := mrCancel;
    btnCancel.Left := btnOk.Left + btnOk.Width + 16;
    btnCancel.Top := h - 40;
  end;
  
  Result := pnl;
end;

function QuickLabel(f, p: TComponent; t, l, w: Integer; c: String): TLabel;
var
  lbl: TLabel;
begin
  lbl := TLabel.Create(f);
  lbl.Parent := p;
  lbl.Top := t;
  lbl.Left := l;
  lbl.Width := w;
  lbl.Caption := c;
  
  Result := lbl;
end;

function QuickComboBox(f, p: TComponent; t, l, w: Integer; it: String; 
  n: Integer): TComboBox;
var
  cb: TComboBox;
begin
  cb := TComboBox.Create(f);
  cb.Parent := p;
  cb.Left := l;
  cb.Top := t;
  cb.Width := w;
  cb.Items.Text := it;
  cb.ItemIndex := n;
  cb.Style := csDropDownList;
  
  Result := cb;
end;

function QuickPanel(f, p: TComponent; h: Integer; a: TAlign): TPanel;
var
  pnl: TPanel;
begin
  pnl := TPanel.Create(f);
  pnl.Parent := p;
  pnl.Height := h;
  pnl.Align := a;
  
  Result := pnl;
end;

function FileLoadOrderFormID(f: IInterface; formID: Cardinal): Cardinal;
begin
  Result := GetLoadOrder(f) * $01000000 + formID;
end;

function LocalRecordByFormID(f: IInterface; formID: Cardinal): IInterface;
begin
  Result := RecordByFormID(f, GetLoadOrder(f) * $01000000 + formID, false);
end;

procedure ReplaceStringValue(rec: IInterface; path, key, value: String);
var
  oldValue, newValue: String;
begin
  oldValue := geev(rec, path);
  newValue := StringReplace(oldValue, key, value, [rfReplaceAll]);
  seev(rec, path, newValue);
end;

function GetGroup(f: IInterface; sig: string): IInterface;
begin
  Result := GroupBySignature(f, sig);
  if not Assigned(Result) then Result := Add(f, sig, true);
end;

procedure LoadRecordEditorIDs(group: IInterface; var sl: TStringList; objectMap: Boolean);
var
  i: Integer;
  rec: IInterface;
begin
  for i := 0 to Pred(ElementCount(group)) do begin
    rec := ElementByIndex(group, i);
    if objectMap then 
      sl.AddObject(EditorID(rec), TObject(rec))
    else
      sl.Add(EditorID(rec));
  end;
end;

procedure BuildRecordMap(sig: String; var sl: TStringList);
var
  group: IInterface;
begin
  group := GroupBySignature(mxPatchFile, sig);
  LoadRecordEditorIDs(group, sl, true);
end;

function GetMapRecord(var sl: TStringList; edid: String): IInterface;
var
  i: Integer;
begin
  i := sl.IndexOf(edid);
  if i > -1 then
    Result := ObjectToElement(sl.Objects[i]);
end;

procedure SetObjectBounds(rec: IInterface; x1, y1, z1, x2, y2, z2: Integer);
begin
  SetElementNativeValues(rec, 'X1', x1);
  SetElementNativeValues(rec, 'Y1', y1);
  SetElementNativeValues(rec, 'Z1', z1);
  SetElementNativeValues(rec, 'X2', x2);
  SetElementNativeValues(rec, 'Y2', y2);
  SetElementNativeValues(rec, 'Z2', z2);
end;

function GetScript(rec: IInterface; index: Integer): IInterface;
var
  scripts: IInterface;
begin
  scripts := ElementByPath(rec, 'VMAD\Data\Scripts');
  Result := ElementByIndex(scripts, index);
end;

function GetScriptProperty(script: IInterface; index: Integer): IInterface;
var
  scriptProperties: IInterface;
begin
  scriptProperties := ElementByPath(script, 'Properties');
  Result := ElementByIndex(scriptProperties, index);
end;

procedure SetScriptObjectPropertyValue(script: IInterface; index: Integer; 
  reference: IInterface);
var
  prop: IInterface;
  value: Cardinal;
begin
  prop := GetScriptProperty(script, index);
  value := GetLoadOrderFormID(reference);
  SetElementNativeValues(prop, 'Value\Object Union\Object v2\FormID', value);
end;

procedure SetScriptStringPropertyValue(script: IInterface; index: Integer; 
  value: String);
var
  prop: IInterface;
begin
  prop := GetScriptProperty(script, index);
  SetElementNativeValues(prop, 'Value', value);
end;

function NewArrayElement(rec: IInterface; path: String): IInterface;
var
  a: IInterface;
begin
  a := ElementByPath(rec, path);
  if Assigned(a) then begin
    Result := ElementAssign(a, HighInteger, nil, false);
  end
  else begin 
    a := Add(rec, path, true);
    Result := ElementByIndex(a, 0);
  end;
end;

function AddKeyword(rec, keyword: IInterface): IInterface;
begin
  Result := NewArrayElement(rec, 'KWDA - Keywords');
  SetNativeValue(Result, GetLoadOrderFormID(keyword));
end;

procedure AddLeveledListEntry(rec: IInterface; level: Integer; 
  reference: IInterface; count: Integer);
var
  entry: IInterface;
begin
  entry := NewArrayElement(rec, 'Leveled List Entries');
  SetElementNativeValues(entry, 'LVLO\Level', level);
  SetElementNativeValues(entry, 'LVLO\Reference', GetLoadOrderFormID(reference));
  SetElementNativeValues(entry, 'LVLO\Count', count);
end;

{ Returns true if the flag at the given index on the given element is set }  
function GetFlag(element: IInterface; index: Integer): boolean;
var
  mask: Integer;
begin
  mask := 1 shl index;
  Result := (GetNativeValue(element) and mask) > 0;
end;

{ Used to raise "element not found" exceptions }
procedure ElementNotFoundError(FunctionName, Target: String; rec: IInterface);
const
  ElementNotFound = '%s: %s element not found on %s';
begin
  raise Exception.Create(Format(ElementNotFound, 
    [FunctionName, Target, Name(rec)]));
end;

{ Returns the BODT or BOD2 element for an ARMO record }
function GetBodt(rec: IInterface): IInterface;
const
  FunctionName = 'GetBodt';
  Target = 'BODT and BOD2';
begin
  if ElementExists(rec, 'BODT') then
    Result := ElementByPath(rec, 'BODT')
  else
    Result := ElementByPath(rec, 'BOD2');
  if not Assigned(Result) then 
    ElementNotFoundError(FunctionName, Target, rec);
end;

{ Returns the First Person Flags element for an ARMO record }
function GetFirstPersonFlags(rec: IInterface): IInterface;
const
  FunctionName = 'GetFirstPersonFlags';
  Target = 'First Person Flags';
begin
  Result := ElementByPath(GetBodt(rec), Target);
  if not Assigned(Result) then 
    ElementNotFoundError(FunctionName, Target, rec);
end;

{ Returns the General Flags element for an ARMO record }
function GetGeneralFlags(rec: IInterface): IInterface;
const
  FunctionName = 'GetGeneralFlags';
  Target = 'General Flags';
begin
  Result := ElementByPath(GetBodt(rec), 'General Flags');
  if not Assigned(Result) then 
    ElementNotFoundError(FunctionName, Target, rec);
end;

{ Returns true if the armor is marked as not playable in its BODT 
  General Flags }
function GetARMOIsUnplayable(rec: IInterface): Boolean;
begin
  Result := GetFlag(GetGeneralFlags(rec), 4);
end;

{ Returns true if the armor has the head, body, hands, or feet First 
  Person Flags }
function IsBaseArmor(rec: IInterface): Boolean;
var
  firstPersonFlags: IInterface;
  bIsHelmet, bIsCuriass, bIsGauntlets, bIsBoots: Boolean;
begin
  firstPersonFlags := GetFirstPersonFlags(rec);
  bIsHelmet := GetFlag(firstPersonFlags, 1);
  bIsCuriass := GetFlag(firstPersonFlags, 2);
  bIsGauntlets := GetFlag(firstPersonFlags, 3);
  bIsBoots := GetFlag(firstPersonFlags, 7);
  Result := bIsHelmet or bIsCuriass or bIsGauntlets or bIsBoots;
end;

{ Creates and returns a new record with the given signature in the given file }
function NewRecord(f: IInterface; sig: String): IInterface;
var
  group: IInterface;
begin
  group := GetGroup(f, 'KYWD');
  Result := Add(group, 'KYWD', true);
end;

end.