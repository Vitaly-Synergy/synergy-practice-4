unit uAuthMiddleware;

interface

uses
  System.SysUtils, Web.HTTPApp, System.JSON, uJWT;

/// <summary>
/// Глобальный секретный ключ. Инициализируется один раз в WebModuleCreate.
/// </summary>
var
  GSecretKey: string;

/// <summary>
/// Низкоуровневая проверка: извлекает UserID из токена.
/// </summary>
function VerifyJwtAndExtractUserID(Request: TWebRequest; const ASecretKey: string; out AUserID: Integer): Boolean;

/// <summary>
/// Высокоуровневый хелпер: проверяет авторизацию и возвращает UserID.
/// Если токен невалиден — сама выставляет Response.StatusCode := 401 и Handled := True.
/// Возвращает UserID (>0) при успехе, 0 при ошибке.
/// </summary>
function CheckAuthorization(Request: TWebRequest; Response: TWebResponse; var Handled: Boolean): Integer;

implementation

function VerifyJwtAndExtractUserID(Request: TWebRequest; const ASecretKey: string; out AUserID: Integer): Boolean;
var
  AuthHeader, Token: string;
  PayloadObj: TJSONObject;
  UserIdValue: TJSONNumber;
begin
  Result := False;
  AUserID := 0;

  AuthHeader := Request.GetFieldByName('Authorization');
  if AuthHeader = '' then Exit;

  if not AuthHeader.StartsWith('Bearer ', True) then Exit;

  Token := AuthHeader.Substring(7).Trim;
  if Token = '' then Exit;

  PayloadObj := TJWT.ValidateToken(Token, ASecretKey);
  if not Assigned(PayloadObj) then Exit;

  try
    UserIdValue := PayloadObj.GetValue<TJSONNumber>('userID');
    if not Assigned(UserIdValue) then
      UserIdValue := PayloadObj.GetValue<TJSONNumber>('UserID');
    if not Assigned(UserIdValue) then
      UserIdValue := PayloadObj.GetValue<TJSONNumber>('user_id');

    if Assigned(UserIdValue) then
    begin
      AUserID := UserIdValue.AsInt;
      Result := True;
    end;
  finally
    PayloadObj.Free;
  end;
end;

function CheckAuthorization(Request: TWebRequest; Response: TWebResponse; var Handled: Boolean): Integer;
begin
  if not VerifyJwtAndExtractUserID(Request, GSecretKey, Result) then
  begin
    Response.StatusCode := 401;
    Response.ContentType := 'application/json; charset=utf-8';
    Response.Content := '{"error":"Unauthorized: Invalid or missing token"}';
    Handled := True;
    Result := 0;
  end;
end;

end.
