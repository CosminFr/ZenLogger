unit ZenProfiler;
(***********************************************************************************************************************

 Zen Profiler - used with ITraceLogger when the LogLevel is Trace.

  The unit introduces a simple logger interface.

  Logger Kind
  ================
  See LogManager factory unit how to initialize the correct "Kind" of logger for your purposes.
  First 3 are implicit (see BaseLogger), while others are only available if included in the project (showing how to add further custom loggers)
    * Null       - "Empty" logger = ignores all requests
    * Standard   - "Default" (Base) logger = simple file logger & base class for all other loggers
    * Console    - command line programs -> log to the console output | (otherwise) debug messages in Delphi GUI
    + Async      - decouple writing the log file from your application (using TTask from Parallel Programming Library)
    + ThreadSafe - adds thread info to standard message context (aka time & log level)
    + Mock       - TBD - for unit testing

  Logger Interface
  ================
  There are five log levels, each with a specific method to log a message text:
    * Error    - Indicates a serious problem that has caused a failure in part of the application (e.g. exceptions or critical failures)
    * Warning  - Highlights a potential issue or unexpected behavior that isn't immediately harmful but may lead to problems
    * Info     - Provides general operational messages that track the application’s progress
    * Debug    - Gives detailed diagnostic information useful for debugging during development (e.g. internal state changes, variable values)
    * Trace    - The most detailed level, showing step-by-step execution or fine-grained application flow, typically used for in-depth troubleshooting
    ~~~ (each of the above) has an overloaded version with extra Args: ~~~(Msg, Args) = ~~~(Format(Msg, Args))
    * Flush    - push in memory data to the log file (important for Async Kind)

  Getters & Setters for the available properties:
    * LogPath  - Specifies the directory path where log files will be stored
    * LogName  - Sets the base name of the log file. The actual log file with include the date (e.g. LogName_2025-05-23.log).
    * LogLevel - Determines the level of messages to be logged. Messages above this level will be ignored.
    * DaysKeep - Indicates how many days log files should be retained before being deleted (to help manage disk space).


  Logger Config
  ================
  Different loggers may need different details. As a starting base class TLogConfig has only LogLevel.
  However file loggers will need a name, path & retention period (see TFileLogConfig in FileLogger.pas).

  This unit defines the settings required to initialize the global logger (which is assumed to be file based):
    * Default_LogKind  : Integer;
    * Default_LogName  : String;
    * Default_LogPath  : String;
    * Default_LogLevel : Integer;
    * Default_DaysKeep : Integer;
  Use InitializeLogger function at the start of your project to setup or directly set the values BEFORE using Log.


  Trace Logger & Profiling
  ========================
  See ZenProfiler.pas for details.
  Trace Logger is a special kind of method logger that uses another logger to do the output.
    * GetTraceLogger(aProcName            ; aLogger = nil): ITraceLogger;
    * GetTraceLogger(aClassName, aProcName; aLogger = nil): ITraceLogger;
  If the "other" logger is not set, the global Log is assumed and used.

  See "Demo/Sort Algorithms" for usage.
  There are 3 reasons to use this as a local logger in a procedure:
    * adds a "context" to the log message: [<ClassName>.]<ProcName>: <LogMessage>
    * (if LL_TRACE) adds Enter/Exit Trace messages (on create/destroy).
    * (if LL_TRACE) calculates the elapsed time in milliseconds & updates the profiler stats for that context

  Note: Use GetTraceLogger(...).ForceProfile; to gather stats for the function regardless of the log level.
      ~ This should be used with caution and only while needed.

************************************************************************************************************************
Developer: Cosmin Frentiu
Licence:   GPL v3
Homepage:  https://github.com/CosminFr
***********************************************************************************************************************)
interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.SyncObjs, System.Types,
  System.Generics.Collections, System.Generics.Defaults,
//  System.Threading,
  System.Diagnostics,
  ZenLogger, BaseLogger;

type
  TTraceLogConfig = class(TLogConfig)
  private
    fLogger : ILogger;
  public
    constructor Create(const aLogLevel: Integer = LL_INFO; aLogger : ILogger = nil);

    property Logger : ILogger read fLogger write fLogger;
  end;

  TTraceLogger = class(TAbstractLogger, ITraceLogger)
  private
    fLogger  : ILogger;
    fContext : String;
    fProfile : Boolean;
    fTime    : TStopwatch;
  protected
    procedure WriteLog(const Line:string); override;
    procedure WriteLogLine(const LineType:TLogLineType; const MsgText :string); override;
    function  Trace: ILogger;
    procedure DoStartTrace;
    procedure DoStopTrace;
  public
    constructor Create(const aContext: string; const aLogger: ILogger = nil); reintroduce;
    destructor  Destroy; override;
  end;



  TZenProfiler = class
  private
    type
      TStatsData = class
        Count      : Integer;
        MaxTime    : Int64;
        MinTime    : Int64;
        TotalTime  : Int64;
      end;
      TTotalTimeComparer = class(TInterfacedObject, IComparer<TStatsData>)
        function Compare(const Left, Right: TStatsData): Integer;
      end;
    class var _clsDict : TOrderedDictionary<String, TStatsData>;
    class constructor ClassCreate;
    class destructor  ClassDestroy;
    class procedure DoValueNotify(Sender: TObject; const Value: TStatsData; Action: TCollectionNotification);

  protected
    class function  GetDefaultFileName: String;
  public
    class procedure Add(const aKey: String; const aTime: Int64);
    class procedure Report(aFileName: String = '');
    class procedure Reset;
  end;


implementation

uses
  System.IOUtils, System.TimeSpan;

{ TTraceLogConfig }

constructor TTraceLogConfig.Create(const aLogLevel: Integer; aLogger: ILogger);
begin
  inherited Create(aLogLevel);
  fLogger := aLogger;
end;

{ TTraceLogger }

constructor TTraceLogger.Create(const aContext: string; const aLogger: ILogger = nil);
begin
  fContext := aContext;
  fLogger  := aLogger;
  if not Assigned(fLogger) then
    fLogger := ZenLogger.Log();
  fLogLevel := fLogger.LogLevel;
  fProfile := (fLogLevel >= LL_TRACE);
  DoStartTrace;
end;

destructor TTraceLogger.Destroy;
begin
  DoStopTrace;
  inherited;
end;

procedure TTraceLogger.DoStartTrace;
begin
  if fProfile then begin
    fTime := TStopwatch.StartNew;
    fLogger.Trace('>>> %s', [fContext]);
  end;
end;

procedure TTraceLogger.DoStopTrace;
begin
  if fProfile then begin
    fTime.Stop;
    fLogger.Trace('<<< %s (%d ms)', [fContext, fTime.ElapsedMilliseconds]);
    TZenProfiler.Add(fContext, fTime.ElapsedMilliseconds);
  end;
end;

function TTraceLogger.Trace: ILogger;
begin
  if not fProfile then begin
    fProfile := True;
    DoStartTrace;
  end;
  Result := Self;
end;

procedure TTraceLogger.WriteLog(const Line: string);
begin
  //
  InternalDebugLog.Error('Should not come here!!! (Class=%s) %s', [ClassName, Line]);
end;

procedure TTraceLogger.WriteLogLine(const LineType: TLogLineType; const MsgText: string);
var
  sLine : String;
begin
  if fLogger.LogLevel >= Ord(LineType) then begin
    sLine := fContext + ': ' + MsgText;
    case fLogger.LogLevel of
      LL_ERROR   : fLogger.Error(sLine);
      LL_WARNING : fLogger.Warning(sLine);
      LL_INFO    : fLogger.Info(sLine);
      LL_DEBUG   : fLogger.Debug(sLine);
      LL_TRACE   : fLogger.Trace(sLine);
    end;
  end;
end;


{ TZenProfiler }

class constructor TZenProfiler.ClassCreate;
begin
  inherited;
  _clsDict := TOrderedDictionary<String, TStatsData>.Create;
  _clsDict.OnValueNotify := DoValueNotify;
end;

class destructor TZenProfiler.ClassDestroy;
begin
  FreeAndNil(_clsDict);
  inherited;
end;

class procedure TZenProfiler.DoValueNotify(Sender: TObject; const Value: TStatsData; Action: TCollectionNotification);
begin
  if Assigned(Value) and (Action = cnRemoved) then
    Value.Free;
end;

class function TZenProfiler.GetDefaultFileName: String;
var
  AppName : String;
  AppPath : String;
begin
  AppName := GetModuleName(HInstance);
  AppPath := TPath.GetDirectoryName(AppName);
  AppName := TPath.GetFileNameWithoutExtension(AppName);
  Result  := IncludeTrailingPathDelimiter(AppPath) + AppName + '_Profiler.txt';
end;

class procedure TZenProfiler.Add(const aKey: String; const aTime: Int64);
var
  Data : TStatsData;
begin
  if not _clsDict.TryGetValue(aKey, Data) then begin
    Data := TStatsData.Create;
    _clsDict.AddOrSetValue(aKey, Data);
  end;
  Inc(Data.Count);
  if Data.MaxTime < aTime then
    Data.MaxTime := aTime;
  if (Data.MinTime = 0) or (Data.MinTime > aTime) then
    Data.MinTime := aTime;
  Inc(Data.TotalTime, aTime);
end;

class procedure TZenProfiler.Report(aFileName: String = '');
var
  lFile : Text;
  Key   : String;
  Data  : TStatsData;

  function Duration2Text(aDuration: Int64): String;
  begin
    if aDuration < 1000 then
      Result := aDuration.ToString + ' ms'
    else if aDuration < 60000 then
      Result := FloatToStr(aDuration/1000) + ' s'
    else if aDuration < MSecsPerSec * SecsPerHour then  //minutes not hours
      Result := FormatDateTime('nn:ss.zzz', aDuration/MSecsPerDay)
    else if aDuration < MSecsPerDay then
      Result := FormatDateTime('hh:nn:ss.zzz', aDuration/MSecsPerDay)
    else
      Result := TTimeSpan.Create(aDuration* TTimeSpan.TicksPerMillisecond).ToString;
  end;

begin
  if _clsDict.IsEmpty then  //Nothing to report!
    Exit;

  if aFileName = '' then
    aFileName := GetDefaultFileName;

  System.AssignFile(lFile, aFileName);
  System.Rewrite(lFile);
  try
    _clsDict.SortByValues(TTotalTimeComparer.Create);
    for Key in _clsDict.Keys do
      if _clsDict.TryGetValue(Key, Data) then begin
        Writeln(lFile,   '**********************************************************************');
        Writeln(lFile,   'Function: ' + Key);
        Writeln(lFile,   '  Exec Count: ' + Data.Count.ToString);
        Writeln(lFile,   '  Total Time: ' + Duration2Text(Data.TotalTime));

        if Data.Count > 1 then begin
          Writeln(lFile, '    Max Time: ' + Duration2Text(Data.MaxTime));
          Writeln(lFile, '    Min Time: ' + Duration2Text(Data.MinTime));
          Writeln(lFile, '    Avg Time: ' + Duration2Text(Data.TotalTime div Data.Count));
        end;
      end;
  finally
    CloseFile(lFile);
  end;
end;

class procedure TZenProfiler.Reset;
begin
  _clsDict.Clear;
end;

{ TZenProfiler.TTotalTimeComparer }

function TZenProfiler.TTotalTimeComparer.Compare(const Left, Right: TStatsData): Integer;
begin
  Result := Right.TotalTime - Left.TotalTime;
end;

initialization

finalization
  TZenProfiler.Report;

end.
