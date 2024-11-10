unit uJ2534_v2;

interface

uses
  Windows,
  SysUtils,
  Classes,
  Registry;

type
  TFLAGS = record
  const
    CONNECT_FLAGS_CAN_11BIT_ID: longWord = 0;
    TRANSMITT_FLAGS_ISO15765_FRAME_PAD: longWord = $00000040;
    FILTER_TYPE_FLOW_CONTROL_FILTER: longWord = 3;
  end;

  { -----������ ���������, �� ������ � �.� }
type
  TDIAG = record
    Device_ID: longWord; // ����� ����������
    ProtocilID: longWord; // ����� ��������� �����
    Flags: longWord; // ����� ����������
    Baudrate: longWord; // �������� �����
    ChannelID: longWord; // ����� ������ �����
    FilterID: longWord; // ����� �������, ����� ��� �������� �������
  end;

  { --- ��������� ��������� --- }
type
  TPASSTHRU_MSG = record
    ProtocolID: longWord; // vehicle network protocol
    RxStatus: longWord; // receive message status
    TxFlags: longWord; // transmit message flags
    Timestamp: longWord; // receive message timestamp (in microseconds)
    DataSize: longWord; // byte size of message payload in the Data array
    ExtraDataIndex: longWord;
    // start of extra data (i.e. CRC, checksum, etc) in Data array
    Data: array [0 .. 4127] of Byte; // message payload or data
  end;

type
  // ����������� ������� ������, ���������� ������� �������
  TERROR_MESS = array [0 .. $1A] of string;

  TJ2534_v2 = class
  private
    // ������� ���� ����� � ���������
    TPassThruOpen: function(Name: PChar; DeviceID: PLongWord): Byte; stdcall;
    // ������� ���� ����� � ���������
    TPassThruClose: function(DeviceID: longWord): Byte; stdcall;
    // ��������� ���������� �� ���������
    TPassThruConnect: function(DeviceID: longWord; ProtocolID: longWord;
      Flags: longWord; Baudrate: longWord; pChannelID: PLongWord)
      : integer; stdcall;
    // ������������ �����
    TPassThruDisconnect: function(DeviceID: longWord): Byte; stdcall;
    // ������ ��������� ������  ChannelID - ������������� ������
    TPassThruReadMsgs: function(ChannelID: longWord; TPASSTHRU_MSG_: pointer;
      pNumMsgs: Pint; Timeout: longWord): integer; stdcall;
    // �������� ��������� ��������
    TPassThruWriteMsgs: function(ChannelID: longWord; TPASSTHRU_MSG_: pointer;
      pNumMsgs: Pint; Timeout: longWord): integer; stdcall;
    // ��������� ������� ���������
    TPassThruStartMsgFilter: function(ChannelID: longWord; FilterType: longWord;
      pMaskMsg: pointer; pPatternMsg: pointer; pFlowControlMsg: pointer;
      FilterID: pointer): integer; stdcall;
    // �������� �������� ���������
    TPassThruStopMsgFilter: function(ChannelID: longWord; FilterID: longWord)
      : integer; stdcall;
    // ������ ������ ��������, ���, api
    TPassThruReadVersion: function(DeviceID: longWord;
      pFirmwareVersion, pDllVersion, pApiVersion: pointer): integer; stdcall;
    // ���������� ������ � �������
    TPassThruIoctl: function(ChannelID: longWord; IoctlID: longWord;
      pInput: pointer; pOutput: pointer): integer; stdcall;
    // ������ ���������� DLL
    FDLLHandle: THandle;
    // ��������� ��������� TDIAG
    DiagInfo: TDIAG;
    // ��������� ��������� ��� �������� ���������
    PASSTHRU_WRITE_MSG: TPASSTHRU_MSG;
    // ��������� ��������� ��� ����� ���������
    PASSTHRU_READ_MSG: TPASSTHRU_MSG;
  public
    constructor Create(DLLPath: string);
    destructor Destroy; override;
    function PassThruOpen(): Byte;
    function PassThruClose(): Byte;
    function PassThruConnect(Protocol_id: longWord; flag: longWord;
      Baudrate: longWord): Byte;
    function PassThruDisconnect(): Byte;
    function PassThruWriteMsg(Data: array of Byte; Tx_Flag: longWord;
      Timeout: longWord): integer;
    function PassThruReadMsgs(Data: pointer; Size: PLongWord;
      Timeout: longWord): integer;
    function PassThruStartMsgFilter(Filter_type: longWord;
      MaskMsg, PatternMsg, FlowControlMsg: array of Byte;
      TxFlags: longWord): integer;
    function PassThruStopMsgFilter(): integer;
    function PassThrueReadVersion(): TstringList;
    function ClearRxBufer(): integer;
    function GetErrorDescriptions(error_code: integer): string;
  end;

  // ����� ��� ��������� ����� � ��� ��� �������� ���������� ������
function GetListDll(StringList: pointer): TstringList;

implementation

var
  ERROR_MESS: TERROR_MESS = // ���������� ������� ������
    ('STATUS_NOERROR', // ������� ��������� �������
    'ERR_SUCCESS', //
    'ERR_NOT_SUPPORTED', // ������� �� ������������ ����������� ���������.
    'ERR_INVALID_CHANNEL_ID',
    // ����� �� ������������ ������������� ������ ChannelID.
    'ERR_NULL_PARAMETER', // �� ����� ��������� �� ����� ������� ������� pMsg.
    'ERR_INVALID_IOCTL_VALUE', // �� ��������� ����� �������� Ioctl ���������.
    'ERR_INVALID_FLAGS', // ����� �� ������������ ����
    'ERR_FAILED',
    // �������� ���������� J2534. � ��������, ��� ���� ������� �� ������������.
    'ERR_DEVICE_NOT_CONNECTED', // ��� ���������� � ���������.
    'ERR_TIMEOUT', // �� �������� ����� ������ ������ ��������� ��� ��������.
    'ERR_INVALID_MSG',
    // �� ���������� ��������� ��������� �������� � ��������� pMsg
    'ERR_INVALID_TIME_INTERVAL', // �� ��������� ����� �������� ������ ���������
    'ERR_EXCEEDED_LIMIT', // ��������� ���������� ������������� ��������.
    'ERR_INVALID_MSG_ID',
    // ����� �� ������������ ������������� �������� DeviceID
    'ERR_DEVICE_IN_USE',
    // ������ ��� ������������ ����������. ��������� �������: �� ���� ��������� ������� PassThruClose � ���������� ������.
    'ERR_INVALID_IOCTL_ID',
    // ����� �� ������������ ������������� ������ IoctlID
    'ERR_BUFFER_EMPTY', // ������� ������� ������.
    'ERR_BUFFER_FULL', // ������� �������� �����������.
    'ERR_BUFFER_OVERFLOW',
    // ���������� ��� ������� ������� ���� ����������� � ��������� ���� ��������. �������� ���������� �������� ��������� ����� ��������� � NumMsgs.
    'ERR_PIN_INVALID', // �� ��������� ����� ����� �����������.
    'ERR_CHANNEL_IN_USE', // ����� ��� ������������. �������� ���������� J2534.
    'ERR_MSG_PROTOCOL_ID',
    // �������� �������� � ���������� ������������� ��������� �� ��������� � ���������� �������� � ChannelID
    'ERR_INVALID_FILTER_ID',
    // ����� �� ������������ ������������� ������� FilterID
    'ERR_NO_FLOW_CONTROL',
    // ��� ��������� ISO15765 �� ���������� ������ ��� Flow Control.
    'ERR_NOT_UNIQUE',
    // CAN ID � pPatternMsg ��� pFlowControlMsg ������������� ������ ���� ID � ��� ������������ FLOW_CONTROL_FILTER
    'ERR_INVALID_BAUDRATE', // ������ �� ���������� �������� ������
    'ERR_INVALID_DEVICE_ID'
    // ����� �� ������������ ������������� �������� DeviceID
    );

  // �������� ������ ���
function GetListDll(StringList: pointer): TstringList;
var
  P: ^TstringList;
  reg: TRegistry;
  s: TstringList;
  i: integer;
  str: string;
  dll_: string;
begin
  P := StringList;
  result := TstringList.Create;
  s := TstringList.Create;
  reg := TRegistry.Create;
  reg.RootKey := HKEY_LOCAL_MACHINE;
  if reg.OpenKey('SOFTWARE', false) then
    if reg.OpenKeyReadOnly('PassThruSupport.04.04') then
      reg.GetKeyNames(s);
  str := reg.CurrentPath;

  for i := 0 to s.Count - 1 do
  begin

    // �������� �������� ������
    if reg.OpenKeyReadOnly(s[i]) then
    begin

      // �������� ������������� dll
      dll_ := reg.ReadString('FunctionLibrary');
      if dll_ <> '' then
      begin
        P^.Add(s[i]);
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
  // �������� ���������� ��������
  FillChar(DiagInfo, SizeOf(DiagInfo), 0);
  FillChar(PASSTHRU_WRITE_MSG, SizeOf(PASSTHRU_WRITE_MSG), 0);
  FillChar(PASSTHRU_READ_MSG, SizeOf(PASSTHRU_READ_MSG), 0);
  FDLLHandle := LoadLibrary(PChar(DLLPath));

  if FDLLHandle = 0 then
    raise Exception.Create('�� ������� ��������� DLL: ' + DLLPath);

  // ��������� ���������� ������ ������ �������
  TPassThruOpen := GetProcAddress(FDLLHandle, 'PassThruOpen');
  if addr(TPassThruOpen) = nil then
    raise Exception.Create('�� ������� ����� ������� PassThruOpen � DLL');

  TPassThruClose := GetProcAddress(FDLLHandle, 'PassThruClose');
  if addr(TPassThruClose) = nil then
    raise Exception.Create('�� ������� ����� ������� PassThruClose � DLL');

  TPassThruConnect := GetProcAddress(FDLLHandle, 'PassThruConnect');
  if addr(TPassThruConnect) = nil then
    raise Exception.Create('�� ������� ����� ������� PassThruConnect � DLL');

  TPassThruDisconnect := GetProcAddress(FDLLHandle, 'PassThruDisconnect');
  if addr(TPassThruDisconnect) = nil then
    raise Exception.Create('�� ������� ����� ������� PassThruDisconnect � DLL');

  TPassThruReadMsgs := GetProcAddress(FDLLHandle, 'PassThruReadMsgs');
  if addr(TPassThruReadMsgs) = nil then
    raise Exception.Create('�� ������� ����� ������� PassThruReadMsgs � DLL');

  TPassThruWriteMsgs := GetProcAddress(FDLLHandle, 'PassThruWriteMsgs');
  if addr(TPassThruWriteMsgs) = nil then
    raise Exception.Create('�� ������� ����� ������� PassThruWriteMsgs � DLL');

  TPassThruStartMsgFilter := GetProcAddress(FDLLHandle,
    'PassThruStartMsgFilter');
  if addr(TPassThruStartMsgFilter) = nil then
    raise Exception.Create
      ('�� ������� ����� ������� PassThruStartMsgFilter � DLL');

  TPassThruStopMsgFilter := GetProcAddress(FDLLHandle, 'PassThruStopMsgFilter');
  if addr(TPassThruStopMsgFilter) = nil then
    raise Exception.Create
      ('�� ������� ����� ������� PassThruStopMsgFilter � DLL');

  TPassThruReadVersion := GetProcAddress(FDLLHandle, 'PassThruReadVersion');
  if addr(TPassThruReadVersion) = nil then
    raise Exception.Create
      ('�� ������� ����� ������� PassThruReadVersion � DLL');

  TPassThruIoctl := GetProcAddress(FDLLHandle, 'PassThruIoctl');
  if addr(TPassThruReadVersion) = nil then
    raise Exception.Create('�� ������� ����� ������� PassThruIoctl � DLL');
end;

destructor TJ2534_v2.Destroy;
begin
  // ����������� DLL, ���� ��� ���� ���������
  if FDLLHandle <> 0 then
    FreeLibrary(FDLLHandle);

  inherited Destroy;
end;

function TJ2534_v2.PassThruOpen(): Byte;
begin
  try
    // �������� ����� PassThruOpen, ��������� ���������
    result := TPassThruOpen(nil, @DiagInfo.Device_ID);
  except
    on E: Exception do
    begin
      // ��������� ������
      raise Exception.Create('�� ������� ������� ���� ��������');
    end;
  end;
end;

function TJ2534_v2.PassThruClose(): Byte;
begin
  try
    // �������� ����� PassThruClose
    result := TPassThruClose(DiagInfo.Device_ID);
  except
    on E: Exception do
    begin
      // ��������� ������
      raise Exception.Create('�� ������� ������� ���� ��������');
    end;
  end;
end;

function TJ2534_v2.PassThruConnect(Protocol_id: Cardinal; flag: Cardinal;
  Baudrate: Cardinal): Byte;
begin
  try
    DiagInfo.ProtocilID := Protocol_id;
    DiagInfo.Flags := flag;
    DiagInfo.Baudrate := Baudrate;
    // �������� ����� PassThruConnect
    result := TPassThruConnect(DiagInfo.Device_ID, DiagInfo.ProtocilID,
      DiagInfo.Flags, DiagInfo.Baudrate, @DiagInfo.ChannelID);
  except
    on E: Exception do
    begin
      // ��������� ������
      raise Exception.Create('�� ������� ���������� ����������');
    end;
  end;
end;

function TJ2534_v2.PassThruDisconnect(): Byte;
begin
  try
    result := self.TPassThruDisconnect(self.DiagInfo.ChannelID);
  except
    on E: Exception do
    begin
      // ��������� ������
      raise Exception.Create('������ PassThruDisconnect');
    end;
  end;
end;

function TJ2534_v2.PassThruWriteMsg(Data: array of Byte; Tx_Flag: Cardinal;
  Timeout: Cardinal): integer;
var
  num_msg: integer;
begin
  try
    FillChar(PASSTHRU_WRITE_MSG, SizeOf(PASSTHRU_WRITE_MSG), 0);
    num_msg := 1;
    PASSTHRU_WRITE_MSG.ProtocolID := self.DiagInfo.ProtocilID;
    PASSTHRU_WRITE_MSG.TxFlags := Tx_Flag;
    PASSTHRU_WRITE_MSG.DataSize := length(Data);
    move(Data[0], PASSTHRU_WRITE_MSG.Data[0], length(Data));
    result := self.TPassThruWriteMsgs(self.DiagInfo.ChannelID,
      @PASSTHRU_WRITE_MSG, @num_msg, Timeout);
  except
    on E: Exception do
    begin
      // ��������� ������
      raise Exception.Create('������ PassThruWriteMsgs');
    end;
  end;
end;

function TJ2534_v2.PassThruReadMsgs(Data: pointer; Size: PLongWord;
  Timeout: Cardinal): integer;
var
  NumMsg: integer;
begin
  try
    Size^ := 0;
    FillChar(PASSTHRU_READ_MSG, SizeOf(PASSTHRU_READ_MSG), 0);
    NumMsg := 1;
    PASSTHRU_READ_MSG.ProtocolID := DiagInfo.ProtocilID;
    result := self.TPassThruReadMsgs(self.DiagInfo.ChannelID,
      @PASSTHRU_READ_MSG, @NumMsg, Timeout);
    Size^ := PASSTHRU_READ_MSG.DataSize;
    move(PASSTHRU_READ_MSG.Data[0], Data^, Size^);
  except
    on E: Exception do
    begin
      // ��������� ������
      raise Exception.Create('������ PassThruReadMsgs');
    end;
  end;
end;

function TJ2534_v2.PassThruStartMsgFilter(Filter_type: longWord;
  MaskMsg, PatternMsg, FlowControlMsg: array of Byte;
  TxFlags: longWord): integer;
{ ��������� ������� ����� ��������� }
var
  mask, patter, FC: TPASSTHRU_MSG;
  i: integer;
begin
  FillChar(mask, SizeOf(mask), 0);
  FillChar(patter, SizeOf(patter), 0);
  FillChar(FC, SizeOf(FC), 0);
  mask.TxFlags := TxFlags;
  patter.TxFlags := TxFlags;
  FC.TxFlags := TxFlags;
  mask.ProtocolID := DiagInfo.ProtocilID;
  patter.ProtocolID := DiagInfo.ProtocilID;
  FC.ProtocolID := DiagInfo.ProtocilID;
  for i := 0 to 3 do
  begin
    mask.Data[i] := MaskMsg[i];
    patter.Data[i] := PatternMsg[i];
    FC.Data[i] := FlowControlMsg[i];
  end;
  try
    result := self.TPassThruStartMsgFilter(self.DiagInfo.ChannelID, Filter_type,
      @mask, @patter, @FC, @DiagInfo.FilterID);
  except
    on E: Exception do
    begin
      // ��������� ������
      raise Exception.Create('������ PassThruReadMsgs');
    end;
  end;
end;

function TJ2534_v2.PassThruStopMsgFilter(): integer;
{ �������� ������� ����� ��������� }
begin
  try
    result := self.TPassThruStopMsgFilter(self.DiagInfo.ChannelID,
      self.DiagInfo.FilterID);
  except
    on E: Exception do
    begin
      // ��������� ������
      raise Exception.Create('������ PassThruStopMsgFilter');
    end;
  end;
end;

{ ������ ������ }
function TJ2534_v2.PassThrueReadVersion(): TstringList;
var
  firm_version, dll_version, ApiVersion: array [0 .. 80] of Byte;
  err: integer;
  F, D, A: string;
begin
  result := TstringList.Create;
  result.Clear;
  try
    err := self.TPassThruReadVersion(self.DiagInfo.Device_ID, @firm_version,
      @dll_version, @ApiVersion);
    if (err <> 0) and (err < $1B) then
    begin
      result.Add(ERROR_MESS[err]);
      exit;
    end;
    F := 'Firmware Version : ';
    D := 'DLL Version : ';
    A := 'API Version : ';
    for err := 0 to 79 do
    begin
      F := F + Char(firm_version[err]);
      D := D + Char(dll_version[err]);
      A := A + Char(ApiVersion[err]);
    end;
    result.Add(F);
    result.Add(D);
    result.Add(A);
  except
    on E: Exception do
    begin
      // ��������� ������
      raise Exception.Create('������ PassThruReadVersion');
    end;
  end;
end;

function TJ2534_v2.ClearRxBufer(): integer;
begin
  try
    result := self.TPassThruIoctl(self.DiagInfo.ChannelID, $08, nil, nil);
  except
    on E: Exception do
    begin
      // ��������� ������
      raise Exception.Create('������ ClearRx');
    end;
  end;
end;

function TJ2534_v2.GetErrorDescriptions(error_code: integer): string;
begin
  if (error_code >= 0) and (error_code < length(ERROR_MESS)) then
    result := ERROR_MESS[error_code]
  else
    result := 'index error out of range';

end;

end.
