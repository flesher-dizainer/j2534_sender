unit uWBO;

interface

uses
  System.Classes, System.SysUtils, System.Threading;

type
  TuWBO = class(TThread)
  private
    FStopped: boolean;
    number_sensor: byte;
  public
    constructor Create(CreateSuspended: boolean; number_sensor: byte);
    destructor Destroy; override;
    procedure Execute; override;
  end;

implementation

constructor TuWBO.Create(CreateSuspended: boolean; number_sensor: byte);
begin
  inherited Create(CreateSuspended);
  self.number_sensor := number_sensor;
  FStopped := False;
end;

destructor TuWBO.Destroy;
begin
  FStopped := True;
  inherited Destroy;
end;

procedure TuWBO.Execute;
begin
  while not FStopped do
  begin
    // Тело цикла потока
    sleep(1);
  end;
end;

end.
