unit uAuthService;

interface

uses
  System.SysUtils, System.JSON, Data.DB, Data.Win.ADODB, uJWT, System.Hash;

type
  TAuthService = class
  private
    FConnection: TADOConnection;
    FSecretKey: string;
  public
    constructor Create(AConnection: TADOConnection; const ASecretKey: string);

    // Логин: проверка username/password, возврат JWT токена
    function Login(const AUsername, APassword: string): string;

    // Проверка токена и возврат данных пользователя
    function ValidateToken(const AToken: string): TJSONObject;

    // Хэширование пароля (для сравнения)
    class function HashPassword(const APassword: string): string;
  end;

implementation

{ TAuthService }

constructor TAuthService.Create(AConnection: TADOConnection; const ASecretKey: string);
begin
  inherited Create;
  FConnection := AConnection;
  FSecretKey := ASecretKey;
end;

class function TAuthService.HashPassword(const APassword: string): string;
begin
  // Используем тот же алгоритм хэширования, что и при создании пользователя
  Result := System.Hash.THashSHA2.GetHashString(APassword);
end;

function TAuthService.Login(const AUsername, APassword: string): string;
var
  Qry: TADOQuery;
  UserID: Integer;
  StoredHash, InputHash: string;
  Payload: TJSONObject;
begin
  Result := '';

  // --- БЛОК 1: РАБОТА С БАЗОЙ ДАННЫХ ---
  try
    Qry := TADOQuery.Create(nil);
    try
      Qry.Connection := FConnection;
      Qry.ParamCheck := True;
      Qry.SQL.Text := 'SELECT UserID, PasswordHash FROM Users WHERE Username = :username';
      Qry.Parameters.ParamByName('username').Value := AUsername;
      Qry.Open;

      if not Qry.IsEmpty then
      begin
        UserID := Qry.FieldByName('UserID').AsInteger;
        StoredHash := Qry.FieldByName('PasswordHash').AsString;
      end
      else
        Exit; // Пользователь не найден
    finally
      Qry.Free;
    end;
  except
    on E: Exception do
      Exit('ERROR_IN_DB: ' + E.Message);
  end;

  // --- БЛОК 2: ХЕШИРОВАНИЕ ПАРОЛЯ ---
  try
    InputHash := HashPassword(APassword);
  except
    on E: Exception do
      Exit('ERROR_IN_HASH: ' + E.Message);
  end;

  if InputHash <> StoredHash then
    Exit; // Неверный пароль

  // --- БЛОК 3: ГЕНЕРАЦИЯ JWT ТОКЕНА ---
  try
    Payload := TJSONObject.Create;
    try
      Payload.AddPair('userID', TJSONNumber.Create(UserID));
      Payload.AddPair('username', AUsername);
      Result := TJWT.CreateToken(Payload, FSecretKey, 60);
    finally
      Payload.Free;
    end;
  except
    on E: Exception do
      Exit('ERROR_IN_JWT: ' + E.Message);
  end;
end;

function TAuthService.ValidateToken(const AToken: string): TJSONObject;
begin
  // Проверяем токен и возвращаем payload
  Result := TJWT.ValidateToken(AToken, FSecretKey);
end;

end.

