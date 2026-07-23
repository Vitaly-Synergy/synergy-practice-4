unit uUserRepository;

interface

uses
  System.SysUtils, System.JSON, Data.DB, Data.Win.ADODB, System.Hash, System.Variants;

type
  TUserRepository = class
  private
    FConnection: TADOConnection;
  public
    constructor Create(AConnection: TADOConnection);

    function GetAllUsers: TJSONArray;
    function CreateUser(const AUsername, AEmail, APassword, AFullName: string): Integer;
    function GetUserById(AUserID: Integer): TJSONObject;
    function UpdateUser(AUserID: Integer; const AEmail, AFullName: string): Boolean;
    function DeleteUser(AUserID: Integer): Boolean;
    function UpdateUserWithPassword(AUserID: Integer; const AEmail, AFullName, ANewPassword: string): Boolean;
  end;

implementation

{ TUserRepository }

constructor TUserRepository.Create(AConnection: TADOConnection);
begin
  inherited Create;
  FConnection := AConnection;
end;

function TUserRepository.GetAllUsers: TJSONArray;
var
  Qry: TADOQuery;
  JSONObj: TJSONObject;
begin
  Result := TJSONArray.Create;
  Qry := TADOQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text :=
      'SELECT UserID, Username, Email, FullName, CreatedAt ' +
      'FROM Users ORDER BY Username';
    Qry.Open;

    while not Qry.Eof do
    begin
      JSONObj := TJSONObject.Create;
      JSONObj.AddPair('userID', TJSONNumber.Create(Qry.FieldByName('UserID').AsInteger));
      JSONObj.AddPair('username', Qry.FieldByName('Username').AsString);
      JSONObj.AddPair('email', Qry.FieldByName('Email').AsString);

      if not Qry.FieldByName('FullName').IsNull then
        JSONObj.AddPair('fullName', Qry.FieldByName('FullName').AsString)
      else
        JSONObj.AddPair('fullName', TJSONNull.Create);

      JSONObj.AddPair('createdAt', Qry.FieldByName('CreatedAt').AsString);

      Result.AddElement(JSONObj);
      Qry.Next;
    end;
  finally
    Qry.Free;
  end;
end;

function TUserRepository.CreateUser(const AUsername, AEmail, APassword, AFullName: string): Integer;
var
  Qry: TADOQuery;
  PasswordHash: string;
begin
  PasswordHash := THashSHA2.GetHashString(APassword);

  Qry := TADOQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text :=
      'INSERT INTO Users (Username, Email, PasswordHash, FullName) ' +
      'OUTPUT INSERTED.UserID ' +
      'VALUES (:username, :email, :hash, :fullname)';

    Qry.Parameters.ParamByName('username').DataType := ftWideString;
    Qry.Parameters.ParamByName('username').Value := AUsername;

    Qry.Parameters.ParamByName('email').DataType := ftWideString;
    Qry.Parameters.ParamByName('email').Value := AEmail;

    Qry.Parameters.ParamByName('hash').DataType := ftWideString;
    Qry.Parameters.ParamByName('hash').Value := PasswordHash;

    Qry.Parameters.ParamByName('fullname').DataType := ftWideString;
    if AFullName <> '' then
      Qry.Parameters.ParamByName('fullname').Value := AFullName
    else
      Qry.Parameters.ParamByName('fullname').Value := Null;

    Qry.Open;
    Result := Qry.FieldByName('UserID').AsInteger;
  finally
    Qry.Free;
  end;
end;

function TUserRepository.GetUserById(AUserID: Integer): TJSONObject;
var
  Qry: TADOQuery;
begin
  Result := nil;
  Qry := TADOQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text :=
      'SELECT UserID, Username, Email, FullName, CreatedAt ' +
      'FROM Users WHERE UserID = :id';
    Qry.Parameters.ParamByName('id').Value := AUserID;
    Qry.Open;

    if not Qry.IsEmpty then
    begin
      Result := TJSONObject.Create;
      Result.AddPair('userID', TJSONNumber.Create(Qry.FieldByName('UserID').AsInteger));
      Result.AddPair('username', Qry.FieldByName('Username').AsString);
      Result.AddPair('email', Qry.FieldByName('Email').AsString);

      if not Qry.FieldByName('FullName').IsNull then
        Result.AddPair('fullName', Qry.FieldByName('FullName').AsString)
      else
        Result.AddPair('fullName', TJSONNull.Create);

      Result.AddPair('createdAt', Qry.FieldByName('CreatedAt').AsString);
    end;
  finally
    Qry.Free;
  end;
end;

function TUserRepository.UpdateUser(AUserID: Integer; const AEmail, AFullName: string): Boolean;
var
  Qry: TADOQuery;
  RowsAffected: Integer;
begin
  Qry := TADOQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text :=
      'UPDATE Users SET Email = :email, FullName = :fullname WHERE UserID = :id';

    Qry.Parameters.ParamByName('email').Value := AEmail;

    if AFullName <> '' then
      Qry.Parameters.ParamByName('fullname').Value := AFullName
    else
      Qry.Parameters.ParamByName('fullname').Value := Null;

    Qry.Parameters.ParamByName('id').Value := AUserID;

    Qry.ExecSQL;

    // Проверяем, сколько строк было обновлено
    RowsAffected := Qry.RowsAffected;
    Result := (RowsAffected > 0);
  finally
    Qry.Free;
  end;
end;

function TUserRepository.DeleteUser(AUserID: Integer): Boolean;
var
  Cmd: TADOCommand;
begin
  Result := False;
  Cmd := TADOCommand.Create(nil);
  try
    Cmd.Connection := FConnection;

    // Один SQL-скрипт со всеми операциями (используем ? вместо @id)
    Cmd.CommandText :=
      'SET NOCOUNT ON; ' +
      'DELETE FROM Comments WHERE UserID = ?; ' +
      'DELETE FROM TaskStatusHistory WHERE ChangedBy = ?; ' +
      'UPDATE Tasks SET AssignedTo = NULL WHERE AssignedTo = ?; ' +
      'DELETE FROM Tasks WHERE CreatedBy = ?; ' +
      'UPDATE Projects SET CreatedBy = NULL WHERE CreatedBy = ?; ' +
      'DELETE FROM Users WHERE UserID = ?;';

    Cmd.Parameters.Clear;
    Cmd.Parameters.CreateParameter('', ftInteger, pdInput, 0, AUserID);
    Cmd.Parameters.CreateParameter('', ftInteger, pdInput, 0, AUserID);
    Cmd.Parameters.CreateParameter('', ftInteger, pdInput, 0, AUserID);
    Cmd.Parameters.CreateParameter('', ftInteger, pdInput, 0, AUserID);
    Cmd.Parameters.CreateParameter('', ftInteger, pdInput, 0, AUserID);
    Cmd.Parameters.CreateParameter('', ftInteger, pdInput, 0, AUserID);

    Cmd.Execute;

    Result := True;
  except
    on E: Exception do
    begin
      raise Exception.Create('Delete failed: ' + E.Message);
    end;
  end;
  Cmd.Free;
end;

function TUserRepository.UpdateUserWithPassword(AUserID: Integer; const AEmail, AFullName, ANewPassword: string): Boolean;
var
  Qry: TADOQuery;
  PasswordHash: string;
begin
  Result := False;

  // Хэшируем новый пароль
  PasswordHash := THashSHA2.GetHashString(ANewPassword);

  Qry := TADOQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text :=
      'UPDATE Users SET Email = :Email, FullName = :FullName, PasswordHash = :PasswordHash ' +
      'WHERE UserID = :UserID';

    Qry.Parameters.ParamByName('Email').Value := AEmail;
    Qry.Parameters.ParamByName('FullName').Value := AFullName;
    Qry.Parameters.ParamByName('PasswordHash').Value := PasswordHash;
    Qry.Parameters.ParamByName('UserID').Value := AUserID;

    Qry.ExecSQL;

    // Считаем успешным, если не произошло исключений
    Result := True;
  finally
    Qry.Free;
  end;
end;

end.
