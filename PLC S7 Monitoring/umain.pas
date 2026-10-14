unit umain;

{ Siemens S7 online monitor built on PascalSCADA (TTCP_UDPPort + TISOTCPDriver).
  All PascalSCADA objects are created at runtime so tags can be added, removed,
  saved and loaded from the tag panel without touching the form designer. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, IniFiles, TypInfo, fgl, Forms, Controls, Graphics, Dialogs,
  StdCtrls, ExtCtrls, ComCtrls, Grids, Spin, Menus,
  tcp_udpport, socket_types, isotcpdriver, s7types, tag, plctag, plcnumber,
  plctagnumber, tagbit, uchart, uabout;

type
  TS7Area = (saI, saQ, saM, saDB);
  TS7DataType = (sdBool, sdByte, sdInt, sdWord, sdDInt, sdDWord, sdReal, sdLReal);

  { One monitored variable. For sdBool, BaseTag reads the containing byte and
    BitTag extracts the bit. }
  TMonTag = class
  public
    Name: string;
    Area: TS7Area;
    DBNumber: Integer;
    ByteAddr: Integer;
    BitAddr: Integer;
    DataType: TS7DataType;
    BaseTag: TPLCTagNumber;
    BitTag: TTagBit;
    destructor Destroy; override;
    function Address: string;
    function NumberTag: TPLCNumber;
  end;

  TMonTagList = specialize TFPGObjectList<TMonTag>;

  { ISO-TCP driver that does not busy-wait. With ReadSomethingAlways off the
    stock scan loop only yields the thread when no tag is due, which spins a
    CPU core; sleep briefly instead. }
  TMonS7Driver = class(TISOTCPDriver)
  protected
    procedure DoScanRead(Sender: TObject; var NeedSleep: LongInt); override;
  end;

  { TfrmMain }

  TfrmMain = class(TForm)
    btnAddTag: TButton;
    btnClearTags: TButton;
    btnConnect: TButton;
    btnDisconnect: TButton;
    btnRemoveTag: TButton;
    btnToggle: TButton;
    btnWrite: TButton;
    btnClearLog: TButton;
    cbArea: TComboBox;
    cbCPU: TComboBox;
    cbType: TComboBox;
    chkAutoReconnect: TCheckBox;
    dlgOpen: TOpenDialog;
    dlgSave: TSaveDialog;
    edtBit: TSpinEdit;
    edtByte: TSpinEdit;
    edtDB: TSpinEdit;
    edtIP: TEdit;
    edtPort: TSpinEdit;
    edtRack: TSpinEdit;
    edtScan: TSpinEdit;
    edtSlot: TSpinEdit;
    edtTagName: TEdit;
    edtTimeout: TSpinEdit;
    edtWriteValue: TEdit;
    gbNetwork: TGroupBox;
    gbTagEdit: TGroupBox;
    gbTags: TGroupBox;
    gbStats: TGroupBox;
    lblArea: TLabel;
    lblBit: TLabel;
    lblByte: TLabel;
    lblCPU: TLabel;
    lblDB: TLabel;
    lblIP: TLabel;
    lblPort: TLabel;
    lblRack: TLabel;
    lblScan: TLabel;
    lblSlot: TLabel;
    lblStatus: TLabel;
    lblStats: TLabel;
    lblTagName: TLabel;
    lblTimeout: TLabel;
    lblType: TLabel;
    lblWrite: TLabel;
    memLog: TMemo;
    miAbout: TMenuItem;
    miAddToChart: TMenuItem;
    miHelp: TMenuItem;
    miChart: TMenuItem;
    miClearChart: TMenuItem;
    miConnect: TMenuItem;
    miDisconnect: TMenuItem;
    miExit: TMenuItem;
    miExportChart: TMenuItem;
    miNetwork: TMenuItem;
    miSepNetwork: TMenuItem;
    miShowNetPanel: TMenuItem;
    miFile: TMenuItem;
    miOpen: TMenuItem;
    miSave: TMenuItem;
    miSaveAs: TMenuItem;
    miSepChart: TMenuItem;
    miSepFile: TMenuItem;
    miShowChart: TMenuItem;
    mnuMain: TMainMenu;
    pnlLeft: TPanel;
    pnlLogHeader: TPanel;
    pnlLog: TPanel;
    pnlMain: TPanel;
    shpStatus: TShape;
    splLeft: TSplitter;
    splLog: TSplitter;
    sbMain: TStatusBar;
    sgTags: TStringGrid;
    tmrRefresh: TTimer;
    procedure btnAddTagClick(Sender: TObject);
    procedure btnClearLogClick(Sender: TObject);
    procedure btnClearTagsClick(Sender: TObject);
    procedure btnConnectClick(Sender: TObject);
    procedure btnDisconnectClick(Sender: TObject);
    procedure btnRemoveTagClick(Sender: TObject);
    procedure btnToggleClick(Sender: TObject);
    procedure btnWriteClick(Sender: TObject);
    procedure cbAreaChange(Sender: TObject);
    procedure cbCPUChange(Sender: TObject);
    procedure cbTypeChange(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure miAboutClick(Sender: TObject);
    procedure miAddToChartClick(Sender: TObject);
    procedure miClearChartClick(Sender: TObject);
    procedure miExitClick(Sender: TObject);
    procedure miExportChartClick(Sender: TObject);
    procedure miShowNetPanelClick(Sender: TObject);
    procedure miOpenClick(Sender: TObject);
    procedure miSaveAsClick(Sender: TObject);
    procedure miSaveClick(Sender: TObject);
    procedure miShowChartClick(Sender: TObject);
    procedure sgTagsMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure sgTagsMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure sgTagsSelection(Sender: TObject; aCol, aRow: Integer);
    procedure tmrRefreshTimer(Sender: TObject);
  private
    FPort: TTCP_UDPPort;
    FDriver: TMonS7Driver;
    FTags: TMonTagList;
    FConnecting: Boolean;
    FIsOpen: Boolean;       // last reported port state, to log transitions only once
    // communication statistics (PascalSCADA does not update its per-second counters)
    FStatTick: QWord;
    FStatTX, FStatRX, FStatReads: Int64;
    FTXRate, FRXRate, FReadRate: Int64;
    FChart: TfrmChart;
    FFileName: string;      // current configuration file
    FSavedState: string;    // configuration as last loaded/saved, to detect changes
    FDragRow: Integer;
    FDragStart: TPoint;
    function ChartQueryDrop(Source: TObject; out AName: string;
      out AValueTag: TPLCNumber; out AStatusTag: TPLCTag;
      out AIsBool: Boolean): Boolean;
    function AddTagToChart(mt: TMonTag): Boolean;
    procedure WriteConfig(ini: TCustomIniFile);
    procedure ReadConfig(ini: TCustomIniFile);
    function ConfigState: string;
    procedure SetFileName(const AFile: string);
    function SaveTo(const AFile: string): Boolean;
    function SaveAs: Boolean;
    procedure Log(const Msg: string);
    procedure PortOpened(Sender: TObject);
    procedure PortClosed(Sender: TObject);
    procedure PortOpenError(Sender: TObject);
    procedure PortDisconnected(Sender: TObject);
    procedure ApplyNetworkConfig;
    procedure UpdateStatistics;
    procedure UpdateEditorState;
    procedure SetStatus(AColor: TColor; const AText: string);
    function CreateMonTag(const AName: string; AArea: TS7Area; ADB, AByte,
      ABit: Integer; AType: TS7DataType): TMonTag;
    procedure RebuildGrid;
    procedure RefreshValues;
    function SelectedTag: TMonTag;
    procedure ClearTags;
    procedure SaveConfig(const AFile: string);
    procedure LoadConfig(const AFile: string);
    function DefaultConfigFile: string;
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.lfm}

const
  COL_NAME = 0;
  COL_ADDR = 1;
  COL_TYPE = 2;
  COL_VALUE = 3;
  COL_STATUS = 4;
  COL_READS = 5;
  COL_ERRORS = 6;
  COL_TIME = 7;

  // MemReadFunction / MemWriteFunction codes of TSiemensProtocolFamily
  AreaCode: array[TS7Area] of Integer = (1, 2, 3, 4);
  AreaName: array[TS7Area] of string = ('I', 'Q', 'M', 'DB');

  TypeName: array[TS7DataType] of string =
    ('Bool', 'Byte', 'Int', 'Word', 'DInt', 'DWord', 'Real', 'LReal');
  TypeTagType: array[TS7DataType] of TTagType =
    (pttByte, pttByte, pttSmallInt, pttWord, pttLongInt, pttDWord, pttFloat, pttDouble);
  TypeSize: array[TS7DataType] of Integer = (1, 1, 2, 2, 4, 4, 4, 8);

  // Rack / slot of the CPU for the presets in cbCPU (last item = custom)
  CPURack: array[0..4] of Integer = (0, 0, 0, 0, 0);
  CPUSlot: array[0..4] of Integer = (2, 3, 1, 1, 0);

var
  DotFormat: TFormatSettings;

function AreaPrefix(AArea: TS7Area; AType: TS7DataType): string;
const
  SizeLetter: array[TS7DataType] of string = ('', 'B', 'W', 'W', 'D', 'D', 'D', 'D');
begin
  if AArea = saDB then
    Result := 'DBX'
  else
    Result := AreaName[AArea];
  if AType <> sdBool then
  begin
    if AArea = saDB then
      Result := 'DB' + SizeLetter[AType]
    else
      Result := Result + SizeLetter[AType];
  end;
end;

{ TMonS7Driver }

procedure TMonS7Driver.DoScanRead(Sender: TObject; var NeedSleep: LongInt);
begin
  inherited DoScanRead(Sender, NeedSleep);
  if NeedSleep < 0 then
    NeedSleep := 5; // ms; small compared to any scan rate
end;

{ TMonTag }

destructor TMonTag.Destroy;
begin
  // The bit tag references the base tag, so it must go first
  FreeAndNil(BitTag);
  FreeAndNil(BaseTag);
  inherited Destroy;
end;

function TMonTag.Address: string;
begin
  Result := AreaPrefix(Area, DataType) + IntToStr(ByteAddr);
  if DataType = sdBool then
    Result := Result + '.' + IntToStr(BitAddr);
  if DataType = sdLReal then
    Result := Result + ' (8 bytes)';
  if Area = saDB then
    Result := 'DB' + IntToStr(DBNumber) + '.' + Result;
end;

function TMonTag.NumberTag: TPLCNumber;
begin
  if Assigned(BitTag) then
    Result := BitTag
  else
    Result := BaseTag;
end;

{ TfrmMain }

procedure TfrmMain.FormCreate(Sender: TObject);
var
  t: TS7DataType;
begin
  FTags := TMonTagList.Create(True);

  FPort := TTCP_UDPPort.Create(nil);
  FPort.PortType := ptTCP;
  FPort.Port := 102;
  FPort.OnCommPortOpened := @PortOpened;
  FPort.OnCommPortClosed := @PortClosed;
  FPort.OnCommPortOpenError := @PortOpenError;
  FPort.OnCommPortDisconnected := @PortDisconnected;

  FDriver := TMonS7Driver.Create(nil);
  FDriver.ConnectionWay := ISOTCP;
  FDriver.CommunicationPort := FPort;
  // The S7 driver defaults to polling continuously; honour each tag's scan rate instead
  FDriver.ReadSomethingAlways := False;

  cbType.Items.Clear;
  for t := Low(TS7DataType) to High(TS7DataType) do
    cbType.Items.Add(TypeName[t]);
  cbType.ItemIndex := Ord(sdInt);

  sgTags.Cells[COL_NAME, 0] := 'Tag name';
  sgTags.Cells[COL_ADDR, 0] := 'Address';
  sgTags.Cells[COL_TYPE, 0] := 'Type';
  sgTags.Cells[COL_VALUE, 0] := 'Value';
  sgTags.Cells[COL_STATUS, 0] := 'Status';
  sgTags.Cells[COL_READS, 0] := 'Reads OK';
  sgTags.Cells[COL_ERRORS, 0] := 'Read errors';
  sgTags.Cells[COL_TIME, 0] := 'Last update';
  sgTags.ColWidths[COL_NAME] := 140;
  sgTags.ColWidths[COL_ADDR] := 130;
  sgTags.ColWidths[COL_TYPE] := 60;
  sgTags.ColWidths[COL_VALUE] := 130;
  sgTags.ColWidths[COL_STATUS] := 110;
  sgTags.ColWidths[COL_READS] := 80;
  sgTags.ColWidths[COL_ERRORS] := 80;
  sgTags.ColWidths[COL_TIME] := 100;
  sgTags.DragCursor := crDrag;
  FDragRow := -1;

  FChart := TfrmChart.Create(nil);
  FChart.OnQueryDrop := @ChartQueryDrop;

  SetFileName(DefaultConfigFile);
  if FileExists(FFileName) then
    LoadConfig(FFileName)
  else
    FSavedState := ConfigState;

  SetStatus(clGray, 'Disconnected');
  UpdateEditorState;
  Log('Ready. Configure the PLC network and press Connect.');
end;

procedure TfrmMain.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if ConfigState = FSavedState then
    Exit;
  case MessageDlg('Save changes to ' + ExtractFileName(FFileName) + '?',
    mtConfirmation, [mbYes, mbNo, mbCancel], 0) of
    mrYes: CanClose := SaveTo(FFileName);
    mrNo: CanClose := True;
  else
    CanClose := False;
  end;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  tmrRefresh.Enabled := False;
  // The chart references the tags, so it goes first
  FreeAndNil(FChart);
  if Assigned(FPort) then
  begin
    FPort.OnCommPortOpened := nil;
    FPort.OnCommPortClosed := nil;
    FPort.OnCommPortOpenError := nil;
    FPort.OnCommPortDisconnected := nil;
    FPort.Active := False;
  end;
  // Tags first, then the driver, then the port
  FreeAndNil(FTags);
  FreeAndNil(FDriver);
  FreeAndNil(FPort);
end;

{ ---------- logging / status ---------- }

procedure TfrmMain.Log(const Msg: string);
begin
  memLog.Lines.Add(FormatDateTime('hh:nn:ss.zzz', Now) + '  ' + Msg);
  while memLog.Lines.Count > 1000 do
    memLog.Lines.Delete(0);
  memLog.SelStart := Length(memLog.Text);
end;

procedure TfrmMain.SetStatus(AColor: TColor; const AText: string);
begin
  shpStatus.Brush.Color := AColor;
  lblStatus.Caption := AText;
  sbMain.Panels[0].Text := AText;
end;

procedure TfrmMain.PortOpened(Sender: TObject);
begin
  FConnecting := False;
  SetStatus(clLime, 'Connected to ' + FPort.Host);
  if not FIsOpen then
    Log(Format('Connected to %s:%d (rack %d, slot %d)',
      [FPort.Host, FPort.Port, FDriver.PLCRack, FDriver.PLCSlot]));
  FIsOpen := True;
end;

procedure TfrmMain.PortClosed(Sender: TObject);
begin
  FConnecting := False;
  SetStatus(clGray, 'Disconnected');
  if FIsOpen then
    Log('Connection closed.');
  FIsOpen := False;
end;

procedure TfrmMain.PortOpenError(Sender: TObject);
begin
  SetStatus(clRed, 'Connection error');
  Log(Format('Cannot connect to %s:%d - %s',
    [FPort.Host, FPort.Port, FPort.LastOSErrorMessage]));
end;

procedure TfrmMain.PortDisconnected(Sender: TObject);
begin
  if FPort.EnableAutoReconnect then
    SetStatus(clYellow, 'Connection lost - reconnecting...')
  else
    SetStatus(clRed, 'Connection lost');
  if FIsOpen then
    Log('Connection to PLC lost.');
  FIsOpen := False;
end;

{ ---------- network panel ---------- }

procedure TfrmMain.cbCPUChange(Sender: TObject);
var
  custom: Boolean;
begin
  custom := cbCPU.ItemIndex = cbCPU.Items.Count - 1;
  if (cbCPU.ItemIndex >= 0) and not custom then
  begin
    edtRack.Value := CPURack[cbCPU.ItemIndex];
    edtSlot.Value := CPUSlot[cbCPU.ItemIndex];
  end;
  UpdateEditorState;
end;

procedure TfrmMain.ApplyNetworkConfig;
var
  mt: TMonTag;
begin
  FPort.Host := Trim(edtIP.Text);
  FPort.Port := edtPort.Value;
  FPort.Timeout := edtTimeout.Value;
  FPort.EnableAutoReconnect := chkAutoReconnect.Checked;
  FPort.ReconnectRetryInterval := 5000;
  FDriver.PLCRack := edtRack.Value;
  FDriver.PLCSlot := edtSlot.Value;
  for mt in FTags do
    mt.BaseTag.RefreshTime := edtScan.Value;
end;

procedure TfrmMain.btnConnectClick(Sender: TObject);
begin
  if Trim(edtIP.Text) = '' then
  begin
    MessageDlg('Enter the PLC IP address.', mtWarning, [mbOK], 0);
    edtIP.SetFocus;
    Exit;
  end;
  if FPort.Active then
    FPort.Active := False;
  FStatTick := 0; // restart the per-second statistics
  ApplyNetworkConfig;
  Log(Format('Connecting to %s:%d ...', [FPort.Host, FPort.Port]));
  SetStatus(clYellow, 'Connecting...');
  FConnecting := True;
  FPort.Active := True;
  UpdateEditorState;
  tmrRefresh.Enabled := True;
end;

procedure TfrmMain.btnDisconnectClick(Sender: TObject);
begin
  FPort.Active := False;
  FConnecting := False;
  FChart.Online := False;
  SetStatus(clGray, 'Disconnected');
  UpdateEditorState;
  RefreshValues;
end;

procedure TfrmMain.UpdateEditorState;
var
  isOn, custom: Boolean;
begin
  if FPort = nil then
    Exit; // events fired while the form is still streaming
  isOn := FPort.Active;
  btnConnect.Enabled := not isOn;
  btnDisconnect.Enabled := isOn;
  miConnect.Enabled := not isOn;
  miDisconnect.Enabled := isOn;
  edtIP.Enabled := not isOn;
  edtPort.Enabled := not isOn;
  cbCPU.Enabled := not isOn;
  custom := cbCPU.ItemIndex = cbCPU.Items.Count - 1;
  edtRack.Enabled := custom and not isOn;
  edtSlot.Enabled := custom and not isOn;
  edtTimeout.Enabled := not isOn;
  chkAutoReconnect.Enabled := not isOn;
  miOpen.Enabled := not isOn;
  miAddToChart.Enabled := Assigned(SelectedTag);
  edtDB.Enabled := cbArea.ItemIndex = Ord(saDB);
  edtBit.Enabled := cbType.ItemIndex = Ord(sdBool);
  btnToggle.Enabled := Assigned(SelectedTag) and (SelectedTag.DataType = sdBool);
end;

{ ---------- tag panel ---------- }

function TfrmMain.CreateMonTag(const AName: string; AArea: TS7Area; ADB, AByte,
  ABit: Integer; AType: TS7DataType): TMonTag;
var
  wide: Boolean;
begin
  Result := TMonTag.Create;
  Result.Name := AName;
  Result.Area := AArea;
  Result.DBNumber := ADB;
  Result.ByteAddr := AByte;
  Result.BitAddr := ABit;
  Result.DataType := AType;

  Result.BaseTag := TPLCTagNumber.Create(nil);
  with Result.BaseTag do
  begin
    // Configure everything before attaching the driver, so the tag is
    // registered with its final address.
    MemReadFunction := AreaCode[AArea];
    MemWriteFunction := AreaCode[AArea];
    if AArea = saDB then
      MemFile_DB := ADB
    else
      MemFile_DB := 0;
    MemAddress := AByte;
    TagType := TypeTagType[AType];
    // S7 is big endian
    wide := TypeSize[AType] > 1;
    SwapBytes := wide;
    SwapWords := TypeSize[AType] >= 4;
    SwapDWords := TypeSize[AType] >= 8;
    RefreshTime := edtScan.Value;
    AutoRead := True;
    AutoWrite := True;
    ProtocolDriver := FDriver;
  end;

  if AType = sdBool then
  begin
    Result.BitTag := TTagBit.Create(nil);
    Result.BitTag.PLCTag := Result.BaseTag;
    Result.BitTag.StartBit := ABit;
    Result.BitTag.EndBit := ABit;
  end;
end;

procedure TfrmMain.btnAddTagClick(Sender: TObject);
var
  nm: string;
  mt: TMonTag;
begin
  nm := Trim(edtTagName.Text);
  if nm = '' then
    nm := 'Tag' + IntToStr(FTags.Count + 1);
  for mt in FTags do
    if SameText(mt.Name, nm) then
    begin
      MessageDlg(Format('A tag named "%s" already exists.', [nm]), mtWarning, [mbOK], 0);
      Exit;
    end;

  mt := CreateMonTag(nm, TS7Area(cbArea.ItemIndex), edtDB.Value,
    edtByte.Value, edtBit.Value, TS7DataType(cbType.ItemIndex));
  FTags.Add(mt);
  Log(Format('Tag added: %s = %s (%s)', [mt.Name, mt.Address, TypeName[mt.DataType]]));
  RebuildGrid;
  sgTags.Row := sgTags.RowCount - 1;
  edtTagName.Text := '';
end;

procedure TfrmMain.btnRemoveTagClick(Sender: TObject);
var
  mt: TMonTag;
begin
  mt := SelectedTag;
  if mt = nil then
    Exit;
  Log('Tag removed: ' + mt.Name);
  FChart.RemoveTag(mt.NumberTag);
  FTags.Remove(mt); // owned list frees the tag
  RebuildGrid;
  UpdateEditorState;
end;

procedure TfrmMain.btnClearTagsClick(Sender: TObject);
begin
  if FTags.Count = 0 then
    Exit;
  if MessageDlg('Remove all tags?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;
  ClearTags;
  Log('All tags removed.');
end;

procedure TfrmMain.ClearTags;
begin
  FChart.ClearSeries;
  FTags.Clear;
  RebuildGrid;
  UpdateEditorState;
end;

procedure TfrmMain.cbAreaChange(Sender: TObject);
begin
  UpdateEditorState;
end;

procedure TfrmMain.cbTypeChange(Sender: TObject);
begin
  UpdateEditorState;
end;

function TfrmMain.SelectedTag: TMonTag;
var
  idx: Integer;
begin
  Result := nil;
  if FTags = nil then
    Exit;
  idx := sgTags.Row - sgTags.FixedRows;
  if (idx >= 0) and (idx < FTags.Count) then
    Result := FTags[idx];
end;

procedure TfrmMain.sgTagsSelection(Sender: TObject; aCol, aRow: Integer);
var
  mt: TMonTag;
begin
  mt := SelectedTag;
  if mt <> nil then
  begin
    edtTagName.Text := mt.Name;
    cbArea.ItemIndex := Ord(mt.Area);
    edtDB.Value := mt.DBNumber;
    edtByte.Value := mt.ByteAddr;
    edtBit.Value := mt.BitAddr;
    cbType.ItemIndex := Ord(mt.DataType);
    lblWrite.Caption := 'Write to ' + mt.Name + ':';
  end;
  UpdateEditorState;
end;

procedure TfrmMain.RebuildGrid;
var
  i: Integer;
begin
  sgTags.RowCount := sgTags.FixedRows + FTags.Count;
  for i := 0 to FTags.Count - 1 do
  begin
    sgTags.Cells[COL_NAME, i + 1] := FTags[i].Name;
    sgTags.Cells[COL_ADDR, i + 1] := FTags[i].Address;
    sgTags.Cells[COL_TYPE, i + 1] := TypeName[FTags[i].DataType];
  end;
  RefreshValues;
  sbMain.Panels[1].Text := Format('%d tag(s)', [FTags.Count]);
end;

function FormatTagValue(mt: TMonTag; v: Double): string;
begin
  case mt.DataType of
    sdBool:
      if v <> 0 then Result := 'TRUE' else Result := 'FALSE';
    sdReal:
      Result := FloatToStrF(v, ffGeneral, 7, 0, DotFormat);
    sdLReal:
      Result := FloatToStrF(v, ffGeneral, 15, 0, DotFormat);
  else
    Result := FormatFloat('0', v, DotFormat);
  end;
end;

function IOResultText(r: TProtocolIOResult): string;
begin
  Result := GetEnumName(TypeInfo(TProtocolIOResult), Ord(r));
  if Copy(Result, 1, 2) = 'io' then
    Delete(Result, 1, 2);
end;

procedure TfrmMain.RefreshValues;
var
  i, r: Integer;
  mt: TMonTag;
  st: TProtocolIOResult;
begin
  for i := 0 to FTags.Count - 1 do
  begin
    mt := FTags[i];
    r := i + 1;
    st := mt.BaseTag.LastASyncReadStatus;
    if FPort.Active and (st = ioOk) then
      sgTags.Cells[COL_VALUE, r] := FormatTagValue(mt, mt.NumberTag.Value)
    else if not FPort.Active then
      sgTags.Cells[COL_VALUE, r] := '---'
    else if sgTags.Cells[COL_VALUE, r] = '' then
      sgTags.Cells[COL_VALUE, r] := '???';

    if not FPort.Active then
      sgTags.Cells[COL_STATUS, r] := 'Offline'
    else
      sgTags.Cells[COL_STATUS, r] := IOResultText(st);
    sgTags.Cells[COL_READS, r] := IntToStr(mt.BaseTag.CommReadsOK);
    sgTags.Cells[COL_ERRORS, r] := IntToStr(mt.BaseTag.CommReadErrors);
    if mt.BaseTag.ValueTimestamp > 0 then
      sgTags.Cells[COL_TIME, r] := FormatDateTime('hh:nn:ss.zzz', mt.BaseTag.ValueTimestamp)
    else
      sgTags.Cells[COL_TIME, r] := '';
  end;
end;

procedure TfrmMain.tmrRefreshTimer(Sender: TObject);
begin
  FChart.Online := FPort.Active;
  RefreshValues;
  if FPort.Active then
  begin
    UpdateStatistics;
    lblStats.Caption := Format(
      'Tag reads/s: %d' + LineEnding +
      'TX: %d bytes (%d B/s)' + LineEnding +
      'RX: %d bytes (%d B/s)',
      [FReadRate, FPort.TXBytes, FTXRate, FPort.RXBytes, FRXRate]);
  end
  else
    lblStats.Caption := 'Not connected';
end;

procedure TfrmMain.UpdateStatistics;
var
  now_: QWord;
  reads: Int64;
  mt: TMonTag;
  dt: Double;
begin
  now_ := GetTickCount64;
  reads := 0;
  for mt in FTags do
    reads := reads + mt.BaseTag.CommReadsOK;
  if FStatTick = 0 then
  begin
    FStatTick := now_;
    FStatTX := FPort.TXBytes;
    FStatRX := FPort.RXBytes;
    FStatReads := reads;
    Exit;
  end;
  if now_ - FStatTick < 1000 then
    Exit;
  dt := (now_ - FStatTick) / 1000;
  FTXRate := Round((FPort.TXBytes - FStatTX) / dt);
  FRXRate := Round((FPort.RXBytes - FStatRX) / dt);
  FReadRate := Round((reads - FStatReads) / dt);
  FStatTick := now_;
  FStatTX := FPort.TXBytes;
  FStatRX := FPort.RXBytes;
  FStatReads := reads;
end;

{ ---------- writing ---------- }

procedure TfrmMain.btnWriteClick(Sender: TObject);
var
  mt: TMonTag;
  s: string;
  v: Double;
begin
  mt := SelectedTag;
  if mt = nil then
  begin
    MessageDlg('Select a tag in the list first.', mtInformation, [mbOK], 0);
    Exit;
  end;
  if not FPort.Active then
  begin
    MessageDlg('Not connected to the PLC.', mtWarning, [mbOK], 0);
    Exit;
  end;

  s := Trim(edtWriteValue.Text);
  if SameText(s, 'TRUE') or SameText(s, 'ON') then
    v := 1
  else if SameText(s, 'FALSE') or SameText(s, 'OFF') then
    v := 0
  else if not TryStrToFloat(StringReplace(s, ',', '.', []), v, DotFormat) then
  begin
    MessageDlg(Format('"%s" is not a valid number.', [s]), mtError, [mbOK], 0);
    Exit;
  end;
  if mt.DataType = sdBool then
    if v <> 0 then v := 1;

  try
    mt.NumberTag.Value := v; // AutoWrite sends it to the PLC
    Log(Format('Write %s (%s) := %s', [mt.Name, mt.Address, FormatTagValue(mt, v)]));
  except
    on E: Exception do
      Log('Write failed on ' + mt.Name + ': ' + E.Message);
  end;
end;

procedure TfrmMain.btnToggleClick(Sender: TObject);
var
  mt: TMonTag;
begin
  mt := SelectedTag;
  if (mt = nil) or (mt.DataType <> sdBool) then
    Exit;
  if mt.NumberTag.Value <> 0 then
    edtWriteValue.Text := '0'
  else
    edtWriteValue.Text := '1';
  btnWriteClick(Sender);
end;

procedure TfrmMain.btnClearLogClick(Sender: TObject);
begin
  memLog.Clear;
end;

{ ---------- chart / drag & drop ---------- }

procedure TfrmMain.sgTagsMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  c, r: Integer;
begin
  FDragRow := -1;
  if Button <> mbLeft then
    Exit;
  sgTags.MouseToCell(X, Y, c, r);
  if (r >= sgTags.FixedRows) and (r < sgTags.RowCount) then
  begin
    FDragRow := r;
    FDragStart := Point(X, Y);
  end;
end;

procedure TfrmMain.sgTagsMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
begin
  // Start dragging a tag once the mouse has moved a few pixels with the
  // left button held down
  if (ssLeft in Shift) and (FDragRow >= sgTags.FixedRows) and not sgTags.Dragging
    and ((Abs(X - FDragStart.X) > 5) or (Abs(Y - FDragStart.Y) > 5)) then
  begin
    sgTags.Row := FDragRow;
    if not FChart.Visible then
      FChart.Show;
    sgTags.BeginDrag(True);
  end;
end;

function TfrmMain.ChartQueryDrop(Source: TObject; out AName: string;
  out AValueTag: TPLCNumber; out AStatusTag: TPLCTag;
  out AIsBool: Boolean): Boolean;
var
  idx: Integer;
  mt: TMonTag;
begin
  AName := '';
  AValueTag := nil;
  AStatusTag := nil;
  AIsBool := False;
  Result := False;
  if Source <> sgTags then
    Exit;
  idx := FDragRow - sgTags.FixedRows;
  if (idx < 0) or (idx >= FTags.Count) then
    Exit;
  mt := FTags[idx];
  AName := mt.Name;
  AValueTag := mt.NumberTag;
  AStatusTag := mt.BaseTag;
  AIsBool := mt.DataType = sdBool;
  Result := True;
end;

function TfrmMain.AddTagToChart(mt: TMonTag): Boolean;
begin
  Result := FChart.AddTag(mt.Name, mt.NumberTag, mt.BaseTag, mt.DataType = sdBool);
  if Result then
    Log('Tag added to chart: ' + mt.Name);
end;

procedure TfrmMain.miShowChartClick(Sender: TObject);
begin
  FChart.Show;
  FChart.BringToFront;
end;

procedure TfrmMain.miAddToChartClick(Sender: TObject);
var
  mt: TMonTag;
begin
  mt := SelectedTag;
  if mt = nil then
    Exit;
  if not AddTagToChart(mt) then
    Log(mt.Name + ' is already on the chart.');
  miShowChartClick(Sender);
end;

procedure TfrmMain.miClearChartClick(Sender: TObject);
begin
  FChart.ClearData;
end;

procedure TfrmMain.miExportChartClick(Sender: TObject);
begin
  FChart.ExportWithDialog;
end;

procedure TfrmMain.miShowNetPanelClick(Sender: TObject);
begin
  miShowNetPanel.Checked := not miShowNetPanel.Checked;
  pnlLeft.Visible := miShowNetPanel.Checked;
  splLeft.Visible := miShowNetPanel.Checked;
  if splLeft.Visible then
    splLeft.Left := pnlLeft.Left + pnlLeft.Width; // keep splitter right of the panel
end;

{ ---------- configuration file ---------- }

function TfrmMain.DefaultConfigFile: string;
begin
  Result := ChangeFileExt(Application.ExeName, '.ini');
end;

procedure TfrmMain.SetFileName(const AFile: string);
begin
  FFileName := AFile;
  Caption := 'Siemens S7 PLC Online Monitor - ' + ExtractFileName(AFile);
end;

procedure TfrmMain.WriteConfig(ini: TCustomIniFile);
var
  i: Integer;
  sec: string;
  sl: TStringList;
begin
  // drop stale tag sections
  sl := TStringList.Create;
  try
    ini.ReadSections(sl);
    for i := 0 to sl.Count - 1 do
      if Pos('Tag_', sl[i]) = 1 then
        ini.EraseSection(sl[i]);
  finally
    sl.Free;
  end;
  ini.EraseSection('Chart');

  ini.WriteString('Network', 'IP', edtIP.Text);
  ini.WriteInteger('Network', 'Port', edtPort.Value);
  ini.WriteInteger('Network', 'CPU', cbCPU.ItemIndex);
  ini.WriteInteger('Network', 'Rack', edtRack.Value);
  ini.WriteInteger('Network', 'Slot', edtSlot.Value);
  ini.WriteInteger('Network', 'Timeout', edtTimeout.Value);
  ini.WriteInteger('Network', 'ScanRate', edtScan.Value);
  ini.WriteBool('Network', 'AutoReconnect', chkAutoReconnect.Checked);

  ini.WriteInteger('Tags', 'Count', FTags.Count);
  for i := 0 to FTags.Count - 1 do
  begin
    sec := Format('Tag_%d', [i]);
    ini.WriteString(sec, 'Name', FTags[i].Name);
    ini.WriteString(sec, 'Area', AreaName[FTags[i].Area]);
    ini.WriteInteger(sec, 'DB', FTags[i].DBNumber);
    ini.WriteInteger(sec, 'Byte', FTags[i].ByteAddr);
    ini.WriteInteger(sec, 'Bit', FTags[i].BitAddr);
    ini.WriteString(sec, 'Type', TypeName[FTags[i].DataType]);
  end;

  FChart.SaveSettings(ini);
end;

procedure TfrmMain.ReadConfig(ini: TCustomIniFile);
var
  i, n: Integer;
  sec, s: string;
  a, aa: TS7Area;
  t, tt: TS7DataType;
  mt: TMonTag;
begin
  edtIP.Text := ini.ReadString('Network', 'IP', edtIP.Text);
  edtPort.Value := ini.ReadInteger('Network', 'Port', edtPort.Value);
  cbCPU.ItemIndex := ini.ReadInteger('Network', 'CPU', cbCPU.ItemIndex);
  edtRack.Value := ini.ReadInteger('Network', 'Rack', edtRack.Value);
  edtSlot.Value := ini.ReadInteger('Network', 'Slot', edtSlot.Value);
  edtTimeout.Value := ini.ReadInteger('Network', 'Timeout', edtTimeout.Value);
  edtScan.Value := ini.ReadInteger('Network', 'ScanRate', edtScan.Value);
  chkAutoReconnect.Checked := ini.ReadBool('Network', 'AutoReconnect', chkAutoReconnect.Checked);

  FChart.ClearSeries;
  FTags.Clear;
  n := ini.ReadInteger('Tags', 'Count', 0);
  for i := 0 to n - 1 do
  begin
    sec := Format('Tag_%d', [i]);
    if not ini.SectionExists(sec) then
      Continue;
    a := saDB;
    s := ini.ReadString(sec, 'Area', 'DB');
    for aa := Low(TS7Area) to High(TS7Area) do
      if SameText(AreaName[aa], s) then a := aa;
    t := sdInt;
    s := ini.ReadString(sec, 'Type', 'Int');
    for tt := Low(TS7DataType) to High(TS7DataType) do
      if SameText(TypeName[tt], s) then t := tt;
    FTags.Add(CreateMonTag(ini.ReadString(sec, 'Name', 'Tag' + IntToStr(i + 1)), a,
      ini.ReadInteger(sec, 'DB', 1), ini.ReadInteger(sec, 'Byte', 0),
      ini.ReadInteger(sec, 'Bit', 0) and 7, t));
  end;

  n := ini.ReadInteger('Chart', 'Count', 0);
  for i := 0 to n - 1 do
  begin
    s := ini.ReadString('Chart', 'Tag' + IntToStr(i), '');
    for mt in FTags do
      if SameText(mt.Name, s) then
        FChart.AddTag(mt.Name, mt.NumberTag, mt.BaseTag, mt.DataType = sdBool);
  end;
  // general chart settings and per-series styles
  FChart.LoadSettings(ini);
end;

function TfrmMain.ConfigState: string;
var
  ini: TMemIniFile;
  sl: TStringList;
begin
  ini := TMemIniFile.Create('');
  sl := TStringList.Create;
  try
    WriteConfig(ini);
    ini.GetStrings(sl);
    Result := sl.Text;
  finally
    sl.Free;
    ini.Free;
  end;
end;

procedure TfrmMain.SaveConfig(const AFile: string);
var
  ini: TIniFile;
begin
  ini := TIniFile.Create(AFile);
  try
    WriteConfig(ini);
  finally
    ini.Free;
  end;
end;

procedure TfrmMain.LoadConfig(const AFile: string);
var
  ini: TIniFile;
begin
  ini := TIniFile.Create(AFile);
  try
    ReadConfig(ini);
  finally
    ini.Free;
  end;
  RebuildGrid;
  UpdateEditorState;
  SetFileName(AFile);
  FSavedState := ConfigState;
  Log(Format('Configuration loaded from %s (%d tags).', [ExtractFileName(AFile), FTags.Count]));
end;

function TfrmMain.SaveTo(const AFile: string): Boolean;
begin
  Result := False;
  try
    SaveConfig(AFile);
  except
    on E: Exception do
    begin
      MessageDlg('Could not save configuration: ' + E.Message, mtError, [mbOK], 0);
      Exit;
    end;
  end;
  SetFileName(AFile);
  FSavedState := ConfigState;
  Log('Configuration saved to ' + AFile);
  Result := True;
end;

function TfrmMain.SaveAs: Boolean;
begin
  dlgSave.InitialDir := ExtractFilePath(FFileName);
  dlgSave.FileName := ExtractFileName(FFileName);
  Result := dlgSave.Execute and SaveTo(dlgSave.FileName);
end;

procedure TfrmMain.miOpenClick(Sender: TObject);
begin
  if ConfigState <> FSavedState then
    case MessageDlg('Save changes to ' + ExtractFileName(FFileName) + '?',
      mtConfirmation, [mbYes, mbNo, mbCancel], 0) of
      mrYes: if not SaveTo(FFileName) then Exit;
      mrNo: ;
    else
      Exit;
    end;
  dlgOpen.InitialDir := ExtractFilePath(FFileName);
  if dlgOpen.Execute then
    LoadConfig(dlgOpen.FileName);
end;

procedure TfrmMain.miSaveClick(Sender: TObject);
begin
  SaveTo(FFileName);
end;

procedure TfrmMain.miSaveAsClick(Sender: TObject);
begin
  SaveAs;
end;

procedure TfrmMain.miAboutClick(Sender: TObject);
begin
  ShowAboutDialog;
end;

procedure TfrmMain.miExitClick(Sender: TObject);
begin
  Close;
end;

initialization
  DotFormat := DefaultFormatSettings;
  DotFormat.DecimalSeparator := '.';
  DotFormat.ThousandSeparator := #0;

end.
