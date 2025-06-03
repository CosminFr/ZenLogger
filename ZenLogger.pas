unit ZenLogger;
(***********************************************************************************************************************

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

  Note: Use GetTraceLogger(...).Trace; to gather stats for the function regardless of the log level.
      ~ This should be used with caution and only while needed.


************************************************************************************************************************
Developer: Cosmin Frentiu
Licence:   GPL v3
Homepage:  https://github.com/CosminFr
***********************************************************************************************************************)
interface

uses
  Winapi.Windows, System.SysUtils, System.IOUtils, System.Threading;

type
  TLogLineType = (ltNone, ltError, ltWarning, ltInfo, ltDebug, ltTrace);

const
  LOG_TYPE_NAME : array [TLogLineType] of String = ('', ' ERROR..... ', ' WARNING... ', ' INFO...... ', ' DEBUG..... ', ' TRACE..... ');

  LOG_KIND_NULL     = 0;
  LOG_KIND_STANDARD = 1;
  LOG_KIND_CONSOLE  = 2;
  LOG_KIND_ASYNC    = 3;
  LOG_KIND_THREAD   = 4;
  LOG_KIND_MOCK     = 5;

  LL_ERROR          = 1;
  LL_WARNING        = 2;
  LL_INFO           = 3;
  LL_DEBUG          = 4;
  LL_TRACE          = 5;

  LOG_EXTENSION     = '.log';
  PRODUCT_NAME      = 'ZenLogger';


type
  TLogConfig = class
  private
    fLogLevel : Integer;
  public
    constructor Create(const aLogLevel: Integer = LL_INFO);

    property  LogLevel : Integer read fLogLevel  write fLogLevel;
  end;

  ILogger = interface
    procedure Error  (const MsgText: String);  overload;
    procedure Warning(const MsgText: String);  overload;
    procedure Info   (const MsgText: String);  overload;
    procedure Debug  (const MsgText: String);  overload;
    procedure Trace  (const MsgText: String);  overload;
    procedure Error  (const MsgText: String; const E: Exception);         overload;
    procedure Error  (const MsgText: String; const Args: array of const); overload;
    procedure Warning(const MsgText: String; const Args: array of const); overload;
    procedure Info   (const MsgText: String; const Args: array of const); overload;
    procedure Debug  (const MsgText: String; const Args: array of const); overload;
    procedure Trace  (const MsgText: String; const Args: array of const); overload;

    procedure Flush;
    procedure LoadConfig(const aConfig: TLogConfig);

    {$REGION '// Setters & Getters'}
    function  GetLogLevel: Integer;
    procedure SetLogLevel(const Value: Integer);
    {$ENDREGION}

    property  LogLevel : Integer read GetLogLevel write SetLogLevel;
  end;

  IFileLogger = interface(ILogger)
    {$REGION '// Setters & Getters'}
    function  GetLogPath: String;
    procedure SetLogPath(const Value: String);
    function  GetLogName: String;
    procedure SetLogName(const Value: String);
    function  GetLogFileName: string;
    function  GetLogLevel: Integer;
    procedure SetLogLevel(const Value: Integer);
    function  GetDaysKeep: Integer;
    procedure SetDaysKeep(const Value: Integer);
    {$ENDREGION}

    property  LogPath     : String  read GetLogPath     write SetLogPath;
    property  LogName     : String  read GetLogName     write SetLogName;
    property  LogFileName : String  read GetLogFileName;
    property  LogLevel    : Integer read GetLogLevel    write SetLogLevel;
    property  DaysKeep    : Integer read GetDaysKeep    write SetDaysKeep;

  end;


  ITraceLogger = interface(ILogger)
    function Trace: ILogger;
  end;

var
  Default_LogKind  : Integer;
  Default_LogName  : String;
  Default_LogPath  : String;
  Default_LogLevel : Integer;
  Default_DaysKeep : Integer;

//Set default Log options & create global instance (if not exists yet)
procedure InitializeLogger(aLogKind: Integer = -1; aLogLevel: Integer = -1; aLogName: String = ''; aLogPath: String = ''; aDaysKeep: Integer = -1);
procedure ReleaseLogger;

function  Log: ILogger;

function  GetLogger(aKind: Integer = -1; const aConfig : TLogConfig = nil) : ILogger;
procedure SetLogger(aLogger : ILogger);

function  GetTraceLogger(const aProcName : String; const aLogger: ILogger = nil): ITraceLogger; overload;
function  GetTraceLogger(const aClassName, aProcName : String; const aLogger: ILogger = nil): ITraceLogger; overload;

implementation

uses
  LogManager;

var
  _Log_Instance : ILogger = nil;


procedure InitializeLogger(aLogKind: Integer = -1; aLogLevel: Integer = -1; aLogName: String = ''; aLogPath: String = ''; aDaysKeep: Integer = -1);
var
  AppName : String;
begin
  if aLogKind > -1 then
    Default_LogKind  := aLogKind;
  if aLogLevel > -1 then
    Default_LogLevel := aLogLevel;
  if aLogName <> '' then
    Default_LogName  := aLogName;
  if aLogPath <> '' then
    Default_LogPath  := aLogPath;
  if aDaysKeep > -1 then
    Default_DaysKeep := aDaysKeep;

  if (Default_LogName = '') or (Default_LogPath = '') then begin
    AppName    := GetModuleName(HInstance);

    if Default_LogName = '' then
      Default_LogName := TPath.GetFileNameWithoutExtension(AppName);

    if Default_LogPath = '' then begin
      Default_LogPath := TPath.GetDirectoryName(AppName);
      if Default_LogPath = '' then
        Default_LogPath := IncludeTrailingPathDelimiter(TPath.GetHomePath()) + PRODUCT_NAME;
    end;
    ForceDirectories(Default_LogPath);
  end;

  if not Assigned(_Log_Instance) then begin
    _Log_Instance := GetLogger();
  end;
end;

procedure ReleaseLogger;
begin
  try
    _Log_Instance := nil;
  except
  end;
end;

function Log: ILogger;
begin
  if not Assigned(_Log_Instance) then
    _Log_Instance := GetLogger();
  Result := _Log_Instance;
end;

function  GetLogger(aKind: Integer = -1; const aConfig : TLogConfig = nil) : ILogger; overload;
begin
  if aKind < 0 then
    aKind := Default_LogKind;
  Result := TLogManager.GetLogger(aKind, aConfig);
end;

procedure SetLogger(aLogger : ILogger);
begin
  if aLogger <> _Log_Instance then begin
    if Assigned(_Log_Instance) then
      ReleaseLogger;
    _Log_Instance := aLogger;
  end;
end;

function  GetTraceLogger(const aProcName : String; const aLogger: ILogger = nil): ITraceLogger; overload;
begin
  Result := TLogManager.GetTraceLogger(aProcName, aLogger);
end;

function  GetTraceLogger(const aClassName, aProcName : String; const aLogger: ILogger = nil): ITraceLogger; overload;
begin
  Result := TLogManager.GetTraceLogger(aClassName+'.'+aProcName, aLogger);
end;

{ TLogConfig }

constructor TLogConfig.Create(const aLogLevel: Integer);
begin
  inherited Create;
  fLogLevel := aLogLevel;
end;

initialization
  Default_LogKind  := LOG_KIND_STANDARD;
  Default_LogName  := '';
  Default_LogPath  := '';
  Default_LogLevel := LL_INFO;
  Default_DaysKeep := 30;

finalization
  ReleaseLogger;
end.
