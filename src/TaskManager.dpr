library TaskManager;

uses
  Winapi.ActiveX,
  System.Win.ComObj,
  Web.WebBroker,
  Web.Win.ISAPIApp,
  Web.Win.ISAPIThreadPool,
  WebModuleUnit1 in 'WebModuleUnit1.pas' {WebModule1: TWebModule},
  uTaskRepository in 'uTaskRepository.pas',
  uUserRepository in 'uUserRepository.pas',
  uJWT in 'uJWT.pas',
  uAuthService in 'uAuthService.pas',
  uAuthMiddleware in 'uAuthMiddleware.pas';

{$R *.res}

exports
  GetExtensionVersion,
  HttpExtensionProc,
  TerminateExtension;

begin
  CoInitFlags := COINIT_MULTITHREADED;
  Application.Initialize;
  Application.WebModuleClass := WebModuleClass;
  Application.Run;
end.
