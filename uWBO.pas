unit uWBO;
{
  Модуль приёма данных с ШДК.
  Использование:
  1. wbo := TWbo.create;
  2. StringListComPort:=wbo.GetListWbo();
  3. StringListTypeWbo:=wbo.GetListPorts();
  4. wbo.Start(Номер выбранного ШДК(StringListComPort), Название Com порта(StringListTypeWbo) например (COM1));
  //wbo.NewData - флаг обновленных данных
  //Работа в потоке или в таймере
  if wbo.NewData then begin
    WboAfr := wbo.AFR;
    WboLambda := wbo.Lambda;
    wbo.NewData := False;
  end;
}

interface

uses
  System.Classes, System.SysUtils, Windows;

type
  TWbo = class(TThread)
  private
    fStopped: Boolean;
    fNumberSensor: Integer;
    hCOMPort: THandle; // хэндл ком порта
    fAFR: Real; // Состав смеси
    fNewData: Boolean; // флаг обновлённых данных
    fComPortOpened: Boolean; // флаг открытого порта
    fStart: Boolean; // флаг принимать данные с порта
    fPortName: string; // Назавние порта
    fBaudRatePort: Integer; // скорость порта
    fMsgWbo: String;

  protected
    function OpenComPort(const aComPort: string; const aBaudRate: Integer): Boolean;
    procedure CloseComPort(); // Добавляем метод для закрытия COM-порта
    function ReOpenPort(): Boolean;
    function Repack_AEM_9600(aData: TBytes): Boolean;
    function Repack_AEM_19200(aData: TBytes): Boolean;
    function Repack_LC(const aData: TBytes): Boolean;
    procedure GenfAFR(const data: TBytes); // разбор данных LC1/2
    function GetLambda(): Real;
  public
    destructor Destroy; override;
    procedure Execute; override;
    /// <summary>Запрос поддерживаемых WBO</summary>
    function GetListWbo(): TStrings;
    /// <summary>Получить состав смеси</summary>
    property AFR: Real read fAFR write fAFR;
    /// <summary>Установить наличие обновлённых данных</summary>
    property NewData: Boolean read fNewData write fNewData;
    property MessageWbo: string read fMsgWbo;
    property Lambda: Real read GetLambda;
    /// <summary>Запуск приёма данных с ШДК в потоке</summary>
    /// <param name="aNumberSensor">Номер выбранного типа ШДК</param>
    /// <param name="aNamePort">Название COM порта, например COM1</param>
    procedure Start(const aNumberSensor: Integer; const aNamePort: string);
    // получаем список доступных ComPorts
    function GetListPorts(): TStrings;
  end;

implementation

const
  FWboArray: array [0 .. 2] of String = ('LC1/2', 'AEM 9600', 'AEM 19200');
  fBaudRate: array [0 .. 2] of Integer = (19200, 9600, 19200);

destructor TWbo.Destroy;
begin
  fStopped := True;
  Waitfor;
  CloseComPort(); // Вызываем закрытие COM-порта перед завершением работы
  inherited Destroy;
end;

procedure TWbo.CloseComPort();
begin
  if fComPortOpened then
  begin
    CloseHandle(hCOMPort); // Закрываем хэндл COM-порта
    fComPortOpened := False;
  end;
end;

function TWbo.ReOpenPort(): Boolean;
begin
  CloseHandle(hCOMPort);
  result := OpenComPort(fPortName, fBaudRatePort);
end;

procedure TWbo.Execute;
var
  COMStat: TCOMStat;
  Errors, lSizeData, NumberOfBytesReaded: Cardinal;
  lComData: TBytes;
  lFlagSynchronized: Boolean; // флаг синхронизировался пакет или нет
  lSynchroByte: byte; // приёмник байт для синхронизации
  lSizePackSynchro: Cardinal; // количество байт в синхронизированном пакете
begin
  // lComData := [];
  lFlagSynchronized := False;
  lSizePackSynchro := 0;
  while not fStopped do
  begin
    // Тело цикла потока
    Sleep(1);
    if fStart then
    begin
      // принимаем данные с шдк
      if ClearCommError(hCOMPort, Errors, @COMStat) then
      begin
        lSizeData := COMStat.cbInQue;
        if lSizeData > 0 then
        begin
          // если не синхронизированы, то пытаемся найти начало данных
          if not lFlagSynchronized then
          begin
            if fNumberSensor <> 0 then
              ReadFile(hCOMPort, lSynchroByte, 1, NumberOfBytesReaded, nil);
            fMsgWbo := 'Search synchro byte : ' + IntToHex(lSynchroByte, 2);
            case fNumberSensor of
              0:
                begin
                  // lc1/2  $00
                  if lSizeData >= 2 then
                  begin
                    ReadFile(hCOMPort, lSynchroByte, 1, NumberOfBytesReaded, nil);
                    if lSynchroByte and $A2 = $A2 then
                    begin
                      ReadFile(hCOMPort, lSynchroByte, 1, NumberOfBytesReaded, nil);
                      if lSynchroByte and $80 = $80 then
                      begin
                        fMsgWbo := 'Search synchro OK ';
                        lFlagSynchronized := True;
                        lSizePackSynchro := 6;
                      end;

                    end;

                  end;

                end;
              1:
                begin
                  // aem 9600   $0A
                  if lSynchroByte = $0A then
                  begin
                    lFlagSynchronized := True;
                    lSizePackSynchro := 6;
                  end;
                end;
              2:
                begin
                  // aem 19200   $0D
                  if lSynchroByte = $0D then
                  begin
                    lFlagSynchronized := True;
                    lSizePackSynchro := 22;
                  end;
                end;
            end;
          end
          else
          begin
            if lSizeData >= lSizePackSynchro then
            begin
              // синхронизированы
              SetLength(lComData, lSizePackSynchro);
              if ReadFile(hCOMPort, lComData[0], lSizePackSynchro, NumberOfBytesReaded, nil) then
              begin
                case fNumberSensor of
                  0:
                    if not Repack_LC(lComData) then
                      lFlagSynchronized := False;
                  1:
                    if not Repack_AEM_9600(lComData) then
                      lFlagSynchronized := False;
                  2:
                    if not Repack_AEM_19200(lComData) then
                      lFlagSynchronized := False;
                end;
              end
              else
              begin
                lFlagSynchronized := False;
                self.ReOpenPort;
              end;
            end;
          end;

        end;

      end
      else
      begin
        lFlagSynchronized := False;
        self.ReOpenPort;
      end;
    end;
  end;
end;

function TWbo.GetListWbo(): TStrings;
var
  i: Integer;
begin
  result := TStringList.Create;
  for i := Low(FWboArray) to High(FWboArray) do
    result.Add(FWboArray[i]);
end;

procedure TWbo.Start(const aNumberSensor: Integer; const aNamePort: string);
begin
  if OpenComPort(aNamePort, fBaudRate[aNumberSensor]) then
    fStart := True
  else
    raise Exception.Create(Format('Не удалось открыть порт WBO %s', [aNamePort]));
  fNumberSensor := aNumberSensor;
  fPortName := aNamePort;
  fBaudRatePort := fBaudRate[aNumberSensor];
end;

function TWbo.OpenComPort(const aComPort: string; const aBaudRate: Integer): Boolean;
var
  DCB: TDCB;
begin
  result := False;
  if hCOMPort = INVALID_HANDLE_VALUE then
    hCOMPort := CreateFile(PChar(aComPort), GENERIC_READ or GENERIC_WRITE, 0, nil, OPEN_EXISTING, FILE_FLAG_WRITE_THROUGH, 0);
  if hCOMPort <> INVALID_HANDLE_VALUE then
  begin
    GetCommState(hCOMPort, DCB);
    with DCB do
    begin
      BaudRate := aBaudRate;
      ByteSize := 8;
      StopBits := ONESTOPBIT;
      Parity := NOPARITY;
    end;
    if SetCommState(hCOMPort, DCB) and PurgeComm(hCOMPort, PURGE_TXCLEAR or PURGE_RXCLEAR) then
    begin
      fComPortOpened := True;
      result := True;
    end
    else
    begin
      CloseHandle(hCOMPort);
      fComPortOpened := False;
      result := False;
    end;

  end;
end;

function TWbo.GetListPorts: TStrings;
var
  i: Integer;
begin
  result := TStringList.Create;
  for i := 1 to 20 do
  begin
    hCOMPort := CreateFile(PChar('COM' + IntToStr(i)), GENERIC_READ or GENERIC_WRITE, 0, nil, OPEN_EXISTING, FILE_FLAG_WRITE_THROUGH, 0);
    if hCOMPort <> INVALID_HANDLE_VALUE then
    begin
      result.Add(Format('COM%d', [i]));
      CloseHandle(hCOMPort);
    end;
  end;
end;

function StrToFloatD(value: string): Real;
begin
  try
    value := StringReplace(value, '.', ',', [rfReplaceAll, rfIgnoreCase]);
    result := StrToFloat(value);
  except
    value := StringReplace(value, ',', '.', [rfReplaceAll, rfIgnoreCase]);
    result := StrToFloat(value);
  end;
end;

function TWbo.Repack_AEM_9600(aData: TBytes): Boolean;
var
  lStrAFR: string;
  i: Integer;
begin
  lStrAFR := '';
  for i := Low(aData) to High(aData) do
    if ((aData[i] >= $30) and (aData[i] <= $39)) or (aData[i] = $2E) then
      lStrAFR := lStrAFR + Char(aData[i]);
  fAFR := StrToFloatD(lStrAFR);
  self.fNewData := True;
  result := aData[high(aData)] = $0A;
end;

function TWbo.Repack_AEM_19200(aData: TBytes): Boolean;
var
  lMessage: string;
  i: Integer;
  lStrungList: TStringList;
begin
  lMessage := '';
  result := aData[high(aData)] = $0D;
  for i := Low(aData) to High(aData) do
    lMessage := lMessage + Char(aData[i]);
  lStrungList := TStringList.Create;
  lStrungList.Delimiter := Char($9);
  lStrungList.DelimitedText := lMessage;
  if lStrungList.Count > 0 then
  begin
    self.fNewData := True;
    self.fAFR := StrToFloatD(lStrungList[0]) * 14.7;
    if lStrungList.Count > 1 then
      self.fMsgWbo := lStrungList[1];
    if lStrungList.Count > 2 then
      self.fMsgWbo := fMsgWbo + ' ' + lStrungList[2];
  end;

  lStrungList.Free;
end;

function TWbo.Repack_LC(const aData: TBytes): Boolean;
begin
  if ((aData[high(aData)] and $80 = $80) and (aData[high(aData) - 1] and $A2 = $A2)) then
  begin
    GenfAFR(aData);
    result := True;
  end
  else
    result := False;
end;

procedure TWbo.GenfAFR(const data: TBytes);
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
  Lambda, O2Lvl, WarmUp: Real;
  ERRCode: Integer;
begin
  State := (data[0] shr 2) and $07;
  case State of
    LambdaValue:
      begin
        // AF := (((data[0] and 1) shl 7) + (data[1] and $7F)) / 10;
        Lambda := (((data[2] and $7F) shl 7) + (data[3] and $7F) + 500) / 1000;
        fAFR := StrToFloat(FormatFloat('##0.##', Lambda * 14.7));
        // stochiometric := AF;

        fMsgWbo := 'fAFR: ' + floattostr(fAFR);
        fNewData := True;
      end;
    O2Level:
      begin
        O2Lvl := (((data[2] and $7F) shl 7) + (data[3] and $7F)) / 10;
        fMsgWbo := 'O2Lvl: ' + floattostr(O2Lvl);
        fNewData := False;
      end;
    WarmingUp:
      begin
        /// (data[2] * 128  / 10 ) + (data[3] /10)
        WarmUp := (data[2] * 128 / 10) + (data[3] / 10);
        fMsgWbo := 'WarmUp: ' + floattostr(WarmUp);
        fNewData := False;
      end;

    ErrorCode:
      begin
        ERRCode := (((data[2] and $7F) shl 7) + (data[3] and $7F));
        // ShowMessage(inttostr(ErrCode));
        fMsgWbo := 'Error  ' + IntToStr(ERRCode);
        fNewData := False;
      end;
  end;
end;

function TWbo.GetLambda(): Real;
begin
  result := fAFR / 14.7;
end;

end.
