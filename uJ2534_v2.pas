unit uJ2534_v2;

{
  Модуль работы с J2534 адаптером через dll адаптера.
}
interface

uses
  Windows,
  SysUtils,
  Classes,
  Registry;

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
    TPassThruOpen: function(Name: PChar; aPDeviceID: PLongWord): byte; stdcall;
    // закрыть шлюз связи с адаптером
    TPassThruClose: function(DeviceID: longWord): byte; stdcall;
    // Установка соединения по протоколу
    TPassThruConnect: function(DeviceID: longWord; ProtocolID: longWord; Flags: longWord; BaudRate: longWord; pChannelID: PLongWord)
      : integer; stdcall;
    // разьединение связи
    TPassThruDisconnect: function(DeviceID: longWord): byte; stdcall;
    // Чтение принятого пакета  ChannelID - идентификатор канала
    TPassThruReadMsgs: function(ChannelID: longWord; aPPassthruMsg: PPassthruMsg; pNumMsgs: Pint; Timeout: longWord): integer; stdcall;
    // отправка сообщения адаптеру
    TPassThruWriteMsgs: function(ChannelID: longWord; aPPassthruMsg: PPassthruMsg; pNumMsgs: Pint; Timeout: longWord): integer; stdcall;
    // установка фильтра сообщения
    TPassThruStartMsgFilter: function(ChannelID: longWord; FilterType: longWord; pMaskMsg: pointer; pPatternMsg: pointer;
      pFlowControlMsg: pointer; FilterID: pointer): integer; stdcall;
    // удаление фильтров сообщений
    TPassThruStopMsgFilter: function(ChannelID: longWord; FilterID: longWord): integer; stdcall;
    // чтение версии прошивки, длл, api
    TPassThruReadVersion: function(DeviceID: longWord; pFirmwareVersion, pDllVersion, pApiVersion: pointer): integer; stdcall;
    // управление вводом и выводом
    TPassThruIoctl: function(ChannelID: longWord; IoctlID: longWord; pInput: pointer; pOutput: pointer): integer; stdcall;
    // Храним дескриптор DLL
    fDLLHandle: THandle;
    // Хранилище данных адаптера. DevId для последующей работы с адаптером.
    fDiagData: TDiagData;
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
    /// <param name="aPDeviceID">Указатель для хранения Device ID</param>
    function PassThruOpen(): byte;
    function PassThruClose(): byte;
    function PassThruConnect(const aProtocol_id, aFlag, aBaudRate: longWord): byte;
  published
    { published declarations }
  end;

implementation

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
  i: integer;
  lAddrFunctions: pointer;
  LastError: DWORD;
const
  FUNC_NAME: array [0 .. 9] of PChar = ('PassThruOpen', 'PassThruClose', 'PassThruConnect', 'PassThruDisconnect', 'PassThruReadMsgs',
    'PassThruWriteMsgs', 'PassThruStartMsgFilter', 'PassThruStopMsgFilter', 'PassThruReadVersion', 'PassThruIoctl');
begin
  Result := False;
  for i := Low(FUNC_NAME) to High(FUNC_NAME) do
  begin
    // Проверяем успешность поиска каждой функции
    lAddrFunctions := GetProcAddress(fDLLHandle, FUNC_NAME[i]);
    LastError := GetLastError;
    if LastError = ERROR_SUCCESS then
    begin
      Result := True;
    end
    else
    begin
      Result := False;
      Break;
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
    if LastError = ERROR_SUCCESS then
    begin
      // проверка наличия функций в DLL
      if CheckFunctionDll(fDLLHandle) then
      begin
        // загрузка адресов функций
        TPassThruOpen := GetProcAddress(fDLLHandle, 'PassThruOpen1');
        TPassThruClose := GetProcAddress(fDLLHandle, 'PassThruClose');
        TPassThruConnect := GetProcAddress(fDLLHandle, 'PassThruConnect');
        TPassThruDisconnect := GetProcAddress(fDLLHandle, 'PassThruDisconnect');
        TPassThruReadMsgs := GetProcAddress(fDLLHandle, 'PassThruReadMsgs');
        TPassThruWriteMsgs := GetProcAddress(fDLLHandle, 'PassThruWriteMsgs');
        TPassThruStartMsgFilter := GetProcAddress(fDLLHandle, 'PassThruStartMsgFilter');
        TPassThruStopMsgFilter := GetProcAddress(fDLLHandle, 'PassThruStopMsgFilter');
        TPassThruReadVersion := GetProcAddress(fDLLHandle, 'PassThruReadVersion');
        TPassThruIoctl := GetProcAddress(fDLLHandle, 'PassThruIoctl');
        Result := True;
      end;
    end
    else
    begin
      FreeLibrary(fDLLHandle);
    end;
  end;
end;

function TJ2534_v2.PassThruOpen(): byte;
begin
  Result := $FF;
  if Assigned(TPassThruOpen) then
    Result := TPassThruOpen(nil, @fDiagData.Device_ID)
  else
    raise EExternalException.Create('Function PassThruOpen not found');
end;

function TJ2534_v2.PassThruClose(): byte;
begin
  Result := $FF;
  if Assigned(TPassThruClose) then
    Result := TPassThruClose(fDiagData.Device_ID)
  else
    raise EExternalException.Create('Function PassThruClose not found');
end;

function TJ2534_v2.PassThruConnect(const aProtocol_id, aFlag, aBaudRate: longWord): byte;
begin
  if Assigned(TPassThruConnect) then
  begin
    fDiagData.ProtocilID := aProtocol_id;
    fDiagData.Flags := aFlag;
    fDiagData.BaudRate := aBaudRate;
    Result := TPassThruConnect(fDiagData.Device_ID, fDiagData.ProtocilID, fDiagData.Flags, fDiagData.BaudRate, @fDiagData.ChannelID);
  end
  else
    raise EExternalException.Create('Function PassThruConnect not found');
end;

end.
