program MultiThreadZenLoggerDemo;

uses
{$IFDEF USE_FASTMM5}
  FastMM5,
{$ENDIF }
  Vcl.Forms,
  MainDemoMultiThread in 'MainDemoMultiThread.pas' {frmMain},
  uLoggerTestThread in 'uLoggerTestThread.pas',
  ZenLogger in '..\..\ZenLogger.pas',
  LogManager in '..\..\LogManager.pas',
  BaseLogger in '..\..\BaseLogger.pas',
  FileLogger in '..\..\FileLogger.pas',
  AsyncLogger in '..\..\AsyncLogger.pas',
  MockLogger in '..\..\MockLogger.pas',
  Faker in 'Faker.pas';

{$R *.res}

begin
  InitializeLogger();
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
