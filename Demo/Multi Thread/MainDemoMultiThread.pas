unit MainDemoMultiThread;
(***********************************************************************************************************************

  Testing ZenLogger in a multi-thread environment.
  See PrepareData for the generation of ranmdom strings to log. Same data will be used by all logger threads!

  Specify the Log details and "Run Tests":
    * Log Kind       - determines the kind of log will be tested
    * No of Threads  - how many threads will start logging
       > Same File   - all logs use same file (or not)
       > Same Logger - (if same file) use the same logger object or generate independent loggers for each thread
    * No of Rows     - specify how many rows should be logged

  See uLoogerTestThread for details. All Threads are initialized before starting execution.


***********************************************************************************************************************)
interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.StdCtrls, Vcl.Buttons, Vcl.Mask,
  Vcl.Samples.Spin, Data.DB, Vcl.Grids, Vcl.DBGrids, Vcl.DBCtrls, Datasnap.DBClient,
  System.ImageList, Vcl.ImgList, System.Generics.Collections,
  ZenLogger, uLoggerTestThread;

type
  TfrmMain = class(TForm)
    grdResults: TDBGrid;
    pnlTest: TPanel;
    lblLogKind: TLabel;
    lblDataCount: TLabel;
    edDataCount: TSpinEdit;
    btnRun: TBitBtn;
    edThreadCount: TSpinEdit;
    lblThreadCount: TLabel;
    cbSameFile: TCheckBox;
    cdsResults: TClientDataSet;
    cdsResultsKind: TIntegerField;
    cdsResultsStartTime: TDateTimeField;
    cdsResultsEndTime: TDateTimeField;
    cdsResultsLogTime: TIntegerField;
    cdsResultsFlushTime: TIntegerField;
    cdsResultsTotalTime: TIntegerField;
    cdsResultsThreadId: TIntegerField;
    dsResults: TDataSource;
    cdsResultsID: TIntegerField;
    cbLogKind: TComboBox;
    ImageList: TImageList;
    OpenDialog: TOpenDialog;
    lblWorkload: TLabel;
    edWorkload: TSpinEdit;
    cbSameLogger: TCheckBox;
    TimerTestRunning: TTimer;
    cpgConfig: TCategoryPanelGroup;
    cpnlConfig: TCategoryPanel;
    pnlConfig: TPanel;
    lblPath: TLabel;
    SpeedButton1: TSpeedButton;
    lblLevel: TLabel;
    lblDaysKeep: TLabel;
    edPath: TButtonedEdit;
    edName: TLabeledEdit;
    cbLogLevel: TComboBox;
    edDaylsKeep: TSpinEdit;
    cdsResultsKindName: TStringField;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure btnRunClick(Sender: TObject);
    procedure TimerTestRunningTimer(Sender: TObject);
    procedure cate(Sender: TObject);
    procedure cpnlConfigCollapse(Sender: TObject);
    procedure cpnlConfigExpand(Sender: TObject);
  private
    arrData    : TArray<string>;
    arrThreads : TArray<TLoggerTestThread>;
    fLastResultID : Integer;
    procedure InitializeLogKinds;
    procedure PrepareData;
    procedure InitializeThreads;
    procedure ThreadOnTerminate(Sender: TObject);
    function  GetThreadLogger(aIndex: Integer): ILogger;
    function  GetNextId: Integer;
    procedure ResetLogger;
    procedure UpdateGridFor(aThread: TLoggerTestThread);
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.dfm}

uses
  System.IOUtils, System.Math, Faker,
  LogManager, BaseLogger, FileLogger;


procedure TfrmMain.cate(Sender: TObject);
begin
  cbSameLogger.Enabled := cbSameFile.Checked;
end;

procedure TfrmMain.cpnlConfigCollapse(Sender: TObject);
begin
  cpgConfig.Height := cpgConfig.HeaderHeight +3;
end;

procedure TfrmMain.cpnlConfigExpand(Sender: TObject);
begin
  cpgConfig.Height := cpgConfig.HeaderHeight + pnlConfig.Height +3;
end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  arrData   := TArray<string>(nil);
  Randomize;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  SetLength(arrData, 0);
  arrData  := nil;
end;

procedure TfrmMain.FormShow(Sender: TObject);
begin
  edPath.Text := ExtractFilePath(Application.ExeName);
  edName.Text := TPath.GetFileNameWithoutExtension(Application.ExeName);
  PrepareData;
  InitializeLogKinds;
  if cdsResults.Active then
    cdsResults.EmptyDataSet
  else
    cdsResults.CreateDataSet;
end;

function RandomInputString: string;
begin
  Result := TFaker.text(RandomRange(10, 25));
end;

procedure TfrmMain.PrepareData;
var
  i : Integer;
begin
  if edDataCount.Value <> Length(arrData) then
  begin
    SetLength(arrData, edDataCount.Value);
    for i := 0 to edDataCount.Value - 1 do
      arrData[i] := RandomInputString;
  end;
end;

procedure TfrmMain.InitializeLogKinds;
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

procedure TfrmMain.InitializeThreads;
var
  i : Integer;
  thr : TLoggerTestThread;
begin
  if Length(arrThreads) > 0 then
    raise Exception.CreateFmt('Cannot initialize Threads. There are already %d threads in progress!', [Length(arrThreads)]);

  SetLength(arrThreads, edThreadCount.Value);
  for i := 0 to edThreadCount.Value - 1 do begin
    thr := TLoggerTestThread.Create(arrData);
    thr.ThreadNo        := i;
    thr.Logger          := GetThreadLogger(i);
    thr.Workload        := edWorkload.Value;
    thr.FreeOnTerminate := True;
    thr.OnTerminate     := ThreadOnTerminate;

    UpdateGridFor(thr);

    arrThreads[i] := thr;
  end;
end;

procedure TfrmMain.ResetLogger;
begin
  Default_LogKind  := Integer(cbLogKind.Items.Objects[cbLogKind.ItemIndex]);
  Default_LogPath  := edPath.Text;
  Default_LogLevel := cbLogLevel.ItemIndex;
  Default_DaysKeep := edDaylsKeep.Value;

  ReleaseLogger;
  InitializeLogger();
end;

function TfrmMain.GetNextId: Integer;
begin
  Inc(fLastResultID);
  Result := fLastResultID;
end;

function TfrmMain.GetThreadLogger(aIndex: Integer): ILogger;
var
  lName : String;
begin
  if cbSameFile.Checked then begin
    lName := edName.Text;
    if cbSameLogger.Checked then
      Result := Log()                          //use the global logger
    else
      Result := GetLogger();           //Creates a new logger with the same options
  end else begin
    Result := GetLogger();
    if (Result is TFileLogger) then
      TFileLogger(Result).LogName := TFileLogger(Result).LogName + Format('_Thread_%2d', [aIndex]);
  end;
end;

procedure TfrmMain.ThreadOnTerminate(Sender: TObject);
var
  thr : TLoggerTestThread;
begin
  if Sender is TLoggerTestThread then begin
    thr := TLoggerTestThread(Sender);
    arrThreads[thr.ThreadNo] := nil;  // destroy the reference to finalized thread
    UpdateGridFor(thr);
  end;
end;

procedure TfrmMain.UpdateGridFor(aThread: TLoggerTestThread);
begin
  if aThread.ResultID = 0 then
    aThread.ResultID := GetNextId;

  if cdsResults.Locate('ID', aThread.ResultID, []) then
    cdsResults.Edit
  else begin
    cdsResults.Append;
    cdsResultsID.Value        := aThread.ResultID;
    cdsResultsKind.Value      := Default_LogKind;
    cdsResultsThreadId.Value  := aThread.ThreadNo;
    cdsResultsKindName.Value  := cbLogKind.Text;
  end;

  cdsResultsStartTime.Value := aThread.StartTime;
  cdsResultsEndTime.Value   := aThread.EndTime;

  cdsResultsLogTime.Value   := aThread.GetLogElapsed;
  cdsResultsFlushTime.Value := aThread.GetFlashElapsed;

  if aThread.EndTime > aThread.StartTime then
    cdsResultsTotalTime.Value := Trunc((aThread.EndTime - aThread.StartTime) * MSecsPerDay);

  cdsResults.Post;
end;

procedure TfrmMain.btnRunClick(Sender: TObject);
var
  thr : TLoggerTestThread;
begin
  PrepareData;
  ResetLogger;
  InitializeThreads;

  for thr in arrThreads do begin
    thr.Start;
    UpdateGridFor(thr);
  end;
  TimerTestRunning.Enabled := True;
end;

procedure TfrmMain.TimerTestRunningTimer(Sender: TObject);
var
  cntActive : Integer;
  thr : TLoggerTestThread;
begin
  cntActive := 0;
  for thr in arrThreads do
    if Assigned(thr) then begin
      Inc(cntActive);
      UpdateGridFor(thr);
    end;

  if cntActive = 0 then begin
    TimerTestRunning.Enabled := False;
    SetLength(arrThreads, 0);
  end;
end;

end.
