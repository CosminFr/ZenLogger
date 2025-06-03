unit FileLogger;

interface

uses
  Winapi.Windows, System.SysUtils, System.IOUtils, System.Types,
  ZenLogger, BaseLogger;

type
  TFileLogConfig = class(TLogConfig)
  private
    fLogName   : string;
    fLogPath : string;
    fDaysKeep  : Integer;
  public
    constructor Create(const aLogLevel: Integer = LL_INFO; const aLogName: string = '');

    property  LogPath : String  read fLogPath write fLogPath;
    property  LogName   : String  read fLogName   write fLogName;
    property  DaysKeep  : Integer read fDaysKeep  write fDaysKeep;
  end;
//  TLogConfigClass = class of TLogConfig;

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
    procedure LoadConfig(const aConfig: TLogConfig = nil); override;
    /// WriteLog - save line to the log file
    procedure WriteLog(const Line:string); override;
    function  GetLogFileName: string; virtual;

    function  InternalDebugLog: ILogger; override;
    procedure DeleteOldFiles;
  public
//    constructor Create(const aLogName: string); virtual;
//    constructor Create(const aConfig: TLogConfig = nil); override;
//    destructor  Destroy; override;

    class function LogKindName: String; override;

    property  LogPath     : String  read GetLogPath     write SetLogPath;
    property  LogName     : String  read GetLogName     write SetLogName;
    property  LogFileName : String  read GetLogFileName;
    property  LogLevel    : Integer read GetLogLevel    write SetLogLevel;
    property  DaysKeep    : Integer read GetDaysKeep    write SetDaysKeep;
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
end;

procedure TFileLogger.SetLogName(const Value: String);
begin
  fLogName := Value;
end;
{$ENDREGION}

procedure TFileLogger.WriteLog(const Line: string);
var
  LogFile : Text;
  Count   : Integer;
  ioRes   : Integer;   //copy of IOResult so it can be logged.
begin
  System.AssignFile(LogFile, LogFileName);
  {$I-}
  //Keep trying to open for writing
  Count := 0;
  while Count < 1000 do begin
    System.Append(LogFile);
    ioRes := IOResult;
    case ioRes of
      0   : Break;
      2   : begin                                //2   = File not found
              System.Rewrite(LogFile);
              {$I+}
              try
                DeleteOldFiles;            //"new day" -> time for cleanup...
              except
                on E:Exception do
                  InternalDebugLog.Debug('Error deleting old files: %s', [E.Message]);
              end;
              {$I-}
              Continue;
            end;
      3   : ForceDirectories(LogPath);         //3   = Path not found
      32  : Sleep(Count *10);                    //32  = Sharing violation
      102 : AssignFile(LogFile, LogFileName);    //102 = File not assigned.
      else  Sleep(1);
    end;
    Inc(Count);
    if ioRes <> 32 then  //skip debug logging an expected condition.
      InternalDebugLog.Debug('Trying to Append... IOResult=%d; Attempt=%d; Class=%s; Obj=%d', [ioRes, Count, ClassName, Integer(Self)]);
  end;
  //Write line
  Writeln(LogFile, Line);
  ioRes := IOResult;
  if ioRes <> 0 then
    InternalDebugLog.Debug('Trying to Write... IOResult=%d; Obj=%d; Line=%s', [ioRes, Integer(Self), Line]);

  System.CloseFile(LogFile);
  ioRes := IOResult;
  if ioRes <> 0 then
    InternalDebugLog.Debug('Trying to CloseFile... IOResult=%d; Obj=%d; Line=%s', [ioRes, Integer(Self), Line]);
  {$I+}
end;

procedure TFileLogger.DeleteOldFiles;
var
  FileName: string;
  OlderThan: TDateTime;
begin
  OlderThan := Trunc(Date() - DaysKeep);
  for FileName in TDirectory.GetFiles(fLogPath, '*.log') do
    if TFile.GetCreationTime(FileName) < OlderThan then
    try
      TFile.Delete(FileName);
    except
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

//IOResult error codes:
//  2 - File not found.
//  3 - Path not found.
//  4 - Too many open files.
//  5 - Access denied.
//  6 - Invalid file handle.
// 12 - Invalid file-access mode.
// 13 - Permission denied
// 15 - Invalid disk number.
// 16 - Cannot remove current directory.
// 17 - Cannot rename across volumes.
// 20 - Not a directory
// 21 - Is a directory
// 32 - Sharing violation
//100 - Error when reading from disk.
//101 - Error when writing to disk.
//102 - File not assigned.
//103 - File not open.
//104 - File not opened for input.
//105 - File not opened for output.
//106 - Invalid number.
//150 - Disk is write protected.
//151 - Unknown device.
//152 - Drive not ready.
//153 - Unknown command.
//154 - CRC check failed.
//155 - Invalid drive specified..
//156 - Seek error on disk.
//157 - Invalid media type.
//158 - Sector not found.
//159 - Printer out of paper.
//160 - Error when writing to device.
//161 - Error when reading from device.
//162 - Hardware failure.



