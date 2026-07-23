unit WebModuleUnit1;

interface

uses
  System.SysUtils, System.Classes, Web.HTTPApp, Data.DB, Data.Win.ADODB, System.JSON, uTaskRepository, uUserRepository, uAuthService, uAuthMiddleware;

type
  TWebModule1 = class(TWebModule)
    ADOConnection1: TADOConnection;
    ADOQueryTasks: TADOQuery;
    procedure WebModule1DefaultHandlerAction(Sender: TObject;
      Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
    procedure WebModule1waTestAction(Sender: TObject;
      Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
    procedure WebModule1waGetTasksAction(Sender: TObject; Request: TWebRequest;
      Response: TWebResponse; var Handled: Boolean);
    procedure WebModule1waCreateTaskAction(Sender: TObject;
      Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
    procedure WebModuleCreate(Sender: TObject);
    procedure WebModuleDestroy(Sender: TObject);
    procedure WebModule1waGetHistoryActionAction(Sender: TObject;
      Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
    procedure WebModule1waChangeStatusActionAction(Sender: TObject;
      Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
    procedure WebModule1waGetUsersActionAction(Sender: TObject;
      Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
    procedure WebModule1waCreateUserActionAction(Sender: TObject;
      Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
    procedure WebModule1waGetUserByIdActionAction(Sender: TObject;
      Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
    procedure WebModule1waUpdateUserActionAction(Sender: TObject;
      Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
    procedure WebModule1waDeleteUserActionAction(Sender: TObject;
      Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
    procedure WebModule1waLoginActionAction(Sender: TObject;
      Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
    procedure WebModule1waGetTaskByIdAction(Sender: TObject;
      Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
    procedure WebModule1waGetMeActionAction(Sender: TObject;
      Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
    procedure WebModule1waUpdateMeActionAction(Sender: TObject;
      Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
    procedure WebModule1waUpdateTaskActionAction(Sender: TObject;
      Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
  private
    FTaskRepo: TTaskRepository;
    FUserRepo: TUserRepository;
    FAuthService: TAuthService;
  public
    { Public declarations }
  end;

var
  WebModuleClass: TComponentClass = TWebModule1;

implementation

{%CLASSGROUP 'System.Classes.TPersistent'}

{$R *.dfm}

procedure TWebModule1.WebModule1DefaultHandlerAction(Sender: TObject;
  Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
begin
  Response.Content :=
    '<html>' +
    '<head><title>Web Server Application</title></head>' +
    '<body>Web Server Application</body>' +
    '</html>';
end;

procedure TWebModule1.WebModule1waChangeStatusActionAction(Sender: TObject;
  Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
var
  JSONValue: TJSONValue;
  JSONObject: TJSONObject;
  TaskID, UserID, NewStatusID: Integer;
  Comment: string;
  Success: Boolean;
begin
  UserID := CheckAuthorization(Request, Response, Handled);
  if UserID = 0 then Exit;

  try
    JSONValue := TJSONObject.ParseJSONValue(Request.Content);
    if not (JSONValue is TJSONObject) then
      raise Exception.Create('Invalid JSON format');

    JSONObject := JSONValue as TJSONObject;
    TaskID := JSONObject.GetValue<Integer>('task_id');
    NewStatusID := JSONObject.GetValue<Integer>('new_status_id');
    Comment := JSONObject.GetValue<string>('comment', '');

    if (TaskID = 0) or (NewStatusID = 0) then
      raise Exception.Create('task_id and new_status_id are required');

    Success := FTaskRepo.ChangeTaskStatus(TaskID, UserID, NewStatusID, Comment);

    if Success then
    begin
      Response.StatusCode := 200;
      Response.ContentType := 'application/json; charset=utf-8';
      Response.Content := '{"status":"success","message":"Status updated and history saved"}';
    end
    else
    begin
      Response.StatusCode := 404;
      Response.Content := '{"error":"Task not found"}';
    end;
    Handled := True;
  except
    on E: Exception do
    begin
      Response.StatusCode := 400;
      Response.ContentType := 'application/json; charset=utf-8';
      Response.Content := '{"error":"' + StringReplace(E.Message, '"', '\"', [rfReplaceAll]) + '"}';
      Handled := True;
    end;
  end;
end;

procedure TWebModule1.WebModule1waCreateTaskAction(Sender: TObject;
  Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
var
  JSONValue: TJSONValue;
  JSONObject: TJSONObject;
  Title, Description: string;
  StatusID, PriorityID, AssignedTo, UserID: Integer;
  NewTaskID: Integer;
begin
  UserID := CheckAuthorization(Request, Response, Handled);
  if UserID = 0 then Exit;

  try
    JSONValue := TJSONObject.ParseJSONValue(Request.Content);
    if not (JSONValue is TJSONObject) then
      raise Exception.Create('Invalid JSON format');

    JSONObject := JSONValue as TJSONObject;

    Title := JSONObject.GetValue<string>('title');
    Description := JSONObject.GetValue<string>('description', '');
    StatusID := JSONObject.GetValue<Integer>('status_id', 1);
    PriorityID := JSONObject.GetValue<Integer>('priority_id', 2);
    AssignedTo := JSONObject.GetValue<Integer>('assigned_to', 0);

    if Title = '' then
      raise Exception.Create('Title is required');

    NewTaskID := FTaskRepo.CreateTask(Title, Description, StatusID, PriorityID, UserID, AssignedTo);

    Response.StatusCode := 201;
    Response.ContentType := 'application/json; charset=utf-8';
    Response.Content := '{"status":"success","message":"Task created","task_id":' + IntToStr(NewTaskID) + '}';
    Handled := True;
    JSONObject.Free;
  except
    on E: Exception do
    begin
      Response.StatusCode := 400;
      Response.ContentType := 'application/json; charset=utf-8';
      Response.Content := '{"error":"' + StringReplace(E.Message, '"', '\"', [rfReplaceAll]) + '"}';
      Handled := True;
    end;
  end;
end;

procedure TWebModule1.WebModule1waCreateUserActionAction(Sender: TObject;
  Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
var
  JSONValue: TJSONValue;
  JSONObject: TJSONObject;
  Username, Email, Password, FullName: string;
  NewUserID: Integer;
begin
  try
    // 1. Парсим входящий JSON
    JSONValue := TJSONObject.ParseJSONValue(Request.Content);
    if not (JSONValue is TJSONObject) then
      raise Exception.Create('Invalid JSON format');

    JSONObject := JSONValue as TJSONObject;

    // 2. Извлекаем данные
    Username := JSONObject.GetValue<string>('username', '');
    Email := JSONObject.GetValue<string>('email', '');
    Password := JSONObject.GetValue<string>('password', '');
    FullName := JSONObject.GetValue<string>('fullName', '');

    // 3. Валидация обязательных полей
    if Username = '' then
      raise Exception.Create('Username is required');
    if Email = '' then
      raise Exception.Create('Email is required');
    if Password = '' then
      raise Exception.Create('Password is required');

    // 4. Создаем пользователя
    NewUserID := FUserRepo.CreateUser(Username, Email, Password, FullName);

    // 5. Формируем ответ
    Response.StatusCode := 201; // 201 Created
    Response.ContentType := 'application/json; charset=utf-8';
    Response.Content := '{"status":"success","message":"User created","userID":' + IntToStr(NewUserID) + '}';
    Handled := True;

    // Освобождаем JSON
    JSONObject.Free;
  except
    on E: Exception do
    begin
      Response.StatusCode := 400; // Bad Request
      Response.ContentType := 'application/json; charset=utf-8';
      Response.Content := '{"error":"' + StringReplace(E.Message, '"', '\"', [rfReplaceAll]) + '"}';
      Handled := True;
    end;
  end;
end;

procedure TWebModule1.WebModule1waDeleteUserActionAction(Sender: TObject;
  Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
var
  UserID: Integer;
  Success: Boolean;
  AuthUserId: Integer;
begin
  AuthUserID := CheckAuthorization(Request, Response, Handled);
  if AuthUserID = 0 then Exit;

  try
    UserID := StrToIntDef(Request.QueryFields.Values['id'], 0);
    if UserID = 0 then
      raise Exception.Create('Parameter "id" is required');

    // Удаляем пользователя (каскадно удалятся все связанные данные)
    Success := FUserRepo.DeleteUser(UserID);

    // Формируем ответ
    if Success then
    begin
      Response.StatusCode := 200;
      Response.ContentType := 'application/json; charset=utf-8';
      Response.Content := '{"status":"success","message":"User deleted"}';
    end
    else
    begin
      Response.StatusCode := 404;
      Response.ContentType := 'application/json; charset=utf-8';
      Response.Content := '{"error":"User not found"}';
    end;
    Handled := True;
  except
    on E: Exception do
    begin
      Response.StatusCode := 500;
      Response.ContentType := 'application/json; charset=utf-8';
      Response.Content := '{"error":"' + StringReplace(E.Message, '"', '\"', [rfReplaceAll]) + '"}';
      Handled := True;
    end;
  end;
end;

procedure TWebModule1.WebModule1waGetHistoryActionAction(Sender: TObject;
  Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
var
  TaskID: Integer;
  JSONArr: TJSONArray;
  UserID: Integer;
begin
  UserID := CheckAuthorization(Request, Response, Handled);
  if UserID = 0 then Exit;

  try
    // Ожидаем запрос вида: /api/tasks/history?task_id=5
    TaskID := StrToIntDef(Request.QueryFields.Values['task_id'], 0);
    if TaskID = 0 then
      raise Exception.Create('Parameter task_id is required');

    JSONArr := FTaskRepo.GetTaskHistory(TaskID);
    try
      Response.ContentType := 'application/json; charset=utf-8';
      Response.Content := JSONArr.ToJSON;
      Response.StatusCode := 200;
    finally
      JSONArr.Free;
    end;
    Handled := True;
  except
    on E: Exception do
    begin
      Response.StatusCode := 400;
      Response.ContentType := 'application/json; charset=utf-8';
      Response.Content := '{"error":"' + StringReplace(E.Message, '"', '\"', [rfReplaceAll]) + '"}';
      Handled := True;
    end;
  end;
end;

procedure TWebModule1.WebModule1waGetMeActionAction(Sender: TObject;
  Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
var
  UserID: Integer;
  JSONObj: TJSONObject;
begin
  UserID := CheckAuthorization(Request, Response, Handled);
  if UserID = 0 then Exit;

  try
    JSONObj := FUserRepo.GetUserById(UserID);
    try
      if JSONObj = nil then
      begin
        Response.StatusCode := 404;
        Response.ContentType := 'application/json; charset=utf-8';
        Response.Content := '{"error":"User not found"}';
      end
      else
      begin
        Response.StatusCode := 200;
        Response.ContentType := 'application/json; charset=utf-8';
        Response.Content := JSONObj.ToJSON;
      end;
    finally
      JSONObj.Free;
    end;
    Handled := True;
  except
    on E: Exception do
    begin
      Response.StatusCode := 500;
      Response.ContentType := 'application/json; charset=utf-8';
      Response.Content := '{"error":"' + StringReplace(E.Message, '"', '\"', [rfReplaceAll]) + '"}';
      Handled := True;
    end;
  end;
end;

procedure TWebModule1.WebModule1waGetTasksAction(Sender: TObject;
   Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
var
   JSONArr: TJSONArray;
   UserID: Integer;
begin
  UserID := CheckAuthorization(Request, Response, Handled);
  if UserID = 0 then Exit;

   try
     JSONArr := FTaskRepo.GetAllTasks;
     try
       Response.ContentType := 'application/json; charset=utf-8';
       Response.Content := JSONArr.ToJSON;
       Response.StatusCode := 200;
     finally
       JSONArr.Free;
     end;
     Handled := True;
   except
     on E: Exception do
     begin
       Response.StatusCode := 500;
       Response.ContentType := 'application/json; charset=utf-8';
       Response.Content := '{"error":"' + StringReplace(E.Message, '"', '\"', [rfReplaceAll]) + '"}';
       Handled := True;
     end;
   end;
end;

procedure TWebModule1.WebModule1waGetTaskByIdAction(Sender: TObject;
  Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
var
  TaskID: Integer;
  JSONObj: TJSONObject;
  UserID: Integer;
begin
  UserID := CheckAuthorization(Request, Response, Handled);
  if UserID = 0 then Exit;

  try
    TaskID := StrToIntDef(Request.QueryFields.Values['id'], 0);
    if TaskID = 0 then
      raise Exception.Create('Parameter "id" is required');

    JSONObj := FTaskRepo.GetTaskById(TaskID);
    try
      if JSONObj = nil then
      begin
        Response.StatusCode := 404;
        Response.ContentType := 'application/json; charset=utf-8';
        Response.Content := '{"error":"Task not found"}';
      end
      else
      begin
        Response.StatusCode := 200;
        Response.ContentType := 'application/json; charset=utf-8';
        Response.Content := JSONObj.ToJSON;
      end;
    finally
      JSONObj.Free;
    end;
    Handled := True;
  except
    on E: Exception do
    begin
      Response.StatusCode := 400;
      Response.ContentType := 'application/json; charset=utf-8';
      Response.Content := '{"error":"' + StringReplace(E.Message, '"', '\"', [rfReplaceAll]) + '"}';
      Handled := True;
    end;
  end;
end;

procedure TWebModule1.WebModule1waGetUserByIdActionAction(Sender: TObject;
  Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
var
  UserID: Integer;
  AuthUserId: Integer;
  JSONObj: TJSONObject;
begin
  AuthUserID := CheckAuthorization(Request, Response, Handled);
  if AuthUserID = 0 then Exit;

  try
    // 1. Получаем id из QueryString: /api/users/details?id=5
    UserID := StrToIntDef(Request.QueryFields.Values['id'], 0);
    if UserID = 0 then
      raise Exception.Create('Parameter "id" is required');

    // 2. Получаем пользователя из репозитория
    JSONObj := FUserRepo.GetUserById(UserID);
    try
      // 3. Проверяем, найден ли пользователь
      if JSONObj = nil then
      begin
        Response.StatusCode := 404;
        Response.ContentType := 'application/json; charset=utf-8';
        Response.Content := '{"error":"User not found"}';
      end
      else
      begin
        Response.StatusCode := 200;
        Response.ContentType := 'application/json; charset=utf-8';
        Response.Content := JSONObj.ToJSON;
      end;
    finally
      JSONObj.Free;
    end;
    Handled := True;
  except
    on E: Exception do
    begin
      Response.StatusCode := 400;
      Response.ContentType := 'application/json; charset=utf-8';
      Response.Content := '{"error":"' + StringReplace(E.Message, '"', '\"', [rfReplaceAll]) + '"}';
      Handled := True;
    end;
  end;
end;

procedure TWebModule1.WebModule1waGetUsersActionAction(Sender: TObject;
  Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
var
  JSONArr: TJSONArray;
  UserId: Integer;
begin
  UserID := CheckAuthorization(Request, Response, Handled);
  if UserID = 0 then Exit;

  try
    JSONArr := FUserRepo.GetAllUsers;
    try
      Response.ContentType := 'application/json; charset=utf-8';
      Response.Content := JSONArr.ToJSON;
      Response.StatusCode := 200;
    finally
      JSONArr.Free;
    end;
    Handled := True;
  except
    on E: Exception do
    begin
      Response.StatusCode := 500;
      Response.ContentType := 'application/json; charset=utf-8';
      Response.Content := '{"error":"' + StringReplace(E.Message, '"', '\"', [rfReplaceAll]) + '"}';
      Handled := True;
    end;
  end;
end;

procedure TWebModule1.WebModule1waLoginActionAction(Sender: TObject;
  Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
var
  JSONValue: TJSONValue;
  JSONObject: TJSONObject;
  Username, Password: string;
  AuthToken: string;
  RequestBody: string;
  JsonResponse: string;
begin
  try
    // 1. Читаем тело запроса как UTF-8
    RequestBody := TEncoding.UTF8.GetString(Request.RawContent);

    JSONValue := TJSONObject.ParseJSONValue(RequestBody);
    if not (JSONValue is TJSONObject) then
      raise Exception.Create('Invalid JSON format');

    JSONObject := JSONValue as TJSONObject;

    Username := JSONObject.GetValue<string>('username', '');
    Password := JSONObject.GetValue<string>('password', '');

    JSONObject.Free; // Освобождаем JSON

    // 2. Валидация
    if Username = '' then
      raise Exception.Create('Username is required');
    if Password = '' then
      raise Exception.Create('Password is required');

    // 3. Пытаемся авторизоваться
    AuthToken := FAuthService.Login(Username, Password);

    if AuthToken = '' then
    begin
      Response.StatusCode := 401;
      Response.ContentType := 'application/json; charset=utf-8';
      JsonResponse := '{"error":"Invalid username or password"}';
      // Отправляем поток сырых байтов UTF-8
      Response.ContentStream := TBytesStream.Create(TEncoding.UTF8.GetBytes(JsonResponse));
      Response.FreeContentStream := True; // Пусть WebBroker сам удалит поток после отправки
      Handled := True;
      Exit;
    end;

    // 4. Формируем успешный ответ
    Response.StatusCode := 200;
    Response.ContentType := 'application/json; charset=utf-8';
    JsonResponse := '{"token":"' + AuthToken + '"}';
    // Отправляем поток сырых байтов UTF-8
    Response.ContentStream := TBytesStream.Create(TEncoding.UTF8.GetBytes(JsonResponse));
    Response.FreeContentStream := True;
    Handled := True;

  except
    on E: Exception do
    begin
      Response.StatusCode := 400;
      Response.ContentType := 'application/json; charset=utf-8';
      JsonResponse := '{"error":"' + E.ClassName + ': ' + StringReplace(E.Message, '"', '\"', [rfReplaceAll]) + '"}';
      // Отправляем поток сырых байтов UTF-8
      Response.ContentStream := TBytesStream.Create(TEncoding.UTF8.GetBytes(JsonResponse));
      Response.FreeContentStream := True;
      Handled := True;
    end;
  end;
end;

procedure TWebModule1.WebModule1waTestAction(Sender: TObject;
  Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
begin
  try
    // Проверяем подключение
    if ADOConnection1.Connected then
    begin
      // Пробуем выполнить запрос
      ADOQueryTasks.Open;

      Response.ContentType := 'application/json';
      Response.Content := '{"status":"success","message":"Database connected!","task_count":' +
                          IntToStr(ADOQueryTasks.RecordCount) + '}';
    end
    else
    begin
      Response.StatusCode := 500;
      Response.Content := '{"status":"error","message":"Database not connected"}';
    end;
  except
    on E: Exception do
    begin
      Response.StatusCode := 500;
      Response.Content := '{"status":"error","message":"' + StringReplace(E.Message, '"', '\"', [rfReplaceAll]) + '"}';
    end;
  end;
  Handled := True;
end;

procedure TWebModule1.WebModule1waUpdateMeActionAction(Sender: TObject;
  Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
var
  JSONValue: TJSONValue;
  JSONObject: TJSONObject;
  UserID: Integer;
  Email, FullName, NewPassword, ConfirmPassword: string;
  Success: Boolean;
begin
  UserID := CheckAuthorization(Request, Response, Handled);
  if UserID = 0 then Exit;

  try
    // Парсим входящий JSON
    JSONValue := TJSONObject.ParseJSONValue(Request.Content);
    if not (JSONValue is TJSONObject) then
      raise Exception.Create('Invalid JSON format');

    JSONObject := JSONValue as TJSONObject;

    Email := JSONObject.GetValue<string>('email', '');
    FullName := JSONObject.GetValue<string>('fullName', '');
    NewPassword := JSONObject.GetValue<string>('newPassword', '');
    ConfirmPassword := JSONObject.GetValue<string>('confirmPassword', '');

    JSONObject.Free;

    if Email = '' then
      raise Exception.Create('Email is required');

    // Проверка совпадения паролей (если они указаны)
    if (NewPassword <> '') or (ConfirmPassword <> '') then
    begin
      if NewPassword <> ConfirmPassword then
        raise Exception.Create('Passwords do not match');
      if Length(NewPassword) < 4 then
        raise Exception.Create('Password must be at least 4 characters');
    end;

    // Обновляем пользователя
    // Если пароль указан, обновляем с паролем; иначе только Email и FullName
    if NewPassword <> '' then
      Success := FUserRepo.UpdateUserWithPassword(UserID, Email, FullName, NewPassword)
    else
      Success := FUserRepo.UpdateUser(UserID, Email, FullName);

    // Формируем ответ
    if Success then
    begin
      Response.StatusCode := 200;
      Response.ContentType := 'application/json; charset=utf-8';
      Response.Content := '{"status":"success","message":"Profile updated"}';
    end
    else
    begin
      Response.StatusCode := 404;
      Response.ContentType := 'application/json; charset=utf-8';
      Response.Content := '{"error":"User not found"}';
    end;
    Handled := True;
  except
    on E: Exception do
    begin
      Response.StatusCode := 400;
      Response.ContentType := 'application/json; charset=utf-8';
      Response.Content := '{"error":"' + StringReplace(E.Message, '"', '\"', [rfReplaceAll]) + '"}';
      Handled := True;
    end;
  end;
end;

procedure TWebModule1.WebModule1waUpdateTaskActionAction(Sender: TObject;
  Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
var
  JSONValue: TJSONValue;
  JSONObject: TJSONObject;
  TaskID, UserID, AssignedTo: Integer;
  Title, Description: string;
begin
  UserID := CheckAuthorization(Request, Response, Handled);
  if UserID = 0 then Exit;

  try
    TaskID := StrToIntDef(Request.QueryFields.Values['id'], 0);
    if TaskID = 0 then
      raise Exception.Create('Parameter "id" is required');

    JSONValue := TJSONObject.ParseJSONValue(Request.Content);
    if not (JSONValue is TJSONObject) then
      raise Exception.Create('Invalid JSON format');

    JSONObject := JSONValue as TJSONObject;

    Title := JSONObject.GetValue<string>('title');
    Description := JSONObject.GetValue<string>('description', '');
    AssignedTo := JSONObject.GetValue<Integer>('assigned_to', 0);

    if Title = '' then
      raise Exception.Create('Title is required');

    if FTaskRepo.UpdateTask(TaskID, Title, Description, AssignedTo) then
    begin
      Response.StatusCode := 200;
      Response.ContentType := 'application/json; charset=utf-8';
      Response.Content := '{"status":"success","message":"Task updated"}';
    end
    else
    begin
      Response.StatusCode := 404;
      Response.ContentType := 'application/json; charset=utf-8';
      Response.Content := '{"error":"Task not found"}';
    end;
    Handled := True;
    JSONObject.Free;
  except
    on E: Exception do
    begin
      Response.StatusCode := 400;
      Response.ContentType := 'application/json; charset=utf-8';
      Response.Content := '{"error":"' + StringReplace(E.Message, '"', '\"', [rfReplaceAll]) + '"}';
      Handled := True;
    end;
  end;
end;

procedure TWebModule1.WebModule1waUpdateUserActionAction(Sender: TObject;
  Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
var
  JSONValue: TJSONValue;
  JSONObject: TJSONObject;
  UserID: Integer;
  Email, FullName: string;
  Success: Boolean;
begin
  UserID := CheckAuthorization(Request, Response, Handled);
  if UserID = 0 then Exit;

  try
    // 1. Парсим входящий JSON
    JSONValue := TJSONObject.ParseJSONValue(Request.Content);
    if not (JSONValue is TJSONObject) then
      raise Exception.Create('Invalid JSON format');

    JSONObject := JSONValue as TJSONObject;

    // 2. Извлекаем данные
    UserID := JSONObject.GetValue<Integer>('userID', 0);
    Email := JSONObject.GetValue<string>('email', '');
    FullName := JSONObject.GetValue<string>('fullName', '');

    // 3. Валидация
    if UserID = 0 then
      raise Exception.Create('userID is required');
    if Email = '' then
      raise Exception.Create('Email is required');

    // 4. Обновляем пользователя
    Success := FUserRepo.UpdateUser(UserID, Email, FullName);

    // 5. Формируем ответ
    if Success then
    begin
      Response.StatusCode := 200;
      Response.ContentType := 'application/json; charset=utf-8';
      Response.Content := '{"status":"success","message":"User updated"}';
    end
    else
    begin
      Response.StatusCode := 404;
      Response.ContentType := 'application/json; charset=utf-8';
      Response.Content := '{"error":"User not found"}';
    end;
    Handled := True;

    // Освобождаем JSON
    JSONObject.Free;
  except
    on E: Exception do
    begin
      Response.StatusCode := 400;
      Response.ContentType := 'application/json; charset=utf-8';
      Response.Content := '{"error":"' + StringReplace(E.Message, '"', '\"', [rfReplaceAll]) + '"}';
      Handled := True;
    end;
  end;
end;

procedure TWebModule1.WebModuleCreate(Sender: TObject);
begin
  GSecretKey := 'SecretKey123';
  FTaskRepo := TTaskRepository.Create(ADOConnection1);
  FUserRepo := TUserRepository.Create(ADOConnection1);
  FAuthService := TAuthService.Create(ADOConnection1, GSecretKey);
end;

procedure TWebModule1.WebModuleDestroy(Sender: TObject);
begin
  FTaskRepo.Free;
  FUserRepo.Free;
  FAuthService.Free;
end;

end.
