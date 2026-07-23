unit uTaskRepository;

interface

uses
  System.SysUtils, System.JSON, Data.DB, Data.Win.ADODB, Variants;

type
  TTaskRepository = class
  private
    FConnection: TADOConnection;
  public
    constructor Create(AConnection: TADOConnection);

    function GetAllTasks: TJSONArray;
    function CreateTask(const ATitle, ADescription: string; AStatusID, APriorityID, ACreatedBy, AAssignedTo: Integer): Integer;
    function ChangeTaskStatus(ATaskID, AUserID, ANewStatusID: Integer; const AComment: string): Boolean;
    function GetTaskHistory(ATaskID: Integer): TJSONArray;
    function GetTaskById(ATaskID: Integer): TJSONObject;
    function UpdateTask(ATaskID: Integer; const ATitle, ADescription: string; AAssignedTo: Integer): Boolean;
  end;

implementation

{ TTaskRepository }

constructor TTaskRepository.Create(AConnection: TADOConnection);
begin
  inherited Create;
  FConnection := AConnection;
end;

function TTaskRepository.GetAllTasks: TJSONArray;
var
  Qry: TADOQuery;
  JSONObj: TJSONObject;
begin
  Result := TJSONArray.Create;
  Qry := TADOQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text :=
      'SELECT t.TaskID, t.Title, s.StatusName, p.PriorityName, u.FullName AS AssignedToName ' +
      'FROM Tasks t ' +
      'LEFT JOIN TaskStatuses s ON t.StatusID = s.StatusID ' +
      'LEFT JOIN Priorities p ON t.PriorityID = p.PriorityID ' +
      'LEFT JOIN Users u ON t.AssignedTo = u.UserID ' +
      'ORDER BY t.TaskID DESC';
    Qry.Open;

    while not Qry.Eof do
    begin
      JSONObj := TJSONObject.Create;
      JSONObj.AddPair('TaskID', TJSONNumber.Create(Qry.FieldByName('TaskID').AsInteger));
      JSONObj.AddPair('Title', Qry.FieldByName('Title').AsString);
      JSONObj.AddPair('StatusName', Qry.FieldByName('StatusName').AsString);
      JSONObj.AddPair('PriorityName', Qry.FieldByName('PriorityName').AsString);
      if Qry.FieldByName('AssignedToName').IsNull then
        JSONObj.AddPair('AssignedToName', TJSONNull.Create)
      else
        JSONObj.AddPair('AssignedToName', Qry.FieldByName('AssignedToName').AsString);

      Result.AddElement(JSONObj);
      Qry.Next;
    end;
  finally
    Qry.Free;
  end;
end;

function TTaskRepository.GetTaskById(ATaskID: Integer): TJSONObject;
var
  Qry: TADOQuery;
begin
  Result := nil;
  Qry := TADOQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text :=
      'SELECT t.TaskID, t.Title, t.Description, t.AssignedTo, ' +
      's.StatusName, p.PriorityName, u.FullName AS AssignedToName ' +
      'FROM Tasks t ' +
      'LEFT JOIN TaskStatuses s ON t.StatusID = s.StatusID ' +
      'LEFT JOIN Priorities p ON t.PriorityID = p.PriorityID ' +
      'LEFT JOIN Users u ON t.AssignedTo = u.UserID ' +
      'WHERE t.TaskID = :TaskID';
    Qry.Parameters.ParamByName('TaskID').Value := ATaskID;
    Qry.Open;

    if not Qry.IsEmpty then
    begin
      Result := TJSONObject.Create;
      Result.AddPair('TaskID', TJSONNumber.Create(Qry.FieldByName('TaskID').AsInteger));
      Result.AddPair('Title', Qry.FieldByName('Title').AsString);
      Result.AddPair('Description', Qry.FieldByName('Description').AsString);
      Result.AddPair('StatusName', Qry.FieldByName('StatusName').AsString);
      Result.AddPair('PriorityName', Qry.FieldByName('PriorityName').AsString);

      if Qry.FieldByName('AssignedTo').IsNull then
        Result.AddPair('AssignedTo', TJSONNull.Create)
      else
        Result.AddPair('AssignedTo', TJSONNumber.Create(Qry.FieldByName('AssignedTo').AsInteger));

      if Qry.FieldByName('AssignedToName').IsNull then
        Result.AddPair('AssignedToName', TJSONNull.Create)
      else
        Result.AddPair('AssignedToName', Qry.FieldByName('AssignedToName').AsString);
    end;
  finally
    Qry.Free;
  end;
end;

function TTaskRepository.CreateTask(const ATitle, ADescription: string; AStatusID, APriorityID, ACreatedBy, AAssignedTo: Integer): Integer;
var
  Qry: TADOQuery;
begin
  Qry := TADOQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text :=
      'INSERT INTO Tasks (Title, Description, CreatedBy, AssignedTo, StatusID, PriorityID, CreatedAt) ' +
      'OUTPUT INSERTED.TaskID ' +
      'VALUES (:Title, :Description, :CreatedBy, :AssignedTo, :StatusID, :PriorityID, GETDATE())';

    Qry.Parameters.ParamByName('Title').Value := ATitle;
    Qry.Parameters.ParamByName('Description').Value := ADescription;
    Qry.Parameters.ParamByName('CreatedBy').Value := ACreatedBy;

    if AAssignedTo = 0 then
      Qry.Parameters.ParamByName('AssignedTo').Value := Null
    else
      Qry.Parameters.ParamByName('AssignedTo').Value := AAssignedTo;

    Qry.Parameters.ParamByName('StatusID').Value := AStatusID;
    Qry.Parameters.ParamByName('PriorityID').Value := APriorityID;

    Qry.Open;
    if not Qry.IsEmpty then
      Result := Qry.Fields[0].AsInteger;
   finally
    Qry.Free;
  end;
end;

function TTaskRepository.ChangeTaskStatus(ATaskID, AUserID, ANewStatusID: Integer; const AComment: string): Boolean;
var
  Qry: TADOQuery;
  OldStatusID: Integer;
begin
  Result := False;
  Qry := TADOQuery.Create(nil);
  try
    Qry.Connection := FConnection;

    // 1. Начинаем транзакцию ADO
    FConnection.BeginTrans;
    try
      // 2. Узнаем старый статус
      Qry.SQL.Text := 'SELECT StatusID FROM Tasks WHERE TaskID = :id';
      Qry.Parameters.ParamByName('id').Value := ATaskID;
      Qry.Open;
      if Qry.IsEmpty then
      begin
        FConnection.RollbackTrans;
        Exit;
      end;
      OldStatusID := Qry.FieldByName('StatusID').AsInteger;
      Qry.Close;

      // 3. Обновляем задачу
      Qry.SQL.Text := 'UPDATE Tasks SET StatusID = :new_status, UpdatedAt = GETDATE() WHERE TaskID = :id';
      Qry.Parameters.ParamByName('new_status').Value := ANewStatusID;
      Qry.Parameters.ParamByName('id').Value := ATaskID;
      Qry.ExecSQL;

      // 4. Пишем в историю
      Qry.SQL.Text :=
        'INSERT INTO TaskStatusHistory (TaskID, OldStatusID, NewStatusID, ChangedBy, Comment) ' +
        'VALUES (:task, :old, :new, :user, :comment)';
      Qry.Parameters.ParamByName('task').Value := ATaskID;
      Qry.Parameters.ParamByName('old').Value := OldStatusID;
      Qry.Parameters.ParamByName('new').Value := ANewStatusID;
      Qry.Parameters.ParamByName('user').Value := AUserID;
      Qry.Parameters.ParamByName('comment').Value := AComment;
      Qry.ExecSQL;

      // 5. Фиксируем изменения
      FConnection.CommitTrans;
      Result := True;
    except
      on E: Exception do
      begin
        FConnection.RollbackTrans;
        raise; // Пробрасываем ошибку выше
      end;
    end;
  finally
    Qry.Free;
  end;
end;

function TTaskRepository.GetTaskHistory(ATaskID: Integer): TJSONArray;
var
  Qry: TADOQuery;
  JSONObj: TJSONObject;
begin
  Result := TJSONArray.Create;
  Qry := TADOQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text :=
      'SELECT h.ChangedAt, h.Comment, ' +
      'ISNULL(s1.StatusName, ''Создание'') AS OldStatus, ' +
      's2.StatusName AS NewStatus, ' +
      'u.Username AS ChangedByUser ' +
      'FROM TaskStatusHistory h ' +
      'LEFT JOIN TaskStatuses s1 ON h.OldStatusID = s1.StatusID ' +
      'INNER JOIN TaskStatuses s2 ON h.NewStatusID = s2.StatusID ' +
      'INNER JOIN Users u ON h.ChangedBy = u.UserID ' +
      'WHERE h.TaskID = :id ORDER BY h.ChangedAt DESC';
    Qry.Parameters.ParamByName('id').Value := ATaskID;
    Qry.Open;

    while not Qry.Eof do
    begin
      JSONObj := TJSONObject.Create;
      JSONObj.AddPair('oldStatus', Qry.FieldByName('OldStatus').AsString);
      JSONObj.AddPair('newStatus', Qry.FieldByName('NewStatus').AsString);
      JSONObj.AddPair('changedBy', Qry.FieldByName('ChangedByUser').AsString);
      JSONObj.AddPair('changedAt', Qry.FieldByName('ChangedAt').AsString);
      JSONObj.AddPair('comment', Qry.FieldByName('Comment').AsString);
      Result.AddElement(JSONObj);
      Qry.Next;
    end;
  finally
    Qry.Free;
  end;
end;

function TTaskRepository.UpdateTask(ATaskID: Integer; const ATitle, ADescription: string; AAssignedTo: Integer): Boolean;
var
  Qry: TADOQuery;
begin
  Result := False;
  Qry := TADOQuery.Create(nil);
  try
    Qry.Connection := FConnection;
    Qry.SQL.Text :=
      'UPDATE Tasks SET Title = :Title, Description = :Description, AssignedTo = :AssignedTo, UpdatedAt = GETDATE() ' +
      'WHERE TaskID = :TaskID';

    Qry.Parameters.ParamByName('Title').Value := ATitle;
    Qry.Parameters.ParamByName('Description').Value := ADescription;

    if AAssignedTo = 0 then
      Qry.Parameters.ParamByName('AssignedTo').Value := Null
    else
      Qry.Parameters.ParamByName('AssignedTo').Value := AAssignedTo;

    Qry.Parameters.ParamByName('TaskID').Value := ATaskID;

    Qry.ExecSQL;
    Result := True; // Если исключений нет, считаем успешным
  finally
    Qry.Free;
  end;
end;

end.
