program MultiThreadZenLoggerDemo;

uses
{$IFDEF USE_FASTMM5}
  FastMM5,
{$ENDIF }
  Vcl.Forms,
  MainDemoMultiThread in 'MainDemoMultiThread.pas' {frmMain},
  uLoggerTestThread in 'uLoggerTestThread.pas',
  ZenLogger in '..\..\Source\ZenLogger.pas',
  ZenProfiler in '..\..\Source\ZenProfiler.pas',
  LogManager in '..\..\Source\LogManager.pas',
  LogFileStream in '..\..\Source\LogFileStream.pas',
  BaseLogger in '..\..\Source\BaseLogger.pas',
  FileLogger in '..\..\Source\FileLogger.pas',
  AsyncLogger in '..\..\Source\AsyncLogger.pas',
  MockLogger in '..\..\Source\MockLogger.pas',
  Faker in 'Faker.pas';

{$R *.res}

begin
  InitializeLogger();
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
