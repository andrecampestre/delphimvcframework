unit MVCFramework.JSONRPC;

interface

uses
  Classes,
  SysUtils,
  jsondataobjects, MVCFramework, MVCFramework.Commons, System.Rtti,
  System.Generics.Collections;

const
  JSONRPC_VERSION = '2.0';
  JSONRPC_HEADER = 'jsonrpc';
  JSONRPC_METHOD = 'method';
  JSONRPC_PARAMS = 'params';
  JSONRPC_ID = 'id';
  JSONRPC_RESULT = 'result';
  JSONRPC_ERROR = 'error';
  JSONRPC_CODE = 'code';
  JSONRPC_MESSAGE = 'message';
  JSONRPC_DATA = 'data';

type
  IMVCJSONRPCMessage = interface
    ['{73B8D463-75E1-404B-8437-EF4B3C950D2F}']
    function AsJSONRPCMessage: string;
  end;

  TMVCJSONRPCMessage = class abstract(TInterfacedObject, IMVCJSONRPCMessage)
  private
    fJSON: TJsonObject;
  protected
    class procedure CheckVersion(const aJSON: TJsonObject);
    class procedure CheckMethod(const aJSON: TJsonObject);
    class procedure CheckID(const aJSON: TJsonObject; out aIsNotification: Boolean);
    constructor Create; overload;
    procedure Build(const aJSON: TJsonObject); virtual; abstract;
    { IMVCJSONRPCMessage }
    function AsJSONRPCMessage: string;
  public
    function AsJSON: TJsonObject; virtual;
  end;

  TJSONRPCRequestParams = TList<TValue>;

  TJSONRPCMessage = class(TObject)
  private
    FID: TValue;
    procedure SetID(const Value: TValue);
    function GetJSONString: string;
  protected
    function GetJSON: TJsonObject; virtual;
  public
    constructor Create; virtual;
    property AsJSON: TJsonObject read GetJSON;
    property AsJSONString: string read GetJSONString;
    property ID: TValue read FID write SetID;
  end;

  {$SCOPEDENUMS ON}

  TJSONRPCRequestType = (Request, Notification);

  TJSONRPCRequest = class(TJSONRPCMessage)
  private
    FParams: TJSONRPCRequestParams;
    FMethod: string;
    procedure SetMethod(const Value: string);
    function GetRequestType: TJSONRPCRequestType;
  protected
    function GetJSON: TJsonObject; override;
  public
    constructor Create; override;
    destructor Destroy; override;
    property Method: string read FMethod write SetMethod;
    property Params: TJSONRPCRequestParams read FParams;
    property RequestType: TJSONRPCRequestType read GetRequestType;
  end;

  TJSONRPCResponseError = class
  private
    FCode: Integer;
    FMessage: string;
    procedure SetCode(const Value: Integer);
    procedure SetMessage(const Value: string);
  public
    property Code: Integer read FCode write SetCode;
    property message: string read FMessage write SetMessage;
  end;

  TJSONRCPResponse = class(TJSONRPCMessage)
  private
    FResult: TValue;
    FError: TJSONRPCResponseError;
    procedure SetResult(const Value: TValue);
    procedure SetError(const Value: TJSONRPCResponseError);
  protected
    function GetJSON: TJsonObject; override;
  public
    constructor Create; override;
    destructor Destroy; override;
    property Result: TValue read FResult write SetResult;
    property Error: TJSONRPCResponseError read FError write SetError;
  end;

  EMVCJSONRPCInvalidVersion = class(Exception)

  end;

  EMVCJSONRPCException = class(Exception)

  end;

  EMVCJSONRPCErrorResponse = class abstract(Exception)
  private
    FJSONRPCErrorCode: Integer;
  public
    property JSONRPCErrorCode: Integer read FJSONRPCErrorCode;
  end;

  EMVCJSONRPCParseError = class(EMVCJSONRPCErrorResponse)
  public
    constructor Create;
  end;

  EMVCJSONRPCInvalidRequest = class(EMVCJSONRPCErrorResponse)
  public
    constructor Create;
  end;

  EMVCJSONRPCMethodNotFound = class(EMVCJSONRPCErrorResponse)
  public
    constructor Create;
  end;

  EMVCJSONRPCInvalidParams = class(EMVCJSONRPCErrorResponse)
  public
    constructor Create(const Message: string);
  end;

  EMVCJSONRPCInternalError = class(EMVCJSONRPCErrorResponse)
  public
    constructor Create;
  end;

  { -32000 to -32099	Server error	Reserved for implementation-defined server-errors. }
  EMVCJSONRPCServerError = class(EMVCJSONRPCErrorResponse)
  public
    constructor Create(const JSONRPCError: Integer; const Message: string);
  end;

  TMVCJSONObject = TJsonObject;
  TMVCJSONArray = TJDOJsonArray;

  TMVCJSONRPCController = class(TMVCController)
  protected
    function CreateError(const RequestID: TValue; const ErrorCode: Integer;
      const Message: string): TJsonObject;
    function CreateResponse(const RequestID: TValue; const Value: TValue): TJSONRCPResponse;
    function CreateRequest(const JSON: TJsonObject): TJSONRPCRequest;
  public
    [MVCPath]
    [MVCHTTPMethods([httpPOST])]
    [MVCConsumes(TMVCMediaType.APPLICATION_JSON)]
    [MVCProduces(TMVCMediaType.APPLICATION_JSON)]
    procedure Index; virtual;
  end;

implementation

uses
  Data.DB, MVCFramework.Serializer.Intf, MVCFramework.Serializer.JsonDataObjects,
  MVCFramework.Serializer.Commons;

function JSONDataValueToTValue(const JSONDataValue: TJsonDataValueHelper): TValue;
begin
  case JSONDataValue.Typ of
    jdtString:
      begin
        Result := JSONDataValue.Value;
      end;
    jdtFloat:
      begin
        Result := JSONDataValue.FloatValue;
      end;
    jdtBool:
      begin
        Result := JSONDataValue.BoolValue;
      end;
    jdtArray:
      begin
        Result := JSONDataValue.ArrayValue;
      end;
    jdtObject:
      begin
        Result := JSONDataValue.ObjectValue;
      end;
    jdtInt:
      begin
        Result := JSONDataValue.IntValue;
      end;
    jdtLong:
      begin
        Result := JSONDataValue.LongValue;
      end;
    jdtULong:
      begin
        Result := JSONDataValue.ULongValue;
      end;
  else
    raise EMVCJSONRPCException.Create('Invalid parameter type');
  end;
end;

procedure TValueToJsonElement(const Value: TValue; const JSON: TJSONObject; const KeyName: string);
var
  lSer: TMVCJsonDataObjectsSerializer;
  lJArr: TJsonArray;
begin
  case Value.Kind of
    tkInteger:
      begin
        JSON.I[JSONRPC_RESULT] := Value.AsInteger;
      end;
    tkFloat:
      begin
        JSON.D[JSONRPC_RESULT] := Value.AsExtended;
      end;
    tkString, tkUString, tkWChar, tkLString, tkWString:
      begin
        JSON.S[JSONRPC_RESULT] := Value.AsString;
      end;
    tkInt64:
      begin
        JSON.I[JSONRPC_RESULT] := Value.AsInt64;
      end;
    tkClass:
      begin
        if Value.AsObject is TJsonObject then
        begin
          JSON.O[JSONRPC_RESULT] := TJsonObject.Create;
          JSON.O[JSONRPC_RESULT].Assign(TJsonObject(Value.AsObject));
        end
        else if Value.AsObject is TJsonArray then
        begin
          JSON.A[JSONRPC_RESULT] := TJsonArray.Create;
          JSON.A[JSONRPC_RESULT].Assign(TJsonArray(Value.AsObject));
        end
        else if Value.AsObject is TDataSet then
        begin
          lSer := TMVCJsonDataObjectsSerializer.Create;
          try
            JSON.A[JSONRPC_RESULT] := TJsonArray.Create;
            lSer.DataSetToJsonArray(TDataSet(Value.AsObject), JSON.A[JSONRPC_RESULT], TMVCNameCase.ncLowerCase, []);
          finally
            lSer.Free;
          end;
        end
        else
        begin
          lSer := TMVCJsonDataObjectsSerializer.Create;
          try
            JSON.O[JSONRPC_RESULT] := TJsonObject.Create;
            lSer.ObjectToJsonObject(Value.AsObject, JSON.O[JSONRPC_RESULT], TMVCSerializationType.stProperties, []);
          finally
            lSer.Free;
          end;
        end;
      end;
  else
    raise EMVCJSONRPCException.Create('Invalid parameter type');
  end;
end;

function StringToJSON(const aValue: string): TJsonObject;
var
  lJSON: TJSONObject;
begin
  lJSON := nil;
  try
    lJSON := TJsonObject.Parse(aValue) as TJSONObject;
    Result := lJSON;
  except
    on E: Exception do
    begin
      lJSON.Free;
      raise EMVCJSONRPCParseError.Create;
    end;
  end;
end;

{ TMVCJSONRPCMessage }

function TMVCJSONRPCMessage.AsJSON: TJsonObject;
begin
  Result := TMVCJSONObject.Create;
  Result.S[JSONRPC_HEADER] := JSONRPC_VERSION;
end;

function TMVCJSONRPCMessage.AsJSONRPCMessage: string;
begin
  Result := fJSON.ToJSON();
end;

class procedure TMVCJSONRPCMessage.CheckID(const aJSON: TMVCJSONObject; out aIsNotification: Boolean);
begin
  {
    id
    An identifier established by the Client that MUST contain a String, Number, or NULL value if included.
    If it is not included it is assumed to be a notification.
    The value SHOULD normally not be Null [1] and Numbers SHOULD NOT contain fractional parts [2]
  }
  aIsNotification := not aJSON.Contains(JSONRPC_ID);
  if not aIsNotification then
  begin
    if not(aJSON.Types[JSONRPC_ID] in [jdtString, jdtInt, jdtLong, jdtULong, jdtNone]) then
      raise EMVCJSONRPCException.Create('Message is not a notification but its ''id'' property is not valid');
  end;
end;

class procedure TMVCJSONRPCMessage.CheckMethod(const aJSON: TMVCJSONObject);
begin
  if (aJSON.Types[JSONRPC_METHOD] <> jdtString) then
    raise EMVCJSONRPCException.Create('Invalid ''method''');
end;

class procedure TMVCJSONRPCMessage.CheckVersion(const aJSON: TMVCJSONObject);
begin
  if not Assigned(aJSON) then
    raise EMVCJSONRPCException.Create('JSON not assigned');

  if aJSON.S[JSONRPC_HEADER] <> JSONRPC_VERSION then
    raise EMVCJSONRPCInvalidVersion.Create(JSONRPC_HEADER + ' must be "2.0"');

end;

constructor TMVCJSONRPCMessage.Create;
begin
  inherited Create;
end;

{ TMVCJSONRPCController }

function TMVCJSONRPCController.CreateError(const RequestID: TValue; const ErrorCode: Integer;
  const Message: string): TJsonObject;
var
  lErrResp: TJSONRCPResponse;
begin
  lErrResp := TJSONRCPResponse.Create;
  try
    lErrResp.ID := RequestID;
    lErrResp.Error := TJSONRPCResponseError.Create;
    lErrResp.Error.Code := ErrorCode;
    lErrResp.Error.Message := message;
    Result := lErrResp.AsJSON;
  finally
    lErrResp.Free;
  end;
end;

function TMVCJSONRPCController.CreateRequest(
  const JSON: TJsonObject): TJSONRPCRequest;
var
  I: Integer;
  lParams: TJsonArray;
begin
  Result := TJSONRPCRequest.Create;
  if JSON.Types[JSONRPC_ID] = jdtString then
    Result.ID := JSON.S[JSONRPC_ID]
  else if JSON.Types[JSONRPC_ID] = jdtInt then
    Result.ID := JSON.I[JSONRPC_ID]
  else if JSON.Types[JSONRPC_ID] = jdtLong then
    Result.ID := JSON.L[JSONRPC_ID]
  else if JSON.Types[JSONRPC_ID] = jdtULong then
    Result.ID := JSON.U[JSONRPC_ID]
  else
    Result.ID := TValue.Empty;

  Result.Method := JSON.S[JSONRPC_METHOD];

  if JSON.Types[JSONRPC_PARAMS] = jdtArray then
  begin
    lParams := JSON.A[JSONRPC_PARAMS];
    for I := 0 to lParams.Count - 1 do
    begin
      Result.Params.Add(JSONDataValueToTValue(lParams[I]));
    end;
  end
  else if JSON.Types[JSONRPC_PARAMS] <> jdtNone then
  begin
    raise EMVCJSONRPCException.Create('Params must be a JSON array or null');
  end;
end;

function TMVCJSONRPCController.CreateResponse(const RequestID: TValue; const Value: TValue): TJSONRCPResponse;
begin
  Result := TJSONRCPResponse.Create;
  Result.ID := RequestID;
  Result.Result := Value;
end;

procedure TMVCJSONRPCController.Index;
var
  lJSONRPCReq: TJSONRPCRequest;
  lMethod: string;
  lRTTI: TRTTIContext;
  lRTTIType: TRttiType;
  lRTTIMethod: TRttiMethod;
  lRTTIMethodParams: TArray<TRttiParameter>;
  lRes: TValue;
  lJSONRPCResponse: TJSONRCPResponse;
  lParamsToInject: TArray<TValue>;
  lReqID: TValue;
begin
  lReqID := TValue.Empty;
  SetLength(lParamsToInject, 0);
  try
    lJSONRPCReq := CreateRequest(StringToJSON(Context.Request.Body));
    try
      lMethod := lJSONRPCReq.Method;
      lRTTI := TRTTIContext.Create;
      try
        lRTTIType := lRTTI.GetType(ClassType);
        lRTTIMethod := lRTTIType.GetMethod(lMethod);
        if Assigned(lRTTIMethod) then
        begin
          lRTTIMethodParams := lRTTIMethod.GetParameters;
          if (Length(lRTTIMethodParams) <> lJSONRPCReq.Params.Count) then
            raise EMVCJSONRPCInvalidParams.Create('Wrong parameters count');

          try
            try
              lRes := lRTTIMethod.Invoke(Self, lJSONRPCReq.Params.ToArray);
            except
              on E: EInvalidCast do
              begin
                raise EMVCJSONRPCInvalidParams.Create('Check your input parameters types');
              end;
            end;
            if lJSONRPCReq.RequestType = TJSONRPCRequestType.Notification then
            begin
              ResponseStatus(HTTP_STATUS.NoContent);
            end
            else
            begin
              lJSONRPCResponse := CreateResponse(lJSONRPCReq.ID, lRes);
              try
                ResponseStatus(200);
                Render(lJSONRPCResponse.AsJSON);
              finally
                lJSONRPCResponse.Free;
              end;
            end;
          finally
            if lRes.IsObject or lres.IsObjectInstance then
              lRes.AsObject.Free;
          end;
        end
        else
          raise EMVCJSONRPCMethodNotFound.Create;
      finally
        lRTTI.Free;
      end;
    finally
      lJSONRPCReq.Free;
    end;
  except
    on E: EMVCJSONRPCErrorResponse do
    begin
      {
        http://www.jsonrpc.org/historical/json-rpc-over-http.html#response-codes
        HTTP Status	code	message
        500	-32700	Parse error.
        400	-32600	Invalid Request.
        404	-32601	Method not found.
        500	-32602	Invalid params.
        500	-32603	Internal error.
        500	-32099..-32000	Server error.
      }
      case E.JSONRPCErrorCode of
        - 32700: ResponseStatus(500);
        -32600: ResponseStatus(400);
        -32601: ResponseStatus(404);
        -32602: ResponseStatus(500);
        -32603: ResponseStatus(500);
        -32099 .. -32000: ResponseStatus(500);
      end;
      Render(CreateError(lReqID, E.JSONRPCErrorCode, E.Message), True);
    end;
    on E: EMVCJSONRPCException do
    begin
      Render(CreateError(lReqID, 0, E.Message), True);
    end;
  end;
end;

{ EMVCJSONRPCParseError }

constructor EMVCJSONRPCParseError.Create;
begin
  inherited Create('Parse error. Invalid JSON was received by the server. An error occurred on the server while parsing the JSON text');
  FJSONRPCErrorCode := -32700;
end;

{ EMVCJSONRPCInvalidRequest }

constructor EMVCJSONRPCInvalidRequest.Create;
begin
  inherited Create('Invalid Request. The JSON sent is not a valid Request object.');
  FJSONRPCErrorCode := -32600;
end;

{ EMVCJSONRPCMethodNotFound }

constructor EMVCJSONRPCMethodNotFound.Create;
begin
  inherited Create('Method not found. The method does not exist / is not available');
  FJSONRPCErrorCode := -32601;
end;

{ EMVCJSONRPCInvalidParams }

constructor EMVCJSONRPCInvalidParams.Create(const message: string);
begin
  inherited Create('Invalid params. [hint: ' + message + ']');
  FJSONRPCErrorCode := -32602;
end;

{ EMVCJSONRPCInternalError }

constructor EMVCJSONRPCInternalError.Create;
begin
  inherited Create('Internal JSON-RPC error');
  FJSONRPCErrorCode := -32603;
end;

{ EMVCJSONRPCServerError }

constructor EMVCJSONRPCServerError.Create(const JSONRPCError: Integer; const message: string);
begin
  inherited Create(message);
  FJSONRPCErrorCode := JSONRPCError;

end;

{ TMVCJSONRCPResponse }

{ TJSONRPCRequest }

constructor TJSONRPCRequest.Create;
begin
  inherited Create;
  FParams := TJSONRPCRequestParams.Create;
end;

destructor TJSONRPCRequest.Destroy;
var
  lValue: TValue;
begin
  for lValue in FParams do
  begin
    if lValue.IsObjectInstance then
      lValue.AsObject.Free;
  end;
  FParams.Free;
  inherited;
end;

function TJSONRPCRequest.GetJSON: TJsonObject;
var
  I: Integer;
begin
  Result := inherited;
  Result.S[JSONRPC_METHOD] := FMethod;
  for I := 0 to FParams.Count - 1 do
  begin
    TValueToJsonElement(FParams[I], Result, JSONRPC_PARAMS);
  end;
end;

function TJSONRPCRequest.GetRequestType: TJSONRPCRequestType;
begin
  if FID.IsEmpty then
    Result := TJSONRPCRequestType.Notification
  else
    Result := TJSONRPCRequestType.Request;
end;

procedure TJSONRPCRequest.SetMethod(const Value: string);
begin
  FMethod := Value;
end;

{ TJSONRCPResponse }

constructor TJSONRCPResponse.Create;
begin
  inherited;
  FError := nil;
end;

destructor TJSONRCPResponse.Destroy;
begin
  FreeAndNil(FError);
  inherited;
end;

function TJSONRCPResponse.GetJSON: TJsonObject;
begin
  Result := inherited;
  // Must generate something like the following:
  // {"jsonrpc": "2.0", "error": {"code": -32601, "message": "Method not found"}, "id": "1"}
  try
    if Assigned(FError) then
    begin
      Result.O[JSONRPC_ERROR].I[JSONRPC_CODE] := FError.Code;
      Result.O[JSONRPC_ERROR].S[JSONRPC_MESSAGE] := FError.Message;
    end
    else
    begin
      TValueToJsonElement(Self.FResult, Result, JSONRPC_RESULT);
    end;
  except
    Result.Free;
    raise;
  end;
end;

procedure TJSONRCPResponse.SetError(const Value: TJSONRPCResponseError);
begin
  FError := Value;
end;

procedure TJSONRCPResponse.SetResult(const Value: TValue);
begin
  FResult := Value;
end;

{ TJSONRPCMessage }

constructor TJSONRPCMessage.Create;
begin
  inherited;
end;

function TJSONRPCMessage.GetJSON: TJsonObject;
begin
  Result := TJsonObject.Create;
  Result.S[JSONRPC_HEADER] := JSONRPC_VERSION;
  if not FID.IsEmpty then
  begin
    if FID.IsType<string> then
    begin
      Result.S[JSONRPC_ID] := FID.AsString;
    end
    else if FID.IsType<Int32> then
    begin
      Result.I[JSONRPC_ID] := FID.AsInteger;
    end
    else if FID.IsType<Int64> then
    begin
      Result.I[JSONRPC_ID] := FID.AsInt64;
    end
    else
      raise EMVCJSONRPCException.Create('ID can be only Int32, Int64 or String');
  end;
end;

function TJSONRPCMessage.GetJSONString: string;
var
  lJSON: TJsonObject;
begin
  lJSON := GetJSON;
  try
    Result := lJSON.ToJson;
  finally
    lJSON.Free;
  end;
end;

procedure TJSONRPCMessage.SetID(const Value: TValue);
begin
  FID := Value;
end;

{ TJSONRPCResponseError }

procedure TJSONRPCResponseError.SetCode(const Value: Integer);
begin
  FCode := Value;
end;

procedure TJSONRPCResponseError.SetMessage(const Value: string);
begin
  FMessage := Value;
end;

end.
