unit uJsonData;

interface

uses
  System.SysUtils, System.JSON, System.Classes;

type
  /// <summary>
  /// Structure for storing parameter data (e.g., ERRORS, TEMPERATURE, etc.)
  /// </summary>
  TDataStructure = record
    Name: string; // Parameter name
    Offset: Integer; // Offset value
    StorageType: string; // Data type (e.g., uint8, int16, etc.)
    Mul_: Real; // Multiplier
    Div_: Real; // Divider
    Subb: Real; // Subtrahend
    FlagBit: Integer; // Flag bit
  end;

  /// <summary>
  /// Structure for storing parameter arrays and their names
  /// </summary>
  TDataArray = record
    Name: string; // Array name
    RequestBytes: TArray<Byte>; // Byte array (if required)
    Structures: TArray<TDataStructure>; // Parameter array
  end;

  /// <summary>
  /// Array of TDataArray structures
  /// </summary>
  TDataArrayList = TArray<TDataArray>;

type
  TJsonData = class
  private
    FJSONObject: TJSONObject;

    /// <summary>
    /// Gets value by key or raises an exception if key not found
    /// </summary>
    function GetValue(const aKey: string): TJSONValue;

  public
    /// <summary>
    /// Creates class instance and initializes empty JSON object
    /// </summary>
    constructor Create;

    /// <summary>
    /// Frees resources
    /// </summary>
    destructor Destroy; override;

    /// <summary>
    /// Loads JSON from string
    /// </summary>
    procedure LoadFromString(const aJsonString: string);

    /// <summary>
    /// Saves JSON to string
    /// </summary>
    function SaveToString: string;

    /// <summary>
    /// Loads JSON from file
    /// </summary>
    procedure LoadFromFile(const aFileName: string);

    /// <summary>
    /// Saves JSON to file
    /// </summary>
    procedure SaveToFile(const aFileName: string);

    /// <summary>
    /// Adds or updates value by key
    /// </summary>
    procedure PutValue(const aKey: string; aValue: TJSONValue); overload;
    procedure PutValue(const aKey: string; aValue: string); overload;
    procedure PutValue(const aKey: string; aValue: Integer); overload;
    procedure PutValue(const aKey: string; aValue: Boolean); overload;

    /// <summary>
    /// Removes value by key
    /// </summary>
    procedure RemoveValue(const aKey: string);

    /// <summary>
    /// Gets string value by key
    /// </summary>
    function GetString(const aKey: string; aDefault: string = ''): string;

    /// <summary>
    /// Gets integer value by key
    /// </summary>
    function GetInteger(const aKey: string; aDefault: Integer = 0): Integer;

    /// <summary>
    /// Gets floating point value by key from JSON object
    /// </summary>
    function GetFloat(const aKey: string; aDefault: Real = 0): Real;

    /// <summary>
    /// Gets boolean value by key
    /// </summary>
    function GetBoolean(const aKey: string; aDefault: Boolean = False): Boolean;

    /// <summary>
    /// Clears JSON object
    /// </summary>
    procedure Clear;

    /// <summary>
    /// Converts JSON array to array of TDataStructure structures
    /// </summary>
    function ParseStructures(const aJSONArray: TJSONArray): TArray<TDataStructure>;

    /// <summary>
    /// Converts JSON array to TDataArray array
    /// </summary>
    function ParseDataArrays(const aJSONArray: TJSONArray): TDataArrayList;

    /// <summary>
    /// Loads JSON and returns TDataArray array
    /// </summary>
    function LoadDataArrays: TDataArrayList;
  end;

implementation

{ TJsonData }

constructor TJsonData.Create;
begin
  FJSONObject := TJSONObject.Create;
end;

destructor TJsonData.Destroy;
begin
  FJSONObject.Free;
  inherited;
end;

procedure TJsonData.LoadFromString(const aJsonString: string);
begin
  Clear;
  FJSONObject := TJSONObject.ParseJSONValue(aJsonString) as TJSONObject;
  if FJSONObject = nil then
    raise Exception.Create('Invalid JSON string');
end;

function TJsonData.SaveToString: string;
begin
  Result := FJSONObject.ToJSON;
end;

procedure TJsonData.LoadFromFile(const aFileName: string);
var
  lFileStream: TStringStream;
begin
  lFileStream := TStringStream.Create;
  try
    lFileStream.LoadFromFile(aFileName);
    LoadFromString(lFileStream.DataString);
  finally
    lFileStream.Free;
  end;
end;

procedure TJsonData.SaveToFile(const aFileName: string);
var
  lFileStream: TStringStream;
begin
  lFileStream := TStringStream.Create(SaveToString);
  try
    lFileStream.SaveToFile(aFileName);
  finally
    lFileStream.Free;
  end;
end;

procedure TJsonData.PutValue(const aKey: string; aValue: TJSONValue);
begin
  RemoveValue(aKey);
  FJSONObject.AddPair(aKey, aValue);
end;

procedure TJsonData.PutValue(const aKey: string; aValue: string);
begin
  PutValue(aKey, TJSONString.Create(aValue));
end;

procedure TJsonData.PutValue(const aKey: string; aValue: Integer);
begin
  PutValue(aKey, TJSONNumber.Create(aValue));
end;

procedure TJsonData.PutValue(const aKey: string; aValue: Boolean);
begin
  PutValue(aKey, TJSONBool.Create(aValue));
end;

procedure TJsonData.RemoveValue(const aKey: string);
var
  lPair: TJSONPair;
begin
  lPair := FJSONObject.RemovePair(aKey);
  if Assigned(lPair) then
    lPair.Free;
end;

function TJsonData.GetValue(const aKey: string): TJSONValue;
begin
  Result := FJSONObject.GetValue(aKey);
  if Result = nil then
    raise Exception.CreateFmt('Key "%s" not found', [aKey]);
end;

function TJsonData.GetString(const aKey: string; aDefault: string): string;
var
  lValue: TJSONValue;
begin
  lValue := FJSONObject.GetValue(aKey);
  if (lValue <> nil) and (lValue is TJSONString) then
    Result := TJSONString(lValue).Value
  else
    Result := aDefault;
end;

function TJsonData.GetInteger(const aKey: string; aDefault: Integer): Integer;
var
  lValue: TJSONValue;
begin
  lValue := FJSONObject.GetValue(aKey);
  if (lValue <> nil) and (lValue is TJSONNumber) then
    Result := TJSONNumber(lValue).AsInt
  else
    Result := aDefault;
end;

function TJsonData.GetFloat(const aKey: string; aDefault: Real): Real;
var
  lValue: TJSONValue;
begin
  lValue := FJSONObject.GetValue(aKey);
  if (lValue <> nil) and (lValue is TJSONNumber) then
    Result := TJSONNumber(lValue).AsDouble
  else
    Result := aDefault;
end;

function TJsonData.GetBoolean(const aKey: string; aDefault: Boolean): Boolean;
var
  lValue: TJSONValue;
begin
  lValue := FJSONObject.GetValue(aKey);
  if (lValue <> nil) and (lValue is TJSONBool) then
    Result := TJSONBool(lValue).AsBoolean
  else
    Result := aDefault;
end;

procedure TJsonData.Clear;
begin
  FJSONObject.Free;
  FJSONObject := TJSONObject.Create;
end;

function TJsonData.ParseStructures(const aJSONArray: TJSONArray): TArray<TDataStructure>;
var
  I: Integer;
  lJSONValue: TJSONValue;
  lStructure: TDataStructure;
  lJSONObject: TJSONObject;
begin
  SetLength(Result, aJSONArray.Count);
  for I := 0 to aJSONArray.Count - 1 do
  begin
    lJSONValue := aJSONArray.Items[I];
    if lJSONValue is TJSONObject then
    begin
      lJSONObject := TJSONObject(lJSONValue);
      lStructure.Name := lJSONObject.GetValue('name').Value;
      lStructure.Offset := StrToIntDef(lJSONObject.GetValue('offset').Value, 0);
      lStructure.StorageType := lJSONObject.GetValue('storagetype').Value;
      lStructure.Mul_ := StrToFloatDef(lJSONObject.GetValue('mul').Value, 0);
      lStructure.Div_ := StrToFloatDef(lJSONObject.GetValue('div').Value, 0);
      lStructure.Subb := StrToFloatDef(lJSONObject.GetValue('subb').Value, 0);
      lStructure.FlagBit := StrToIntDef(lJSONObject.GetValue('flag_bit').Value, 0);
      Result[I] := lStructure;
    end;
  end;
end;

function TJsonData.ParseDataArrays(const aJSONArray: TJSONArray): TDataArrayList;
var
  I: Integer;
  lJSONValue: TJSONValue;
  lDataArray: TDataArray;
  lJSONObject: TJSONObject;
begin
  SetLength(Result, aJSONArray.Count);
  for I := 0 to aJSONArray.Count - 1 do
  begin
    lJSONValue := aJSONArray.Items[I];
    if lJSONValue is TJSONObject then
    begin
      lJSONObject := TJSONObject(lJSONValue);
      lDataArray.Name := lJSONObject.GetValue('name').Value;
      lDataArray.Structures := ParseStructures(lJSONObject.GetValue('structures') as TJSONArray);
      Result[I] := lDataArray;
    end;
  end;
end;

function TJsonData.LoadDataArrays: TDataArrayList;
begin
  if not Assigned(FJSONObject) then
    raise Exception.Create('JSON data is not loaded');
  Result := ParseDataArrays(FJSONObject.GetValue('data') as TJSONArray);
end;

end.
