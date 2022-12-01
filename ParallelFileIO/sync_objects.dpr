program sync_objects;

uses
  Vcl.Forms,
  Unit1 in 'Unit1.pas' {MainForm},
  FileThreads in 'FileThreads.pas',
  ShrdObj in 'ShrdObj.pas',
  SyncCntnrs in 'SyncCntnrs.pas';

{$R *.res}

begin
  ReportMemoryLeaksOnShutdown := True;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
