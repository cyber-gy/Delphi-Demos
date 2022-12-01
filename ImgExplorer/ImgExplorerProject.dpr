program ImgExplorerProject;

uses
  Vcl.Forms,
  MainFormUnit in 'src\MainFormUnit.pas' {MainForm},
  ThmbObj in 'src\ThmbObj.pas',
  SyncCntnrs in 'src\utils\SyncCntnrs.pas',
  FileThrd in 'src\threads\FileThrd.pas',
  MngThrd in 'src\threads\MngThrd.pas';

{$R *.res}

begin
  ReportMemoryLeaksOnShutdown := True;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
