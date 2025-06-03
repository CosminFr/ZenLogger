program SortingDemo;

uses
{$IFDEF USE_FASTMM5}
  FastMM5,
{$ENDIF }
  Vcl.Forms,
  MainSortDemo in 'MainSortDemo.pas' {frmSortDemo},
  SortThreads in 'SortThreads.pas',
  ZenLogger in '..\..\ZenLogger.pas',
  LogManager in '..\..\LogManager.pas',
  BaseLogger in '..\..\BaseLogger.pas',
  FileLogger in '..\..\FileLogger.pas',
  AsyncLogger in '..\..\AsyncLogger.pas',
  ZenProfiler in '..\..\ZenProfiler.pas',
  PaintArray in 'PaintArray.pas';

{$R *.res}

begin
  InitializeLogger(LOG_KIND_STANDARD, LL_DEBUG, '', '', 1);
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmSortDemo, frmSortDemo);
  Application.Run;
end.
