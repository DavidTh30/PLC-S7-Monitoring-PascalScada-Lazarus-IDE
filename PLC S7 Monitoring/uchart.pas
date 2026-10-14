unit uchart;

{ Trend chart window. Tags are attached by dragging rows from the main form's
  tag grid onto the chart or onto the series list. The main form answers
  OnQueryDrop to translate the drag source into a tag.
  The settings panel (General / Axes / Series) configures the chart; all
  settings are persisted through SaveSettings / LoadSettings. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, IniFiles, fgl, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, ComCtrls, CheckLst, Spin, TAGraph, TASeries, TAIntervalSources,
  TAChartUtils, TALegend, TATypes,
  tag, plctag, plcnumber;

type
  TChartTagQuery = function(Source: TObject; out AName: string;
    out AValueTag: TPLCNumber; out AStatusTag: TPLCTag;
    out AIsBool: Boolean): Boolean of object;

  TChartEntry = class
  public
    Name: string;
    ValueTag: TPLCNumber;
    StatusTag: TPLCTag;
    Series: TLineSeries;
  end;

  TChartEntryList = specialize TFPGObjectList<TChartEntry>;

  { TfrmChart }

  TfrmChart = class(TForm)
    btnClear: TButton;
    btnExport: TButton;
    btnPause: TButton;
    btnRemove: TButton;
    btnSettings: TButton;
    cbLegendPos: TComboBox;
    cbLineStyle: TComboBox;
    cbTimeFormat: TComboBox;
    cbtnBack: TColorButton;
    cbtnGrid: TColorButton;
    cbtnPlot: TColorButton;
    cbtnSeries: TColorButton;
    chkOnTop: TCheckBox;
    chkPoints: TCheckBox;
    chkShowGrid: TCheckBox;
    chkShowLegend: TCheckBox;
    chkShowTitle: TCheckBox;
    chkStep: TCheckBox;
    chkYAuto: TCheckBox;
    chMain: TChart;
    clbSeries: TCheckListBox;
    dlgExport: TSaveDialog;
    edtSample: TSpinEdit;
    edtTitle: TEdit;
    edtWindow: TSpinEdit;
    edtXTitle: TEdit;
    edtYTitle: TEdit;
    fseYMax: TFloatSpinEdit;
    fseYMin: TFloatSpinEdit;
    lblBack: TLabel;
    lblDropHint: TLabel;
    lblGridColor: TLabel;
    lblLegendPos: TLabel;
    lblPlot: TLabel;
    lblSample: TLabel;
    lblSColor: TLabel;
    lblSeriesHint: TLabel;
    lblSeriesName: TLabel;
    lblSStyle: TLabel;
    lblSWidth: TLabel;
    lblTimeFormat: TLabel;
    lblWindow: TLabel;
    lblXTitle: TLabel;
    lblYMax: TLabel;
    lblYMin: TLabel;
    lblYTitle: TLabel;
    pcSettings: TPageControl;
    pnlSettings: TPanel;
    pnlSide: TPanel;
    pnlTop: TPanel;
    seWidth: TSpinEdit;
    splSettings: TSplitter;
    splSide: TSplitter;
    tmrSample: TTimer;
    tsAxes: TTabSheet;
    tsGeneral: TTabSheet;
    tsSeries: TTabSheet;
    procedure btnClearClick(Sender: TObject);
    procedure btnExportClick(Sender: TObject);
    procedure btnPauseClick(Sender: TObject);
    procedure btnRemoveClick(Sender: TObject);
    procedure btnSettingsClick(Sender: TObject);
    procedure chkOnTopChange(Sender: TObject);
    procedure clbSeriesClickCheck(Sender: TObject);
    procedure clbSeriesSelectionChange(Sender: TObject; User: Boolean);
    procedure ChartSettingChange(Sender: TObject);
    procedure edtSampleChange(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure SeriesSettingChange(Sender: TObject);
    procedure TagDragDrop(Sender, Source: TObject; X, Y: Integer);
    procedure TagDragOver(Sender, Source: TObject; X, Y: Integer;
      State: TDragState; var Accept: Boolean);
    procedure tmrSampleTimer(Sender: TObject);
  private
    FEntries: TChartEntryList;
    FTimeSource: TDateTimeIntervalChartSource;
    FPaused: Boolean;
    FUpdating: Boolean;
    FOnQueryDrop: TChartTagQuery;
    function IndexOfTag(AValueTag: TPLCNumber): Integer;
    function IndexOfName(const AName: string): Integer;
    procedure DeleteEntry(AIndex: Integer);
    procedure UpdateAxisRange;
    procedure ApplyChartSettings;
    procedure ApplySeriesStyle(e: TChartEntry; AColor: TColor; AWidth: Integer;
      AStyle: TPenStyle; AStep, APoints: Boolean);
    procedure LoadSeriesControls;
    procedure SetSettingsVisible(AVisible: Boolean);
    function GetCount: Integer;
    function GetEntryName(AIndex: Integer): string;
  public
    Online: Boolean;
    function AddTag(const AName: string; AValueTag: TPLCNumber;
      AStatusTag: TPLCTag; AIsBool: Boolean): Boolean;
    procedure RemoveTag(AValueTag: TPLCNumber);
    procedure ClearSeries;
    procedure ClearData;
    procedure ExportCSV(const AFile: string);
    procedure ExportWithDialog;
    procedure SaveSettings(ini: TCustomIniFile);
    procedure LoadSettings(ini: TCustomIniFile);
    property Count: Integer read GetCount;
    property EntryName[AIndex: Integer]: string read GetEntryName;
    property OnQueryDrop: TChartTagQuery read FOnQueryDrop write FOnQueryDrop;
  end;

implementation

{$R *.lfm}

const
  SeriesColors: array[0..9] of TColor = (
    $00B4771F, $000E7FFF, $002CA02C, $002827D6, $00BD6794,
    $004B568C, $00C277E3, $007F7F7F, $0022BDBC, $00CFBE17);

  // Order matches cbLegendPos items
  LegendAlign: array[0..3] of TLegendAlignment =
    (laBottomCenter, laTopCenter, laCenterRight, laCenterLeft);

  // Order matches cbLineStyle items
  LineStyles: array[0..3] of TPenStyle = (psSolid, psDash, psDot, psDashDot);

  SEC = 'Chart';

function StyleIndex(AStyle: TPenStyle): Integer;
begin
  for Result := Low(LineStyles) to High(LineStyles) do
    if LineStyles[Result] = AStyle then
      Exit;
  Result := 0;
end;

{ TfrmChart }

procedure TfrmChart.FormCreate(Sender: TObject);
begin
  FEntries := TChartEntryList.Create(True);

  FTimeSource := TDateTimeIntervalChartSource.Create(Self);
  chMain.BottomAxis.Marks.Source := FTimeSource;
  chMain.BottomAxis.Marks.Style := smsLabel;
  chMain.BottomAxis.Title.Visible := True;
  chMain.LeftAxis.Title.Visible := True;
  chMain.LeftAxis.Title.LabelFont.Orientation := 900;

  tmrSample.Interval := edtSample.Value;
  SetSettingsVisible(False);
  pcSettings.ActivePage := tsGeneral;
  ApplyChartSettings;
  LoadSeriesControls;
end;

procedure TfrmChart.FormDestroy(Sender: TObject);
begin
  tmrSample.Enabled := False;
  ClearSeries;
  FreeAndNil(FEntries);
end;

procedure TfrmChart.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  // Keep sampling in the background; the menu re-shows the window
  CloseAction := caHide;
end;

function TfrmChart.GetCount: Integer;
begin
  Result := FEntries.Count;
end;

function TfrmChart.GetEntryName(AIndex: Integer): string;
begin
  Result := FEntries[AIndex].Name;
end;

function TfrmChart.IndexOfTag(AValueTag: TPLCNumber): Integer;
begin
  for Result := 0 to FEntries.Count - 1 do
    if FEntries[Result].ValueTag = AValueTag then
      Exit;
  Result := -1;
end;

function TfrmChart.IndexOfName(const AName: string): Integer;
begin
  for Result := 0 to FEntries.Count - 1 do
    if SameText(FEntries[Result].Name, AName) then
      Exit;
  Result := -1;
end;

function TfrmChart.AddTag(const AName: string; AValueTag: TPLCNumber;
  AStatusTag: TPLCTag; AIsBool: Boolean): Boolean;
var
  e: TChartEntry;
  i: Integer;
begin
  Result := False;
  if (AValueTag = nil) or (IndexOfTag(AValueTag) >= 0) then
    Exit;

  e := TChartEntry.Create;
  e.Name := AName;
  e.ValueTag := AValueTag;
  e.StatusTag := AStatusTag;
  e.Series := TLineSeries.Create(chMain);
  e.Series.Title := AName;
  e.Series.Pointer.Style := psCircle;
  e.Series.Pointer.HorizSize := 3;
  e.Series.Pointer.VertSize := 3;
  ApplySeriesStyle(e, SeriesColors[FEntries.Count mod Length(SeriesColors)], 2,
    psSolid, AIsBool, False);
  chMain.AddSeries(e.Series);
  FEntries.Add(e);

  i := clbSeries.Items.Add(AName);
  clbSeries.Checked[i] := True;
  if clbSeries.ItemIndex < 0 then
    clbSeries.ItemIndex := i;
  LoadSeriesControls;
  tmrSample.Enabled := not FPaused;
  Result := True;
end;

procedure TfrmChart.DeleteEntry(AIndex: Integer);
begin
  FEntries[AIndex].Series.Free; // removes itself from the chart
  FEntries.Delete(AIndex);
  clbSeries.Items.Delete(AIndex);
  LoadSeriesControls;
end;

procedure TfrmChart.RemoveTag(AValueTag: TPLCNumber);
var
  i: Integer;
begin
  i := IndexOfTag(AValueTag);
  if i >= 0 then
    DeleteEntry(i);
end;

procedure TfrmChart.ClearSeries;
begin
  while FEntries.Count > 0 do
    DeleteEntry(FEntries.Count - 1);
end;

procedure TfrmChart.ClearData;
var
  e: TChartEntry;
begin
  for e in FEntries do
    e.Series.Clear;
end;

procedure TfrmChart.UpdateAxisRange;
var
  t: TDateTime;
begin
  t := Now;
  with chMain.BottomAxis.Range do
  begin
    Min := t - edtWindow.Value / SecsPerDay;
    Max := t;
    UseMin := True;
    UseMax := True;
  end;
end;

procedure TfrmChart.tmrSampleTimer(Sender: TObject);
var
  t, oldest: TDateTime;
  e: TChartEntry;
begin
  if FPaused then
    Exit;
  t := Now;
  oldest := t - edtWindow.Value / SecsPerDay;
  for e in FEntries do
  begin
    if Online and (e.StatusTag.LastASyncReadStatus = ioOk) then
      e.Series.AddXY(t, e.ValueTag.Value);
    while (e.Series.Count > 0) and (e.Series.XValue[0] < oldest) do
      e.Series.Delete(0);
  end;
  UpdateAxisRange;
end;

{ ---------- chart settings ---------- }

procedure TfrmChart.ApplyChartSettings;
var
  li: Integer;
begin
  // General
  chMain.Title.Visible := chkShowTitle.Checked;
  chMain.Title.Text.Text := edtTitle.Text;
  chMain.Title.Font.Style := [fsBold];
  chMain.Title.Font.Color := clBlack;
  chMain.Color := cbtnBack.ButtonColor;
  chMain.BackColor := cbtnPlot.ButtonColor;

  chMain.Legend.Visible := chkShowLegend.Checked;
  li := cbLegendPos.ItemIndex;
  if (li < Low(LegendAlign)) or (li > High(LegendAlign)) then
    li := 0;
  chMain.Legend.Alignment := LegendAlign[li];
  if li <= 1 then
    chMain.Legend.ColumnCount := 4
  else
    chMain.Legend.ColumnCount := 1;
  cbLegendPos.Enabled := chkShowLegend.Checked;

  chMain.LeftAxis.Grid.Visible := chkShowGrid.Checked;
  chMain.BottomAxis.Grid.Visible := chkShowGrid.Checked;
  chMain.LeftAxis.Grid.Color := cbtnGrid.ButtonColor;
  chMain.BottomAxis.Grid.Color := cbtnGrid.ButtonColor;
  cbtnGrid.Enabled := chkShowGrid.Checked;

  // Axes
  if Trim(cbTimeFormat.Text) <> '' then
    FTimeSource.DateTimeFormat := cbTimeFormat.Text;
  chMain.BottomAxis.Title.Caption := edtXTitle.Text;
  chMain.BottomAxis.Title.Visible := edtXTitle.Text <> '';
  chMain.LeftAxis.Title.Caption := edtYTitle.Text;
  chMain.LeftAxis.Title.Visible := edtYTitle.Text <> '';

  fseYMin.Enabled := not chkYAuto.Checked;
  fseYMax.Enabled := not chkYAuto.Checked;
  with chMain.LeftAxis.Range do
    if chkYAuto.Checked or (fseYMax.Value <= fseYMin.Value) then
    begin
      UseMin := False;
      UseMax := False;
    end
    else
    begin
      Min := fseYMin.Value;
      Max := fseYMax.Value;
      UseMin := True;
      UseMax := True;
    end;

  UpdateAxisRange;
end;

procedure TfrmChart.ChartSettingChange(Sender: TObject);
begin
  // FTimeSource is nil while the form is still streaming
  if not FUpdating and Assigned(FTimeSource) then
    ApplyChartSettings;
end;

procedure TfrmChart.edtSampleChange(Sender: TObject);
begin
  if Assigned(tmrSample) then
    tmrSample.Interval := edtSample.Value;
end;

procedure TfrmChart.ApplySeriesStyle(e: TChartEntry; AColor: TColor;
  AWidth: Integer; AStyle: TPenStyle; AStep, APoints: Boolean);
begin
  e.Series.SeriesColor := AColor;
  e.Series.LinePen.Width := AWidth;
  e.Series.LinePen.Style := AStyle;
  if AStep then
    e.Series.LineType := ltStepXY
  else
    e.Series.LineType := ltFromPrevious;
  e.Series.ShowPoints := APoints;
  e.Series.Pointer.Brush.Color := AColor;
  e.Series.Pointer.Pen.Color := AColor;
end;

procedure TfrmChart.LoadSeriesControls;
var
  i: Integer;
  e: TChartEntry;
  has: Boolean;
begin
  if FEntries = nil then
    Exit;
  i := clbSeries.ItemIndex;
  has := (i >= 0) and (i < FEntries.Count);
  cbtnSeries.Enabled := has;
  seWidth.Enabled := has;
  cbLineStyle.Enabled := has;
  chkStep.Enabled := has;
  chkPoints.Enabled := has;
  if not has then
  begin
    lblSeriesName.Caption := 'No series selected';
    Exit;
  end;

  e := FEntries[i];
  FUpdating := True;
  try
    lblSeriesName.Caption := e.Name;
    cbtnSeries.ButtonColor := e.Series.SeriesColor;
    seWidth.Value := e.Series.LinePen.Width;
    cbLineStyle.ItemIndex := StyleIndex(e.Series.LinePen.Style);
    chkStep.Checked := e.Series.LineType = ltStepXY;
    chkPoints.Checked := e.Series.ShowPoints;
  finally
    FUpdating := False;
  end;
end;

procedure TfrmChart.SeriesSettingChange(Sender: TObject);
var
  i: Integer;
begin
  if FUpdating or (FEntries = nil) then
    Exit;
  i := clbSeries.ItemIndex;
  if (i < 0) or (i >= FEntries.Count) or (cbLineStyle.ItemIndex < 0) then
    Exit;
  ApplySeriesStyle(FEntries[i], cbtnSeries.ButtonColor, seWidth.Value,
    LineStyles[cbLineStyle.ItemIndex], chkStep.Checked, chkPoints.Checked);
end;

procedure TfrmChart.clbSeriesSelectionChange(Sender: TObject; User: Boolean);
begin
  LoadSeriesControls;
end;

procedure TfrmChart.SetSettingsVisible(AVisible: Boolean);
begin
  pnlSettings.Visible := AVisible;
  splSettings.Visible := AVisible;
  if AVisible then
  begin
    splSettings.Left := pnlSettings.Left - splSettings.Width; // keep it left of the panel
    btnSettings.Caption := 'Hide settings';
  end
  else
    btnSettings.Caption := 'Settings...';
end;

procedure TfrmChart.btnSettingsClick(Sender: TObject);
begin
  SetSettingsVisible(not pnlSettings.Visible);
end;

procedure TfrmChart.chkOnTopChange(Sender: TObject);
begin
  if chkOnTop.Checked then
    FormStyle := fsSystemStayOnTop
  else
    FormStyle := fsNormal;
end;

{ ---------- persistence ---------- }

procedure TfrmChart.SaveSettings(ini: TCustomIniFile);
var
  i: Integer;
  e: TChartEntry;
  k: string;
begin
  ini.WriteBool(SEC, 'AlwaysOnTop', chkOnTop.Checked);
  ini.WriteBool(SEC, 'SettingsVisible', pnlSettings.Visible);
  ini.WriteBool(SEC, 'ShowTitle', chkShowTitle.Checked);
  ini.WriteString(SEC, 'Title', edtTitle.Text);
  ini.WriteInteger(SEC, 'BackColor', cbtnBack.ButtonColor);
  ini.WriteInteger(SEC, 'PlotColor', cbtnPlot.ButtonColor);
  ini.WriteBool(SEC, 'ShowLegend', chkShowLegend.Checked);
  ini.WriteInteger(SEC, 'LegendPos', cbLegendPos.ItemIndex);
  ini.WriteBool(SEC, 'ShowGrid', chkShowGrid.Checked);
  ini.WriteInteger(SEC, 'GridColor', cbtnGrid.ButtonColor);

  ini.WriteInteger(SEC, 'Window', edtWindow.Value);
  ini.WriteInteger(SEC, 'Sample', edtSample.Value);
  ini.WriteString(SEC, 'TimeFormat', cbTimeFormat.Text);
  ini.WriteString(SEC, 'XTitle', edtXTitle.Text);
  ini.WriteString(SEC, 'YTitle', edtYTitle.Text);
  ini.WriteBool(SEC, 'YAuto', chkYAuto.Checked);
  ini.WriteFloat(SEC, 'YMin', fseYMin.Value);
  ini.WriteFloat(SEC, 'YMax', fseYMax.Value);

  ini.WriteInteger(SEC, 'Count', FEntries.Count);
  for i := 0 to FEntries.Count - 1 do
  begin
    e := FEntries[i];
    k := 'Tag' + IntToStr(i);
    ini.WriteString(SEC, k, e.Name);
    ini.WriteInteger(SEC, k + '.Color', e.Series.SeriesColor);
    ini.WriteInteger(SEC, k + '.Width', e.Series.LinePen.Width);
    ini.WriteInteger(SEC, k + '.Style', StyleIndex(e.Series.LinePen.Style));
    ini.WriteBool(SEC, k + '.Step', e.Series.LineType = ltStepXY);
    ini.WriteBool(SEC, k + '.Points', e.Series.ShowPoints);
    ini.WriteBool(SEC, k + '.Visible', e.Series.Active);
  end;
end;

procedure TfrmChart.LoadSettings(ini: TCustomIniFile);
var
  i, n, j, st: Integer;
  e: TChartEntry;
  k: string;
begin
  FUpdating := True;
  try
    chkShowTitle.Checked := ini.ReadBool(SEC, 'ShowTitle', chkShowTitle.Checked);
    edtTitle.Text := ini.ReadString(SEC, 'Title', edtTitle.Text);
    cbtnBack.ButtonColor := ini.ReadInteger(SEC, 'BackColor', cbtnBack.ButtonColor);
    cbtnPlot.ButtonColor := ini.ReadInteger(SEC, 'PlotColor', cbtnPlot.ButtonColor);
    chkShowLegend.Checked := ini.ReadBool(SEC, 'ShowLegend', chkShowLegend.Checked);
    cbLegendPos.ItemIndex := ini.ReadInteger(SEC, 'LegendPos', cbLegendPos.ItemIndex);
    chkShowGrid.Checked := ini.ReadBool(SEC, 'ShowGrid', chkShowGrid.Checked);
    cbtnGrid.ButtonColor := ini.ReadInteger(SEC, 'GridColor', cbtnGrid.ButtonColor);

    edtWindow.Value := ini.ReadInteger(SEC, 'Window', edtWindow.Value);
    edtSample.Value := ini.ReadInteger(SEC, 'Sample', edtSample.Value);
    cbTimeFormat.Text := ini.ReadString(SEC, 'TimeFormat', cbTimeFormat.Text);
    edtXTitle.Text := ini.ReadString(SEC, 'XTitle', edtXTitle.Text);
    edtYTitle.Text := ini.ReadString(SEC, 'YTitle', edtYTitle.Text);
    chkYAuto.Checked := ini.ReadBool(SEC, 'YAuto', chkYAuto.Checked);
    fseYMin.Value := ini.ReadFloat(SEC, 'YMin', fseYMin.Value);
    fseYMax.Value := ini.ReadFloat(SEC, 'YMax', fseYMax.Value);

    // Series were attached by the owner; restore their styles by name
    n := ini.ReadInteger(SEC, 'Count', 0);
    for i := 0 to n - 1 do
    begin
      k := 'Tag' + IntToStr(i);
      j := IndexOfName(ini.ReadString(SEC, k, ''));
      if j < 0 then
        Continue;
      e := FEntries[j];
      st := ini.ReadInteger(SEC, k + '.Style', 0);
      if (st < Low(LineStyles)) or (st > High(LineStyles)) then
        st := 0;
      ApplySeriesStyle(e,
        ini.ReadInteger(SEC, k + '.Color', e.Series.SeriesColor),
        ini.ReadInteger(SEC, k + '.Width', e.Series.LinePen.Width),
        LineStyles[st],
        ini.ReadBool(SEC, k + '.Step', e.Series.LineType = ltStepXY),
        ini.ReadBool(SEC, k + '.Points', False));
      e.Series.Active := ini.ReadBool(SEC, k + '.Visible', True);
      clbSeries.Checked[j] := e.Series.Active;
    end;
  finally
    FUpdating := False;
  end;
  tmrSample.Interval := edtSample.Value;
  chkOnTop.Checked := ini.ReadBool(SEC, 'AlwaysOnTop', chkOnTop.Checked);
  SetSettingsVisible(ini.ReadBool(SEC, 'SettingsVisible', pnlSettings.Visible));
  ApplyChartSettings;
  LoadSeriesControls;
end;

{ ---------- drag & drop ---------- }

procedure TfrmChart.TagDragOver(Sender, Source: TObject; X, Y: Integer;
  State: TDragState; var Accept: Boolean);
var
  nm: string;
  vt: TPLCNumber;
  st: TPLCTag;
  b: Boolean;
begin
  Accept := Assigned(FOnQueryDrop) and FOnQueryDrop(Source, nm, vt, st, b)
    and (IndexOfTag(vt) < 0);
end;

procedure TfrmChart.TagDragDrop(Sender, Source: TObject; X, Y: Integer);
var
  nm: string;
  vt: TPLCNumber;
  st: TPLCTag;
  b: Boolean;
begin
  if Assigned(FOnQueryDrop) and FOnQueryDrop(Source, nm, vt, st, b) then
    AddTag(nm, vt, st, b);
end;

{ ---------- toolbar ---------- }

procedure TfrmChart.btnPauseClick(Sender: TObject);
begin
  FPaused := not FPaused;
  if FPaused then
    btnPause.Caption := 'Resume'
  else
    btnPause.Caption := 'Pause';
end;

procedure TfrmChart.btnClearClick(Sender: TObject);
begin
  ClearData;
end;

procedure TfrmChart.btnExportClick(Sender: TObject);
begin
  ExportWithDialog;
end;

procedure TfrmChart.btnRemoveClick(Sender: TObject);
begin
  if clbSeries.ItemIndex >= 0 then
    DeleteEntry(clbSeries.ItemIndex);
end;

procedure TfrmChart.clbSeriesClickCheck(Sender: TObject);
var
  i: Integer;
begin
  for i := 0 to FEntries.Count - 1 do
    FEntries[i].Series.Active := clbSeries.Checked[i];
end;

{ ---------- CSV export ---------- }

function CsvQuote(const S: string): string;
begin
  Result := '"' + StringReplace(S, '"', '""', [rfReplaceAll]) + '"';
end;

procedure TfrmChart.ExportCSV(const AFile: string);
var
  sl: TStringList;
  idx: array of Integer;
  fs: TFormatSettings;
  i: Integer;
  line: string;
  t, x: Double;
  found: Boolean;
begin
  fs := DefaultFormatSettings;
  fs.DecimalSeparator := '.';
  fs.ThousandSeparator := #0;

  sl := TStringList.Create;
  try
    line := CsvQuote('Time');
    for i := 0 to FEntries.Count - 1 do
      line := line + ',' + CsvQuote(FEntries[i].Name);
    sl.Add(line);

    // Each series is sorted by time; merge them into one row per timestamp.
    // A blank cell means that tag had no valid sample at that instant.
    SetLength(idx, FEntries.Count);
    repeat
      found := False;
      t := 0;
      for i := 0 to FEntries.Count - 1 do
        if idx[i] < FEntries[i].Series.Count then
        begin
          x := FEntries[i].Series.XValue[idx[i]];
          if not found or (x < t) then
            t := x;
          found := True;
        end;
      if not found then
        Break;

      line := FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', t);
      for i := 0 to FEntries.Count - 1 do
      begin
        line := line + ',';
        if (idx[i] < FEntries[i].Series.Count) and
           (FEntries[i].Series.XValue[idx[i]] = t) then
        begin
          line := line + FloatToStr(FEntries[i].Series.YValue[idx[i]], fs);
          Inc(idx[i]);
        end;
      end;
      sl.Add(line);
    until False;

    sl.SaveToFile(AFile);
  finally
    sl.Free;
  end;
end;

procedure TfrmChart.ExportWithDialog;
begin
  if FEntries.Count = 0 then
  begin
    MessageDlg('There are no tags on the chart to export.', mtInformation, [mbOK], 0);
    Exit;
  end;
  dlgExport.FileName := 'Trend_' + FormatDateTime('yyyymmdd_hhnnss', Now) + '.csv';
  if not dlgExport.Execute then
    Exit;
  try
    ExportCSV(dlgExport.FileName);
    MessageDlg('Chart data exported to' + LineEnding + dlgExport.FileName,
      mtInformation, [mbOK], 0);
  except
    on E: Exception do
      MessageDlg('Export failed: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

end.
