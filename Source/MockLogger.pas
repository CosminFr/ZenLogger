unit MockLogger;
(***********************************************************************************************************************

  TMockLogger
  =================
  Can be used for unit testing where the a log file is not needed. Instead, the mock logger fires events!

  The client application needs to register for notifications -if/when interested:
    * RegisterMockHandler
    * UnregisterMockHandler
    * ClearHandlers

  Protected function overriden from the Abstract logger:
    * WriteLog(Line)                  - empty implementation (raises an EAssertionFailed exception!)
    * WriteLogLine(LineType, MsgText) - fires the registered events


  TMockLogEvent
  ================
  Signature to register for mock log events:
    > procedure(const LineType:TLogLineType; const MsgText :string) of object;

  Where TLogLineType defined in ZenLogger.pas as:
    > TLogLineType = (ltNone, ltError, ltWarning, ltInfo, ltDebug, ltTrace);


************************************************************************************************************************
Developer: Cosmin Frentiu
Licence:   GPL v3
Homepage:  https://github.com/CosminFr/ZenLogger
***********************************************************************************************************************)
interface

uses
  Winapi.Windows,
  System.SysUtils,
  System.Generics.Collections,
  ZenLogger, BaseLogger;


type
  TMockLogEvent = procedure(const LineType:TLogLineType; const MsgText :string) of object;

  TMockLogger = class(TAbstractLogger, ILogger)
  private
    class var CNotifyList : TList<TMockLogEvent>;
    class constructor ClassCreate;
    class destructor  ClassDestroy;
  protected
    procedure WriteLog(const Line:string); override;
    procedure WriteLogLine(const LineType:TLogLineType; const MsgText :string); override;
  public
    class procedure RegisterMockHandler(const aHandler: TMockLogEvent);
    class procedure UnregisterMockHandler(const aHandler: TMockLogEvent);
    class procedure ClearHandlers();
  end;


implementation

uses
  LogManager;

{ TMockLogger }

class constructor TMockLogger.ClassCreate;
begin
  CNotifyList := TList<TMockLogEvent>.Create;
  TLogManager.RegisterLogKind(LOG_KIND_MOCK, TMockLogger);
end;

class destructor TMockLogger.ClassDestroy;
begin
  FreeAndNil(CNotifyList);
  TLogManager.UnRegisterLogKind(LOG_KIND_MOCK);
  inherited;
end;

class procedure TMockLogger.RegisterMockHandler(const aHandler: TMockLogEvent);
begin
  if Assigned(aHandler) then
    CNotifyList.Add(aHandler);
end;

class procedure TMockLogger.UnregisterMockHandler(const aHandler: TMockLogEvent);
begin
  CNotifyList.Remove(aHandler);
end;

class procedure TMockLogger.ClearHandlers;
begin
  CNotifyList.Clear;
end;


procedure TMockLogger.WriteLog(const Line: string);
begin
  Assert(False, 'TMockLogger should use WriteLogLine for sending the LineType!');
  InternalDebugLog.Error('TMockLogger.WriteLog - Should not come here!!! %s', [Line]);
end;

procedure TMockLogger.WriteLogLine(const LineType: TLogLineType; const MsgText:string);
var
  lEvent : TMockLogEvent;
begin
  if LogLevel >= Ord(LineType) then
    for lEvent in CNotifyList do
      try
        lEvent(LineType, MsgText);
      except
      end;
end;


end.

