unit uWBO;

interface

uses
  System.Classes, SysUtils, windows, Dialogs, Forms;

type
  TLC_DATA = record
    Port: string;
    LamSensor: string;
    PortOpen: boolean;
  end;

type
  TLcThreat = class(TThread)
    hCOMPort: THandle; // COM-порт
  private
    AEM: boolean; // используется шдк АЕМ
    LC_1: boolean; // используется ШДК LC-1
    VEMS: boolean; // используется ШДК АЕМ
    SizePackVems: cardinal; // размер пакета от шдк
    SLE: integer; // задержка запроса пакета vems, инициализация
    // Sensor_ID:byte;
    procedure ReadPort_LC; // Чтение из порта lc-1
    procedure ReadPortVems; // чтение VEMS
    procedure ReadPort_AEM; // чтение из порта AEM
    Procedure GenAFR(data: array of byte);
    function OpenPortLC(): boolean;
    procedure ClosePortLC;
    { Private declarations }
  protected
    procedure Execute; override;
  Public
    AFR: REAL; // состав смеси на ШДК
    stochiometric: REAL; // стехиометрия с шдк
    Message_LC1: string; // сообщение о состоянии ЛС-1
    lc: boolean; // флаг включенного шдк
    ExitReadPort: boolean; // флаг прекращения чтения с порта
    LC_CONNECT: boolean; // флаг подключенного порта
    EGT: integer;
    procedure stop;
    destructor Destroy; override;
    class var RunThread: boolean;

    constructor Create(Port: string; LamSensor: string);

  end;

var
  LC_DATA: TLC_DATA;

implementation

procedure TLcThreat.Execute;
begin
  while (RunThread) and (not terminated) do
  begin
    sleep(1);
    if ExitReadPort then
    begin
      TLcThreat.RunThread := false;
      exit;
    end;
    if LC_1 then
      ReadPort_LC;
    if AEM then
      ReadPort_AEM;
    if VEMS then
      ReadPortVems;
  end;
end;

constructor TLcThreat.Create(Port: string; LamSensor: string);
// var
// i: integer;
// DCB: TDCB;
begin
  inherited Create(true);
  LC_DATA.Port := Port;
  lc := false;
  SLE := 100;
  if LamSensor = 'AEM' then
  begin
    AEM := true;
    LC_1 := false;
    VEMS := false;
  end;
  if LamSensor = 'LC/LM-1/2' then
  begin
    LC_1 := true;
    AEM := false;
    VEMS := false;
  end;
  if LamSensor = 'VEMS' then
  begin
    LC_1 := false;
    AEM := false;
    VEMS := true;
  end;

  ExitReadPort := false;
  // Выставляем флаг работы потока
  // RunThread := false;
  OpenPortLC;
  RunThread := true;
  resume;
end;

// протокол чтения LC-1
procedure TLcThreat.ReadPort_LC;
var
  Errors, Size, NumberOfBytesReaded: cardinal;
  COMStat: TCOMStat;
  count: integer;
  // s: string;
  i: integer;
  data: array [0 .. 10] of byte;
  dataAfr: array [0 .. 3] of byte;
  SleepCount: integer;
begin
  // ---------------------
  // LengthPack:=((( data[ 0 ] and 1 ) shl 7 ) + ( data[ 1 ] and $7F ));
  // длина пакета указывается во втором байте
  // длина пакета = (data[1] and $7F) * 2, умножить на 2, потому что слово двухбайтное и
  // data 1 and 2 это заголовок двухбайтный
  // ---------------------
  // сброс данных с порта
  if not PurgeComm(hCOMPort, PURGE_TXCLEAR or PURGE_RXCLEAR) then
  begin
    ClosePortLC; // закрываем порт, если ну удалось очистить порт
    if not OpenPortLC then
      exit; // пробуем снова открыть, если не удалось то выходим
  end;
  // цикл ожидания данных на порту
  SleepCount := 0;
  repeat
    sleep(5);
    SleepCount := SleepCount + 5;
    if not ClearCommError(hCOMPort, Errors, @COMStat) then
      exit;
    Size := COMStat.cbInQue;
    count := Size;
  until (count > 0) or (SleepCount > 2000) or (ExitReadPort);
  // проверяем флаг на выход чтения порта
  if ExitReadPort then
  begin
    PurgeComm(hCOMPort, PURGE_TXCLEAR or PURGE_RXCLEAR);
    exit;
  end;
  // если Count > 0 значит читаем порт
  if count > 0 then
    ReadFile(hCOMPort, data, 1, NumberOfBytesReaded, nil)
  else
  begin
    Message_LC1 := 'LC: NoDATA';
    lc := false;
    exit;
  end;
  if not data[0] and $A2 = $A2 then
    exit;
  //
  // читаем второй заголовок
  SleepCount := 0;
  repeat
    sleep(5);
    SleepCount := SleepCount + 5;
    ClearCommError(hCOMPort, Errors, @COMStat);
    Size := COMStat.cbInQue;
    count := Size;
  until (count > 0) or (SleepCount > 2000) or (ExitReadPort);
  // проверяем флаг на выход чтения порта
  if ExitReadPort then
  begin
    PurgeComm(hCOMPort, PURGE_TXCLEAR or PURGE_RXCLEAR);
    exit;
  end;
  // если Count > 0 значит читаем порт
  if count > 0 then
    ReadFile(hCOMPort, data, 1, NumberOfBytesReaded, nil)
  else
    exit;
  if not data[0] and $80 = $80 then
    exit;
  // читаем пакет из 4 байт
  SleepCount := 0;
  repeat
    sleep(5);
    SleepCount := SleepCount + 5;
    ClearCommError(hCOMPort, Errors, @COMStat);
    Size := COMStat.cbInQue;
    count := Size;
  until (count > 0) or (SleepCount > 4000) or (ExitReadPort);
  // проверяем флаг на выход чтения порта
  if ExitReadPort then
  begin
    PurgeComm(hCOMPort, PURGE_TXCLEAR or PURGE_RXCLEAR);
    exit;
  end;
  // если Count > 3 значит читаем порт
  if count > 3 then
    ReadFile(hCOMPort, data, 4, NumberOfBytesReaded, nil)
  else
    exit;
  PurgeComm(hCOMPort, PURGE_TXCLEAR or PURGE_RXCLEAR);
  for i := 0 to 3 do
    dataAfr[i] := data[i];
  GenAFR(dataAfr);
end;

// чтение шдк вемс
procedure TLcThreat.ReadPortVems;
var
  WriteDataPort: array [0 .. 1] of byte;
  Errors, Size, NumberOfBytesWritten, NumberOfBytesReaded: cardinal;
  COMStat: TCOMStat;
  SL: integer;
  data: array [0 .. 100] of byte;

begin
  // ----- проверка очистки порта ----------
  if not PurgeComm(hCOMPort, PURGE_TXCLEAR or PURGE_RXCLEAR) then
  begin
    ClosePortLC; // закрываем порт, если ну удалось очистить порт
    if not OpenPortLC then
      exit; // пробуем снова открыть, если не удалось то выходим
  end;
  // ----- отправка запроса на данные -----------
  WriteDataPort[0] := $41;
  WriteDataPort[1] := $2E;
  if not WriteFile(hCOMPort, WriteDataPort, 2, NumberOfBytesWritten, nil) then
    exit;
  // ----- читаем пакет данных из порта -----------------------
  // Считываем данные
  SL := 0;
  repeat
    sleep(SLE);
    ClearCommError(hCOMPort, Errors, @COMStat);
    Size := COMStat.cbInQue;
    SL := SL + 1;
  until (SL > 500) or (Size = SizePackVems) or (Size > 15);
  if SizePackVems <> Size then
  begin
    SizePackVems := Size;
    SLE := 1;
  end;
  if not ReadFile(hCOMPort, data, Size, NumberOfBytesReaded, nil) then
    exit;
  // ------- теперь проверка флагов о состоянии шдк ------------
  // 12 байт проверочный
  if data[12] and $60 = $60 then
  begin
    lc := false;
    Message_LC1 := 'WarmUP';
    exit;
  end;
  if data[12] and $40 = $40 then
  begin
    lc := true;
    Message_LC1 := 'EGT: ' + FloatToStr((data[4] * 256 + data[5]) - 50);
    EGT := round((data[4] * 256 + data[5]) - 50);
    AFR := 14.7 * (data[0] * 256 + data[1]) / 16384;
  end;
end;

// протокол чтения АЕМ
procedure TLcThreat.ReadPort_AEM;
var
  id_data: byte;
  Errors, Size, NumberOfBytesReaded: cardinal;
  COMStat: TCOMStat;
  // Count:integer;
  count_data: byte;
  data: ARRAY [0 .. 20] OF byte;
  test: string;
  // LogLC:textfile;
  filename: string;
  // s:string;
  count_sleep: integer;
  pack_good: boolean; // флаг, что пакет считан
begin
  // очистка содержимого порта
  if not PurgeComm(hCOMPort, PURGE_TXCLEAR or PURGE_RXCLEAR) then
  begin
    ClosePortLC; // закрываем порт, если ну удалось очистить порт
    if not OpenPortLC then
    begin
      Message_LC1 := 'LC: error open port';
      exit; // пробуем снова открыть, если не удалось то выходим
    end;
  end;
  // Считываем данные
  count_sleep := 0;
  count_data := 1;
  id_data := 1;
  pack_good := false;
  // --------------------- зацикливание формирования пакета -------------------------
  repeat
    sleep(1);
    ClearCommError(hCOMPort, Errors, @COMStat);
    // проверка наличия симоволов в порту
    Size := COMStat.cbInQue; // количество байт в порту
    // ---------------------------формироание пакета----------------------
    if Size >= count_data then
    begin
      ReadFile(hCOMPort, data, count_data, NumberOfBytesReaded, nil);
      // ---------
      case id_data of
        // пакет данных
        3:
          begin
            pack_good := true;
            id_data := 1;
            count_data := 1;
          end;
        // второй байт заголовка
        2:
          begin
            if data[0] = $0A then
            begin
              id_data := 3;
              count_data := 4;
            end
            else
            begin
              id_data := 1;
              count_data := 1;
            end;
          end;
        // первый байт заголовка
        1:
          begin
            if data[0] = $0D then
            begin
              id_data := 2;
              count_data := 1;
            end
            else
              id_data := 1;
          end;
      end;
      // ---------
    end;
    // ---------------------- end формирование пакета -------------------------------------
    inc(count_sleep);
  until (pack_good = true) or (count_sleep > 5000);
  // определяем начало заголовка пакета $0D
  if not pack_good then
  begin
    Message_LC1 := 'LC:no data';
    exit;
  end;
  // ------------------ конец цикла формирования пакета -----------------------

  // -------------- разбор пакета данных ----------------------------
  test := chr(data[0]) + chr(data[1]) + chr(data[2]) + chr(data[3]);
  test := StringReplace(test, '.', ',', [rfReplaceAll, rfIgnoreCase]);
  Message_LC1 := test;
  try
    AFR := StrToFloat(test);
  except
  end;
  if (AFR > 20) or (AFR < 10) then
    lc := false
  else
    lc := true;

  // ----------------------------------------------------------------------

  // -------- проверка очистки порта -------------------
  if not PurgeComm(hCOMPort, PURGE_TXCLEAR or PURGE_RXCLEAR) then
    showmessage('Error Lc Port');
  {
    ReadFile( hCOMPort, Data, 1, NumberOfBytesReaded, nil);
    if data[0]=$0D then begin

    //---проверяем второй байт заголовка пакета
    repeat
    ClearCommError( hCOMPort, Errors, @COMStat );
    Size := COMStat.cbInQue;
    Count := Size;
    until count > 0 ;

    ReadFile( hCOMPort, Data, 1, NumberOfBytesReaded, nil);
    if data[0]=$0A then begin
    //читаем весь оставшийся пакет и ещё один байт начала заголовка
    repeat
    ClearCommError( hCOMPort, Errors, @COMStat );
    Size := COMStat.cbInQue;
    Count := Size;
    until count > 4 ;
    ReadFile( hCOMPort, Data, 5, NumberOfBytesReaded, nil);
    if data[4]=$0D then begin //если после пакета снова заголовок, то пакет истина
    //сохраняем в лог протокол без заголовка
    S:=FormatDateTime( 'tt', now ) + '   ' + IntToHex( data[0],2 )+' '+IntToHex( data[1],2 )+' '+inttohex(data[2],2)+' '+IntToHex(data[3],2);
    fileName := 'LogAEM.txt';
    if not FileExists(fileName) then begin
    AssignFile(LogLC, fileName);
    Rewrite(LogLC);
    CloseFile(LogLC);
    end;
    AssignFile(LogLC, fileName);
    Append(LogLC);
    WriteLn(LogLC, s);
    CloseFile(LogLC);

    //очистка порта от накопленных данных, чтоб всё чётко работало

    //PurgeComm(hCOMPort,PURGE_RXCLEAR);
    //  exit;
    end;
    end;
    end;
    // lc:=false;
  }
end;

Procedure TLcThreat.stop;
begin
  RunThread := false;
  WaitFor;
  // sleep(500);
  if hCOMPort <> 0 then
    CloseHandle(hCOMPort);
  // Destroy;
end;

destructor TLcThreat.Destroy;
begin
  CloseHandle(hCOMPort);
  inherited Destroy;
end;

procedure TLcThreat.GenAFR(data: array of byte);
const
  LambdaValue = 0;
  O2Level = 1;
  FreeAirCalibProgress = 2;
  NeedFreeAirCalibRequest = 3;
  WarmingUp = 4;
  HeaterCalib = 5;
  ErrorCode = 6;
  Reserver = 7;
var
  State: byte;
  AF, Lambda, O2Lvl, WarmUp: REAL;
  ERRCode: integer;
  // i:integer;
begin
  State := data[0] shr 2 and $07;
  case State of
    LambdaValue:
      begin
        AF := (((data[0] and 1) shl 7) + (data[1] and $7F)) / 10;
        Lambda := (((data[2] and $7F) shl 7) + (data[3] and $7F) + 500) / 1000;
        AFR := StrToFloat(formatfloat('##0.##', Lambda * 14.7));
        stochiometric := AF;
        if AFR > 21 then
          AFR := 21;
        if AFR < 10 then
          AFR := 10;
        Message_LC1 := 'AFR: ' + FloatToStr(AFR);
        lc := true;
      end;
    O2Level:
      begin
        O2Lvl := (((data[2] and $7F) shl 7) + (data[3] and $7F)) / 10;
        // ShowMessage(floattostr(O2Lvl));
        // AFR:=strtofloat(formatfloat('##0.##', O2Lvl));
        // if AFR > 21 then AFR:=21;
        Message_LC1 := 'O2Lvl: ' + FloatToStr(O2Lvl);
        lc := false;
      end;
    WarmingUp:
      begin
        /// (data[2] * 128  / 10 ) + (data[3] /10)
        WarmUp := (data[2] * 128 / 10) + (data[3] / 10);
        Message_LC1 := 'WarmUp: ' + FloatToStr(WarmUp);
        lc := false;
      end;

    ErrorCode:
      begin
        ERRCode := (((data[2] and $7F) shl 7) + (data[3] and $7F));
        // ShowMessage(inttostr(ErrCode));
        Message_LC1 := 'Error  ' + inttostr(ERRCode);
        lc := false;
      end;
  end;
end;

function TLcThreat.OpenPortLC(): boolean;
var
  DCB: TDCB;
begin
  hCOMPort := CreateFile(PChar(LC_DATA.Port), Generic_Read + Generic_Write, 0,
    nil, Open_Existing, File_Attribute_Normal, 0);
  // Проверяем отсутствие ошибок при отрытии
  if hCOMPort = Invalid_Handle_Value then
  begin
    // Application.MessageBox(PChar( 'Ошибка открытия порта ' + lc_data.Port ), 'Ошибка',
    // MB_ICONWARNING + MB_OK );
    LC_DATA.PortOpen := false;
    LC_CONNECT := false;
    exit(false);
  end;
  LC_DATA.PortOpen := true;
  LC_CONNECT := true;
  Message_LC1 := 'LC: Подключено';
  PurgeComm(hCOMPort, PURGE_TXCLEAR or PURGE_RXCLEAR);
  // PurgeComm(hCOMPort,PURGE_RXCLEAR);
  // Выставляем настройки порта для LC_1
  if (LC_1) or (VEMS) then
  begin
    GetCommState(hCOMPort, DCB);
    DCB.BaudRate := 19200; // BaudRate;
    DCB.ByteSize := 8;
    DCB.Parity := NOPARITY;
    DCB.StopBits := ONESTOPBIT;
  end;
  // выставляем настройки порта для АЕМ
  if AEM then
  begin
    GetCommState(hCOMPort, DCB);
    DCB.BaudRate := 9600; // BaudRate;
    DCB.ByteSize := 8;
    DCB.Parity := NOPARITY;
    DCB.StopBits := ONESTOPBIT;
  end;
  // Проверка настройки порта
  if not SetCommState(hCOMPort, DCB) then
  begin
    Application.MessageBox(PChar('Ошибка установки настроек порта ШДК ' +
      LC_DATA.Port), 'Ошибка', MB_ICONWARNING + MB_OK);
    ClosePortLC;
    exit(false);
  end;
  result := true;
end;

procedure TLcThreat.ClosePortLC;
begin
  if LC_DATA.PortOpen then
  begin
    CloseHandle(hCOMPort);
    LC_DATA.PortOpen := false;
    LC_CONNECT := false;
    Message_LC1 := 'LC: Отключено';
  end;
end;

end.
