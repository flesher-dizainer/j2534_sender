unit uJ2534_v2;

{
  Модуль работы с J2534 адаптером через dll адаптера.
}
interface

uses
  Windows,
  SysUtils,
  Classes,
  Registry,
  System.TypInfo;

type
  TERROR_MESS = (STATUS_NOERROR, ERR_SUCCESS, ERR_NOT_SUPPORTED, ERR_INVALID_CHANNEL_ID, ERR_NULL_PARAMETER, ERR_INVALID_IOCTL_VALUE,
    ERR_INVALID_FLAGS, ERR_FAILED, ERR_DEVICE_NOT_CONNECTED, ERR_TIMEOUT, ERR_INVALID_MSG, ERR_INVALID_TIME_INTERVAL, ERR_EXCEEDED_LIMIT,
    ERR_INVALID_MSG_ID, ERR_DEVICE_IN_USE, ERR_INVALID_IOCTL_ID, ERR_BUFFER_EMPTY, ERR_BUFFER_FULL, ERR_BUFFER_OVERFLOW, ERR_PIN_INVALID,
    ERR_CHANNEL_IN_USE, ERR_MSG_PROTOCOL_ID, ERR_INVALID_FILTER_ID, ERR_NO_FLOW_CONTROL, ERR_NOT_UNIQUE, ERR_INVALID_BAUDRATE,
    ERR_INVALID_DEVICE_ID);

const
  TERROR_CMT: array [TERROR_MESS] of string = (' Функция выполнена успешно ', 'Информация отсутствует ',
    ' Адаптер не поддерживает запрошенные параметры.', ' Задан не существующий идентификатор канала ChannelID.',
    ' не Задан указатель на буфер приёмных пакетов pMsg.', ' не правильно Задан значение Ioctl параметра.', ' Задан не существующий флаг ',
    ' Определён стандартом J2534.В адаптере, для этой функции не используется.', ' Нет соединения с адаптером.',
    ' За заданное время пришло меньше сообщений чем заказали.', ' не правильная структура сообщения заданная В указателе pMsg ',
    ' не правильно Задан интервал выдачи сообщений ', ' Превышено количество установленных фильтров.',
    ' Задан не существующий идентификатор адаптера DeviceID ',
    ' Прибор уже используется программой.Возможные причины: не была выполнена Функция PassThruClose В предыдущей сессии.',
    ' Задан не существующий идентификатор канала IoctlID ', ' Приёмная очередь пустая.', ' очередь передачи переполнена.',
    ' Показывает что Приёмная очередь была переполнена и сообщения были потеряны.Реальное количество принятых сообщений будет находится В NumMsgs.',
    ' не правильно Задан вывод коммутатора.', ' Канал уже используется.Определён стандартом J2534.',
    ' Протокол заданный В параметрах передаваемого сообщения не совпадает с протоколом заданным В ChannelID ',
    ' Задан не существующий идентификатор фильтра FilterID ', ' для протокола ISO15765 не установлен фильтр для Flow Control.',
    ' CAN ID В pPatternMsg или pFlowControlMsg соответствует какому либо ID В уже существующем FLOW_CONTROL_FILTER ',
    ' Задана не правильная скорость обмена ', ' Задан не существующий идентификатор адаптера DeviceID ');

type
  /// <summary >Указатель на массив байт</summary >
  PTBytes = ^TBytes;

type
  TProtocolID = record
  const
    CAN = $05;
    ISO15765 = $06;
  end;

type
  TBaudRate = record
  const
    BaudRate = 500000;
  end;

type
  TFilterMSG = record
  const
    MaskMsg: array [0 .. 3] of byte = ($0, $0, $07, $FF);
    PatternMsg: array [0 .. 3] of byte = (0, 0, $07, $E8);
    FlowControlMsg: array [0 .. 3] of byte = (0, 0, $07, $E0);
  end;

type
  TFlags = record
  const
    CONNECT_FLAGS_CAN_11BIT_ID = 0;
    TRANSMITT_FLAGS_ISO15765_FRAME_PAD = $40;
    FILTER_TYPE_FLOW_CONTROL_FILTER = 3;
  end;

  { данные протокола, ид канала и т.п }
type
  TDiagData = record
    Device_ID: longWord; // идент устройства
    ProtocilID: longWord; // идент протокола связи
    Flags: longWord; // флаги соединения
    BaudRate: longWord; // скорость связи
    ChannelID: longWord; // идент канала связи
    FilterID: longWord; // идент фильтра, нужен для удаления фильтра
  end;

  { --- структура сообщения TPassthruMsg --- }
type
  /// <summary >Указатель на струкутуру TPassthruMsg</summary >
  PPassthruMsg = ^TPassthruMsg;

  TPassthruMsg = record
    ProtocolID: longWord; // vehicle network protocol
    RxStatus: longWord; // receive message status
    TxFlags: longWord; // transmit message flags
    Timestamp: longWord; // receive message timestamp (in microseconds)
    DataSize: longWord; // byte size of message payload in the Data array
    ExtraDataIndex: longWord;
    Data: array [0 .. 4127] of byte; // message payload or data
  end;

type
  /// <summary >Структура имён адаптеров и путей к DLL.</summary >
  /// <param name="NamesAdapter">Список имён адаптеров</param>
  /// <param name="PathsDll">Список путей к DLL</param>
  TDllsInfo = record
    NamesAdapter: TStrings;
    PathsDll: TStrings;
  end;

  TJ2534_v2 = class
  private
    // открыть шлюз связи с адаптером
    FTPassThruOpen: function(Name: PChar; aPDeviceID: PLongWord): byte; stdcall;
    // закрыть шлюз связи с адаптером
    FTPassThruClose: function(DeviceID: longWord): byte; stdcall;
    // Установка соединения по протоколу
    FTPassThruConnect: function(DeviceID: longWord; ProtocolID: longWord; Flags: longWord; BaudRate: longWord; pChannelID: PLongWord)
      : integer; stdcall;
    // разьединение связи
    FTPassThruDisconnect: function(DeviceID: longWord): byte; stdcall;
    // отправка сообщения адаптеру
    FTPassThruWriteMsgs: function(ChannelID: longWord; aPPassthruMsg: PPassthruMsg; pNumMsgs: Pint; Timeout: longWord): integer; stdcall;
    // Чтение принятого пакета  ChannelID - идентификатор канала
    FTPassThruReadMsgs: function(ChannelID: longWord; aPPassthruMsg: PPassthruMsg; pNumMsgs: Pint; Timeout: longWord): integer; stdcall;
    // установка фильтра сообщения
    FTPassThruStartMsgFilter: function(ChannelID: longWord; FilterType: longWord; pMaskMsg: pointer; pPatternMsg: pointer;
      pFlowControlMsg: pointer; FilterID: pointer): integer; stdcall;
    // удаление фильтров сообщений
    FTPassThruStopMsgFilter: function(ChannelID: longWord; FilterID: longWord): integer; stdcall;
    // чтение версии прошивки, длл, api
    FTPassThruReadVersion: function(DeviceID: longWord; pFirmwareVersion, pDllVersion, pApiVersion: pointer): integer; stdcall;
    // управление вводом и выводом
    FTPassThruIoctl: function(ChannelID: longWord; IoctlID: longWord; pInput: pointer; pOutput: pointer): integer; stdcall;
    // Храним дескриптор DLL
    fDLLHandle: THandle;
    // Хранилище данных адаптера. DevId для последующей работы с адаптером.
    fDiagData: TDiagData;
    function ClearRxBufer(): integer;
  protected
    { protected declarations }
  public
    { public declarations }
    destructor Destroy; override;
    /// <summary >Функция возвращает структуру TDllsInfo. В ней имена адаптеров и пути к DLL</summary >
    function GetNamePathDll: TDllsInfo;
    { Проверяем на наличие функций в dll }
    function CheckFunctionDll(aFDLLHandle: THandle): boolean;
    function LoadDLL(const aPathDll: string): boolean;
    /// <summary >Открываем шлюз адаптера.</summary >
    function PassThruOpen(): byte;
    /// <summary >Закрываем шлюз адаптера.</summary >
    function PassThruClose(): byte;
    function PassThruConnect(const aProtocol_id, aFlag, aBaudRate: longWord): byte;
    // разорвать соединение с адаптером
    function PassThruDisconnect(): byte;
    // отправить сообщение в шину
    function PassThruWriteMsg(const aData: array of byte; aTx_Flag, aTimeout: longWord): integer;
    // получить сообщение из шины
    function PassThruReadMsgs(aData: PTBytes; aSize: PLongWord; aTimeout: longWord): integer;
    // установка фильтров сообшений
    function PassThruStartMsgFilter(aFilter_type: longWord; aMaskMsg, aPatternMsg, aFlowControlMsg: TBytes; aTxFlags: longWord): integer;
    // останавливаем фильтр сообщений
    function PassThruStopMsgFilter(): integer;
    // чтение версии DLL
    // function PassThrueReadVersion(): integer;
    function GetComment(error: TERROR_MESS): string;
    // published
    { published declarations }
  end;

implementation

type
  TEFuncNames = (PassThruOpen, PassThruClose, PassThruConnect, PassThruDisconnect, PassThruReadMsgs, PassThruWriteMsgs,
    PassThruStartMsgFilter, PassThruStopMsgFilter, PassThruReadVersion, PassThruIoctl);

destructor TJ2534_v2.Destroy;
begin
  // Освобождаем DLL, если она была загружена
  if fDLLHandle <> 0 then
    FreeLibrary(fDLLHandle);
  inherited Destroy;
end;

function TJ2534_v2.GetNamePathDll: TDllsInfo;
var
  lRegistry: TRegistry;
  lStrings: TStrings;
  i: integer;
  ldll_name: String;
  lCurrentPath: String;
begin
  // Создаем экземпляры полей NamesAdapter и PathsDll
  Result.NamesAdapter := TStringList.Create;
  Result.PathsDll := TStringList.Create;
  lRegistry := TRegistry.Create;
  try
    lRegistry.RootKey := HKEY_LOCAL_MACHINE;
    if lRegistry.OpenKey('SOFTWARE', False) then
      if lRegistry.OpenKeyReadOnly('PassThruSupport.04.04') then
      begin
        lCurrentPath := lRegistry.CurrentPath;
        lStrings := TStringList.Create;
        try
          lRegistry.GetKeyNames(lStrings);
          for i := 0 to lStrings.Count - 1 do
          begin
            if lRegistry.OpenKeyReadOnly(lStrings[i]) then
            begin
              ldll_name := lRegistry.ReadString('FunctionLibrary');
              if ldll_name <> '' then
              begin
                // добавляем название адаптера
                Result.NamesAdapter.Add(lStrings[i]);
                // добавляем путь к DLL
                Result.PathsDll.Add(ldll_name);
              end;
              lRegistry.CloseKey;
              lRegistry.OpenKeyReadOnly(lCurrentPath);
            end;
          end;
        finally
          lStrings.Free;
        end;
      end;
  finally
    lRegistry.CloseKey;
    lRegistry.Free;
  end;
end;

{ Проверка наличия функций в DLL }
function TJ2534_v2.CheckFunctionDll(aFDLLHandle: THandle): boolean;
var
  lEFuncName: TEFuncNames;
  lFuncName: string;
begin
  // TEFuncName
  Result := True;
  for lEFuncName := Low(TEFuncNames) to high(TEFuncNames) do
  begin
    lFuncName := GetEnumName(TypeInfo(TEFuncNames), integer(lEFuncName));
    if not Assigned(GetProcAddress(fDLLHandle, PChar(lFuncName))) then
    begin
      Result := False;
      raise EExternalException.Create(Format('Не удалось загрузить функцию : %s', [lFuncName]));
    end;
  end;
end;

{ загрузка DLL }
function TJ2534_v2.LoadDLL(const aPathDll: string): boolean;
var
  LastError: Cardinal;
begin
  Result := False;
  if FileExists(aPathDll) then
  begin
    // обнуляем экземпляры структур
    FillChar(fDiagData, SizeOf(fDiagData), 0);
    fDLLHandle := LoadLibrary(PChar(aPathDll));
    LastError := GetLastError;
    if LastError = NO_ERROR then
    begin
      // проверяем на наличие функций в DLL
      try
        CheckFunctionDll(fDLLHandle);
        // присваиваем адреса функций
        FTPassThruOpen := GetProcAddress(fDLLHandle, 'PassThruOpen');
        FTPassThruClose := GetProcAddress(fDLLHandle, 'PassThruClose');
        FTPassThruConnect := GetProcAddress(fDLLHandle, 'PassThruConnect');
        FTPassThruDisconnect := GetProcAddress(fDLLHandle, 'PassThruDisconnect');
        FTPassThruReadMsgs := GetProcAddress(fDLLHandle, 'PassThruReadMsgs');
        FTPassThruWriteMsgs := GetProcAddress(fDLLHandle, 'PassThruWriteMsgs');
        FTPassThruStartMsgFilter := GetProcAddress(fDLLHandle, 'PassThruStartMsgFilter');
        FTPassThruStopMsgFilter := GetProcAddress(fDLLHandle, 'PassThruStopMsgFilter');
        FTPassThruReadVersion := GetProcAddress(fDLLHandle, 'PassThruReadVersion');
        FTPassThruIoctl := GetProcAddress(fDLLHandle, 'PassThruIoctl');
        Result := True;
      except
        on E: Exception do
          raise EExternalException.Create(E.Message);
      end;
    end
    else
    begin
      raise EExternalException.Create(Format('Error Load Api DLL : %s', [aPathDll]));
    end;
  end;

end;

function TJ2534_v2.PassThruOpen(): byte;
begin
  Result := FTPassThruOpen(nil, @fDiagData.Device_ID)
end;

function TJ2534_v2.PassThruClose(): byte;
begin
  Result := FTPassThruClose(fDiagData.Device_ID)
end;

function TJ2534_v2.PassThruConnect(const aProtocol_id, aFlag, aBaudRate: longWord): byte;
begin
  fDiagData.ProtocilID := aProtocol_id;
  fDiagData.Flags := aFlag;
  fDiagData.BaudRate := aBaudRate;
  Result := FTPassThruConnect(fDiagData.Device_ID, fDiagData.ProtocilID, fDiagData.Flags, fDiagData.BaudRate, @fDiagData.ChannelID);
end;

function TJ2534_v2.PassThruDisconnect(): byte;
begin
  Result := self.FTPassThruDisconnect(self.fDiagData.ChannelID);
end;

function TJ2534_v2.PassThruWriteMsg(const aData: array of byte; aTx_Flag, aTimeout: longWord): integer;
var
  num_msg: integer;
  lPassthruMsg: TPassthruMsg;
begin
  FillChar(lPassthruMsg, SizeOf(lPassthruMsg), 0);
  num_msg := 1;
  lPassthruMsg.ProtocolID := self.fDiagData.ProtocilID;
  lPassthruMsg.TxFlags := aTx_Flag;
  lPassthruMsg.DataSize := length(aData);
  move(aData[0], lPassthruMsg.Data[0], length(aData));
  Result := self.FTPassThruWriteMsgs(self.fDiagData.ChannelID, @lPassthruMsg, @num_msg, aTimeout);
end;

function TJ2534_v2.PassThruReadMsgs(aData: PTBytes; aSize: PLongWord; aTimeout: longWord): integer;
var
  lNumMsg: integer;
  lcount_read: integer;
  lPassthruMsg: TPassthruMsg;
begin
  aSize^ := 0;
  lcount_read := 10;
  Repeat
    lNumMsg := 1;
    FillChar(lPassthruMsg, SizeOf(lPassthruMsg), 0);
    lPassthruMsg.ProtocolID := fDiagData.ProtocilID;
    Result := self.FTPassThruReadMsgs(self.fDiagData.ChannelID, @lPassthruMsg, @lNumMsg, aTimeout);
    dec(lcount_read, 1);
  Until (lcount_read = 0) or (lPassthruMsg.RxStatus = 0);
  aSize^ := lPassthruMsg.DataSize;
  move(lPassthruMsg.Data[0], aData^, aSize^);
end;

function TJ2534_v2.PassThruStartMsgFilter(aFilter_type: longWord; aMaskMsg, aPatternMsg, aFlowControlMsg: TBytes;
  aTxFlags: longWord): integer;
var
  lMaskMsg, lPatternMsg, laFlowControlMsg: TPassthruMsg;
  i: integer;
begin
  FillChar(lMaskMsg, SizeOf(lMaskMsg), 0);
  FillChar(lPatternMsg, SizeOf(lPatternMsg), 0);
  FillChar(laFlowControlMsg, SizeOf(laFlowControlMsg), 0);
  lMaskMsg.TxFlags := aTxFlags;
  lPatternMsg.TxFlags := aTxFlags;
  laFlowControlMsg.TxFlags := aTxFlags;
  lMaskMsg.ProtocolID := fDiagData.ProtocilID;
  lPatternMsg.ProtocolID := fDiagData.ProtocilID;
  laFlowControlMsg.ProtocolID := fDiagData.ProtocilID;
  lMaskMsg.DataSize := 4;
  lPatternMsg.DataSize := 4;
  laFlowControlMsg.DataSize := 4;
  for i := 0 to 3 do
  begin
    lMaskMsg.Data[i] := aMaskMsg[i];
    lPatternMsg.Data[i] := aPatternMsg[i];
    laFlowControlMsg.Data[i] := aFlowControlMsg[i];
  end;
  Result := self.FTPassThruStartMsgFilter(self.fDiagData.ChannelID, aFilter_type, @lMaskMsg, @lPatternMsg, @laFlowControlMsg,
    @fDiagData.FilterID);
  ClearRxBufer;

end;

function TJ2534_v2.PassThruStopMsgFilter(): integer;
{ удаление фильтра приёма сообщений }
begin
  Result := self.FTPassThruStopMsgFilter(self.fDiagData.ChannelID, self.fDiagData.FilterID);
end;

function TJ2534_v2.ClearRxBufer(): integer;
begin
  Result := self.FTPassThruIoctl(self.fDiagData.ChannelID, $08, nil, nil);
end;

function TJ2534_v2.GetComment(error: TERROR_MESS): string;
begin
  Result := TERROR_CMT[error];
end;

end.
