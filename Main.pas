unit Main;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ComCtrls, Vcl.StdCtrls, uDiag,
  uJ2534_v2, uWBO, Vcl.CheckLst;

type
  TMainForm = class(TForm)
    StatusBar1: TStatusBar;
    PageControl1: TPageControl;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    ComboBoxDll: TComboBox;
    ComboBoxDiag: TComboBox;
    CheckListBoxDiag: TCheckListBox;
    Memo1: TMemo;
    ButtonConnect: TButton;
    Button1: TButton;
    ButtonSetDiag: TButton;
    ButtonStartDiag: TButton;
    ButtonStopDiag: TButton;
    ComboBox1: TComboBox;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure ButtonConnectClick(Sender: TObject);
    procedure ButtonSetDiagClick(Sender: TObject);
  private
    { Private declarations }
    StringListDll: TstringList;
    J2534: TJ2534_v2;
    Diag: TDiag;
    Wbo: TuWBO;
    procedure create_class_j2534;
    procedure check_adapter_j2534;
    procedure create_diag_class;
    procedure create_class_wbo;
    procedure get_list_param;
    procedure StartDiag;
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

  if Wbo <> nil then
  begin
    FreeAndNil(Wbo);
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
  create_diag_class;
end;

procedure TMainForm.ButtonConnectClick(Sender: TObject);
begin
  create_class_j2534;
  check_adapter_j2534;
end;

procedure TMainForm.ButtonSetDiagClick(Sender: TObject);
begin
  get_list_param;
end;

procedure TMainForm.check_adapter_j2534;
var
  err_number: integer;
  error_description: string;
begin
  Memo1.Lines.Clear;
  if J2534 <> nil then
  begin
    err_number := J2534.PassThruOpen;
    error_description := J2534.GetErrorDescriptions(err_number);
    Memo1.Lines.Add('Open adapter = ' + error_description);
    Memo1.Lines.AddStrings(J2534.PassThrueReadVersion);

    err_number := J2534.PassThruConnect;
    error_description := J2534.GetErrorDescriptions(err_number);
    Memo1.Lines.Add('Connect = ' + error_description);

    err_number := J2534.PassThruStartMsgFilter();
    error_description := J2534.GetErrorDescriptions(err_number);
    Memo1.Lines.Add('Set Msg Filter = ' + error_description);

    err_number := J2534.PassThruDisconnect;
    error_description := J2534.GetErrorDescriptions(err_number);
    Memo1.Lines.Add('Disconnect = ' + error_description);

    err_number := J2534.PassThruClose;
    error_description := J2534.GetErrorDescriptions(err_number);
    Memo1.Lines.Add('Close adapter = ' + error_description);
  end;
end;

procedure TMainForm.create_diag_class;
var
  list_maker: TstringList;
begin
  if J2534 <> nil then
  begin
    Diag := TDiag.Create(False, J2534);
    list_maker := Diag.GetListMaker;
    if list_maker.Count > 0 then
    begin
      ComboBoxDiag.Items.Clear;
      ComboBoxDiag.Items.AddStrings(list_maker);
      ComboBoxDiag.ItemIndex := 0;
    end;
    list_maker.Free;
  end;

end;

procedure TMainForm.create_class_wbo;
begin
  if Wbo = nil then
  begin
    Wbo := TuWBO.Create(True, 1);
  end;
end;

procedure TMainForm.get_list_param;
var
  list_param: TstringList;
  i: integer;
begin
  if Diag <> nil then
    if ComboBoxDiag.ItemIndex >= 0 then
    begin
      CheckListBoxDiag.Items.Clear;
      Diag.CheckListData(ComboBoxDiag.ItemIndex, @Memo1);
      list_param := Diag.GetListParam(ComboBoxDiag.ItemIndex);
      CheckListBoxDiag.Items.AddStrings(list_param);
      for i := 0 to length(Diag.Diag_Struct[ComboBoxDiag.ItemIndex].Systems) - 1 do
        if Diag.Diag_Struct[ComboBoxDiag.ItemIndex].Systems[i].flag_usage = False then
          CheckListBoxDiag.ItemEnabled[i] := False;
      list_param.Free;
    end;

end;

procedure TMainForm.StartDiag;
begin
  Diag.Start();
end;

end.
