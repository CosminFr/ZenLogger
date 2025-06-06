unit LogManager;
(***********************************************************************************************************************

  TLogKindRegistry
  ================
  A simple Dictionary with an Integer Key (LogKind) and the registred class TLoggerClass
    > TLogKindRegistry = TDictionary<Integer, TLoggerClass>;
  See main form in "Demo/Multi Thread" how a combo box is initialized with the registered classes.
  Tip: uses TLoggerClass.LogKindName to display a friendlier name (otherwise TLoggerClass.ClassName)


  TLogManager
  ================
  Don't instantiete! Always use as class.
  It has three methods for <Log Kind> registration:
    * RegisterLogKind   - registers <aKind> implementation so it can be instantiated later.
    * UnRegisterLogKind - un-register the class;
    * LogKindRegistry   - Allows access to the TLogKindRegistry dictionary.

  It has (currently) two functions to create loggers:
    * GetLogger(aKind, aConfig = nil)
           - the generic use - aKind should be previously registered!
           - see the initialization section where some pre-defined classes are registered, forcing specific logger kinds
           - Other loggers (ex AsyncLogger.pas) have to be included in the project to register themselves
    * GetTraceLogger(aContext, aLogger = nil): ITraceLogger;
           - Specific call for the Trace Logger as it returns a ITraceLogger
           - TraceLogger has usually a very limited scope!
           - see ZenProfiler.pas for details

    TBC - if a GetFileLogger should be added to return IFileLogger (has few additional properties)
        - (for now) they should be used as all other loggers just through ILogger interface.


************************************************************************************************************************
Developer: Cosmin Frentiu
Licence:   GPL v3
Homepage:  https://github.com/CosminFr/ZenLogger
***********************************************************************************************************************)
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
