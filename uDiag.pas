unit uDiag;

interface

uses
  Windows, SysUtils, Classes, uJ2534_v2, StrUtils, IOUtils, Xml.XMLDoc,
  Xml.xmldom,
  Xml.XMLIntf, dialogs, Vcl.StdCtrls;

type
  TParam = record
    name: string; // имя параметра
    offset: integer; // номер в массиве
    type_param: byte; // тип параметра 1-byte, 2-word, 3-byte_flags
    mul: real; // множитель параметра
    add: real; // аддитив параметра
    number_bit: byte; // номер бита в байте
  end;

type
  TSystems = record
    name: string; // имя системы
    flag_usage: boolean; // флаг запрашивать или нет параметр
    request_id: array of byte; // байтовый запрос
    response_id: array of byte; // массив для сравнения идентификатора ответ
    response: array of TParam; // структура данных
  end;

type
  TDiag_Struct = record
    name: string; // то что мы будем видеть например в выпадающем списке
    // массив подсистем. Например STD_OBD. У него много запросов 21xx.
    // По этому у каждого запроса есть ответ.
    Systems: array of TSystems;
  end;

type
  TDiag = class(TThread)
  private
    FResult: boolean;
    J2534_ex: TJ2534_v2; // экзепляр класса диагностики
    RunThread: boolean;
    index_param_diag: integer;
    procedure LoadXmlData;

  protected
    procedure Execute; override;
  public
    Diag_Struct: array of TDiag_Struct;
    procedure CheckListData(number_system: integer; memo: pointer);
    constructor Create(CreateSuspended: boolean; ex_j2534: TJ2534_v2);
    destructor Destroy; override;
    function StrToFloatD(value: string): real;
    procedure Diagnose;
    property Result: boolean read FResult;
    function GetListMaker(): TStringList;
    function GetListParam(number_maker: integer): TStringList;
    function Start(): boolean;
    function Stop(): boolean;
  end;

implementation

procedure TDiag.LoadXmlData;
var
  fileName: TFileName;
  XMLDocument: IXMLDocument;
  maker_count: integer;
  name: String;
  child: IXMLNodeList;
  i, t, s, r: integer;
begin
  fileName := TPath.Combine(ExtractFilePath(ParamStr(0)), 'TDiag.xml');
  XMLDocument := TXMLDocument.Create(nil);
  XMLDocument.Active := True;
  try
    XMLDocument.LoadFromFile(fileName);
    maker_count := XMLDocument.DocumentElement.ChildNodes.Count;

    child := XMLDocument.DocumentElement.ChildNodes;
    for i := 0 to child.Count - 1 do
      if child[i].HasAttribute('maker_name') = True then
      begin
        // системы
        name := child[i].Attributes['maker_name'];
        setlength(Diag_Struct, length(Diag_Struct) + 1);
        Diag_Struct[length(Diag_Struct) - 1].name := name;
        for t := 0 to XMLDocument.DocumentElement.ChildNodes[i]
          .ChildNodes.Count - 1 do
        begin
          // запросы
          setlength(Diag_Struct[i].Systems, length(Diag_Struct[i].Systems) + 1);

          if XMLDocument.DocumentElement.ChildNodes[i].ChildNodes[t]
            .HasAttribute('name') then
            Diag_Struct[i].Systems[t].name :=
              XMLDocument.DocumentElement.ChildNodes[i].ChildNodes[t]
              .Attributes['name']
          else
            Diag_Struct[i].Systems[t].name :=
              XMLDocument.DocumentElement.ChildNodes[i].ChildNodes[t].NodeName;
          { -------------массив запроса---------------- }
          if XMLDocument.DocumentElement.ChildNodes[i].ChildNodes[t]
            .HasAttribute('DataRead') then
            name := XMLDocument.DocumentElement.ChildNodes[i].ChildNodes[t]
              .Attributes['DataRead']
          else
            name := '0';
          setlength(Diag_Struct[i].Systems[t].request_id, length(name) div 2);
          for r := 0 to length(Diag_Struct[i].Systems[t].request_id) - 1 do
            Diag_Struct[i].Systems[t].request_id[r] :=
              StrToInt('$' + name[r * 2 + 1] + name[r * 2 + 2]);
          { --------------массив ответа для сравнения----------------- }
          if XMLDocument.DocumentElement.ChildNodes[i].ChildNodes[t]
            .HasAttribute('Data') then
            name := XMLDocument.DocumentElement.ChildNodes[i].ChildNodes[t]
              .Attributes['Data']
          else
            name := '0';
          setlength(Diag_Struct[i].Systems[t].response_id, length(name) div 2);
          for r := 0 to length(Diag_Struct[i].Systems[t].response_id) - 1 do
            Diag_Struct[i].Systems[t].response_id[r] :=
              StrToInt('$' + name[r * 2 + 1] + name[r * 2 + 2]);
          { --------------------------------------------- }

          for s := 0 to XMLDocument.DocumentElement.ChildNodes[i].ChildNodes[t]
            .ChildNodes.Count - 1 do
          begin
            // структуры ответа
            setlength(Diag_Struct[i].Systems[t].response,
              length(Diag_Struct[i].Systems[t].response) + 1);
            { ------------------------------------------------- }
            if XMLDocument.DocumentElement.ChildNodes[i].ChildNodes[t]
              .ChildNodes[s].HasAttribute('name') then
              name := XMLDocument.DocumentElement.ChildNodes[i].ChildNodes[t]
                .ChildNodes[s].Attributes['name']
            else
              name := XMLDocument.DocumentElement.ChildNodes[i].ChildNodes[t]
                .ChildNodes[s].NodeName;
            Diag_Struct[i].Systems[t].response[s].name := name;
            { ------------------------------------------------- }
            if XMLDocument.DocumentElement.ChildNodes[i].ChildNodes[t]
              .ChildNodes[s].HasAttribute('type') then
              name := XMLDocument.DocumentElement.ChildNodes[i].ChildNodes[t]
                .ChildNodes[s].Attributes['type']
            else
              name := '0';
            Diag_Struct[i].Systems[t].response[s].type_param := StrToInt(name);
            { ------------------------------------------------- }
            if XMLDocument.DocumentElement.ChildNodes[i].ChildNodes[t]
              .ChildNodes[s].HasAttribute('number_data') then
              name := XMLDocument.DocumentElement.ChildNodes[i].ChildNodes[t]
                .ChildNodes[s].Attributes['number_data']
            else
              name := '0';
            Diag_Struct[i].Systems[t].response[s].offset := StrToInt(name);
            { ------------------------------------------------- }
            if XMLDocument.DocumentElement.ChildNodes[i].ChildNodes[t]
              .ChildNodes[s].HasAttribute('number_bit') then
              name := XMLDocument.DocumentElement.ChildNodes[i].ChildNodes[t]
                .ChildNodes[s].Attributes['number_bit']
            else
              name := '0';
            Diag_Struct[i].Systems[t].response[s].number_bit := StrToInt(name);
            { ------------------------------------------------- }
            if XMLDocument.DocumentElement.ChildNodes[i].ChildNodes[t]
              .ChildNodes[s].HasAttribute('mul') then
              name := XMLDocument.DocumentElement.ChildNodes[i].ChildNodes[t]
                .ChildNodes[s].Attributes['mul']
            else
            begin
              XMLDocument.DocumentElement.ChildNodes[i].ChildNodes[t].ChildNodes
                [s].Attributes['mul'] := '1';
              name := '1';
            end;
            Diag_Struct[i].Systems[t].response[s].mul := StrToFloatD(name);
            { ------------------------------------------------- }
            if XMLDocument.DocumentElement.ChildNodes[i].ChildNodes[t]
              .ChildNodes[s].HasAttribute('add') then
              name := XMLDocument.DocumentElement.ChildNodes[i].ChildNodes[t]
                .ChildNodes[s].Attributes['add']
            else
              name := '0';
            Diag_Struct[i].Systems[t].response[s].add := StrToFloatD(name);
            // ----------------------------------------------------------
            XMLDocument.DocumentElement.ChildNodes[i].ChildNodes[t].ChildNodes
              [s].AttributeNodes.Delete('mul_h');
            XMLDocument.DocumentElement.ChildNodes[i].ChildNodes[t].ChildNodes
              [s].AttributeNodes.Delete('mul_l');

            if XMLDocument.DocumentElement.ChildNodes[i].ChildNodes[t]
              .ChildNodes[s].HasAttribute('name') then
              name := XMLDocument.DocumentElement.ChildNodes[i].ChildNodes[t]
                .ChildNodes[s].Attributes['name']
            else
              name := XMLDocument.DocumentElement.ChildNodes[i].ChildNodes[t]
                .ChildNodes[s].NodeName;
            XMLDocument.DocumentElement.ChildNodes[i].ChildNodes[t].ChildNodes
              [s].AttributeNodes.Delete('name');
            XMLDocument.DocumentElement.ChildNodes[i].ChildNodes[t].ChildNodes
              [s].Attributes['name'] := name;
          end;

        end;

      end;
  except
    XMLDocument.Active := False;
    raise Exception.Create('Error Xml Load from File');
  end;
  XMLDocument.SaveToFile('new_xml.xml');
  XMLDocument.Active := False;
end;

function arr_hex_to_str(arr: array of byte; size_pack: integer): string;
var
  i: integer;
begin
  Result := '';
  for i := 0 to size_pack - 1 do
    Result := Result + IntToHex(arr[i], 2) + ' ';
end;

procedure TDiag.CheckListData(number_system: integer; memo: pointer);
var
  i, err: integer;
  system_t: TSystems;
  data: array [0 .. 4127] of byte;
  in_size: cardinal;
  response_str: string;
  req: string;
  mem: ^Tmemo;
begin
  mem := memo;
  if (length(Diag_Struct) >= number_system) and (J2534_ex <> nil) then
  begin
    if length(Diag_Struct[number_system].Systems) > 0 then
    begin
      J2534_ex.PassThruOpen;
      J2534_ex.PassThruConnect;
      J2534_ex.PassThruStartMsgFilter;
      i := 0;
      for system_t in Diag_Struct[number_system].Systems do
      begin
        err := J2534_ex.PassThruWriteMsg(system_t.request_id, $40, 0);
        if err = 0 then
          err := J2534_ex.PassThruReadMsgs(@data[0], @in_size, 500);
        if (err = 0) and (in_size > 0) then
        begin
          response_str := arr_hex_to_str(data, in_size);
          mem^.Lines.add(response_str);

          req := arr_hex_to_str(system_t.response_id,
            length(system_t.response_id));
          if pos(req, response_str) > 0 then
          begin
            Diag_Struct[number_system].Systems[i].flag_usage := True;
          end;

        end;
        inc(i, 1);
      end;
      J2534_ex.PassThruDisconnect;
      J2534_ex.PassThruClose;
    end;

  end;

end;

constructor TDiag.Create(CreateSuspended: boolean; ex_j2534: TJ2534_v2);
begin
  inherited Create(CreateSuspended);
  RunThread := False;
  FResult := False;
  J2534_ex := ex_j2534;
  LoadXmlData;
end;

destructor TDiag.Destroy;
begin
  inherited Destroy;
end;

function TDiag.StrToFloatD(value: string): real;
begin
  try
    value := StringReplace(value, '.', ',', [rfReplaceAll, rfIgnoreCase]);
    Result := StrToFloat(value);
  except
    value := StringReplace(value, ',', '.', [rfReplaceAll, rfIgnoreCase]);
    Result := StrToFloat(value);
  end;
end;

procedure TDiag.Diagnose;
begin
  // Логика диагностики.  Пример:
  try
    // ... Ваш код диагностики ...
    Sleep(1); // Пример задержки для имитации работы

    FResult := True;
  except

    FResult := False;
  end;
end;

procedure TDiag.Execute;
begin
  while RunThread do
    if J2534_ex <> nil then
      Diagnose;
end;

function TDiag.GetListMaker(): TStringList;
var
  i: integer;
begin
  try
    Result := TStringList.Create;
    for i := 0 to length(Diag_Struct) - 1 do
      Result.add(Diag_Struct[i].name);
  except
    raise Exception.Create('Error get list diag structures');
  end;
end;

function TDiag.GetListParam(number_maker: integer): TStringList;
var
  i: integer;
begin
  index_param_diag := number_maker;
  Result := TStringList.Create;
  if number_maker <= length(Diag_Struct) - 1 then
  begin
    if length(Diag_Struct[number_maker].Systems) > 0 then
    begin
      for i := 0 to length(Diag_Struct[number_maker].Systems) - 1 do
        Result.add(Diag_Struct[number_maker].Systems[i].name);
    end;
  end;
end;

function TDiag.Start: boolean;
begin
  if J2534_ex.PassThruOpen = 0 then
    if J2534_ex.PassThruConnect = 0 then
      if J2534_ex.PassThruStartMsgFilter = 0 then
        self.RunThread := True;
  Result := RunThread;
end;

function TDiag.Stop;
begin
  self.RunThread := False;
  self.WaitFor;
  J2534_ex.PassThruDisconnect;
  J2534_ex.PassThruClose;
  Result := True;
end;

end.
