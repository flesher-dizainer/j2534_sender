unit Main;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ComCtrls, Vcl.StdCtrls, uDiag,
  uJ2534_v2, Vcl.CheckLst;

type
  TMainForm = class(TForm)
    StatusBar1: TStatusBar;
    PageControl1: TPageControl;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    ComboBoxDll: TComboBox;
    ComboBoxDiag: TComboBox;
    CheckListBox1: TCheckListBox;
    Memo1: TMemo;
    ButtonConnect: TButton;
    Button1: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure ButtonConnectClick(Sender: TObject);
  private
    { Private declarations }
    StringListDll: TstringList;
    J2534: TJ2534_v2;
    Diag: TDiag;
    procedure create_class_j2534;
    procedure check_adapter_j2534;
  public
    { Public declarations }
  end;

var
  MainForm: TMainForm;

implementation

{$R *.dfm}

procedure TMainForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  FreeAndNil(StringListDll);
  if Diag <> nil then
  begin
    Diag.Stop;
    Diag.Free;
  end;
  if J2534 <> nil then
  begin
    FreeAndNil(J2534);
  end;
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  StringListDll := uJ2534_v2.GetListDll(@ComboBoxDll.Items);
  if StringListDll.Count > 0 then
    ComboBoxDll.ItemIndex := 0;
  J2534 := nil;
end;

procedure TMainForm.create_class_j2534;
begin
  if J2534 = nil then
    if StringListDll.Count > 0 then
      J2534 := TJ2534_v2.Create(StringListDll[ComboBoxDll.ItemIndex]);
end;

procedure TMainForm.ButtonConnectClick(Sender: TObject);
begin
create_class_j2534;
check_adapter_j2534;
end;

procedure TMainForm.check_adapter_j2534;
var
err_number:integer;
error_description:string;
begin
memo1.Lines.Clear;
  if J2534 <> nil then begin
    err_number:=J2534.PassThruOpen;
    error_description:=J2534.GetErrorDescriptions(err_number);
    memo1.Lines.Add('Open adapter = '+error_description);
    memo1.Lines.AddStrings(J2534.PassThrueReadVersion);

    err_number:=J2534.PassThruConnect;
    error_description:=J2534.GetErrorDescriptions(err_number);
    memo1.Lines.Add('Connect = '+error_description);

    err_number:=J2534.PassThruStartMsgFilter();
    error_description:=J2534.GetErrorDescriptions(err_number);
    memo1.Lines.Add('Set Msg Filter = '+error_description);

    err_number:=J2534.PassThruDisconnect;
    error_description:=J2534.GetErrorDescriptions(err_number);
    memo1.Lines.Add('Disconnect = '+error_description);

    err_number:=J2534.PassThruClose;
    error_description:=J2534.GetErrorDescriptions(err_number);
    memo1.Lines.Add('Close adapter = '+error_description);
  end;

end;

end.
