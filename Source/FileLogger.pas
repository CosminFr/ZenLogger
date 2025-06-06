unit FileLogger;
(***********************************************************************************************************************

  Basic implementation for ILogger interface.

  TFileLogConfig
  ================
  Extends TLogConfig from ZenLogger (which had the LogLevel) with the file specific options:
    * LogName
    * LogPath
    * DaysKeep

  TFileLogger
  ================
  Implements the STANDARD logger and IFileLogger interface.
  See some sample extensions in AsyncLogger.pas
  If running the Demo apps the Async logger is WAY FASTER. However, in case of issues there is a potential risk that the
  application crashed in a completely different point than what the logger shows.
  With the Standard logger there is a safety in knowing that the application processes are "synchronized" with the log.
  If/when something happens, an up-to-date log file is available. Although, it wont say much if the log level was too low.

  Tip: use Async logger with Info (or lower) levels if performance is a concern.
     & change the kind to Standard and Debug|Trace log levels when investigating an issue.

      {$IFDEF DEBUG}
        InitializeLogger(LOG_KIND_STANDARD, LL_DEBUG);
      {$ELSE}
        InitializeLogger(LOG_KIND_ASYNC, LL_INFO);
      {$ENDIF }

  However, In most cases logging is only a minor part of the processes and consequently, less race conflicts sharing the
  same file. Meaning, the Standard logger is fast enough and a bit safer to indicate up-to-date values.

  Note: All file loggers use the same "LogFile" Stream to safely update the log file.
     -> more details in LogFileStream.pas


************************************************************************************************************************
Developer: Cosmin Frentiu
Licence:   GPL v3
Homepage:  https://github.com/CosminFr/ZenLogger
***********************************************************************************************************************)
interface

uses
  Classes, Windows, SysUtils, IOUtils, Types, SyncObjs, Threading,
  ZenLogger, BaseLogger, LogFileStream;

type
  TFileLogConfig = class(TLogConfig)
  private
    fLogName  : string;
    fLogPath  : string;
    fDaysKeep : Integer;
  public
    constructor Create(const aLogLevel: Integer = LL_INFO; const aLogName: string = '');

    property  LogPath  : String  read fLogPath write fLogPath;
    property  LogName  : String  read fLogName   write fLogName;
    property  DaysKeep : Integer read fDaysKeep  write fDaysKeep;
  end;

  TFileLogger = class(TAbstractLogger, IFileLogger)
  private
    fLogName   : string;
    fLogPath   : string;
    fDaysKeep  : Integer;

    {$REGION '// Setters & Getters'}
    function  GetLogPath: String;
    function  GetLogName: String;
    procedure SetLogPath(const Value: String);
    procedure SetLogName(const Value: String);
    function  GetDaysKeep: Integer;
    procedure SetDaysKeep(const Value: Integer);
    {$ENDREGION}

  protected
    fLogStream : TLogFileStream;

    procedure LoadConfig(const aConfig: TLogConfig = nil); override;
    /// WriteLog - save line to the log file
    procedure WriteLog(const Line:string); override;
    function  GetLogFileName: string; virtual;
    procedure CheckLogName;

    function  InternalDebugLog: ILogger; override;
    procedure DeleteOldFiles;
  public
    constructor Create(const aConfig: TLogConfig = nil); override;
    destructor  Destroy; override;

    class function LogKindName: String; override;

    procedure Flush; override;

    property  LogPath     : String  read GetLogPath     write SetLogPath;
    property  LogName     : String  read GetLogName     write SetLogName;
    property  LogFileName : String  read GetLogFileName;
    property  DaysKeep    : Integer read GetDaysKeep    write SetDaysKeep;

    property  Stream      : TLogFileStream read fLogStream;
  end;
  TFileLoggerClass = class of TFileLogger;

implementation

{ TBaseLogger }

constructor TFileLogConfig.Create(const aLogLevel: Integer = LL_INFO; const aLogName: string = '');
begin
  inherited Create(aLogLevel);
  if aLogName <> '' then
    fLogName := aLogName
  else
    fLogName := Default_LogName;
  //Maybe add these as params...
  fLogPath  := Default_LogPath;
  fDaysKeep := Default_DaysKeep;
end;


{ TFileLogger }

constructor TFileLogger.Create(const aConfig: TLogConfig);
begin
  inherited;
  fLogStream := nil;
end;

destructor TFileLogger.Destroy;
begin
  FreeAndNil(fLogStream);
  inherited;
end;

procedure TFileLogger.LoadConfig(const aConfig: TLogConfig = nil);
var
  AppName : String;
begin
  inherited;
  if aConfig is TFileLogConfig then begin
    fLogName  := TFileLogConfig(aConfig).LogName;
    fLogPath  := TFileLogConfig(aConfig).LogPath;
    fDaysKeep := TFileLogConfig(aConfig).DaysKeep;
  end else begin
    fLogName  := Default_LogName;
    fLogPath  := Default_LogPath;
    fDaysKeep := Default_DaysKeep;
  end;
  AppName    := GetModuleName(HInstance);
  if fLogName = '' then
    fLogName := TPath.GetFileNameWithoutExtension(AppName);

  if fLogPath = '' then begin
    fLogPath := TPath.GetDirectoryName(AppName);
    if fLogPath = '' then
      fLogPath := IncludeTrailingPathDelimiter(TPath.GetHomePath()) + PRODUCT_NAME;
  end;
  ForceDirectories(fLogPath);
  TTask.Run(DeleteOldFiles);
end;

class function TFileLogger.LogKindName: String;
begin
  if ClassNameIs('TFileLogger') then
    Result := 'Standard'
  else
    Result := ClassName;
end;

function TFileLogger.GetLogFileName: string;
begin
  Result := IncludeTrailingPathDelimiter(fLogPath)
            + fLogName + FormatDateTime('_yyyy-mm-dd', Date) + LOG_EXTENSION;
end;

{$REGION '// Setters & Getters'}
function TFileLogger.GetLogPath: String;
begin
  Result := fLogPath;
end;

function TFileLogger.GetLogName: String;
begin
  Result := fLogName;
end;

function TFileLogger.GetDaysKeep: Integer;
begin
  Result := fDaysKeep;
end;

procedure TFileLogger.SetDaysKeep(const Value: Integer);
begin
  fDaysKeep := Value;
end;

procedure TFileLogger.SetLogPath(const Value: String);
begin
  fLogPath := Value;
  CheckLogName;
end;

procedure TFileLogger.SetLogName(const Value: String);
begin
  fLogName := Value;
  CheckLogName;
end;
{$ENDREGION}

procedure TFileLogger.WriteLog(const Line: string);
begin
  CheckLogName;
  Stream.BeginAccess;
  try
    Stream.WriteLine(Line);
  finally
    Stream.EndAccess;
  end;
end;

procedure TFileLogger.Flush;
begin
  if Assigned(fLogStream) then
    fLogStream.Flush;
end;

procedure TFileLogger.CheckLogName;
var
  lName : String;
begin
  lName := GetLogFileName;
  if Assigned(fLogStream) and (fLogStream.FileName <> lName) then begin
    //New file (maybe new day?)
    InternalDebugLog.Debug('New FileName "%s" detected. Closing old file "%s"', [lName, fLogStream.FileName]);
    FreeAndNil(fLogStream);
    TTask.Run(DeleteOldFiles);
  end;
  if not Assigned(fLogStream) then begin
    fLogStream := TLogFileStream.Create(lName);
    InternalDebugLog.Debug('Log Stream created for "%s".', [lName]);
  end;
end;

procedure TFileLogger.DeleteOldFiles;
var
  FileName  : string;
  OlderThan : TDateTime;
begin
  try
    OlderThan := Date() - DaysKeep;
    for FileName in TDirectory.GetFiles(fLogPath, '*.log') do
      if TFile.GetCreationTime(FileName) < OlderThan then
      try
        TFile.Delete(FileName);
      except
      end;
  except
    on E: Exception do
      InternalDebugLog.Error('Error deleting old files: %s', E);
  end;
end;

function TFileLogger.InternalDebugLog: ILogger;
var
  cfg : TFileLogConfig;
begin
  if not Assigned(fDebugLog) then begin
{$IFDEF DEBUG}
    if fLogName <> 'ZenLogger_Debug' then begin
      cfg := TFileLogConfig.Create(5, 'ZenLogger_Debug');
      try
        fDebugLog := TFileLogger.Create(cfg);
      finally
        cfg.Free;
      end;
    end else
{$ENDIF}
      fDebugLog := inherited;
  end;
  Result := fDebugLog;
end;


end.

