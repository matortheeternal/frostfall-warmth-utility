unit frostfallWarmthPatcher;

uses 'lib\mxpf', 'lib\roslib';

const
  armorLocationAccessory = 0;
  armorLocationBase = 1;
  accessoryWarmthKeywords = 
    'None'#13
    'FrostfallIgnore'#13
    'FrostfallIsCloakCloth'#13
    'FrostfallIsCloakLeather'#13
    'FrostfallIsCloakFur'#13
    'FrostfallIsWeatherproofAccessory'#13
    'FrostfallIsWarmAccessory'#13
    'FrostfallExtraCloakCloth'#13
    'FrostfallExtraCloakLeather'#13
    'FrostfallExtraCloakFur';
  baseWarmthKeywords = 
    'None'#13
    'FrostfallIgnore'#13
    'FrostfallWarmthPoor'#13
    'FrostfallWarmthFair'#13
    'FrostfallWarmthGood'#13
    'FrostfallWarmthExcellent'#13
    'FrostfallWarmthMax'#13
    'FrostfallCoveragePoor'#13
    'FrostfallCoverageFair'#13
    'FrostfallCoverageGood'#13
    'FrostfallCoverageExcellent'#13
    'FrostfallCoverageMax'#13
    'FrostfallExtraHeadCloth'#13
    'FrostfallExtraHeadWeatherproof'#13
    'FrostfallExtraHeadWarm';
  VersionString = '0.4';
  separator = '----------------------------------------';

var
  ScriptTerminated: Boolean;
  slWarmth, slFrostfallKeywords: TStringList;


{==============================================================================}
{ HELPER FUNCTIONS }

{ Helper function: Returns the armor location of an armor based on flags }
function GetArmorLocation(rec: IInterface): Integer;
begin
  if IsBaseArmor(rec) then
    Result := armorLocationBase
  else
    Result := armorLocationAccessory;
end;

{ Helper function: Returns a label for an armor location }
function GetArmorLocationLabel(armorLocation: Integer): String;
begin
  if armorLocation = armorLocationBase then
    Result := 'Base'
  else
    Result := 'Accessory';
end;

{ Helper function: Returns the warmth keywords usable for a given armor 
  location }
function GetWarmthKeywords(armorLocation: Integer): String;
begin
  if armorLocation = armorLocationBase then
    Result := baseWarmthKeywords
  else
    Result := accessoryWarmthKeywords;
end;

{ Helper function: Returns true for records which should never be patched }
function SkipRecord(rec: IInterface): Boolean;
var
  bIsUnplayable, bHasTemplate, bIsShield, bIsJewelry, bHasNoName: Boolean;
begin
  // TODO MORE CONDITIONS HERE?
  bIsUnplayable := GetARMOIsUnplayable(rec);
  bHasTemplate := ElementExists(rec, 'TNAM');
  bIsShield := HasKeyword(rec, 'ArmorShield');
  bIsJewelry := HasKeyword(rec, 'ArmorJewelry');
  bHasNoName := not ElementExists(rec, 'FULL');
  Result := bIsUnplayable or bHasTemplate or bIsShield or bIsJewelry or bHasNoName;
end;

{ Helper function: Creates a frostfall keyword in the patch file }
procedure CreateFrostfallKeyword(edid, formID: String);
var
  rec: IInterface;
begin
  rec := NewRecord(mxPatchFile, 'KYWD');
  Add(rec, 'EDID', true);
  seev(rec, 'EDID', edid);
  SetLoadOrderFormID(rec, StrToInt('$' + formID));
end;

{ Helper function: Creates frostfall keywords in the patch file }
procedure CreateFrostfallKeywords;
var
  i: Integer;
  edid, formId: String;
begin
  AddMessage(#13#10'Creating frostfall keywords');
  AddMasterIfMissing(mxPatchFile, 'Skyrim.esm');
  AddMasterIfMissing(mxPatchFile, 'Update.esm');
  for i := 0 to Pred(slFrostfallKeywords.Count) do begin
    edid := slFrostfallKeywords.Names[i];
    formId := slFrostfallKeywords.ValueFromIndex[i];
    AddMessage(Format('  %s [%s]', [edid, formId]));
    CreateFrostfallKeyword(edid, formId);
  end;
end;

{ Helper function: Resolves a frostfall keyword record from an EditorID }
function ResolveFrostfallKeyword(keywordEdid: String): IInterface;
var
  keywordFormID: Cardinal;
begin
  keywordFormID := StrToInt('$' + slFrostfallKeywords.Values[keywordEdid]);
  Result := RecordByFormID(mxPatchFile, keywordFormID, true);
end;

procedure ApplyingKeywordsMessage(rec: IInterface);
var
  full: String;
begin
  full := geev(rec, 'FULL');
  AddMessage(Format('  Applying keywords to %s', [full]));
end;

procedure AddingKeywordMessage(rec: IInterface);
var
  edid: String;
begin
  edid := EditorID(rec);
  AddMessage(Format('  + %s', [edid]));
end;

{ Helper function: Applies a frostfall keyword to a record }
procedure ApplyKeyword(rec: IInterface; keywordEdid: String);
var
  keywordRecord: IInterface;
begin
  if keywordEdid = 'None' then exit;
  keywordRecord := ResolveFrostfallKeyword(keywordEdid);
  AddingKeywordMessage(keywordRecord);
  AddKeyword(rec, keywordRecord);
end;

{ Helper function: Adds a list of keywords to a record }
procedure ApplyKeywords(rec: IInterface; keywords: TStringList);
var
  i: Integer;
begin
  ApplyingKeywordsMessage(rec);
  ApplyKeyword(rec, 'FrostfallEnableKeywordProtection');
  for i := 0 to Pred(keywords.Count) do
    ApplyKeyword(rec, keywords[i]);
end;

{ Loads GUI specified keywords for an input record and applies them to the
  record by calling ApplyKeywords }
procedure LoadAndApplyKeywords(rec: IInterface);
var
  RecordKeywords: TStringList;
  edid: String;
begin
  RecordKeywords := TStringList.Create;
  try
    edid := EditorID(rec);
    RecordKeywords.CommaText := slWarmth.Values[edid];
    ApplyKeywords(rec, RecordKeywords);
  finally
    RecordKeywords.Free;
  end;
end;


{==============================================================================}
{ GUI CODE }
  
function CreateEntryPanel(f: TForm; sb: TScrollBox; rec: IInterface): TPanel;
const
  labelFormat = '%s'#13#10'(%s)';
var
  armorLocation, warmth1, warmth2, warmth3: Integer;
  edid, full, recordLabel, armorLocationLabel, warmthItems: String;
  pnl: TPanel;
  lbl1, lbl2: TLabel;
  cb1, cb2, cb3: TComboBox;
begin
  // helper variables
  edid := EditorID(rec);
  full := geev(rec, 'FULL');
  armorLocation := GetArmorLocation(rec);
  warmthItems := GetWarmthKeywords(armorLocation);
  // TODO: Get default warmth keywords
  warmth1 := 0;
  warmth2 := 0;
  warmth3 := 0;
  
  // build label captions
  recordLabel := Format(labelFormat, [full, edid]);
  armorLocationLabel := GetArmorLocationLabel(armorLocation);
  // TODO: Display armor material type?

  // create components
  pnl := QuickPanel(f, sb, 60, alTop);
  lbl1 := QuickLabel(f, pnl, 16, 16, 230, recordLabel);
  lbl2 := QuickLabel(f, pnl, 16, 290, 40, armorLocationLabel);
  cb1 := QuickComboBox(f, pnl, 20, 360, 160, warmthItems, warmth1);
  cb2 := QuickComboBox(f, pnl, 20, 537, 160, warmthItems, warmth2);
  cb3 := QuickComboBox(f, pnl, 20, 709, 160, warmthItems, warmth3);
  
  Result := pnl;
end;

function CreateContentScrollBox(form: TForm): TScrollBox;
var
  sb: TScrollBox;
begin
  sb := TScrollBox.Create(form);
  sb.Parent := form;
  sb.Align := alClient;
  Result := sb;
end;

procedure GenerateEntryList(form: TForm; entryList: TList);
var
  i: Integer;
  rec, cnam: IInterface;
  scrollbox: TScrollBox;
  panel: TPanel;
begin
  AddMessage('Generating armor entries');
  scrollbox := CreateContentScrollBox(form);
  for i := 0 to MaxRecordIndex do begin
    rec := GetRecord(i);
    panel := CreateEntryPanel(form, scrollbox, rec);
    entryList.Add(panel);
  end;
end;

procedure LoadEntry(panel: TPanel);
var
  edid, warmth1, warmth2, warmth3: String;
begin
  edid := GetTextIn(TLabel(panel.Controls[0]).Caption, '(', ')');
  warmth1 := TComboBox(panel.Controls[2]).Caption;
  warmth2 := TComboBox(panel.Controls[3]).Caption;
  warmth3 := TComboBox(panel.Controls[4]).Caption;
  slWarmth.Values[edid] := warmth1 + ',' + warmth2 + ',' + warmth3;
end;

procedure LoadEntryList(form: TForm; entryList: TList);
var
  i: Integer;
  panel: TPanel;
begin
  AddMessage('GUI displayed, waiting for user input');
  if form.ShowModal = mrOk then begin
    AddMessage('Loading GUI selection');
    for i := 0 to Pred(entryList.Count) do begin
      panel := TPanel(entryList[i]);
      LoadEntry(panel);
    end;
  end
  else
    ScriptTerminated := true;
end;

procedure DisplayGUI;
var
  form: TForm;
  entryList: TList;
begin
  form := TForm.Create(nil);
  entryList := TList.Create;
  try
    SetFormAttributes(form, 'Frostfall Armor Patcher', 910, 600);
    CreateStickyPanel(form, 60, true);
    GenerateEntryList(form, entryList);
    LoadEntryList(form, entryList);
  finally
    form.Free;
    entryList.Free;
  end;
end;


{==============================================================================}

{ Entry point for the script }
function Initialize: Integer;
const
  NoRecordsMessage = 'No records to patch.';
  FileSelectPrompt = 'Select the file you want to patch for Frostfall';
var
  i: Integer;
  edid: String;
  rec: IInterface;
begin
  // get file selection from user
  AddMessage('Frostfall Warmth Utility ' + VersionString);
  AddMessage(separator + #13#10);
  AddMessage('Getting file selection from user');
  mxPatchFile := FileSelect(FileSelectPrompt);

  // initialization
  DefaultOptionsMXPF;
  InitializeMXPF;
  mxSkipPatchedRecords := false;
  AddMessage('Loading resources');
  slWarmth := TStringList.Create;
  slFrostfallKeywords := TStringList.Create;
  slFrostfallKeywords.LoadFromFile(ScriptsPath + 'assets\Frostfall\keywords.txt');
  
  // prepare for patching
  SetInclusions(GetFileName(mxPatchFile));
  AddMessage('Loading armor records');
  LoadRecords('ARMO');
  
  // remove armors that should always be skipped - unplayable armors
  // and armors that use a template
  for i := MaxRecordIndex downto 0 do begin
    rec := GetRecord(i);
    // remove the record 
    if SkipRecord(rec) then
      RemoveRecord(i);
  end;
    
  // skip if no records copied
  if MaxRecordIndex = -1 then begin
    ShowMessage(NoRecordsMessage);
    exit;
  end;
  
  // display user interface
  AddMessage(#13#10'Building GUI');
  DisplayGUI;
  if ScriptTerminated then exit;
  
  // remove armors that have no warmth keywords set
  AddMessage('Removing armors with no warmth keywords');
  for i := MaxRecordIndex downto 0 do begin
    rec := GetRecord(i);
    edid := EditorID(rec);
    if slWarmth.Values[edid] = 'None,None,None' then
      RemoveRecord(i);
  end;
  
  // exit if there are no records to patch
  if MaxRecordIndex = -1 then begin
    ShowMessage(NoRecordsMessage);
    exit;
  end;
  
  // patch the armors
  CreateFrostfallKeywords;
  AddMessage('Applying keywords to records');
  for i := 0 to MaxRecordIndex do begin
    rec := GetRecord(i);
    LoadAndApplyKeywords(rec);
  end;
  
  // clean up
  AddMessage(#13#10'All done!');
  FinalizeMXPF;
end;

end.
