# Система управления задачами (Task Manager)

Веб-приложение для управления задачами и пользователями. Разработано в рамках учебной практики по направлению "Прикладная информатика" (профиль: ИИ и большие данные).

## Описание

MVP системы с базовым функционалом:
- Регистрация и авторизация пользователей
- CRUD операции с задачами (с назначением исполнителей)
- Управление пользователями
- REST API с JWT-токенами

## Технологический стек

**Backend:**
- Delphi 12 Community Edition
- WebBroker (ISAPI DLL)
- ADO (подключение к MS SQL Server)

**Frontend:**
- HTML5 + CSS3
- JavaScript (Fetch API)

**Сервер и БД:**
- MS IIS (Internet Information Services)
- MS SQL Server

## Системные требования

- Windows 10/11
- Delphi 12 Community Edition
- MS SQL Server 2016+
- IIS с поддержкой ISAPI

## Запуск

### 1. База данных

Выполните SQL-скрипт из папки `sql/`:

```sql
-- Выполните файл sql/01_init_database.sql в SQL Server Management Studio
```

### 2. Настройка подключения

Откройте `src/WebModuleUnit1.pas` и измените строку подключения:

```delphi
ConnectionString := 'Server=YOUR_SERVER;Database=TaskManager;UID=your_user;PWD=your_password;';
```

### 3. Компиляция

1. Откройте `src/TaskManager.dproj` в Delphi 12
2. Соберите проект (Build)
3. Получите `TaskManager.dll` в папке `src/Win32/Debug/`

### 4. Развертывание на IIS

1. Скопируйте `TaskManager.dll` в `C:\inetpub\wwwroot\TaskManager\`
2. В IIS Manager создайте Application Pool:
   - Name: `TaskManagerPool`
   - .NET CLR Version: No Managed Code
   - Managed Pipeline Mode: Classic
3. Создайте Virtual Directory:
   - Alias: `TaskManager`
   - Physical path: `C:\inetpub\wwwroot\TaskManager\`
4. Настройте права:
   - IIS_IUSRS: Read & Execute
   - IIS AppPool\TaskManagerPool: Read & Execute

## Структура проекта

```
├── src/                          # Исходный код Delphi
│   ├── TaskManager.dpr           # Главный файл проекта
│   ├── TaskManager.dproj         # Файл проекта
│   ├── TaskManager.res           # Ресурсы проекта
│   ├── WebModuleUnit1.pas        # WebBroker модуль (API endpoints)
│   ├── WebModuleUnit1.dfm        # Форма WebModule
│   ├── uAuthMiddleware.pas       # Middleware авторизации
│   ├── uAuthService.pas          # Сервис аутентификации
│   ├── uJWT.pas                  # Работа с JWT токенами
│   ├── uUserRepository.pas       # Репозиторий пользователей
│   ├── uTaskRepository.pas       # Репозиторий задач
│   └── Win32/Debug/              # Скомпилированная DLL
│
├── frontend/                     # HTML интерфейс
│   ├── login.html                # Страница входа
│   ├── create_user.html          # Регистрация
│   ├── tasks.html                # Список задач
│   ├── create_task.html          # Создание задачи
│   ├── edit_task.html            # Редактирование задачи
│   └── edit_user.html            # Редактирование пользователя
│
├── sql/                          # SQL скрипты
│   └── 01_init_database.sql      # Создание БД и таблиц
│
└── deploy/                       # Файлы для развертывания
    └── TaskManager.dll           # ISAPI DLL (после компиляции)
```

## API Endpoints

### Аутентификация

| Method | Endpoint | Описание |
|--------|----------|----------|
| POST | `/api/auth/login` | Вход в систему |

### Пользователи

| Method | Endpoint | Описание |
|--------|----------|----------|
| GET | `/api/users` | Получить список пользователей |
| GET | `/api/users/:id` | Получить пользователя по ID |
| GET | `/api/users/me` | Получить текущего пользователя |
| POST | `/api/users` | Создать пользователя (регистрация) |
| PUT | `/api/users/:id` | Обновить пользователя |
| PUT | `/api/users/me` | Обновить текущего пользователя |
| DELETE | `/api/users/:id` | Удалить пользователя |

### Задачи

| Method | Endpoint | Описание |
|--------|----------|----------|
| GET | `/api/tasks` | Получить список задач (с назначенными пользователями) |
| GET | `/api/tasks/:id` | Получить задачу по ID |
| POST | `/api/tasks` | Создать задачу (с назначением исполнителя) |
| PUT | `/api/tasks/:id` | Обновить задачу (название, описание, исполнитель) |
| PUT | `/api/tasks/status` | Изменить статус задачи |
| GET | `/api/tasks/history` | История изменений задач |

##  Безопасность

- Пароли хранятся в хешированном виде (SHA-256)
- JWT-токены для аутентификации
- Параметризованные SQL-запросы (защита от SQL Injection)

##  Скриншоты

[create_task.png](screenshots/create_task.png) - создание задачи

[create_user.png](screenshots/create_user.png) - регистрация

[delphi.png](screenshots/delphi.png) - экран среды разработки Delphi 12 Community

[edit_task.png](screenshots/edit_task.png) - редактирование/просмотр задачи

[iis.png](screenshots/iis.png) - экран IIS

[login.png](screenshots/login.png) - логин пользователя

[tasks.png](screenshots/tasks.png) - список задач

``

## Лицензия

MIT License - см. файл [LICENSE](LICENSE)

## Автор

Абдуллин Виталий Викторович  
Учебный проект, 2 курс, 4 семестр  
Направление: Прикладная информатика (ИИ и большие данные)
