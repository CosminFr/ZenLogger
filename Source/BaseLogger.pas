unit BaseLogger;
(***********************************************************************************************************************

  Basic implementation for ILogger interface.

  TAbstractLogger
  ================
  As the name suggests, this is an ABSTRACT class without an implementation for the main method:
    * WriteLog(const Line:string); virtual; abstract;
  However, it handles the various overloads and boring level functions.
    * WriteLogLine(LineType, MsgText) - checks log level for that LineType & formats log line to be sent to the log
       > WriteLog( FormatDateTime('hh:mm:ss.zzz', Now()) + LOG_TYPE_NAME[LineType] + MsgText );
       The date part is missing intentionally as it's part of the file name!
       See TThreadSafeLogger or TTraceLogger for other samples of log line templates
    * WriteLogLineFmt(LineType, MsgText, Args) - minor variation of the above
    * LogKindName - class function - please override if making other loggers to give a unique name for that kind/class
    * InternalDebugLog - use it for debugging as needed.
        -> Console logger if in DEBUG mode
        -> NUll logger otherwise

  TNullLogger
  ================
  Overrides some the methods just to ensure it does nothing!
  Maybe a bit over the top. Any log with LogLevel=0 would behave the same.

  TConsoleLogger
  ================
  Uses IsConsoleApp function to detect if the Std_Output_Handle is valid (once on create).
    # if available sends the log message to the console with "WriteLn(Line)"

************************************************************************************************************************
Developer: Cosmin Frentiu
Licence:   GPL v3
Homepage:  https://github.com/CosminFr/ZenLogger
***********************************************************************************************************************)
interface

uses
  Winapi.Windows, System.SysUtils, System.IOUtils, System.Types,
  ZenLogger;

type
  TAbstractLogger = class(TInterfacedObject, ILogger)
  protected
    fLogLevel  : Integer;
    fDebugLog  : ILogger;

    {$REGION '// Setters & Getters'}
    function  GetLogLevel: Integer;
    procedure SetLogLevel(const Value: Integer);
    {$ENDREGION}

    procedure LoadConfig(const aLogOptions: TLogConfig = nil); virtual;
    /// WriteLog = send line to the log !!! Abstract = MUST be implemented in descendants!
    procedure WriteLog(const Line:string); virtual; abstract;
    /// WriteLogLine* - check log level & format log line to be sent to the log
    procedure WriteLogLine(const LineType:TLogLineType; const MsgText :string); virtual;
    procedure WriteLogLineFmt(const LineType:TLogLineType; const MsgText :string; const Args: array of const); virtual;

    function  TrimPad(const aText: String; aSize: Integer = 10) : String;

    function  InternalDebugLog: ILogger;  virtual;
  public
    constructor Create(const aConfig: TLogConfig = nil); virtual;
    destructor  Destroy; override;

    class function LogKindName: String; virtual;

    procedure Error  (const MsgText: String);  overload;
    procedure Warning(const MsgText: String);  overload;
    procedure Info   (const MsgText: String);  overload;
    procedure Debug  (const MsgText: String);  overload;
    procedure Trace  (const MsgText: String);  overload;

    procedure Error  (const MsgText: String; const E: Exception);     overload;
    procedure Error  (const MsgText: String; const Args: array of const);  overload;
    procedure Warning(const MsgText: String; const Args: array of const);  overload;
    procedure Info   (const MsgText: String; const Args: array of const);  overload;
    procedure Debug  (const MsgText: String; const Args: array of const);  overload;
    procedure Trace  (const MsgText: String; const Args: array of const);  overload;

    procedure Flush; virtual;

    property  LogLevel : Integer read GetLogLevel write SetLogLevel;
  end;
  TLoggerClass = class of TAbstractLogger;

  TNullLogger = class(TAbstractLogger)
  protected
    procedure LoadConfig(const LogOptions: TLogConfig = nil); override;
    procedure WriteLog(const Line:string); override;
    procedure WriteLogLine(const LineType:TLogLineType; const MsgText :string); override;
    procedure WriteLogLineFmt(const LineType:TLogLineType; const MsgText :string; const Args: array of const); override;
  public
    class function LogKindName: String; override;
  end;

  TConsoleLogger = class(TAbstractLogger)
  protected
    bConsoleUsable : Boolean;
    function  IsConsoleApp : Boolean;
    procedure LoadConfig(const LogOptions: TLogConfig = nil); override;
    procedure WriteLog(const Line:string); override;
    function  InternalDebugLog: ILogger;  override;
  public
    class function LogKindName: String; override;
  end;

implementation

{ TBaseLogger }

constructor TAbstractLogger.Create(const aConfig: TLogConfig = nil);
begin
  inherited Create();
  fDebugLog  := nil;
  LoadConfig(aConfig);
end;

destructor TAbstractLogger.Destroy;
begin
  //
  fDebugLog := nil;
  inherited;
end;

procedure TAbstractLogger.LoadConfig(const aLogOptions: TLogConfig = nil);
begin
  if Assigned(aLogOptions) then
    fLogLevel := aLogOptions.LogLevel
  else
    fLogLevel := Default_LogLevel;
end;

class function TAbstractLogger.LogKindName: String;
begin
  if ClassNameIs('TAbstractLogger') then
    Result := 'Abstract'
  else
    Result := ClassName;
end;

{$REGION '// Setters & Getters'}
function TAbstractLogger.GetLogLevel: Integer;
begin
  Result := fLogLevel;
end;

procedure TAbstractLogger.SetLogLevel(const Value: Integer);
begin
  if fLogLevel <> Value then begin
    fLogLevel := Value;
    Info('LogLevel = %d', [fLogLevel]);
  end;
end;
{$ENDREGION}

procedure TAbstractLogger.WriteLogLine(const LineType: TLogLineType; const MsgText:string);
begin
  if fLogLevel >= Ord(LineType) then
    try
      WriteLog( FormatDateTime('hh:mm:ss.zzz', Now()) + LOG_TYPE_NAME[LineType] + MsgText );
    except
      on E:Exception do begin
        OutputDebugString(PChar(Format('Error writing to log "%s %s": %s', [LOG_TYPE_NAME[LineType], MsgText, E.Message])));
        InternalDebugLog.Error('Error writing to log "%s %s": %s', [LOG_TYPE_NAME[LineType], MsgText, E.Message]);
      end;
    end;
end;

procedure TAbstractLogger.WriteLogLineFmt(const LineType: TLogLineType; const MsgText: string; const Args: array of const);
begin
  if fLogLevel >= Ord(LineType) then
    WriteLogLine(LineType, Format(MsgText , Args));
end;

{$REGION '// Interface Level functions'}
procedure TAbstractLogger.Error(const MsgText: String);
begin
  WriteLogLine(ltError, MsgText);
end;

procedure TAbstractLogger.Error(const MsgText: String; const Args: array of const);
begin
  WriteLogLineFmt(ltError, MsgText, Args);
end;

procedure TAbstractLogger.Error(const MsgText: String; const E: Exception);
begin
  Error('%s: [%s] %s', [MsgText, E.ClassName, E.Message]);
end;

procedure TAbstractLogger.Warning(const MsgText: String);
begin
  WriteLogLine(ltWarning, MsgText);
end;

procedure TAbstractLogger.Warning(const MsgText: String; const Args: array of const);
begin
  WriteLogLineFmt(ltWarning, MsgText, Args);
end;

procedure TAbstractLogger.Info(const MsgText: String);
begin
  WriteLogLine(ltInfo, MsgText);
end;

procedure TAbstractLogger.Info(const MsgText: String; const Args: array of const);
begin
  WriteLogLineFmt(ltInfo, MsgText, Args);
end;

procedure TAbstractLogger.Debug(const MsgText: String);
begin
  WriteLogLine(ltDebug, MsgText);
end;

procedure TAbstractLogger.Debug(const MsgText: String; const Args: array of const);
begin
  WriteLogLineFmt(ltDebug, MsgText, Args);
end;

procedure TAbstractLogger.Trace(const MsgText: String);
begin
  WriteLogLine(ltTrace, MsgText);
end;

procedure TAbstractLogger.Trace(const MsgText: String; const Args: array of const);
begin
  WriteLogLineFmt(ltTrace, MsgText, Args);
end;

procedure TAbstractLogger.Flush;
begin
  //Nothing to do in Base!
end;
{$ENDREGION}

function TAbstractLogger.TrimPad(const aText: String; aSize: Integer): String;
var diff : Integer;
begin
  diff := Length(aText) - aSize;
  if diff < 0 then
    Result := aText + StringOfChar('.', -diff)     //less than => pad right
  else if diff > 0 then
    Result := '~' + Copy(aText, diff, aSize)       //too big   => trim left
  else
    Result := aText                                //same size => do nothing
end;

function TAbstractLogger.InternalDebugLog: ILogger;
begin
  if not Assigned(fDebugLog) then begin
{$IFDEF DEBUG}
    fDebugLog := TConsoleLogger.Create;
    fDebugLog.LogLevel := 5;
{$ELSE}
    fDebugLog := TNullLogger.Create;
{$ENDIF}
  end;
  Result := fDebugLog;
end;


{ TNullLogger }

procedure TNullLogger.LoadConfig(const LogOptions: TLogConfig = nil);
begin
  fLogLevel := 0;
end;

class function TNullLogger.LogKindName: String;
begin
  Result := 'Null';
end;

procedure TNullLogger.WriteLog(const Line: string);
begin
  //Do Nothing
end;

procedure TNullLogger.WriteLogLine(const LineType: TLogLineType; const MsgText: string);
begin
  //Do Nothing
end;

procedure TNullLogger.WriteLogLineFmt(const LineType: TLogLineType; const MsgText: string; const Args: array of const);
begin
  //Do Nothing
end;

{ TConsoleLogger }

class function TConsoleLogger.LogKindName: String;
begin
  Result := 'Console';
end;

function TConsoleLogger.InternalDebugLog: ILogger;
begin
  if not Assigned(fDebugLog) then
    fDebugLog := TNullLogger.Create;
  Result := fDebugLog;
end;

function TConsoleLogger.IsConsoleApp: Boolean;
var
  Stdout : THandle;
begin
  Stdout := GetStdHandle(Std_Output_Handle);
  Result := (Stdout <> Invalid_Handle_Value) and (Stdout <> 0);
end;

procedure TConsoleLogger.LoadConfig(const LogOptions: TLogConfig = nil);
begin
  inherited;
  bConsoleUsable := IsConsoleApp;
end;

procedure TConsoleLogger.WriteLog(const Line: string);
begin
  if bConsoleUsable then
    WriteLn(Line)
  else
    OutputDebugString(PChar(Line));
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



