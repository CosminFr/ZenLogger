unit AsyncLogger;
(***********************************************************************************************************************

  Extending the Standard File Logger with two more loggers:

  TThreadSafeLogger
  =================
  Name may be a bit misleading as the Standard logger is Thread Safe too. However, this goes a bit more paranoid with
  a Mutex to ensure no other process is even attempting to write in the same time.
  It also changes the "line context" by adding "TH-<CurrentThreadId>" before the message. Thus, making it more clear
  which thread sent that message to the log. Could be quite usefull during investigations and the main reason it's
  still provided.

  TAsyncLogger
  ================
  Changes the default WriteLog behavior by adding the line to a thread safe Queue and launching a backgroud task to
  update the log file.

  Notes:
    * There is no permanent thread running to monitor the queue and do the updates. The background tasks are created
      as needed from default pool. Very fast and not much overhead.
    * As the process can continue as soon as the Line is added to the threaded queue, the impact to app flow is low.
    * Even better, as the Queue might hold more than one line, the file processing times is much improved over the
      "Line by Line" behavior of the Standard logger.

************************************************************************************************************************
Developer: Cosmin Frentiu
Licence:   GPL v3
Homepage:  https://github.com/CosminFr/ZenLogger
***********************************************************************************************************************)
interface

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Generics.Collections,
  System.Threading,
  ZenLogger, FileLogger, LogManager, LogFileStream;

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
  if Assigned(fTask) and (fTask.Status < TTaskStatus.Completed) then
    fTask.Wait;
end;

procedure TAsyncLogger.WriteLog(const Line: string);
begin
  if (fQueue.QueueSize = fQueueLen) then begin
    fQueue.Grow(fQueueLen);
    Inc(fQueueLen, fQueueLen);
    InternalDebugLog.Warning('Queue grown: New Size=%d (Capacity=%d); TotalItemsPushed=%d; TotalItemsPopped=%d .', [fQueue.QueueSize, fQueueLen, fQueue.TotalItemsPushed, fQueue.TotalItemsPopped]);
  end;
  fQueue.PushItem(Line);

  if not Assigned(fTask) or (fTask.Status > TTaskStatus.Running) then begin
    //Start new task to write Line to the log
    fTask := TTask.Run(
      procedure
      begin
        CheckLogName;
        Stream.BeginAccess;
        try
          while fQueue.TotalItemsPushed > fQueue.TotalItemsPopped do
            Stream.WriteLine(fQueue.PopItem);
        finally
          Stream.EndAccess;
        end;
      end);
  end;
end;

initialization
  TLogManager.RegisterLogKind(LOG_KIND_ASYNC,  TAsyncLogger);
  TLogManager.RegisterLogKind(LOG_KIND_THREAD, TThreadSafeLogger);

finalization
  TLogManager.UnRegisterLogKind(LOG_KIND_THREAD);
  TLogManager.UnRegisterLogKind(LOG_KIND_ASYNC);

end.
