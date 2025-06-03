unit ZenAsync;

interface

uses
  System.Classes, System.Types, System.SysUtils, System.Threading;

type
  EAsyncException = class(Exception);
  TExceptionProc = reference to procedure(const E: Exception);

  IZenAsync = interface
    function Await   (const aProc: TThreadProcedure): IZenAsync;
    function OnError (const aProc: TExceptionProc)  : IZenAsync;
    function OnAbort (const aProc: TThreadProcedure): IZenAsync;    //same as OnCancel
    function OnCancel(const aProc: TThreadProcedure): IZenAsync;    //same as OnAbort
  end;

/// Run aProc asynchronously and return the IZenAsync interface to specify handlers for done/error/...
///  All event handlers are synchronized to main thread!
function Async(const aProc: TThreadProcedure): IZenAsync; overload;
function Async(const aProc, aDoneProc: TThreadProcedure): IZenAsync; overload;
function Async(const aProc, aDoneProc: TThreadProcedure; const aErrProc : TExceptionProc): IZenAsync;   overload;
function Async(const aProc, aDoneProc: TThreadProcedure; const aErrProc : TExceptionProc; const aCancelProc: TThreadProcedure): IZenAsync;   overload;
function Async(const aProc, aDoneProc, aCancelProc: TThreadProcedure): IZenAsync;   overload;

/// sleeps for a bit before running aProc
///  Same as running Async(procedure begin Sleep(aSleep); end).Await(aProc);
function Delay(const aSleep: Integer; aProc: TThreadProcedure): IZenAsync;

implementation

resourcestring
  rsAsyncEventAssigned = 'Async %s event already assigned';

type
  TZenAsync = class(TInterfacedObject, IZenAsync)
  private
    fAsync   : TThreadProcedure;
    fOnDone  : TThreadProcedure;
    fOnAbort : TThreadProcedure;
    fOnError : TExceptionProc;

  public
    constructor Create(const aProc: TThreadProcedure);
    procedure   AfterConstruction; override;

    function Await   (const aProc: TThreadProcedure): IZenAsync;
    function OnError (const aProc: TExceptionProc)  : IZenAsync;
    function OnAbort (const aProc: TThreadProcedure): IZenAsync;
    function OnCancel(const aProc: TThreadProcedure): IZenAsync;

  end;

{ TZenAsync }

constructor TZenAsync.Create(const aProc: TThreadProcedure);
begin
  inherited Create;
  fAsync := aProc;
end;

procedure TZenAsync.AfterConstruction;
begin
  inherited;
  TTask.Run(procedure
            begin
              try
                fAsync;
                if Assigned(fOnDone) then
                  TThread.Queue(nil, fOnDone);
              except
                on E: EAbort do begin
                  if Assigned(fOnAbort) then
                    TThread.Queue(nil, fOnAbort);
                end;
                on E: Exception do begin
                  if Assigned(fOnError) then
                    TThread.Synchronize(nil, procedure begin fOnError(E) end);
                end;
              end;
            end);
end;

function TZenAsync.Await(const aProc: TThreadProcedure): IZenAsync;
begin
  fOnDone := aProc;
end;

function TZenAsync.OnError(const aProc: TExceptionProc): IZenAsync;
begin
  if Assigned(fOnError) then
    raise Exception.CreateFmt(rsAsyncEventAssigned, ['OnError']);
  fOnError := aProc;
end;

function TZenAsync.OnAbort(const aProc: TThreadProcedure): IZenAsync;
begin
  if Assigned(fOnAbort) then
    raise Exception.CreateFmt(rsAsyncEventAssigned, ['OnAbort']);
  fOnAbort := aProc;
end;

function TZenAsync.OnCancel(const aProc: TThreadProcedure): IZenAsync;
begin
  if Assigned(fOnAbort) then
    raise Exception.CreateFmt(rsAsyncEventAssigned, ['OnCancel']);
  fOnAbort := aProc;
end;


{ Zen Async functions }

function Async(const aProc: TThreadProcedure): IZenAsync;
begin
  Result := TZenAsync.Create(aProc);
end;

function Async(const aProc, aDoneProc: TThreadProcedure): IZenAsync; overload;
begin
  Result := TZenAsync.Create(aProc).Await(aDoneProc);
end;

function Async(const aProc, aDoneProc: TThreadProcedure; const aErrProc : TExceptionProc): IZenAsync;   overload;
begin
  Result := TZenAsync.Create(aProc)
                     .Await(aDoneProc)
                     .OnError(aErrProc);
end;

function Async(const aProc, aDoneProc: TThreadProcedure; const aErrProc : TExceptionProc; const aCancelProc: TThreadProcedure): IZenAsync;   overload;
begin
  Result := TZenAsync.Create(aProc)
                     .Await(aDoneProc)
                     .OnError(aErrProc)
                     .OnCancel(aCancelProc);
end;

function Async(const aProc, aDoneProc, aCancelProc: TThreadProcedure): IZenAsync;   overload;
begin
  Result := TZenAsync.Create(aProc)
                     .Await(aDoneProc)
                     .OnCancel(aCancelProc);
end;

function Delay(const aSleep: Integer; aProc: TThreadProcedure): IZenAsync;
begin
  Result := Async(procedure begin Sleep(aSleep); end).Await(aProc);
end;



end.
