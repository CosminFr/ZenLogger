unit MainSortDemo;
(***********************************************************************************************************************

  Testing ZenLogger and ZenProfiler in a multi-thread environment.

  Note: to actually test the performance of the sorting algorithm use Null logger (or low log level)
   AND "Delay GUI updates" option.
   If the Log is not Async and you are using the same file, the file locking becomes quite obvious!


************************************************************************************************************************
Developer: Cosmin Frentiu
Licence:   GPL v3
Homepage:  https://github.com/CosminFr
***********************************************************************************************************************)
interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Types, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.Samples.Spin, Vcl.ExtCtrls, System.ImageList, Vcl.ImgList,
  Vcl.Buttons, System.Generics.Collections,
  ZenLogger, SortThreads, PaintArray;

type
  TfrmSortDemo = class(TForm)
    gbSelectSort: TGroupBox;
    gbMergeSort: TGroupBox;
    gbQuickSort: TGroupBox;
    pnlButtons: TPanel;
    btnClose: TButton;
    btnStart: TButton;
    lblLogKind: TLabel;
    cbLogKind: TComboBox;
    cbSameFile: TCheckBox;
    lblArraySize: TLabel;
    edArraySize: TSpinEdit;
    lblLevel: TLabel;
    cbLogLevel: TComboBox;
    pbQuickSort: TPaintBox;
    pbMergeSort: TPaintBox;
    pbSelectSort: TPaintBox;
    sbRefreshArray: TSpeedButton;
    ImageList: TImageList;
    edMaxValue: TSpinEdit;
    Label1: TLabel;
    cbDelayGUI: TCheckBox;
    tmrDelayedUpdates: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure sbRefreshArrayClick(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
    procedure btnStartClick(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure cbLogKindChange(Sender: TObject);
    procedure cbLogLevelChange(Sender: TObject);
    procedure tmrDelayedUpdatesTimer(Sender: TObject);
  private
    ThreadsRunning : Integer;
    fSelectThread  : TSelectionSort;
    fMergeThread   : TMergeSort;
    fQuickThread   : TQuickSort;
    paQuickSort    : TPaintArray;
    paMergeSort    : TPaintArray;
    paSelectSort   : TPaintArray;
    fDataArray     : TIntegerDynArray;
    procedure RandomizeArrays;
    procedure ThreadDone(Sender: TObject);
    procedure InitializeLogKinds;
    procedure UpdateControls;
    function  GetLogger(aSuffix: String): ILogger;
  public

  end;

var
  frmSortDemo: TfrmSortDemo;

implementation

{$R *.dfm}

uses
  BaseLogger, FileLogger, LogManager;

{ TfrmSortDemo }

procedure TfrmSortDemo.FormCreate(Sender: TObject);
begin
  InitializeLogKinds;
  edArraySize.Value := 100;
  edMaxValue.Value  := 100;
  ThreadsRunning    := 0;
  cbLogLevel.ItemIndex := Default_LogLevel;


  paSelectSort := TPaintArray.Create(Self, gbSelectSort);
  paMergeSort  := TPaintArray.Create(Self, gbMergeSort);
  paQuickSort  := TPaintArray.Create(Self, gbQuickSort);

  RandomizeArrays;
end;

procedure TfrmSortDemo.FormResize(Sender: TObject);
begin
  gbSelectSort.Width := Width div 3;
  gbMergeSort.Width  := Width div 3;
end;

function TfrmSortDemo.GetLogger(aSuffix: String): ILogger;
begin
  if cbSameFile.Checked then
    Result := Log
  else begin
    Result := ZenLogger.GetLogger();
    if (Result is TFileLogger) then
      TFileLogger(Result).LogName := TFileLogger(Result).LogName + '_' + aSuffix;
  end;
end;

procedure TfrmSortDemo.InitializeLogKinds;
var
  K : Integer;
  cls : TLoggerClass;
  arr : TArray<Integer>;
begin
  cbLogKind.Clear;
  // Sort Keys from kind registry...
  arr := TLogManager.LogKindRegistry.Keys.ToArray;
  TArray.Sort<Integer>(arr);
  for K in arr do
    if TLogManager.LogKindRegistry.TryGetValue(K, cls) then begin
      cbLogKind.Items.AddObject(cls.LogKindName, TObject(K));
      if K = Default_LogKind then
        cbLogKind.ItemIndex := cbLogKind.Items.Count -1;
    end;

  if (cbLogKind.ItemIndex < 0) and (cbLogKind.Items.Count > 1) then
    cbLogKind.ItemIndex := 1;
end;

procedure TfrmSortDemo.RandomizeArrays;
var
  I : Integer;
begin
  if ThreadsRunning = 0 then begin
    Randomize;
    SetLength(fDataArray, edArraySize.Value);
    for I := Low(fDataArray) to High(fDataArray) do
      fDataArray[I] := Random(edMaxValue.Value);

    paSelectSort.SetDataArray(fDataArray, edMaxValue.Value);
    paMergeSort. SetDataArray(fDataArray, edMaxValue.Value);
    paQuickSort. SetDataArray(fDataArray, edMaxValue.Value);

    Repaint;
  end;
end;

procedure TfrmSortDemo.UpdateControls;
begin
  btnStart.Enabled       := (ThreadsRunning = 0);
  sbRefreshArray.Enabled := (ThreadsRunning = 0);
  if ThreadsRunning > 0 then
    btnClose.Caption := 'Pause'
  else
    btnClose.Caption := 'Close';
  tmrDelayedUpdates.Enabled := cbDelayGUI.Checked and (ThreadsRunning > 0);
  Repaint;
end;

procedure TfrmSortDemo.sbRefreshArrayClick(Sender: TObject);
begin
  if ThreadsRunning = 0 then
    RandomizeArrays;
end;

procedure TfrmSortDemo.ThreadDone(Sender: TObject);
begin
  Dec(ThreadsRunning);
  UpdateControls;
  if Sender is TSelectionSort then
    fSelectThread  := nil;
  if Sender is TMergeSort then
    fMergeThread  := nil;
  if Sender is TQuickSort then
    fQuickThread  := nil;
end;

procedure TfrmSortDemo.tmrDelayedUpdatesTimer(Sender: TObject);
begin
  if ThreadsRunning > 0 then begin
    if Assigned(fSelectThread) then
      gbSelectSort.Invalidate;
    if Assigned(fMergeThread) then
      gbMergeSort.Invalidate;
    if Assigned(fQuickThread) then
      gbQuickSort.Invalidate;
  end;
end;

procedure TfrmSortDemo.btnCloseClick(Sender: TObject);
begin
  if ThreadsRunning > 0 then begin
    if Assigned(fSelectThread) then
      fSelectThread.Terminate;
    if Assigned(fMergeThread) then
      fMergeThread.Terminate;
    if Assigned(fQuickThread) then
      fQuickThread.Terminate;
  end else
    Close;
end;

procedure TfrmSortDemo.btnStartClick(Sender: TObject);
begin
  var Log := GetTraceLogger(ClassName, 'btnStartClick');
  RandomizeArrays;
  Log.Info('Data array randomized.');
  Prevent_GUI_Updates := cbDelayGUI.Checked;

  ThreadsRunning := 3;
  fSelectThread := TSelectionSort.Create(paSelectSort, GetLogger('SelectSort'), ThreadDone);
  fMergeThread  := TMergeSort.Create(paMergeSort, GetLogger('MergeSort'), ThreadDone);
  fQuickThread  := TQuickSort.Create(paQuickSort, GetLogger('QuickSort'), ThreadDone);
  Log.Info('Threads started.');
  UpdateControls;
end;

procedure TfrmSortDemo.cbLogKindChange(Sender: TObject);
begin
  Default_LogKind  := Integer(cbLogKind.Items.Objects[cbLogKind.ItemIndex]);
  Default_LogLevel := cbLogLevel.ItemIndex;
  ReleaseLogger;
  InitializeLogger;
end;

procedure TfrmSortDemo.cbLogLevelChange(Sender: TObject);
begin
  Default_LogLevel := cbLogLevel.ItemIndex;
  Log.LogLevel     := Default_LogLevel;
end;

end.
