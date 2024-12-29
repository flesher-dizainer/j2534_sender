unit uWBO;

interface

uses
  System.Classes, System.SysUtils;

type
  TWbo = class(TThread)
  private
    fStopped: boolean;
    fNumberSensor: Integer;

  const
    FWboArray: array [0 .. 1] of string = ('AEM', 'LC1/2');
  public
    destructor Destroy; override;
    procedure Execute; override;
    function GetListWbo(): TStrings;
    procedure SetNumberSensor(const aValue: Integer);
  end;

implementation

destructor TWbo.Destroy;
begin
  fStopped := True;
  inherited Destroy;
end;

procedure TWbo.Execute;
begin
  while not fStopped do
  begin
    // Тело цикла потока
    sleep(1);
  end;
end;

function TWbo.GetListWbo(): TStrings;
var
  i: Integer;
begin
  Result := TStringList.Create;
  for i := Low(FWboArray) to High(FWboArray) do
    Result.Add(FWboArray[i]);
end;

procedure TWbo.SetNumberSensor(const aValue: Integer);
begin
  fNumberSensor := aValue;
end;

end.
