unit ZenProfiler;
(***********************************************************************************************************************

 Zen Profiler - used with ITraceLogger when the LogLevel is Trace.


  IProfileEntry
  ================
  Used by Trace logger to capture the Elapsed time traced.
  May also be used directly from TZenProfiler.Enter(aName).
  Associates the <aName> with a Stopwatch (System.Diagnostics). It has functions to control the it:
    * Reset
    * Start
    * Stop
    * IsRunning
  and the same properties to show the elapsed time as the Stopwatch
    * Elapsed             : TTimeSpan
    * ElapsedMilliseconds : Int64
    * ElapsedTicks        : Int64
    +++ ElapsedAsText - shows the elapsed time in a user friendly manner

  TTraceLogger
  ================
  Trace Logger is a special kind of method logger that uses another logger to do the output.
  See the ITraceLogger and create functions in ZenLogger.pas
    * GetTraceLogger(aProcName            ; aLogger = nil): ITraceLogger;
    * GetTraceLogger(aClassName, aProcName; aLogger = nil): ITraceLogger;
  If the "other" logger is not set, the global Log is assumed and used.

  There are 3 reasons to use this as a local logger in a procedure:
    * adds a "context" to the log message: [<ClassName>.]<ProcName>: <LogMessage>
    * (if LL_TRACE) adds Enter/Exit Trace messages (on create/destroy).
    * (if LL_TRACE) calculates the elapsed time in milliseconds & updates the profiler stats for that context

  Note: Use GetTraceLogger(...).Trace; to gather stats for the function regardless of the log level.


  TZenProfiler
  ================
  Defined as "class singleton". There is no need to create instances. All functions should be accessed from class level.
  See Trace Logger destructor for example. Any time the trace logger is cleaned up (on exiting the function) the time
  spent from its creation is added to the profile statistics for that context.

  Main functions:
    * Add - Collects statistics about that context (Count, [Max|Min|Total] Times)
        > TZenProfiler.Add(aContext, <Elapsed Milliseconds>);
    * Enter - returns a IProfileEntry for direct use (without a Trace Logger).
              Similarly, added to statistics when cleared/out of scope
        > TZenProfiler.Enter(aName): IProfileEntry;
    * Reset - cleans up all the statistics gathered till that point
    * Report(aFileName) - saves the current statistics to the <aFileName>.
        > TZenProfiler.Report - called automatically in the finalization section.
                              - <no file name> => GetDefaultFileName = "<AppName>_Profile.txt"
                              - entries are sorted by Total time (DESC)
    * class constructor/destructor for setup & cleanup

************************************************************************************************************************
Developer: Cosmin Frentiu
Licence:   GPL v3
Homepage:  https://github.com/CosminFr
***********************************************************************************************************************)
interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.SyncObjs, System.Types,
  System.Generics.Collections, System.Generics.Defaults,
  System.Diagnostics, System.TimeSpan,
  ZenLogger, BaseLogger;

type
  IProfileEntry = interface
    procedure Reset;
    procedure Start;
    procedure Stop;

    function IsRunning: Boolean;

    function GetElapsed: TTimeSpan;
    function GetElapsedMilliseconds: Int64;
    function GetElapsedTicks: Int64;
    function GetElapsedAsText: String;

    property Elapsed: TTimeSpan read GetElapsed;
    property ElapsedMilliseconds: Int64 read GetElapsedMilliseconds;
    property ElapsedTicks: Int64 read GetElapsedTicks;
    property ElapsedAsText: String read GetElapsedAsText;
  end;

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
    fProfile : IProfileEntry;
    fTime    : TStopwatch;
  protected
    procedure WriteLog(const Line:string); override;
    procedure WriteLogLine(const LineType:TLogLineType; const MsgText :string); override;
    function  Trace: ILogger;
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
    class function  Enter(const aName: String): IProfileEntry;
  end;


implementation

uses
  System.IOUtils;

type
  TProfileEntry = class(TAbstractLogger, IProfileEntry)
  private
    fName : String;
    fTime : TStopwatch;
    function GetElapsed: TTimeSpan;
    function GetElapsedMilliseconds: Int64;
    function GetElapsedTicks: Int64;
    function GetElapsedAsText: String;
  public
    constructor Create(const aName: string);
    destructor  Destroy; override;

    procedure Reset;
    procedure Start;
    procedure Stop;
    function  IsRunning: Boolean;

    property Elapsed: TTimeSpan read GetElapsed;
    property ElapsedMilliseconds: Int64 read GetElapsedMilliseconds;
    property ElapsedTicks: Int64 read GetElapsedTicks;
    property ElapsedAsText: String read GetElapsedAsText;
  end;



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
  if fLogLevel >= LL_TRACE then begin
    fLogger.Trace('>>> %s', [fContext]);
    fProfile := TZenProfiler.Enter(aContext);
  end;
end;

destructor TTraceLogger.Destroy;
begin
  if Assigned(fProfile) then
    fProfile.Stop;
  if fLogLevel >= LL_TRACE then begin
    if Assigned(fProfile) then
      fLogger.Trace('<<< %s (%s)', [fContext, fProfile.ElapsedAsText])
    else
      fLogger.Trace('<<< %s', [fContext]);
  end;
  fProfile := nil;
  inherited;
end;

function TTraceLogger.Trace: ILogger;
begin
  if not Assigned(fProfile) then
    fProfile := TZenProfiler.Enter(fContext);

  Result := Self;
end;

procedure TTraceLogger.WriteLog(const Line: string);
begin
  Assert(False, 'TTraceLogger should use WriteLog from the associated logger!');
  InternalDebugLog.Error('TTraceLogger.WriteLog - Should not come here!!! %s', [Line]);
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

class function TZenProfiler.Enter(const aName: String): IProfileEntry;
begin
  Result := TProfileEntry.Create(aName);
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

{ TProfileEntry }

constructor TProfileEntry.Create(const aName: string);
begin
  inherited Create;
  fName := aName;
  fTime := TStopwatch.StartNew;
end;

destructor TProfileEntry.Destroy;
begin
  fTime.Stop;
  TZenProfiler.Add(fName, fTime.ElapsedMilliseconds);
  inherited;
end;

function TProfileEntry.GetElapsed: TTimeSpan;
begin
  Result := fTime.Elapsed;
end;

function TProfileEntry.GetElapsedAsText: String;
var
  lTicks : Int64;
begin
  lTicks := GetElapsedTicks;
  if lTicks < 2*TTimeSpan.TicksPerMillisecond then
    Result := Format('%.3f ms', [lTicks / TTimeSpan.TicksPerMillisecond])
  else if lTicks < TTimeSpan.TicksPerSecond then
    Result := Format('%d ms', [lTicks div TTimeSpan.TicksPerMillisecond])
  else if lTicks < TTimeSpan.TicksPerMinute then
    Result := Format('%.3f sec', [lTicks / TTimeSpan.TicksPerSecond])
  else if lTicks < TTimeSpan.TicksPerHour then  //minutes not hours
    Result := FormatDateTime('nn:ss mins', lTicks/TTimeSpan.TicksPerDay)
  else if lTicks < TTimeSpan.TicksPerDay then
    Result := FormatDateTime('hh:nn:ss hours', lTicks/TTimeSpan.TicksPerDay)
  else
    Result := GetElapsed.ToString;  //more than a day... use the TTimeSpan.ToString
end;

function TProfileEntry.GetElapsedMilliseconds: Int64;
begin
  Result := fTime.ElapsedMilliseconds;
end;

function TProfileEntry.GetElapsedTicks: Int64;
begin
  Result := fTime.ElapsedTicks;
end;

function TProfileEntry.IsRunning: Boolean;
begin
  Result := fTime.IsRunning;
end;

procedure TProfileEntry.Reset;
begin
  fTime.Reset;
end;

procedure TProfileEntry.Start;
begin
  fTime.Start;
end;

procedure TProfileEntry.Stop;
begin
  fTime.Stop;
end;

initialization

finalization
  TZenProfiler.Report;

end.
