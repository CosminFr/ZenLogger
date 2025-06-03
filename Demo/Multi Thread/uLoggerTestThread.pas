unit uLoggerTestThread;
(***********************************************************************************************************************

  A simple thread to demostrate logging behavior from a thread.
  Note: fLogger is the reference to the logger to be used. Main cases:
    * Same file & Same logger : different threads could share the same logger
    * Same file & Different loggers - multiple logger objects can log to the same file from different threads
    * Different file = Different loggers - shows the behavior without file conflits



***********************************************************************************************************************)
interface

uses
  System.Classes, System.Generics.Collections, //System.TimeSpan,
  System.Diagnostics, SysUtils,
  ZenLogger;

type
  TLoggerTestThread = class(TThread)
  private
    fData       : TArray<string>;
    fLogger     : ILogger;
    fStartTime  : TDateTime;
    fEndTime    : TDateTime;
    fLogWatch   : TStopwatch;
    fFlushWatch : TStopwatch;
    fWorkload   : Integer;
    fThreadNo   : Integer;
    fResultID   : Integer;
  protected
    procedure Execute; override;
  public
    constructor Create(aData: TArray<string>);

    function  GetLogElapsed: Int64;
    function  GetFlashElapsed: Int64;

    property Workload  : Integer   read fWorkload  write fWorkload;
    property Logger    : ILogger   read fLogger    write fLogger;
    property ThreadNo  : Integer   read fThreadNo  write fThreadNo;
    property ResultID  : Integer   read fResultID  write fResultID;
    property StartTime : TDateTime read fStartTime write fStartTime;
    property EndTime   : TDateTime read fEndTime   write fEndTime;
  end;

implementation


{ TLoggerTestThread }

constructor TLoggerTestThread.Create(aData: TArray<string>);
begin
  inherited Create(True);
  fData       := aData;      //reference same memory! no changes allowed while threads are active!
  fLogger     := nil;
  fStartTime  := 0;
  fEndTime    := 0;
  fWorkload   := 0;
  fThreadNo   := 0;
  fResultID   := 0;
  fLogWatch   := TStopwatch.Create;
  fFlushWatch := TStopwatch.Create;
end;

procedure TLoggerTestThread.Execute;
var
  i : Integer;
begin
  fStartTime := Now;
  for i := 0 to Length(fData) - 1 do begin
    if fWorkload > 0 then    //simulate workload...
      Sleep(fWorkload);

    fLogWatch.Start;
    fLogger.Info('%2d %4d %s', [fThreadNo, i, fData[i]]);
    fLogWatch.Stop;
  end;

  fFlushWatch.Start;
  fLogger.Flush;
  fFlushWatch.Stop;
  fEndTime := Now;
end;

function TLoggerTestThread.GetLogElapsed: Int64;
begin
  Result := fLogWatch.ElapsedMilliseconds;
end;

function TLoggerTestThread.GetFlashElapsed: Int64;
begin
  Result := fFlushWatch.ElapsedMilliseconds;
end;

end.
