unit Main;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ComCtrls, Vcl.StdCtrls, uDiag,
  uJ2534_v2, uWBO, Vcl.CheckLst, Vcl.ExtCtrls;

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
    CBWbo: TComboBox;
    Button2: TButton;
    CBPortWbo: TComboBox;
    Timer1: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure ButtonConnectClick(Sender: TObject);
    procedure ButtonSetDiagClick(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
  private
    { Private declarations }
    StringListDll: TstringList;
    J2534: TJ2534_v2;
    Diag: TDiag;
    Wbo: TWbo;
    procedure create_class_j2534;
    procedure check_adapter_j2534;
    procedure create_diag_class;
    procedure create_class_wbo;
    procedure get_list_param;
    procedure StartDiag;
    function StrToFloatD(s: string): real; overload;
  public
    { Public declarations }
  end;

var
  MainForm: TMainForm;

implementation

{$R *.dfm}

function TMainForm.StrToFloatD(s: string): real;
begin
  try
    s := StringReplace(s, '.', ',', [rfReplaceAll, rfIgnoreCase]);
    Result := StrToFloat(s);
  except
    s := StringReplace(s, ',', '.', [rfReplaceAll, rfIgnoreCase]);
    Result := StrToFloat(s);
  end;
end;

procedure TMainForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if Assigned(StringListDll) then
    FreeAndNil(StringListDll);

  if Assigned(Diag) then
  begin
    Diag.Stop;
    Diag.Free;
  end;

  if Assigned(J2534) then
    FreeAndNil(J2534);

  if Assigned(Wbo) then
    FreeAndNil(Wbo);

end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  create_class_j2534;
  create_diag_class;
  create_class_wbo;
end;

procedure TMainForm.create_class_j2534;
var
  lListDlls: TDllsInfo;
begin
  if not Assigned(J2534) then
    J2534 := TJ2534_v2.Create;
  ComboBoxDll.Items.Clear;
  lListDlls := J2534.GetNamePathDll;
  ComboBoxDll.Items := lListDlls.NamesAdapter;
  ComboBoxDll.ItemIndex := 0;
  StringListDll := TstringList.Create;
  StringListDll.AddStrings(lListDlls.PathsDll);
end;

procedure TMainForm.Button2Click(Sender: TObject);
begin
  Wbo.Start(CBWbo.ItemIndex, self.CBPortWbo.Text);
  Timer1.Enabled := True;
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

    err_number := J2534.PassThruConnect();
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
  if not Assigned(Wbo) then
    Wbo := TWbo.Create();
  CBWbo.Items := Wbo.GetListWbo;
  if CBWbo.Items.Count > 0 then
    CBWbo.ItemIndex := 0;
  CBPortWbo.Items := Wbo.GetListPorts;
  if CBPortWbo.Items.Count > 0 then
    CBPortWbo.ItemIndex := 0;
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

procedure TMainForm.Timer1Timer(Sender: TObject);
begin
  if Assigned(Wbo) then
  begin
    // if Wbo.NewData then
    StatusBar1.Panels[0].Text := FloatToStr(Wbo.AFR);
    StatusBar1.Panels[1].Text := FloatToStr(Wbo.Lambda);
    StatusBar1.Panels[2].Text := Wbo.MessageWbo;
    if Wbo.NewData then
    begin
      Memo1.Lines.Add(format('message : %s , AFR : %g', [Wbo.MessageWbo, Wbo.AFR]));
      Wbo.NewData := False;
    end;
  end;
end;

end.
