unit LogManager;

interface

uses
  System.SysUtils, System.Types, System.Generics.Collections,
  ZenLogger, ZenProfiler, BaseLogger, FileLogger;

type
  TLogKindRegistry = TDictionary<Integer, TLoggerClass>;
  TLogManager = class
  private
    class var _clsKindList : TLogKindRegistry;
    class destructor ClassDestroy;
  public
    class procedure RegisterLogKind(aKind : Integer; aClass: TLoggerClass);
    class procedure UnRegisterLogKind(aKind : Integer);
    class function  LogKindRegistry : TLogKindRegistry;

    class function  GetLogger(aKind: Integer; const aConfig : TLogConfig) : ILogger; overload;
    class function  GetTraceLogger(const aContext : String; const aLogger: ILogger = nil): ITraceLogger;
  end;

implementation

{ TLogManager }

class destructor TLogManager.ClassDestroy;
begin
  FreeAndNil(_clsKindList);
end;

class function TLogManager.LogKindRegistry: TLogKindRegistry;
begin
  if not Assigned(_clsKindList) then
    _clsKindList := TLogKindRegistry.Create;
  Result := _clsKindList;
end;

class procedure TLogManager.RegisterLogKind(aKind: Integer; aClass: TLoggerClass);
begin
  LogKindRegistry.AddOrSetValue(aKind, aClass);
end;

class procedure TLogManager.UnRegisterLogKind(aKind: Integer);
begin
  if Assigned(_clsKindList) then
    _clsKindList.Remove(aKind);
end;

class function TLogManager.GetLogger(aKind: Integer; const aConfig : TLogConfig) : ILogger;
var
  logClass : TLoggerClass;
begin
  if LogKindRegistry.TryGetValue(aKind, logClass) then
    Result := logClass.Create(aConfig)
  else
    raise Exception.CreateFmt('Unsupported Logger Kind: %d', [aKind]);
end;

class function TLogManager.GetTraceLogger(const aContext: String; const aLogger: ILogger): ITraceLogger;
begin
  Result := TTraceLogger.Create(aContext, aLogger);
end;


initialization
  //Register pre-defined classes (BaseLogger.pas)
  TLogManager.RegisterLogKind(LOG_KIND_NULL,     TNullLogger);
  TLogManager.RegisterLogKind(LOG_KIND_STANDARD, TFileLogger);
  TLogManager.RegisterLogKind(LOG_KIND_CONSOLE,  TConsoleLogger);

finalization
  TLogManager.UnRegisterLogKind(LOG_KIND_NULL);
  TLogManager.UnRegisterLogKind(LOG_KIND_STANDARD);
  TLogManager.UnRegisterLogKind(LOG_KIND_CONSOLE);


end.
