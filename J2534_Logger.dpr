program J2534_Logger;

uses
  Vcl.Forms,
  Main in 'Main.pas' {MainForm},
  uDiag in 'uDiag.pas',
  uJ2534_v2 in 'uJ2534_v2.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
