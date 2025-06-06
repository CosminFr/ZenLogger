program SortingDemo;

uses
{$IFDEF USE_FASTMM5}
  FastMM5,
{$ENDIF }
  Vcl.Forms,
  MainSortDemo in 'MainSortDemo.pas' {frmSortDemo},
  SortThreads in 'SortThreads.pas',
  ZenLogger in '..\..\Source\ZenLogger.pas',
  ZenProfiler in '..\..\Source\ZenProfiler.pas',
  LogManager in '..\..\Source\LogManager.pas',
  LogFileStream in '..\..\Source\LogFileStream.pas',
  BaseLogger in '..\..\Source\BaseLogger.pas',
  FileLogger in '..\..\Source\FileLogger.pas',
  AsyncLogger in '..\..\Source\AsyncLogger.pas',
  PaintArray in 'PaintArray.pas';

{$R *.res}

begin
  InitializeLogger(LOG_KIND_STANDARD, LL_DEBUG, '', '', 1);
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmSortDemo, frmSortDemo);
  Application.Run;
end.
