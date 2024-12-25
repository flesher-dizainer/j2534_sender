unit uWBO;

interface

uses
  System.Classes,SysUtils,windows,Dialogs,Forms;
  type
  TLC_DATA = record
  Port:string;
  LamSensor:string;
  PortOpen:boolean;
  end;

type
  TLcThreat = class(TThread)
  hCOMPort:  THandle;     // COM-����
  private
    AEM:boolean;//������������ ��� ���
    LC_1:boolean;//������������ ��� LC-1
    VEMS:boolean;//������������ ��� ���
    SizePackVems:cardinal;//������ ������ �� ���
    SLE:integer;//�������� ������� ������ vems, �������������
 // Sensor_ID:byte;
  procedure ReadPort_LC;  // ������ �� ����� lc-1
  procedure ReadPortVems;//������ VEMS
  procedure ReadPort_AEM; //������ �� ����� AEM
  Procedure GenAFR(data: array of byte);
  function OpenPortLC():boolean;
  procedure ClosePortLC;
    { Private declarations }
  protected
    procedure Execute; override;
    Public
    AFR:REAL;//������ ����� �� ���
    stochiometric:real;//������������ � ���
    Message_LC1:string;//��������� � ��������� ��-1
    lc:boolean;//���� ����������� ���
    ExitReadPort:boolean;//���� ����������� ������ � �����
    LC_CONNECT : boolean;//���� ������������� �����
    EGT:Integer;
    procedure stop;
    destructor  Destroy;override;
    class var RunThread: boolean;

     constructor Create( Port: string; LamSensor:string);

  end;
  var
  LC_DATA : TLC_DATA;
implementation
procedure TLcThreat.Execute;
begin
 while (RunThread) and (not terminated) do begin
 sleep(1);
 if ExitReadPort then begin
   TLcThreat.RunThread:=false;
   exit;
 end;
     if LC_1 then ReadPort_LC;
     if AEM  then ReadPort_AEM;
     if VEMS then ReadPortVems;
 end;
end;

constructor TLcThreat.Create(Port: string; Lamsensor:string);
//var
 // i: integer;
  //DCB: TDCB;
begin
  inherited Create( true );
  lc_data.Port:=port;
  LC:=False;
  SLE:=100;
  if Lamsensor = 'AEM' then
  begin
   AEM:=true;
   LC_1:=false;
   Vems:=false;
  end;
  if Lamsensor = 'LC/LM-1/2' then
  begin
   LC_1:=true;
   AEM:=false;
   Vems:=False;
  end;
  if Lamsensor = 'VEMS' then
  begin
   LC_1:=FALSE;
   AEM:=false;
   Vems:=TRUE;
  end;

  ExitReadPort:=False;
  // ���������� ���� ������ ������
 // RunThread := false;
 openportlc;
  RunThread := true;
  resume;
end;

//�������� ������ LC-1
procedure TLcThreat.ReadPort_LC;
var
  Errors, Size, NumberOfBytesReaded: Cardinal;
  COMStat: TCOMStat;
  count:integer;
  //s: string;
  i: integer;
  data: array [0..10]  of byte;
  dataAfr: array[0..3] of byte;
  SleepCount:integer;
begin
// ---------------------
//LengthPack:=((( data[ 0 ] and 1 ) shl 7 ) + ( data[ 1 ] and $7F ));
//����� ������ ����������� �� ������ �����
//����� ������ = (data[1] and $7F) * 2, �������� �� 2, ������ ��� ����� ����������� �
//data 1 and 2 ��� ��������� �����������
//---------------------
//����� ������ � �����
if not  PurgeComm(hCOMPort,PURGE_TXCLEAR or PURGE_RXCLEAR) then begin
 ClosePortLC;//��������� ����, ���� �� ������� �������� ����
 if not openportLC then exit;//������� ����� �������, ���� �� ������� �� �������
end;
//���� �������� ������ �� �����
SleepCount:=0;
repeat
 sleep(5);
 SleepCount:=SleepCount+5;
 if not ClearCommError( hCOMPort, Errors, @COMStat ) then exit;
 Size := COMStat.cbInQue;
 Count := Size;
until (count > 0) or (SleepCount > 2000) or (ExitReadPort) ;
   //��������� ���� �� ����� ������ �����
   if ExitReadPort then begin
    PurgeComm(hCOMPort,PURGE_TXCLEAR or PURGE_RXCLEAR);
    exit;
   end;
//���� Count > 0 ������ ������ ����
if Count > 0 then
 ReadFile( hCOMPort, Data, 1, NumberOfBytesReaded, nil)
 else begin
 Message_LC1:='LC: NoDATA';
 LC:=False;
  exit;
 end;
if not data[0] and $A2 = $A2 then exit;
//
 //������ ������ ���������
SleepCount:=0;
repeat
 sleep(5);
 SleepCount:=SleepCount+5;
 ClearCommError( hCOMPort, Errors, @COMStat );
 Size := COMStat.cbInQue;
 Count := Size;
until (count > 0) or (SleepCount > 2000) or (ExitReadPort) ;
   //��������� ���� �� ����� ������ �����
   if ExitReadPort then begin
    PurgeComm(hCOMPort,PURGE_TXCLEAR or PURGE_RXCLEAR);
    exit;
   end;
//���� Count > 0 ������ ������ ����
if Count > 0 then
 ReadFile( hCOMPort, Data, 1, NumberOfBytesReaded, nil)
 else exit;
if not data[0] and $80 = $80 then exit;
//������ ����� �� 4 ����
SleepCount:=0;
repeat
 sleep(5);
 SleepCount:=SleepCount+5;
 ClearCommError( hCOMPort, Errors, @COMStat );
 Size := COMStat.cbInQue;
 Count := Size;
until (count > 0) or (SleepCount > 4000) or (ExitReadPort) ;
   //��������� ���� �� ����� ������ �����
   if ExitReadPort then begin
    PurgeComm(hCOMPort,PURGE_TXCLEAR or PURGE_RXCLEAR);
    exit;
   end;
//���� Count > 3 ������ ������ ����
if Count > 3 then
 ReadFile( hCOMPort, Data, 4, NumberOfBytesReaded, nil)
 else exit;
 PurgeComm(hCOMPort,PURGE_TXCLEAR or PURGE_RXCLEAR);
 for i := 0 to 3 do
 dataafr[i]:=data[i];
 GenAFR(dataafr);
end;
// ������ ��� ����
procedure TLCTHREAt.ReadPortVems;
var
WriteDataPort:array[0..1] of byte;
Errors,Size, NumberOfBytesWritten,NumberOfBytesReaded: Cardinal;
COMStat: TCOMStat;
SL:integer;
DATA:array [0..100] of byte;

begin
//----- �������� ������� ����� ----------
if not  PurgeComm(hCOMPort,PURGE_TXCLEAR or PURGE_RXCLEAR) then begin
 ClosePortLC;//��������� ����, ���� �� ������� �������� ����
 if not openportLC then exit;//������� ����� �������, ���� �� ������� �� �������
end;
//----- �������� ������� �� ������ -----------
WriteDataPort[0]:=$41;
WriteDataPort[1]:=$2E;
if not WriteFile( hCOMPort, WriteDataPort,2, NumberOfBytesWritten, nil ) then
exit;
//----- ������ ����� ������ �� ����� -----------------------
  // ��������� ������
  SL:=0;
  repeat
  SLEEP(sle);
  ClearCommError( hCOMPort, Errors, @COMStat );
  Size := COMStat.cbInQue;
  SL:=SL+1;
  until (SL > 500) or (size = SizePackVems) or ( size > 15 ) ;
  if SizePackVems <> size then begin
  SizePackVems:=size;
  sle:=1;
  end;
  if not ReadFile( hCOMPort, Data, Size, NumberOfBytesReaded, nil)then exit;
  //------- ������ �������� ������ � ��������� ��� ------------
  //12 ���� �����������
  if data[12] and $60 = $60 then begin
   LC:=False;
   Message_LC1:='WarmUP';
   exit;
  end;
  if data[12] and $40 = $40 then begin
   LC:=true;
   Message_LC1:='EGT: '+FloatToStr((data[4]*256+data[5])-50);
   EGT:=round((data[4]*256+data[5])-50);
   AFR:=14.7*(data[0]*256+data[1])/16384;
  end;
end;
//�������� ������ ���
procedure TLcThreat.ReadPort_AEM;
var
  id_data:byte;
  Errors, Size, NumberOfBytesReaded: Cardinal;
  COMStat: TCOMStat;
//  Count:integer;
  count_data:byte;
  DATA:ARRAY [0..20] OF BYTE;
  test:string;
 // LogLC:textfile;
  filename:string;
 // s:string;
  count_sleep:integer;
  pack_good:boolean; //����, ��� ����� ������
begin
//������� ����������� �����
if not  PurgeComm(hCOMPort,PURGE_TXCLEAR or PURGE_RXCLEAR) then begin
 ClosePortLC;//��������� ����, ���� �� ������� �������� ����
 if not openportLC then begin
  Message_LC1:='LC: error open port';
  exit;//������� ����� �������, ���� �� ������� �� �������
  end;
end;
  // ��������� ������
  count_sleep:=0;
  count_data:=1;
  id_data:=1;
  pack_good:=false;
//--------------------- ������������ ������������ ������ -------------------------
  repeat
  SLEEP(1);
  ClearCommError( hCOMPort, Errors, @COMStat ); //�������� ������� ��������� � �����
  Size := COMStat.cbInQue;  //���������� ���� � �����
//---------------------------����������� ������----------------------
  if Size >= count_data then begin
   ReadFile( hCOMPort, Data, count_data, NumberOfBytesReaded, nil);
//---------
  case id_data of
  //����� ������
  3:begin
   pack_good:=true;
   id_data:=1;
   count_data:=1;
  end;
   //������ ���� ���������
  2:begin
    if data[0]=$0A then begin
     id_data:=3;
     count_data:=4;
    end else begin
     id_data:=1;
     count_data:=1;
    end;
  end;
  //������ ���� ���������
   1:begin 
    if data[0]=$0D then begin
     id_data:=2;
     count_data:=1;
    end else id_data:=1;
   end;
  end;
//---------
  end;
//---------------------- end ������������ ������ -------------------------------------
 inc (count_sleep);
  until (pack_good = true) or (count_sleep > 5000) ;
  //���������� ������ ��������� ������ $0D
  if not pack_good then begin
    Message_LC1:='LC:no data';
    exit;
  end;
//------------------ ����� ����� ������������ ������ -----------------------

//-------------- ������ ������ ������ ----------------------------
   Test:=chr(data[0])+chr(data[1])+chr(data[2])+chr(data[3]);
   Test:=StringReplace(test,'.',',', [rfReplaceAll, rfIgnoreCase]);
   Message_LC1:=Test;
   try
    AFR:=StrToFloat(test);
   except
   end;
   if (AFR > 20) or (afr < 10) then LC:=false else LC:=True;

//----------------------------------------------------------------------


//-------- �������� ������� ����� -------------------
if not  PurgeComm(hCOMPort,PURGE_TXCLEAR or PURGE_RXCLEAR) then showmessage('Error Lc Port');
{  
  ReadFile( hCOMPort, Data, 1, NumberOfBytesReaded, nil);
   if data[0]=$0D then begin

   //---��������� ������ ���� ��������� ������
    repeat
     ClearCommError( hCOMPort, Errors, @COMStat );
     Size := COMStat.cbInQue;
     Count := Size;
    until count > 0 ;

      ReadFile( hCOMPort, Data, 1, NumberOfBytesReaded, nil);
       if data[0]=$0A then begin
       //������ ���� ���������� ����� � ��� ���� ���� ������ ���������
           repeat
            ClearCommError( hCOMPort, Errors, @COMStat );
            Size := COMStat.cbInQue;
            Count := Size;
          until count > 4 ;
        ReadFile( hCOMPort, Data, 5, NumberOfBytesReaded, nil);
        if data[4]=$0D then begin //���� ����� ������ ����� ���������, �� ����� ������
        //��������� � ��� �������� ��� ���������
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

         //������� ����� �� ����������� ������, ���� �� ����� ��������
      
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
  //sleep(500);
  if hCOMPort<>0 then
  CloseHandle( hCOMPort );
 // Destroy;
end;

destructor TLcThreat.Destroy;
begin
  CloseHandle( hCOMPort );
  inherited Destroy;
end;

procedure TLcThreat.GenAFR(data: array of Byte);
const
  LambdaValue             = 0;
  O2Level                 = 1;
  FreeAirCalibProgress    = 2;
  NeedFreeAirCalibRequest = 3;
  WarmingUp               = 4;
  HeaterCalib             = 5;
  ErrorCode               = 6;
  Reserver                = 7;
var
  State: byte;
   AF, Lambda, O2Lvl,WarmUp: Real;
  ERRCode: integer;
//i:integer;
begin
  State := Data[ 0 ] shr 2 and $07;
  case State of
    LambdaValue:
      begin
       AF := ( ( ( Data[ 0 ] and 1 ) shl 7 ) + ( Data[ 1 ] and $7F ) ) / 10;
        Lambda := ( ( ( Data[ 2 ] and $7F ) shl 7 ) + ( Data[ 3 ] and $7F ) + 500 ) / 1000;
        AFR :=strtofloat(formatfloat('##0.##', Lambda * 14.7));
        stochiometric:=AF;
        if AFR > 21 then AFR:= 21;
        if AFR < 10 then AFR:=10;
        Message_LC1:='AFR: '+floattostr(AFR);
        lc:=True;
      end;
    O2Level:
      begin
        O2Lvl := ( ( ( Data[ 2 ] and $7F ) shl 7 ) + ( Data[ 3 ] and $7F ) ) / 10;
         //ShowMessage(floattostr(O2Lvl));
        // AFR:=strtofloat(formatfloat('##0.##', O2Lvl));
        // if AFR > 21 then AFR:=21;
         Message_LC1:='O2Lvl: ' + floattostr(O2Lvl);
         LC:=False;
      end;
      WarmingUp:begin
      ///(data[2] * 128  / 10 ) + (data[3] /10)
      WarmUp:=(data[2] * 128  / 10 ) + (data[3] /10);
      Message_LC1:='WarmUp: ' + floattostr(WarmUp);
      LC:=False;
      end;

    ErrorCode:
      begin
        ErrCode := ( ( ( Data[ 2 ] and $7F ) shl 7 ) + ( Data[ 3 ] and $7F ) );
       // ShowMessage(inttostr(ErrCode));
       Message_LC1:='Error  '+ inttostr(ErrCode);
       LC:=False;
      end;
  end;
end;
function TLcThreat.OpenPortLC():boolean;
var
 DCB: TDCB;
begin
   hCOMPort := CreateFile( PChar( lc_data.Port ), Generic_Read + Generic_Write, 0 , nil, Open_Existing, File_Attribute_Normal, 0 );
  // ��������� ���������� ������ ��� �������
  if hCOMPort = Invalid_Handle_Value then begin
 //  Application.MessageBox(PChar( '������ �������� ����� ' + lc_data.Port ), '������',
                                //  MB_ICONWARNING + MB_OK );
    lc_data.PortOpen:=false;
    LC_CONNECT:=false;
    Exit(false);
  end;
  lc_data.PortOpen:=true;
  LC_CONNECT:=true;
  Message_LC1:='LC: ����������';
  PurgeComm(hCOMPort,PURGE_TXCLEAR or PURGE_RXCLEAR);
  //PurgeComm(hCOMPort,PURGE_RXCLEAR);
  // ���������� ��������� ����� ��� LC_1
  if (LC_1) or (vems) then  begin
  GetCommState( hCOMPort, DCB );
  DCB.BaudRate := 19200; //BaudRate;
  DCB.ByteSize := 8;
  DCB.Parity   := NOPARITY;
  DCB.StopBits := ONESTOPBIT;
  end;
  //���������� ��������� ����� ��� ���
  if AEM then  begin
  GetCommState( hCOMPort, DCB );
  DCB.BaudRate := 9600; //BaudRate;
  DCB.ByteSize := 8;
  DCB.Parity   := NOPARITY;
  DCB.StopBits := ONESTOPBIT;
  end;
  // �������� ��������� �����
  if not SetCommState( hCOMPort, DCB ) then begin
   Application.MessageBox(PChar( '������ ��������� �������� ����� ��� ' + lc_data.Port ), '������',
                                  MB_ICONWARNING + MB_OK );
    ClosePortLC;
    Exit(false);
  end;
  result:=true;
end;
procedure TlcThreat.ClosePortLC;
begin
if lc_data.PortOpen then begin
  CloseHandle( hCOMPort );
  lc_data.PortOpen:=false;
  LC_CONNECT:=false;
  Message_LC1:='LC: ���������';
end;
end;
end.
