unit LogFileStream;
(***********************************************************************************************************************

  The unit introduces a very special thread safe TLogFileStream purposely dedicated to log files.

  A stream is notoriously NOT thread safe because while one thread "seeks" a position to read from, another thread
  should not read/write at a different position!

  However, for log writing specific requirements, this log file stream is serialized with [Begin|End]Access functions.
  The log file itself handles serialization between different loggers/apps trying to access the same file through
  "fmShareDenyWrite" access restriction. Though, it should only keep that lock for as little as possible to no block
  other loggers/apps/processes to do what they need to do.


  TLogFileStream
  ================
  Just like TFileStream it is inherited from THandleStream. With few major differences:
    * It does not open the file handle until ready to write to the file.
    * It has specific ShareMode & handles ERROR_SHARING_VIOLATION by waiting (instead of raising errors)
    * It can open the file in append mode, only writing to the end.
    * It can create the file if it does not exists.
    * It offers [Begin|End]Access functions to serialize access from different threads.

  Usage
  -----------------
  1. Create the Log File Stream for a specified file from the Main thread.   This does not open/lock the file!
  2. Always use a try..finally block to get access before writing to the file
          Stream.BeginAccess;
          try
            while fQueue.TotalItemsPushed > fQueue.TotalItemsPopped do
              Stream.WriteLine(fQueue.PopItem);
          finally
            Stream.EndAccess;
          end;
  3. As a "log" file stream, allways append strings with WriteLine function.
     Note: Never tested using seek/read directly, or any other writers.
           Should be fine as long as you keep within the try..finally
           AND reposition to the end [Seek(0, soEnd)] for other threads to continue as they need!


  Critical Sections
  -----------------
    * fAccessCS - protects the Access counter used by [Begin|End]Access functions;
    * fHandleCS - protects the File Handle => only one thread can open || close the file (as needed);
    * fFileCS   - protects the access to the file => only one thread can write to the file between [Begin..EndAccess];


************************************************************************************************************************
Developer: Cosmin Frentiu
Licence:   GPL v3
Homepage:  https://github.com/CosminFr/ZenLogger
***********************************************************************************************************************)
interface

uses
  Classes, Windows, System.SysUtils, System.IOUtils, System.SyncObjs;

type
  TLogFileStream = class(THandleStream)
  private
    fFileName    : string;
    fEncoding    : TEncoding;
    fShareMode   : Word;
    fAccessCount : Integer;
    fAutoFlash   : Boolean;
    fAccessCS    : TCriticalSection;
    fHandleCS    : TCriticalSection;
    fFileCS      : TCriticalSection;
  protected
    procedure DebugLog(aText: String); overload;
    procedure DebugLog(aText: String; const Args: array of const); overload;

  public
    constructor Create(const aFileName: string);
    destructor  Destroy; override;

    procedure BeginAccess;
    procedure EndAccess;

    function  WaitForAccess: Boolean;
    function  HasAccess: Boolean; inline;
    procedure Close;
    procedure Flush;

//    function Read(var Buffer; Count: Longint): Longint; override;
//    function Write(const Buffer; Count: Longint): Longint; override;
//    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;


    procedure WriteLine(const Value: string);

    property FileName  : string  read fFileName;
    property AutoFlash : Boolean read fAutoFlash write fAutoFlash;

  end;

//  TLogWriter = class(TStreamWriter)
//  private
//    FStream: TStream;
//    FEncoding: TEncoding;
//    FNewLine: string;
//    FAutoFlush: Boolean;
//    FOwnsStream: Boolean;
//
//  public
//    constructor Create(const aFileName: string); overload;
//    function IsOpen: Boolean;
//    function FileName: String;
////    property BaseStream: TStream read FStream;
//  end;

implementation

{ TLogFileStream }

constructor TLogFileStream.Create(const aFileName: string);
begin
  fFileName    := aFileName;
  fShareMode   := fmOpenReadWrite or fmShareDenyWrite;
  fHandle      := INVALID_HANDLE_VALUE;
  fAccessCount := 0;
  fEncoding    := TEncoding.UTF8;
  fAccessCS    := TCriticalSection.Create;
  fHandleCS    := TCriticalSection.Create;
  fFileCS      := TCriticalSection.Create;
  fAutoFlash   := True;
end;

destructor TLogFileStream.Destroy;
begin
  Close;
  fFileCS.Free;
  fHandleCS.Free;
  fAccessCS.Free;
  inherited Destroy;
end;

procedure TLogFileStream.Close;
begin
  fHandleCS.Acquire;
  try
    if fHandle <> INVALID_HANDLE_VALUE then begin
      FileClose(fHandle);
      fHandle := INVALID_HANDLE_VALUE;
    end;
  finally
    fHandleCS.Release;
  end;
end;

procedure TLogFileStream.BeginAccess;
begin
  fAccessCS.Acquire;
  try
    Inc(fAccessCount);
  finally
    fAccessCS.Release;
  end;
  if not HasAccess then
    WaitForAccess;
end;

procedure TLogFileStream.EndAccess;
begin
  fAccessCS.Acquire;
  try
    Dec(fAccessCount);
    if fAccessCount = 0 then
      Close
    else if fAutoFlash and (fAccessCount > 0) then
      Flush
    else if fAccessCount < 0 then
      raise Exception.Create('EndAccess without matching BeginAccess!');
  finally
    fAccessCS.Release;
  end;
end;

procedure TLogFileStream.Flush;
begin
  fHandleCS.Acquire;
  try
    if fHandle <> INVALID_HANDLE_VALUE then begin
      FlushFileBuffers(fHandle);
    end;
  finally
    fHandleCS.Release;
  end;
end;

procedure TLogFileStream.DebugLog(aText: String);
begin
  OutputDebugString(PChar(aText));
end;

procedure TLogFileStream.DebugLog(aText: String; const Args: array of const);
begin
  DebugLog(Format(aText, Args));
end;

function TLogFileStream.WaitForAccess: Boolean;
var
  Count : Integer;
  ioRes : Integer;   //copy of IOResult so it can be logged.
begin
  fHandleCS.Acquire;
  try
    //Keep trying to open for writing
    Count := 0;
    while fHandle = INVALID_HANDLE_VALUE do begin
      fHandle := FileOpen(fFileName, fShareMode);
      if fHandle = INVALID_HANDLE_VALUE then
        ioRes := GetLastError()
      else begin
        ioRes := NO_ERROR;
        Seek(0, soEnd);
      end;

      case ioRes of
        NO_ERROR                 : Break;
        ERROR_FILE_NOT_FOUND     : fHandle := FileCreate(fFileName, fmCreate or fShareMode);
        ERROR_PATH_NOT_FOUND     : ForceDirectories(TPath.GetDirectoryName(fFileName));
        ERROR_SHARING_VIOLATION  : Sleep(Count *10);
        else begin
          Sleep(1);
          DebugLog('Trying to open file ... IOResult=%d; Attempt=%d', [ioRes, Count]);
        end;
      end;

      Inc(Count);
      if Count > 100 then  //giving up
        raise EFOpenError.CreateFmt('Failed to open "%s": %s', [ExpandFileName(fFileName), SysErrorMessage(ioRes)]);
    end;
  finally
    fHandleCS.Release;
  end;
  Result := HasAccess;
end;

function TLogFileStream.HasAccess: Boolean;
begin
  fHandleCS.Acquire;
  try
    Result := fHandle <> INVALID_HANDLE_VALUE;
  finally
    fHandleCS.Release;
  end;
end;

//function TLogFileStream.Read(var Buffer; Count: Longint): Longint;
//begin
//  fFileCS.Acquire;
//  try
//    Result := inherited Read(Buffer, Count);
//  finally
//    fFileCS.Release;
//  end;
//end;
//
//function TLogFileStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
//begin
//  fFileCS.Acquire;
//  try
//    Result := inherited Seek(Offset, Origin);
//  finally
//    fFileCS.Release;
//  end;
//end;
//
//function TLogFileStream.Write(const Buffer; Count: Longint): Longint;
//begin
//  fFileCS.Acquire;
//  try
//    Result := inherited Write(Buffer, Count);
//  finally
//    fFileCS.Release;
//  end;
//end;

procedure TLogFileStream.WriteLine(const Value: string);
const CRLF = #13#10;
var
  Buff : TBytes;
begin
  fFileCS.Acquire;
  try
    Buff := fEncoding.GetBytes(Value + CRLF);
    Write(PByte(Buff)^, Length(Buff));
  finally
    fFileCS.Release;
  end;
end;

//{ TLogWriter }
//
//constructor TLogWriter.Create(const aFileName: string);
//begin
//  inherited Create(TLogFileStream.Create(aFileNAme));
//  OwnStream;
//end;
//
//function TLogWriter.FileName: String;
//begin
//  if (BaseStream is TLogFileStream) then
//    Result := TLogFileStream(BaseStream).FileName
//  else
//    Result := '';
//end;
//
//function TLogWriter.IsOpen: Boolean;
//begin
//  Result := (BaseStream is TLogFileStream) and TLogFileStream(BaseStream).HasAccess;
//end;

end.
