unit AsyncLogger;

interface

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Generics.Collections,
  System.Threading,
  ZenLogger, FileLogger, LogManager;

type
  TThreadSafeLogger = class(TFileLogger)
  private
    FileLock : TMutex;
  protected
    procedure WriteLog(const Line:string); override;
    procedure WriteLogLine(const LineType:TLogLineType; const MsgText :string); override;
  public
    constructor Create(const aConfig: TLogConfig = nil); override;
    destructor  Destroy; override;
    class function LogKindName: String; override;
  end;

  TAsyncLogger = class(TFileLogger)
  protected
    fQueue     : TThreadedQueue<String>;
    fTask      : ITask;
    fIsRunning : Boolean;
    fQueueLen  : Integer;
    procedure WriteLog(const Line:string); override;
  public
    constructor Create(const aConfig: TLogConfig = nil); override;
    destructor  Destroy; override;

    class function LogKindName: String; override;

    procedure Flush; override;
  end;


implementation

{ TThreadSafeLogger }

constructor TThreadSafeLogger.Create(const aConfig: TLogConfig = nil);
begin
  inherited;
  FileLock := TMutex.Create(nil, False, LogName);
end;

destructor TThreadSafeLogger.Destroy;
begin
  FileLock.Free;
  inherited;
end;

class function TThreadSafeLogger.LogKindName: String;
begin
  Result := 'ThreadSafe';
end;

procedure TThreadSafeLogger.WriteLog(const Line: string);
begin
  FileLock.Acquire;
  try
    inherited;
  finally
    FileLock.Release;
  end;
end;

procedure TThreadSafeLogger.WriteLogLine(const LineType: TLogLineType; const MsgText: string);
begin
  if LogLevel >= Ord(LineType) then
    try
      WriteLog(Format('%s%s%s%s',
                      [ FormatDateTime('hh:mm:ss.zzz', Now()),
                        LOG_TYPE_NAME[LineType],
                        TrimPad('TH-' + IntToStr(GetCurrentThreadId), 12),
                        MsgText ] ));
    except
      on E:Exception do
        InternalDebugLog.Error('Error writing to log "%s %s": %s', [LOG_TYPE_NAME[LineType], MsgText, E.Message]);
    end;
end;


{ TAsyncLogger }

constructor TAsyncLogger.Create(const aConfig: TLogConfig = nil);
begin
  inherited;
  fQueue     := TThreadedQueue<String>.Create(100);
  fQueueLen  := 100;   //Default "QueueDepth"
  fTask      := nil;
  fIsRunning := False;
end;

destructor TAsyncLogger.Destroy;
begin
  try
    Flush;
    fQueue.Free;
    try
      fTask := nil;
    except
      on E: Exception do
        InternalDebugLog.Error('Error during Task cleanup:', E);
    end;
    inherited;
  except
    on E: Exception do
      InternalDebugLog.Error('Error during TAsyncLogger.Destroy:', E);
  end;
end;

class function TAsyncLogger.LogKindName: String;
begin
  Result := 'Async';
end;

procedure TAsyncLogger.Flush;
begin
  while fIsRunning do begin
    //Wait for task to complete (aka finish writting to the log)
    if Assigned(fTask) and (fTask.Status < TTaskStatus.Completed) then
      fTask.Wait(10000)
    else
      Break;
  end;
end;

procedure TAsyncLogger.WriteLog(const Line: string);
begin
  if (fQueue.QueueSize = fQueueLen) then begin
    fQueue.Grow(fQueueLen);
    Inc(fQueueLen, fQueueLen);
    InternalDebugLog.Warning('Queue grown: New Size=%d (Capacity=%d); TotalItemsPushed=%d; TotalItemsPopped=%d .', [fQueue.QueueSize, fQueueLen, fQueue.TotalItemsPushed, fQueue.TotalItemsPopped]);
  end;
  fQueue.PushItem(Line);

//  if not Assigned(fTask) or (fTask.Status > TTaskStatus.Running) then begin
  if not fIsRunning then begin
    //Start task to write Line to the log
    fIsRunning := True;
    fTask := TTask.Run(
      procedure
      begin
        var cnt := 0;
        while fQueue.TotalItemsPushed > fQueue.TotalItemsPopped do begin
          inherited WriteLog(fQueue.PopItem);
          Inc(cnt);
        end;
        fIsRunning := False;
//        InternalDebugLog.Debug('Task Completed: Queue Size=%d (LineCount=%d); TotalItemsPushed=%d; TotalItemsPopped=%d .', [fQueue.QueueSize, cnt, fQueue.TotalItemsPushed, fQueue.TotalItemsPopped]);
      end);
//    InternalDebugLog.Debug('Task Started: Queue Size=%d (Capacity=%d); TotalItemsPushed=%d; TotalItemsPopped=%d .', [fQueue.QueueSize, fQueueLen, fQueue.TotalItemsPushed, fQueue.TotalItemsPopped]);
  end;
end;

initialization
  TLogManager.RegisterLogKind(LOG_KIND_ASYNC,  TAsyncLogger);
  TLogManager.RegisterLogKind(LOG_KIND_THREAD, TThreadSafeLogger);

finalization
  TLogManager.UnRegisterLogKind(LOG_KIND_THREAD);
  TLogManager.UnRegisterLogKind(LOG_KIND_ASYNC);

end.
