unit uJWT;

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.NetEncoding, System.Hash, System.DateUtils;

type
  TJWT = class
  private
    class function Base64UrlEncodeString(const AInput: string): string;
    class function Base64UrlEncodeBytes(const AInput: TBytes): string;
    class function Base64UrlDecode(const AInput: string): string;
  public
    class function CreateToken(const APayload: TJSONObject; const ASecret: string; AExpirationMinutes: Integer = 60): string;
    class function ValidateToken(const AToken: string; const ASecret: string): TJSONObject;
  end;

implementation

{ TJWT }

class function TJWT.Base64UrlEncodeString(const AInput: string): string;
var
  Bytes: TBytes;
begin
  // ѕравильно кодируем строку: сначала в байты (UTF-8), потом в Base64
  Bytes := TEncoding.UTF8.GetBytes(AInput);
  Result := TNetEncoding.Base64.EncodeBytesToString(Bytes);
  Result := StringReplace(Result, '+', '-', [rfReplaceAll]);
  Result := StringReplace(Result, '/', '_', [rfReplaceAll]);
  Result := StringReplace(Result, '=', '', [rfReplaceAll]);
end;

class function TJWT.Base64UrlEncodeBytes(const AInput: TBytes): string;
begin
  //  одируем сырые байты напр€мую в Base64
  Result := TNetEncoding.Base64.EncodeBytesToString(AInput);
  Result := StringReplace(Result, '+', '-', [rfReplaceAll]);
  Result := StringReplace(Result, '/', '_', [rfReplaceAll]);
  Result := StringReplace(Result, '=', '', [rfReplaceAll]);
end;

class function TJWT.Base64UrlDecode(const AInput: string): string;
var
  ModifiedInput: string;
begin
  ModifiedInput := AInput;
  ModifiedInput := StringReplace(ModifiedInput, '-', '+', [rfReplaceAll]);
  ModifiedInput := StringReplace(ModifiedInput, '_', '/', [rfReplaceAll]);

  case Length(ModifiedInput) mod 4 of
    2: ModifiedInput := ModifiedInput + '==';
    3: ModifiedInput := ModifiedInput + '=';
  end;

  Result := TNetEncoding.Base64.Decode(ModifiedInput);
end;

class function TJWT.CreateToken(const APayload: TJSONObject; const ASecret: string; AExpirationMinutes: Integer): string;
var
  Header, PayloadWithExp: TJSONObject;
  HeaderEncoded, PayloadEncoded, SignatureInput, Signature: string;
  SignatureBytes: TBytes;
  ExpirationTime: TDateTime;
begin
  Header := TJSONObject.Create;
  try
    Header.AddPair('alg', 'HS256');
    Header.AddPair('typ', 'JWT');
    HeaderEncoded := Base64UrlEncodeString(Header.ToJSON);
  finally
    Header.Free;
  end;

  PayloadWithExp := TJSONObject.ParseJSONValue(APayload.ToJSON) as TJSONObject;
  try
    ExpirationTime := IncMinute(Now, AExpirationMinutes);
    PayloadWithExp.AddPair('exp', TJSONNumber.Create(DateTimeToUnix(ExpirationTime)));
    PayloadEncoded := Base64UrlEncodeString(PayloadWithExp.ToJSON);
  finally
    PayloadWithExp.Free;
  end;

  SignatureInput := HeaderEncoded + '.' + PayloadEncoded;
  SignatureBytes := THashSHA2.GetHMACAsBytes(TEncoding.UTF8.GetBytes(SignatureInput), TEncoding.UTF8.GetBytes(ASecret));

  Signature := Base64UrlEncodeBytes(SignatureBytes);

  Result := SignatureInput + '.' + Signature;
end;

class function TJWT.ValidateToken(const AToken: string; const ASecret: string): TJSONObject;
var
  Parts: TArray<string>;
  HeaderEncoded, PayloadEncoded, SignatureReceived, SignatureExpected, SignatureInput: string;
  SignatureBytes: TBytes;
  PayloadStr: string;
  PayloadJSON: TJSONObject;
  Expiration: Int64;
begin
  Result := nil;

  Parts := AToken.Split(['.']);
  if Length(Parts) <> 3 then
    Exit;

  HeaderEncoded := Parts[0];
  PayloadEncoded := Parts[1];
  SignatureReceived := Parts[2];

  SignatureInput := HeaderEncoded + '.' + PayloadEncoded;
  SignatureBytes := THashSHA2.GetHMACAsBytes(TEncoding.UTF8.GetBytes(SignatureInput), TEncoding.UTF8.GetBytes(ASecret));

  SignatureExpected := Base64UrlEncodeBytes(SignatureBytes);

  if SignatureReceived <> SignatureExpected then
    Exit;

  PayloadStr := Base64UrlDecode(PayloadEncoded);
  PayloadJSON := TJSONObject.ParseJSONValue(PayloadStr) as TJSONObject;

  try
    if PayloadJSON.TryGetValue<Int64>('exp', Expiration) then
    begin
      if DateTimeToUnix(Now) > Expiration then
      begin
        PayloadJSON.Free;
        Exit;
      end;
    end;

    Result := PayloadJSON;
  except
    PayloadJSON.Free;
    Result := nil;
  end;
end;

end.
