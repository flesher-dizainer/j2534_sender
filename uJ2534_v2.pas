unit uJ2534_v2;

interface

uses
  Windows,
  SysUtils,
  Classes,
  Registry;

  type TFLAGS = record
    const
    CONNECT_FLAGS_CAN_11BIT_ID :longWord = 0;
    TRANSMITT_FLAGS_ISO15765_FRAME_PAD : LongWord	= $00000040;
    FILTER_TYPE_FLOW_CONTROL_FILTER : LongWord = 3;
  end;
{-----данные протокола, ид канала и т.п}
  type TDIAG = record
   Device_ID  : LongWord;//идент устройства
   ProtocilID : LongWord;//идент протокола связи
   Flags      : longWord;//флаги соединения
   Baudrate   : LongWord;//скорость связи
   ChannelID  : longword;//идент канала связи
   FilterID   : longword;//идент фильтра, нужен для удаления фильтра
  end;
{--- структура сообщения ---}
type
  TPASSTHRU_MSG = record
    ProtocolID: LongWord;  // vehicle network protocol
    RxStatus: LongWord;   // receive message status
    TxFlags: LongWord;    // transmit message flags
    Timestamp: LongWord;  // receive message timestamp (in microseconds)
    DataSize: LongWord;   // byte size of message payload in the Data array
    ExtraDataIndex: LongWord;  // start of extra data (i.e. CRC, checksum, etc) in Data array
    Data: array[0..4127] of Byte; // message payload or data
  end;

type
  // Определение массива ошибок, доступного внешним методам
  TERROR_MESS = array [0..$1A] of string;

  TJ2534_v2 = class
  private
    //открыть шлюз связи с адаптером
    TPassThruOpen: function(Name: PChar; DeviceID: PLongWord): Byte; stdcall;
    //закрыть шлюз связи с адаптером
    TPassThruClose: function(DeviceID: LongWord): Byte; stdcall;
    //Установка соединения по протоколу
    TPassThruConnect : function ( DeviceID : LongWord; ProtocolID : LongWord; Flags  : LongWord; BaudRate: LongWord; pChannelID : PLongWord):integer;stdcall;
    //разьединение связи
    TPassThruDisconnect : function ( DeviceID : LongWord ):byte;stdcall;
    //Чтение принятого пакета  ChannelID - идентификатор канала
    TPassThruReadMsgs : function ( ChannelID: LongWord; TPASSTHRU_MSG_ : pointer ; pNumMsgs :Pint; Timeout : LongWord):integer;stdcall;
    //отправка сообщения адаптеру
    TPassThruWriteMsgs : function ( ChannelID: LongWord; TPASSTHRU_MSG_ : Pointer ; pNumMsgs : Pint; Timeout : LongWord ):integer;stdcall;
    //установка фильтра сообщения
    TPassThruStartMsgFilter : function ( ChannelID: LongWord; FilterType: LongWord; pMaskMsg : pointer; pPatternMsg: pointer; pFlowControlMsg: pointer; FilterID:pointer ):integer;stdcall;
    //удаление фильтров сообщений
    TPassThruStopMsgFilter : function ( ChannelID: LongWord; FilterID:LongWord ):integer;stdcall;
    //чтение версии прошивки, длл, api
    TPassThruReadVersion : function (DeviceID : LongWord; pFirmwareVersion, pDllVersion, pApiVersion : Pointer ):integer;stdcall;
    //управление вводом и выводом
    TPassThruIoctl : function ( ChannelID : LongWord; IoctlID:LongWord; pInput:pointer; pOutput:pointer):integer;stdcall;
    // Храним дескриптор DLL
    FDLLHandle: THandle;
    // экземпляр структуры TDIAG
    DiagInfo : TDIAG;
    // экземпляр структуры для отправки сообщений
    PASSTHRU_WRITE_MSG : TPASSTHRU_MSG;
    // экземпляр структуры для приёма сообщений
    PASSTHRU_READ_MSG : TPASSTHRU_MSG;
  public
    constructor Create(DLLPath: string);
    destructor Destroy; override;
    function PassThruOpen(): Byte;
    function PassThruClose(): Byte;
    function PassThruConnect(Protocol_id:LongWord; flag:LongWord; Baudrate:LongWord):Byte;
    function PassThruDisconnect():byte;
    function PassThruWriteMsg(data:array of byte; Tx_Flag:LongWord; TimeOut : LongWord):integer;
    function PassThruReadMsgs(data:Pointer; Size:PlongWord; TimeOut : LongWord):integer;
    function PassThruStartMsgFilter(Filter_type:LongWord;MaskMsg,PatternMsg,FlowControlMsg:array of byte;TXFLAGS:LongWord):Integer;
    function PassThruStopMsgFilter():Integer;
    function ClearRxBufer():integer;
    function GetErrorDescriptions(error_code:integer):string;
  end;
//нужно для получения путей к длл без создания экземпляра класса
function GetListDll():TstringList;

implementation

var
  ERROR_MESS: TERROR_MESS = // Объявление массива ошибок
  (
  'STATUS_NOERROR', //  Функция выполнена успешно
  'ERR_SUCCESS',    //
  'ERR_NOT_SUPPORTED',//Адаптер не поддерживает запрошенные параметры.
  'ERR_INVALID_CHANNEL_ID',//Задан не существующий идентификатор канала ChannelID.
  'ERR_NULL_PARAMETER',//Не задан указатель на буфер приёмных пакетов pMsg.
  'ERR_INVALID_IOCTL_VALUE',//Не правильно задан значение Ioctl параметра.
  'ERR_INVALID_FLAGS',//Задан не существующий флаг
  'ERR_FAILED',//Определён стандартом J2534. В адаптере, для этой функции не используется.
  'ERR_DEVICE_NOT_CONNECTED',//Нет соединения с адаптером.
  'ERR_TIMEOUT',//За заданное время пришло меньше сообщений чем заказали.
  'ERR_INVALID_MSG',//  Не правильная структура сообщения заданная в указателе pMsg
  'ERR_INVALID_TIME_INTERVAL',//  Не правильно задан интервал выдачи сообщений
  'ERR_EXCEEDED_LIMIT',//Превышено количество установленных фильтров.
  'ERR_INVALID_MSG_ID',//Задан не существующий идентификатор адаптера DeviceID
  'ERR_DEVICE_IN_USE',//Прибор уже используется программой. Возможные причины: Не была выполнена функция PassThruClose в предыдущей сессии.
  'ERR_INVALID_IOCTL_ID',//Задан не существующий идентификатор канала IoctlID
  'ERR_BUFFER_EMPTY',//Приёмная очередь пустая.
  'ERR_BUFFER_FULL',//  Очередь передачи переполнена.
  'ERR_BUFFER_OVERFLOW',//Показывает что приёмная очередь была переполнена и сообщения были потеряны. Реальное количество принятых сообщений будет находится в NumMsgs.
  'ERR_PIN_INVALID',//Не правильно задан вывод коммутатора.
  'ERR_CHANNEL_IN_USE',//  Канал уже используется. Определён стандартом J2534.
  'ERR_MSG_PROTOCOL_ID',//Протокол заданный в параметрах передаваемого сообщения не совпадает с протоколом заданным в ChannelID
  'ERR_INVALID_FILTER_ID',//Задан не существующий идентификатор фильтра FilterID
  'ERR_NO_FLOW_CONTROL',//Для протокола ISO15765 не установлен фильтр для Flow Control.
  'ERR_NOT_UNIQUE',//CAN ID в pPatternMsg или pFlowControlMsg соответствует какому либо ID в уже существующем FLOW_CONTROL_FILTER
  'ERR_INVALID_BAUDRATE',//Задана не правильная скорость обмена
  'ERR_INVALID_DEVICE_ID'//Задан не существующий идентификатор адаптера DeviceID
  );
//получаем список длл
function GetListDll():TstringList;
var
P:^TStringList;
reg : TRegistry;
s   : TStringList;
i:integer;
str:string;
dll_:string;
begin
  result:=TstringList.Create;
  s:=TStringList.Create;
  reg:=TRegistry.Create;
  reg.RootKey:=HKEY_LOCAL_MACHINE;
  if reg.OpenKey('SOFTWARE', false) then
    if  reg.OpenKeyReadOnly('PassThruSupport.04.04') then
  reg.GetKeyNames(s);
  str:=reg.CurrentPath;

  for i:=0 to s.Count-1 do begin

    //проверка открытия секции
    if  reg.OpenKeyReadOnly(s[i]) then begin

    //проверка существования dll
      dll_:=reg.ReadString('FunctionLibrary');
      if dll_<>'' then begin
         result.Add(dll_);
      end;

      reg.CloseKey;
      reg.OpenKeyReadOnly(str);
    end;
  end;

  reg.CloseKey;
  reg.Free;
  s.Free;
end;

constructor TJ2534_v2.Create(DLLPath: string);
begin
  //обнуляем экземпляры структур
  FillChar(DiagInfo, SizeOf(DiagInfo), 0);
  FillChar(PASSTHRU_WRITE_MSG, SizeOf(PASSTHRU_WRITE_MSG), 0);
  FillChar(PASSTHRU_READ_MSG, SizeOf(PASSTHRU_READ_MSG), 0);
  FDLLHandle := LoadLibrary(PChar(DLLPath));

  if FDLLHandle = 0 then
    raise Exception.Create('Не удалось загрузить DLL: ' + DLLPath);

  // Проверяем успешность поиска каждой функции
  TPassThruOpen := GetProcAddress(FDLLHandle, 'PassThruOpen');
  if addr(TPassThruOpen) = nil then
    raise Exception.Create('Не удалось найти функцию PassThruOpen в DLL');

  TPassThruClose := GetProcAddress(FDLLHandle, 'PassThruClose');
  if addr(TPassThruClose) = nil then
    raise Exception.Create('Не удалось найти функцию PassThruClose в DLL');

  TPassThruConnect := GetProcAddress(FDLLHandle, 'PassThruConnect');
  if addr(TPassThruConnect) = nil then
    raise Exception.Create('Не удалось найти функцию PassThruConnect в DLL');

  TPassThruDisconnect := GetProcAddress(FDLLHandle, 'PassThruDisconnect');
  if addr(TPassThruDisconnect) = nil then
    raise Exception.Create('Не удалось найти функцию PassThruDisconnect в DLL');

  TPassThruReadMsgs := GetProcAddress(FDLLHandle, 'PassThruReadMsgs');
  if addr(TPassThruReadMsgs) = nil then
    raise Exception.Create('Не удалось найти функцию PassThruReadMsgs в DLL');

  TPassThruWriteMsgs := GetProcAddress(FDLLHandle, 'PassThruWriteMsgs');
  if addr(TPassThruWriteMsgs) = nil then
    raise Exception.Create('Не удалось найти функцию PassThruWriteMsgs в DLL');

  TPassThruStartMsgFilter := GetProcAddress(FDLLHandle, 'PassThruStartMsgFilter');
  if addr(TPassThruStartMsgFilter) = nil then
    raise Exception.Create('Не удалось найти функцию PassThruStartMsgFilter в DLL');

  TPassThruStopMsgFilter := GetProcAddress(FDLLHandle, 'PassThruStopMsgFilter');
  if addr(TPassThruStopMsgFilter) = nil then
    raise Exception.Create('Не удалось найти функцию PassThruStopMsgFilter в DLL');

  TPassThruReadVersion := GetProcAddress(FDLLHandle, 'PassThruReadVersion');
  if addr(TPassThruReadVersion) = nil then
    raise Exception.Create('Не удалось найти функцию PassThruReadVersion в DLL');

  TPassThruIoctl := GetProcAddress(FDLLHandle, 'PassThruIoctl');
  if addr(TPassThruReadVersion) = nil then
    raise Exception.Create('Не удалось найти функцию PassThruIoctl в DLL');
end;

destructor TJ2534_v2.Destroy;
begin
  // Освобождаем DLL, если она была загружена
  if FDLLHandle <> 0 then
    FreeLibrary(FDLLHandle);
  inherited Destroy;
end;

function TJ2534_v2.PassThruOpen(): Byte;
begin
  try
    // Вызываем метод PassThruOpen, передавая указатель
    Result := TPassThruOpen(nil, @DiagInfo.Device_ID);
  except
    on E: Exception do
    begin
      // Обработка ошибки
      raise Exception.Create('Не удалось открыть шлюз адаптера');
    end;
  end;
end;

function TJ2534_v2.PassThruClose(): Byte;
begin
  try
    // Вызываем метод PassThruClose
    Result := TPassThruClose(DiagInfo.Device_ID);
  except
    on E: Exception do
    begin
      // Обработка ошибки
      raise Exception.Create('Не удалось закрыть шлюз адаптера');
    end;
  end;
end;

function TJ2534_v2.PassThruConnect(Protocol_id: Cardinal; flag: Cardinal; Baudrate: Cardinal):byte;
begin
  try
    DiagInfo.ProtocilID := Protocol_id;
    DiagInfo.Flags := flag;
    DiagInfo.Baudrate := Baudrate;
    // Вызываем метод PassThruConnect
    Result := TPassThruConnect(DiagInfo.Device_ID, DiagInfo.ProtocilID, DiagInfo.Flags, DiagInfo.Baudrate, @DiagInfo.ChannelID);
  except
    on E: Exception do
    begin
      // Обработка ошибки
      raise Exception.Create('Не удалось установить соединение');
    end;
  end;
end;

function TJ2534_v2.PassThruDisconnect():byte;
begin
  try
    Result := self.TPassThruDisconnect(self.DiagInfo.ChannelID);
  except
    on E: Exception do
    begin
      // Обработка ошибки
      raise Exception.Create('Ошибка PassThruDisconnect');
    end;
  end;
end;

function TJ2534_v2.PassThruWriteMsg(data: array of Byte; Tx_Flag: Cardinal; TimeOut: Cardinal):integer;
var
num_msg : integer;
begin
  try
    FillChar(PASSTHRU_WRITE_MSG, SizeOf(PASSTHRU_WRITE_MSG), 0);
    num_msg := 1;
    PASSTHRU_WRITE_MSG.ProtocolID := self.DiagInfo.ProtocilID;
    PASSTHRU_WRITE_MSG.TxFlags := Tx_Flag;
    PASSTHRU_WRITE_MSG.DataSize := length(data);
    move(data[0], PASSTHRU_WRITE_MSG.Data[0], length(data));
    Result := self.TPassThruWriteMsgs(self.DiagInfo.ChannelID, @PASSTHRU_WRITE_MSG, @num_msg, TimeOut);
  except
    on E: Exception do
    begin
      // Обработка ошибки
      raise Exception.Create('Ошибка PassThruWriteMsgs');
    end;
  end;
end;

function TJ2534_v2.PassThruReadMsgs(data: Pointer; Size: PLongWord; TimeOut: Cardinal):integer;
var
  NumMsg:Integer;
begin
  try
    Size^ := 0;
    FillChar(PASSTHRU_READ_MSG, SizeOf(PASSTHRU_READ_MSG), 0);
    NumMsg:=1;
    PASSTHRU_READ_MSG.ProtocolID := DiagInfo.ProtocilID;
    Result := self.TPassThruReadMsgs(self.DiagInfo.ChannelID, @PASSTHRU_READ_MSG, @NumMsg, TimeOut);
    Size^ := PASSTHRU_READ_MSG.DataSize;
    move(PASSTHRU_READ_MSG.Data[0], data^, Size^);
  except
    on E: Exception do
    begin
      // Обработка ошибки
      raise Exception.Create('Ошибка PassThruReadMsgs');
    end;
  end;
end;

function TJ2534_v2.PassThruStartMsgFilter(Filter_type:LongWord;MaskMsg,PatternMsg,FlowControlMsg:array of byte;TXFLAGS:LongWord):Integer;
{установка фильтра приёма сообщений}
var
  mask, patter, FC: TPASSTHRU_MSG;
  i:integer;
begin
  FillChar(mask, SizeOf(mask), 0);
  FillChar(patter, SizeOf(patter), 0);
  FillChar(FC, SizeOf(FC), 0);
  mask.TxFlags:=TXFLAGS;
  patter.TxFlags:=TXFLAGS;
  FC.TxFlags:=TXFLAGS;
  mask.ProtocolID:=DiagInfo.ProtocilID;
  patter.ProtocolID:=DiagInfo.ProtocilID;
  FC.ProtocolID:=DiagInfo.ProtocilID;
  for I := 0 to 3 do begin
    mask.Data[i]:=MaskMsg[i];
    patter.Data[i]:=PatternMsg[i];
    FC.Data[i]:=FlowControlMsg[i];
  end;
  try
    result:=self.TPassThruStartMsgFilter(self.DiagInfo.ChannelID, Filter_type, @mask, @patter, @FC, @DiagInfo.FilterID);
  except
    on E: Exception do
    begin
      // Обработка ошибки
      raise Exception.Create('Ошибка PassThruReadMsgs');
    end;
  end;
end;

function TJ2534_v2.PassThruStopMsgFilter():integer;
{удаление фильтра приёма сообщений}
begin
  try
    Result := self.TPassThruStopMsgFilter(self.DiagInfo.ChannelID, self.DiagInfo.FilterID);
  except
    on E: Exception do
    begin
      // Обработка ошибки
      raise Exception.Create('Ошибка PassThruStopMsgFilter');
    end;
  end;
end;

function TJ2534_v2.ClearRxBufer():integer;
begin
  try
    Result := self.TPassThruIoctl(self.DiagInfo.ChannelID, $08, nil, nil);
  except
    on E: Exception do
    begin
      // Обработка ошибки
      raise Exception.Create('Ошибка ClearRx');
    end;
  end;
end;

function TJ2534_v2.GetErrorDescriptions(error_code: Integer):string;
begin
   if error_code < length(ERROR_MESS) then result:=ERROR_MESS[error_code] else
    result:='index error out of range';

end;
end.

