object WebModule1: TWebModule1
  OnCreate = WebModuleCreate
  OnDestroy = WebModuleDestroy
  Actions = <
    item
      Default = True
      Name = 'DefaultHandler'
      PathInfo = '/'
      OnAction = WebModule1DefaultHandlerAction
    end
    item
      Name = 'waTest'
      PathInfo = '/test'
      OnAction = WebModule1waTestAction
    end
    item
      MethodType = mtGet
      Name = 'waGetTasks'
      PathInfo = '/api/tasks'
      OnAction = WebModule1waGetTasksAction
    end
    item
      MethodType = mtPost
      Name = 'waCreateTask'
      PathInfo = '/api/tasks'
      OnAction = WebModule1waCreateTaskAction
    end
    item
      MethodType = mtGet
      Name = 'waGetHistoryAction'
      PathInfo = '/api/tasks/history'
      OnAction = WebModule1waGetHistoryActionAction
    end
    item
      MethodType = mtPost
      Name = 'waChangeStatusAction'
      PathInfo = '/api/tasks/status'
      OnAction = WebModule1waChangeStatusActionAction
    end
    item
      MethodType = mtGet
      Name = 'waGetUsersAction'
      PathInfo = '/api/users'
      OnAction = WebModule1waGetUsersActionAction
    end
    item
      MethodType = mtPost
      Name = 'waCreateUserAction'
      PathInfo = '/api/users'
      OnAction = WebModule1waCreateUserActionAction
    end
    item
      MethodType = mtGet
      Name = 'waGetUserByIdAction'
      PathInfo = '/api/users/details'
      OnAction = WebModule1waGetUserByIdActionAction
    end
    item
      MethodType = mtPut
      Name = 'waUpdateUserAction'
      PathInfo = '/api/users/update'
      OnAction = WebModule1waUpdateUserActionAction
    end
    item
      MethodType = mtDelete
      Name = 'waDeleteUserAction'
      PathInfo = '/api/users/delete'
      OnAction = WebModule1waDeleteUserActionAction
    end
    item
      MethodType = mtPost
      Name = 'waLoginAction'
      PathInfo = '/api/auth/login'
      OnAction = WebModule1waLoginActionAction
    end
    item
      MethodType = mtGet
      Name = 'waGetTaskByIdAction'
      PathInfo = '/api/tasks/details'
      OnAction = WebModule1waGetTaskByIdAction
    end
    item
      MethodType = mtGet
      Name = 'waGetMeAction'
      PathInfo = '/api/users/me'
      OnAction = WebModule1waGetMeActionAction
    end
    item
      MethodType = mtPut
      Name = 'waUpdateMeAction'
      PathInfo = '/api/users/me'
      OnAction = WebModule1waUpdateMeActionAction
    end
    item
      MethodType = mtPut
      Name = 'waUpdateTaskAction'
      PathInfo = '/api/tasks'
      OnAction = WebModule1waUpdateTaskActionAction
    end>
  Height = 230
  Width = 415
  object ADOConnection1: TADOConnection
    Connected = True
    ConnectionString = 
      'Provider=SQLOLEDB.1;Password=TaskPass123!;Persist Security Info=' +
      'True;User ID=taskuser;Initial Catalog=TaskManagerDB;Data Source=' +
      '.\SQLEXPRESS;Use Procedure for Prepare=1;Auto Translate=True;Pac' +
      'ket Size=4096;'
    ConnectionTimeout = 5
    LoginPrompt = False
    Provider = 'SQLOLEDB.1'
    Left = 64
    Top = 96
  end
  object ADOQueryTasks: TADOQuery
    Connection = ADOConnection1
    Parameters = <>
    SQL.Strings = (
      'SELECT * FROM Tasks')
    Left = 224
    Top = 96
  end
end
