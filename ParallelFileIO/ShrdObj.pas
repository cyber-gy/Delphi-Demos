{*******************************************************}
{                                                       }
{       Модуль простых потокобезопасных объектов        }
{                                                       }
{       Copyright (C) 2022 Cyber-GY                     }
{                                                       }
{*******************************************************}
unit ShrdObj;

interface

uses
  System.Classes,
  SyncCntnrs;

const
  MaxInt64 = 9223372036854775807;

type
  { Информация о работе потока }

  TThreadInfo = class(TObject)
  private
    FExecCount: Integer;                        // количество операций
    FID: Integer;                               // идентификатор потока
    FDateTime: TDateTime;                       // последнее время записи в файл
  public
    property ExecCount: Integer read FExecCount write FExecCount;
    property DateTime: TDateTime read FDateTime write FDateTime;
    property ID: Integer read FID write FID;
  end;

  { Разделяемый между потоками общий объект }
  { Содержит информацию о потоке, выполнившем последнюю операцию }

  TSharedThreadObject = class abstract (TObject)
  private
    FSyncObject: TThreadObject;                   // объект-синхронизатор
    FInfo: TThreadInfo;                           // информационный объект
  public
    constructor Create(ASyncClass: TSyncObjectClass = nil);
    destructor Destroy; override;
    function Lock: TThreadInfo;
    function TryLock: TThreadInfo;
    procedure UnLock;
  end;

  TCSSharedThreadObject = class(TSharedThreadObject)
  public
    constructor Create;
  end;

  TMonSharedThreadObject = class(TSharedThreadObject)
  public
    constructor Create;
  end;

  { Класс, реализующий общий для потоков доступ к файлу }
  { Интегрирует в себе объекты синхронизации и работы с файлом }

  TSharedThreadFileStream = class(TObject)
  private
    FSyncObject: TSyncObject;                   // объект синхронизации
    FStream: TFileStream;                       // файловый поток
    function GetPos: Int64;
    function GetSize: Int64;
    procedure SetPos(const Value: Int64);
  public
    constructor Create(const AFilename: string; AMode: Word); virtual;
    destructor Destroy; override;
    procedure Lock;
    function ReadString(AMaxLen: Int64 = MaxInt64): string;
    function TryLock: Boolean;
    procedure UnLock;
    procedure WriteString(const AValue: string);
    property Pos: Int64 read GetPos write SetPos;
    property Size: Int64 read GetSize;
  end;

  TCSSharedThreadFileStream = class(TSharedThreadFileStream)
  public
    constructor Create(const AFilename: string; AMode: Word); override;
  end;

  TMonSharedThreadFileStream = class(TSharedThreadFileStream)
  public
    constructor Create(const AFilename: string; AMode: Word); override;
  end;

implementation

uses
  System.SysUtils;

{ TSharedThreadObject }

constructor TSharedThreadObject.Create(ASyncClass: TSyncObjectClass);
begin
  FInfo := TThreadInfo.Create;
  if ASyncClass <> nil then begin
    FSyncObject := TThreadObject.Create(FInfo, False, ASyncClass);
  end else begin
    FSyncObject := TThreadObject.Create(FInfo, False, TCSSyncObject);
  end;
end;

destructor TSharedThreadObject.Destroy;
begin
  FSyncObject.Free;
  FInfo.Free;
  inherited Destroy;
end;

function TSharedThreadObject.Lock: TThreadInfo;
begin
  Result := TThreadInfo(FSyncObject.Lock);
end;

function TSharedThreadObject.TryLock: TThreadInfo;
begin
  Result := TThreadInfo(FSyncObject.TryLock);
end;

procedure TSharedThreadObject.UnLock;
begin
  FSyncObject.UnLock;
end;

{ TCSSharedThreadObject }

constructor TCSSharedThreadObject.Create;
begin
  inherited Create(TCSSyncObject);
end;

{ TMonSharedThreadObject }

constructor TMonSharedThreadObject.Create;
begin
  inherited Create(TMonSyncObject);
end;

{ TSharedThreadFileStream }

constructor TSharedThreadFileStream.Create(const AFilename: string;
  AMode: Word);
begin
  inherited Create;
  FStream := TFileStream.Create(AFilename, AMode);
end;

destructor TSharedThreadFileStream.Destroy;
begin
  FSyncObject.Free;
  FStream.Free;
  inherited Destroy;
end;

function TSharedThreadFileStream.GetPos: Int64;
begin
  Result := FStream.Position
end;

function TSharedThreadFileStream.GetSize: Int64;
begin
  Result := FStream.Size
end;

procedure TSharedThreadFileStream.Lock;
begin
  FSyncObject.Lock;
end;

function TSharedThreadFileStream.ReadString(AMaxLen: Int64): string;
var
  Buf: TBytes;
  Len: Int64;
begin
  Len := FStream.Size - FStream.Position;
  if AMaxLen >= Len then begin
    SetLength(Buf, Len);
    FStream.Read64(Buf, 0, Len);
  end else begin
    SetLength(Buf, AMaxLen);
    FStream.Read64(Buf, 0, AMaxLen);
  end;
  Result := StringOf(Buf);
end;

procedure TSharedThreadFileStream.SetPos(const Value: Int64);
begin
  if Value = FStream.Size then begin
    FStream.Seek(0, soFromEnd);
  end else begin
    FStream.Position := Value
  end;
end;

function TSharedThreadFileStream.TryLock: Boolean;
begin
  Result := FSyncObject.TryLock;
end;

procedure TSharedThreadFileStream.UnLock;
begin
  FSyncObject.UnLock;
end;

procedure TSharedThreadFileStream.WriteString(const AValue: string);
begin
  FStream.WriteData(BytesOf(AValue), Length(AValue));
end;

{ TCSSharedThreadFileStream }

constructor TCSSharedThreadFileStream.Create(const AFilename: string; AMode: Word);
begin
  inherited Create(AFilename, AMode);
  FSyncObject := TCSSyncObject.Create;
end;

{ TMonSharedThreadFileStream }

constructor TMonSharedThreadFileStream.Create(const AFilename: string; AMode: Word);
begin
  inherited Create(AFilename, AMode);
  FSyncObject := TMonSyncObject.Create;
end;

end.
