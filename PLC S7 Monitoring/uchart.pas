unit uchart;

{ Trend chart window. Tags are attached by dragging rows from the main form's
  tag grid onto the chart or onto the series list. The main form answers
  OnQueryDrop to translate the drag source into a tag.
  The settings panel (General / Axes / Series) configures the chart; all
  settings are persisted through SaveSettings / LoadSettings. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Math, IniFiles, fgl, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, ComCtrls, CheckLst, Spin, TAGraph, TASeries, TAIntervalSources,
  TAChartUtils, TALegend, TATypes, TATextElements, TACustomSource, TAChartAxis, TAChartAxisUtils, TATransformations, TATools,
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
    // Own value axis, used when "separate axes" is on. The transformations
    // map the series range onto the shared 0..1 graph range.
    Axis: TChartAxis;
    Trans: TChartAxisTransformations;
    AutoT: TAutoScaleAxisTransform;
    LinT: TLinearAxisTransform;
    // Manual axis offset/zoom applied after the scaling: graph = g * Scale + Offset
    // (graph units, 0..1 = plot height). Set by dragging / mouse wheel on the axis.
    OffT: TLinearAxisTransform;
    AutoScale: Boolean;
    YMin, YMax: Double;
  end;

  TChartEntryList = specialize TFPGObjectList<TChartEntry>;

  { TfrmChart }

  TfrmChart = class(TForm)
    btnClear: TButton;
    btnExport: TButton;
    btnPause: TButton;
    btnRemove: TButton;
    btnResetZoom: TButton;
    btnSettings: TButton;
    cbLegendPos: TComboBox;
    cbLineStyle: TComboBox;
    cbTimeFormat: TComboBox;
    cbZoomMode: TComboBox;
    btnResetOffsets: TButton;
    chkCrosshair: TCheckBox;
    chkSAuto: TCheckBox;
    fseSOffset: TFloatSpinEdit;
    fseSZoom: TFloatSpinEdit;
    lblSZoom: TLabel;
    lblSOffset: TLabel;
    chkSeparateAxes: TCheckBox;
    fseSMax: TFloatSpinEdit;
    fseSMin: TFloatSpinEdit;
    lblSMax: TLabel;
    lblSMin: TLabel;
    lblZoom: TLabel;
    lblZoomState: TLabel;
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
    procedure btnResetOffsetsClick(Sender: TObject);
    procedure btnResetZoomClick(Sender: TObject);
    procedure chkCrosshairChange(Sender: TObject);
    procedure chMainAfterPaint(ASender: TChart);
    procedure chMainDblClick(Sender: TObject);
    procedure chMainMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure chMainMouseLeave(Sender: TObject);
    procedure chMainMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure chMainMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure btnSettingsClick(Sender: TObject);
    procedure cbZoomModeChange(Sender: TObject);
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
    FToolset: TChartToolset;
    FZoomDrag: TZoomDragTool;
    FPanDrag: TPanDragTool;
    FZoomWheel: TZoomMouseWheelTool;
    // crosshair
    FCrossPos: TPoint;
    FCrossVisible: Boolean;
    // axis offset dragging
    FDragEntry: TChartEntry;   // nil = shared axis drag when FDragShared
    FDragShared: Boolean;
    FDragY0: Integer;
    FDragOff0: Double;
    FDragExt0: TDoubleRect;
    function AxisEntryAt(X, Y: Integer): TChartEntry;
    function SharedAxisAt(X, Y: Integer): Boolean;
    function NearestIndex(ASeries: TLineSeries; AX: Double): Integer;
    function ValueToImageY(e: TChartEntry; AValue: Double): Integer;
    procedure SetEntryOffset(e: TChartEntry; AOffset: Double);
    procedure SetEntryTransform(e: TChartEntry; AScale, AOffset: Double);
    function AxisWheelZoom(APoint: TPoint; AFactor: Double): Boolean;
    procedure WheelUpBefore(ATool: TChartTool; APoint: TPoint);
    procedure WheelDownBefore(ATool: TChartTool; APoint: TPoint);
    procedure CreateTools;
    procedure ApplyZoomMode;
    procedure ApplyAxes;
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
  AXIS_WHEEL = 1.2; // zoom step per wheel notch on a value axis

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
  FTimeSource.Params.MinLength := 70; // pixels between time labels
  FTimeSource.Params.Options := FTimeSource.Params.Options + [aipUseMinLength];
  chMain.BottomAxis.Marks.Source := FTimeSource;
  chMain.BottomAxis.Marks.OverlapPolicy := opHideNeighbour;
  chMain.BottomAxis.Marks.Style := smsLabel;
  chMain.BottomAxis.Title.Visible := True;
  chMain.LeftAxis.Title.Visible := True;
  chMain.LeftAxis.Title.LabelFont.Orientation := 900;

  chMain.DoubleBuffered := True;
  CreateTools;
  ApplyZoomMode;

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
  e.AutoScale := True;
  e.YMin := 0;
  e.YMax := 100;

  e.Trans := TChartAxisTransformations.Create(Self);
  e.AutoT := TAutoScaleAxisTransform.Create(e.Trans);
  e.AutoT.Transformations := e.Trans;
  e.LinT := TLinearAxisTransform.Create(e.Trans);
  e.LinT.Transformations := e.Trans;
  e.LinT.Enabled := False;
  e.OffT := TLinearAxisTransform.Create(e.Trans); // applied after the scaling
  e.OffT.Transformations := e.Trans;

  e.Axis := chMain.AxisList.Add;
  e.Axis.Alignment := calLeft;
  e.Axis.Transformations := e.Trans;
  e.Axis.Title.Caption := AName;
  e.Axis.Title.Visible := True;
  e.Axis.Title.LabelFont.Orientation := 900;
  e.Axis.Title.LabelFont.Style := [fsBold];
  e.Axis.Grid.Visible := False;

  ApplySeriesStyle(e, SeriesColors[FEntries.Count mod Length(SeriesColors)], 2,
    psSolid, AIsBool, False);
  chMain.AddSeries(e.Series);
  FEntries.Add(e);
  ApplyAxes;

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
  with FEntries[AIndex] do
  begin
    Series.Free; // removes itself from the chart
    Axis.Free;   // removes itself from AxisList (shifts later axis indexes)
    Trans.Free;  // also frees its transforms
  end;
  FEntries.Delete(AIndex);
  clbSeries.Items.Delete(AIndex);
  if not (csDestroying in ComponentState) then
  begin
    ApplyAxes; // re-links AxisIndexY after the index shift
    LoadSeriesControls;
  end;
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
  // While zoomed the view stays where the user put it; Reset zoom returns to live
  btnResetZoom.Enabled := chMain.IsZoomed;
  if chMain.IsZoomed then
    lblZoomState.Caption := 'Zoomed - live view held'
  else if FPaused then
    lblZoomState.Caption := 'Paused'
  else
    lblZoomState.Caption := 'Live';

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

  // Shared value axis range (only used when the axes are not separated)
  chkYAuto.Enabled := not chkSeparateAxes.Checked;
  fseYMin.Enabled := chkYAuto.Enabled and not chkYAuto.Checked;
  fseYMax.Enabled := fseYMin.Enabled;
  with chMain.LeftAxis.Range do
    if chkSeparateAxes.Checked or chkYAuto.Checked or (fseYMax.Value <= fseYMin.Value) then
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

  ApplyAxes;
  UpdateAxisRange;
end;

procedure TfrmChart.ApplyAxes;
var
  sep, gridDone: Boolean;
  e: TChartEntry;
begin
  sep := chkSeparateAxes.Checked;
  chMain.LeftAxis.Visible := not sep or (FEntries.Count = 0);
  chMain.LeftAxis.Grid.Visible := chkShowGrid.Checked and chMain.LeftAxis.Visible;

  // In separate mode every series is mapped onto 0..1, so pin the vertical
  // extent there; each axis then shows exactly its own range.
  chMain.Extent.YMin := 0;
  chMain.Extent.YMax := 1;
  chMain.Extent.UseYMin := sep;
  chMain.Extent.UseYMax := sep;

  gridDone := False;
  for e in FEntries do
  begin
    if sep then
      e.Series.AxisIndexY := e.Axis.Index
    else
      e.Series.AxisIndexY := chMain.LeftAxis.Index;

    e.Axis.Visible := sep and e.Series.Active;
    e.Axis.Title.Caption := e.Name;
    e.Axis.Title.LabelFont.Color := e.Series.SeriesColor;
    e.Axis.Marks.LabelFont.Color := e.Series.SeriesColor;
    e.Axis.AxisPen.Color := e.Series.SeriesColor;
    e.Axis.AxisPen.Visible := True;
    // One grid is enough; take it from the first visible axis
    e.Axis.Grid.Visible := chkShowGrid.Checked and e.Axis.Visible and not gridDone;
    e.Axis.Grid.Color := cbtnGrid.ButtonColor;
    if e.Axis.Visible then
      gridDone := True;

    if e.AutoScale or (e.YMax <= e.YMin) then
    begin
      e.AutoT.Enabled := True;
      e.LinT.Enabled := False;
    end
    else
    begin
      // value -> (value - min) / (max - min)
      e.LinT.Scale := 1 / (e.YMax - e.YMin);
      e.LinT.Offset := -e.YMin / (e.YMax - e.YMin);
      e.LinT.Enabled := True;
      e.AutoT.Enabled := False;
    end;
  end;
end;

{ ---------- zoom & pan ---------- }

procedure TfrmChart.CreateTools;
begin
  FToolset := TChartToolset.Create(Self);

  // Left drag: zoom box. Dragging right-to-left restores the full view.
  FZoomDrag := TZoomDragTool.Create(FToolset);
  FZoomDrag.Toolset := FToolset;
  FZoomDrag.Shift := [ssLeft];
  FZoomDrag.Brush.Style := bsClear;
  FZoomDrag.Frame.Color := clGray;
  FZoomDrag.Frame.Style := psDash;

  // Right drag: pan
  FPanDrag := TPanDragTool.Create(FToolset);
  FPanDrag.Toolset := FToolset;
  FPanDrag.Shift := [ssRight];

  // Mouse wheel: zoom around the cursor
  FZoomWheel := TZoomMouseWheelTool.Create(FToolset);
  FZoomWheel.Toolset := FToolset;
  FZoomWheel.FixedPoint := True;
  // Wheel over a value axis zooms only that axis
  FZoomWheel.OnBeforeMouseWheelUp := @WheelUpBefore;
  FZoomWheel.OnBeforeMouseWheelDown := @WheelDownBefore;

  chMain.Toolset := FToolset;
end;

procedure TfrmChart.ApplyZoomMode;
const
  WHEEL = 1.2;
begin
  case cbZoomMode.ItemIndex of
    1: begin // time axis only
         FZoomDrag.RatioLimit := zrlFixedY;
         FPanDrag.Directions := [pdLeft, pdRight];
         FZoomWheel.ZoomFactor := WHEEL;
         FZoomWheel.ZoomRatio := 1 / WHEEL;
       end;
    2: begin // value axis only
         FZoomDrag.RatioLimit := zrlFixedX;
         FPanDrag.Directions := [pdUp, pdDown];
         FZoomWheel.ZoomFactor := 1;
         FZoomWheel.ZoomRatio := WHEEL;
       end;
  else     // both axes
    FZoomDrag.RatioLimit := zrlNone;
    FPanDrag.Directions := [pdLeft, pdUp, pdRight, pdDown];
    FZoomWheel.ZoomFactor := WHEEL;
    FZoomWheel.ZoomRatio := 1;
  end;
end;

procedure TfrmChart.cbZoomModeChange(Sender: TObject);
begin
  if Assigned(FToolset) then
    ApplyZoomMode;
end;

procedure TfrmChart.btnResetZoomClick(Sender: TObject);
begin
  chMain.ZoomFull;
end;

{ ---------- axis offset (drag a value axis with the left mouse button) ---------- }

function TfrmChart.AxisEntryAt(X, Y: Integer): TChartEntry;
var
  e: TChartEntry;
begin
  Result := nil;
  if not chkSeparateAxes.Checked then
    Exit;
  // IsPointInside covers the axis marks strip; also accept the title just left of it
  for e in FEntries do
    if e.Axis.Visible and e.Axis.IsPointInside(Point(X, Y)) then
      Exit(e);
  for e in FEntries do
    if e.Axis.Visible and e.Axis.IsPointInside(Point(X + 18, Y)) then
      Exit(e);
end;

function TfrmChart.SharedAxisAt(X, Y: Integer): Boolean;
begin
  Result := chMain.LeftAxis.Visible and
    (chMain.LeftAxis.IsPointInside(Point(X, Y)) or
     chMain.LeftAxis.IsPointInside(Point(X + 18, Y)));
end;

procedure TfrmChart.SetEntryOffset(e: TChartEntry; AOffset: Double);
begin
  SetEntryTransform(e, e.OffT.Scale, AOffset);
end;

procedure TfrmChart.SetEntryTransform(e: TChartEntry; AScale, AOffset: Double);
begin
  e.OffT.Scale := AScale;
  e.OffT.Offset := AOffset;
  if (FEntries.IndexOf(e) = clbSeries.ItemIndex) and not FUpdating then
  begin
    FUpdating := True;
    try
      fseSOffset.Value := AOffset * 100;
      fseSZoom.Value := AScale;
    finally
      FUpdating := False;
    end;
  end;
end;

{ ---------- per-axis wheel zoom ---------- }

function TfrmChart.AxisWheelZoom(APoint: TPoint; AFactor: Double): Boolean;
var
  e: TChartEntry;
  g0: Double;
  ext: TDoubleRect;
begin
  Result := False;
  g0 := chMain.YImageToGraph(APoint.Y);
  e := AxisEntryAt(APoint.X, APoint.Y);
  if Assigned(e) then
  begin
    // Zoom this axis only, keeping the value under the mouse in place:
    // g' = g0 + (g - g0) * k, with g = s * Scale + Offset
    if (e.OffT.Scale * AFactor < 0.01) or (e.OffT.Scale * AFactor > 1000) then
      Exit(True);
    SetEntryTransform(e, e.OffT.Scale * AFactor,
      g0 + (e.OffT.Offset - g0) * AFactor);
    clbSeries.ItemIndex := FEntries.IndexOf(e);
    LoadSeriesControls;
    Result := True;
  end
  else if SharedAxisAt(APoint.X, APoint.Y) then
  begin
    // Single shared axis: zoom the vertical extent around the mouse
    ext := chMain.LogicalExtent;
    ext.a.Y := g0 - (g0 - ext.a.Y) / AFactor;
    ext.b.Y := g0 + (ext.b.Y - g0) / AFactor;
    chMain.LogicalExtent := ext;
    Result := True;
  end;
end;

procedure TfrmChart.WheelUpBefore(ATool: TChartTool; APoint: TPoint);
begin
  if AxisWheelZoom(APoint, AXIS_WHEEL) then
    ATool.Handled; // keep the chart-wide wheel zoom out of it
end;

procedure TfrmChart.WheelDownBefore(ATool: TChartTool; APoint: TPoint);
begin
  if AxisWheelZoom(APoint, 1 / AXIS_WHEEL) then
    ATool.Handled;
end;

procedure TfrmChart.chMainMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  // Only reached outside the plot area: the zoom/pan tools take clicks inside it
  if Button <> mbLeft then
    Exit;
  FDragEntry := AxisEntryAt(X, Y);
  FDragShared := (FDragEntry = nil) and SharedAxisAt(X, Y);
  FDragY0 := Y;
  if Assigned(FDragEntry) then
  begin
    FDragOff0 := FDragEntry.OffT.Offset;
    clbSeries.ItemIndex := FEntries.IndexOf(FDragEntry);
    LoadSeriesControls;
  end
  else if FDragShared then
    FDragExt0 := chMain.LogicalExtent;
end;

procedure TfrmChart.chMainMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
  h, dg: Double;
  ext: TDoubleRect;
begin
  h := chMain.ClipRect.Bottom - chMain.ClipRect.Top;
  if Assigned(FDragEntry) and (ssLeft in Shift) and (h > 0) then
  begin
    // Dragging down moves the series (and its scale) down
    dg := (FDragY0 - Y) / h * (chMain.LogicalExtent.b.Y - chMain.LogicalExtent.a.Y);
    SetEntryOffset(FDragEntry, FDragOff0 + dg);
    Exit;
  end;
  if FDragShared and (ssLeft in Shift) and (h > 0) then
  begin
    ext := FDragExt0;
    dg := (Y - FDragY0) / h * (ext.b.Y - ext.a.Y);
    ext.a.Y := ext.a.Y + dg;
    ext.b.Y := ext.b.Y + dg;
    chMain.LogicalExtent := ext;
    Exit;
  end;

  // Hover feedback
  if (AxisEntryAt(X, Y) <> nil) or SharedAxisAt(X, Y) then
    chMain.Cursor := crSizeNS
  else if chkCrosshair.Checked and PtInRect(chMain.ClipRect, Point(X, Y)) then
    chMain.Cursor := crCross
  else
    chMain.Cursor := crDefault;

  // Crosshair
  if chkCrosshair.Checked then
  begin
    FCrossVisible := PtInRect(chMain.ClipRect, Point(X, Y));
    FCrossPos := Point(X, Y);
    chMain.Invalidate;
  end;
end;

procedure TfrmChart.chMainMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  FDragEntry := nil;
  FDragShared := False;
end;

procedure TfrmChart.chMainDblClick(Sender: TObject);
var
  p: TPoint;
  e: TChartEntry;
begin
  // Double-click a value axis to remove its offset and zoom
  p := chMain.ScreenToClient(Mouse.CursorPos);
  e := AxisEntryAt(p.X, p.Y);
  if Assigned(e) then
    SetEntryTransform(e, 1, 0)
  else if SharedAxisAt(p.X, p.Y) then
    chMain.ZoomFull;
end;

procedure TfrmChart.btnResetOffsetsClick(Sender: TObject);
var
  e: TChartEntry;
begin
  for e in FEntries do
    SetEntryTransform(e, 1, 0);
end;

{ ---------- crosshair ---------- }

procedure TfrmChart.chkCrosshairChange(Sender: TObject);
begin
  FCrossVisible := False;
  chMain.Invalidate;
end;

procedure TfrmChart.chMainMouseLeave(Sender: TObject);
begin
  if FCrossVisible then
  begin
    FCrossVisible := False;
    chMain.Invalidate;
  end;
end;

function TfrmChart.NearestIndex(ASeries: TLineSeries; AX: Double): Integer;
var
  lo, hi, mid: Integer;
begin
  // Points are added in time order, so a binary search is enough
  Result := -1;
  if ASeries.Count = 0 then
    Exit;
  lo := 0;
  hi := ASeries.Count - 1;
  while hi - lo > 1 do
  begin
    mid := (lo + hi) div 2;
    if ASeries.XValue[mid] < AX then
      lo := mid
    else
      hi := mid;
  end;
  if Abs(ASeries.XValue[hi] - AX) < Abs(ASeries.XValue[lo] - AX) then
    Result := hi
  else
    Result := lo;
end;

function TfrmChart.ValueToImageY(e: TChartEntry; AValue: Double): Integer;
begin
  if chkSeparateAxes.Checked then
    Result := chMain.YGraphToImage(e.Trans.AxisToGraph(AValue))
  else
    Result := chMain.YGraphToImage(AValue);
end;

procedure TfrmChart.chMainAfterPaint(ASender: TChart);
var
  c: TCanvas;
  r: TRect;
  t, tol: TDateTime;
  e: TChartEntry;
  idx, i, w, lh, bx, by, px, py: Integer;
  lines: array of string;
  colors: array of TColor;
begin
  if not (chkCrosshair.Checked and FCrossVisible) then
    Exit;
  c := chMain.Canvas;
  r := chMain.ClipRect;
  if not PtInRect(r, FCrossPos) then
    Exit;

  // Cross lines
  c.Pen.Color := clGray;
  c.Pen.Style := psDot;
  c.Pen.Width := 1;
  c.Line(FCrossPos.X, r.Top, FCrossPos.X, r.Bottom);
  c.Line(r.Left, FCrossPos.Y, r.Right, FCrossPos.Y);
  c.Pen.Style := psSolid;

  // Values of every visible series at the nearest sample to the cursor time
  t := chMain.XImageToGraph(FCrossPos.X);
  tol := Max(2 * edtSample.Value, 1000) / MSecsPerDay;
  SetLength(lines, 1);
  SetLength(colors, 1);
  lines[0] := FormatDateTime('hh:nn:ss.zzz', t);
  colors[0] := clBlack;
  for e in FEntries do
  begin
    if not e.Series.Active then
      Continue;
    idx := NearestIndex(e.Series, t);
    // Ignore the nearest sample if it is far from the cursor time (before the
    // first sample, after the last one, or in a gap while offline)
    if (idx >= 0) and (Abs(e.Series.XValue[idx] - t) > tol) then
      idx := -1;
    SetLength(lines, Length(lines) + 1);
    SetLength(colors, Length(colors) + 1);
    colors[High(colors)] := e.Series.SeriesColor;
    if idx < 0 then
    begin
      lines[High(lines)] := e.Name + ': ---';
      Continue;
    end;
    lines[High(lines)] := e.Name + ': ' +
      FloatToStrF(e.Series.YValue[idx], ffGeneral, 7, 0);
    // marker on the sample
    px := chMain.XGraphToImage(e.Series.XValue[idx]);
    py := ValueToImageY(e, e.Series.YValue[idx]);
    if PtInRect(r, Point(px, py)) then
    begin
      c.Brush.Style := bsSolid;
      c.Brush.Color := e.Series.SeriesColor;
      c.Pen.Color := clWhite;
      c.Ellipse(px - 4, py - 4, px + 5, py + 5);
    end;
  end;

  // Readout box next to the cursor, kept inside the plot area
  c.Font := chMain.Font;
  c.Font.Size := 9;
  lh := c.TextHeight('Ag') + 2;
  w := 0;
  for i := 0 to High(lines) do
    w := Max(w, c.TextWidth(lines[i]));
  w := w + 16;
  bx := FCrossPos.X + 12;
  by := FCrossPos.Y + 12;
  if bx + w > r.Right then
    bx := FCrossPos.X - 12 - w;
  if by + Length(lines) * lh + 8 > r.Bottom then
    by := FCrossPos.Y - 12 - Length(lines) * lh - 8;
  c.Brush.Style := bsSolid;
  c.Brush.Color := clInfoBk;
  c.Pen.Color := clGray;
  c.Rectangle(bx, by, bx + w, by + Length(lines) * lh + 8);
  c.Brush.Style := bsClear;
  for i := 0 to High(lines) do
  begin
    c.Font.Color := colors[i];
    if i = 0 then
      c.Font.Style := [fsBold]
    else
      c.Font.Style := [];
    c.TextOut(bx + 8, by + 4 + i * lh, lines[i]);
  end;
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
  // per-series range only matters when each series has its own axis
  chkSAuto.Enabled := has and chkSeparateAxes.Checked;
  fseSOffset.Enabled := chkSAuto.Enabled;
  fseSZoom.Enabled := chkSAuto.Enabled;
  fseSMin.Enabled := chkSAuto.Enabled and not chkSAuto.Checked;
  fseSMax.Enabled := fseSMin.Enabled;
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
    chkSAuto.Checked := e.AutoScale;
    fseSMin.Value := e.YMin;
    fseSMax.Value := e.YMax;
    fseSOffset.Value := e.OffT.Offset * 100;
    fseSZoom.Value := e.OffT.Scale;
    fseSMin.Enabled := chkSAuto.Enabled and not e.AutoScale;
    fseSMax.Enabled := fseSMin.Enabled;
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
  FEntries[i].AutoScale := chkSAuto.Checked;
  FEntries[i].YMin := fseSMin.Value;
  FEntries[i].YMax := fseSMax.Value;
  FEntries[i].OffT.Offset := fseSOffset.Value / 100;
  FEntries[i].OffT.Scale := fseSZoom.Value;
  fseSMin.Enabled := chkSAuto.Enabled and not chkSAuto.Checked;
  fseSMax.Enabled := fseSMin.Enabled;
  ApplyAxes;
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
  ini.WriteBool(SEC, 'SeparateAxes', chkSeparateAxes.Checked);
  ini.WriteInteger(SEC, 'ZoomMode', cbZoomMode.ItemIndex);
  ini.WriteBool(SEC, 'Crosshair', chkCrosshair.Checked);

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
    ini.WriteBool(SEC, k + '.AutoScale', e.AutoScale);
    ini.WriteFloat(SEC, k + '.YMin', e.YMin);
    ini.WriteFloat(SEC, k + '.YMax', e.YMax);
    ini.WriteFloat(SEC, k + '.Offset', e.OffT.Offset);
    ini.WriteFloat(SEC, k + '.Zoom', e.OffT.Scale);
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
    chkSeparateAxes.Checked := ini.ReadBool(SEC, 'SeparateAxes', chkSeparateAxes.Checked);
    cbZoomMode.ItemIndex := ini.ReadInteger(SEC, 'ZoomMode', cbZoomMode.ItemIndex);
    chkCrosshair.Checked := ini.ReadBool(SEC, 'Crosshair', chkCrosshair.Checked);
    if cbZoomMode.ItemIndex < 0 then
      cbZoomMode.ItemIndex := 0;

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
      e.AutoScale := ini.ReadBool(SEC, k + '.AutoScale', True);
      e.YMin := ini.ReadFloat(SEC, k + '.YMin', 0);
      e.YMax := ini.ReadFloat(SEC, k + '.YMax', 100);
      e.OffT.Offset := ini.ReadFloat(SEC, k + '.Offset', 0);
      e.OffT.Scale := EnsureRange(ini.ReadFloat(SEC, k + '.Zoom', 1), 0.01, 1000);
      clbSeries.Checked[j] := e.Series.Active;
    end;
  finally
    FUpdating := False;
  end;
  tmrSample.Interval := edtSample.Value;
  chkOnTop.Checked := ini.ReadBool(SEC, 'AlwaysOnTop', chkOnTop.Checked);
  SetSettingsVisible(ini.ReadBool(SEC, 'SettingsVisible', pnlSettings.Visible));
  ApplyZoomMode;
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
  ApplyAxes; // hidden series also hide their axis
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
