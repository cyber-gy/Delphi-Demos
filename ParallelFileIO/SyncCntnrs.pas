{*******************************************************}
{                                                       }
{       ������ ������� ����������� ���                  }
{       ������������� ������ ����� ��������.            }
{       ���������� �������� �������� ���.               }
{                                                       }
{       Copyright (C) 2022 Cyber-GY                     }
{                                                       }
{*******************************************************}

unit SyncCntnrs;

interface

uses
  System.SyncObjs;

type
                       (* �������-�������������� *)

  // ����������� ������-������� � ����������� ��� �������� �������������

  TSyncObject = class(TObject)
  public
    constructor Create; virtual; abstract;
    procedure Lock; virtual; abstract;
    function TryLock: Boolean; virtual; abstract;
    procedure UnLock; virtual; abstract;
  end;

  TSyncObjectClass = class of TSyncObject;

  // ������������� ����� ����������� ������

  TCSSyncObject = class(TSyncObject)
  private
    FLock: TCriticalSection;
  public
    constructor Create; override;
    destructor Destroy; override;
    procedure Lock; override;
    function TryLock: Boolean; override;
    procedure UnLock; override;
  end;

  // ������������� ����� TMonitor

  TMonSyncObject = class(TSyncObject)
  private
    FLock: TObject;
  public
    constructor Create; override;
    destructor Destroy; override;
    procedure Lock; override;
    function TryLock: Boolean; override;
    procedure UnLock; override;
  end;

                   (* ���������� �� ������ ����������
                       �������-��������������� *)

  // ���������������� ���������� ��� ���� �����������

  TThreadEntity = class (TObject)
  private
    FSyncObject: TSyncObject;                   // �������������
  protected
    procedure DoRelease; virtual; abstract;
    constructor Create(ASyncClass: TSyncObjectClass = nil);
  public
    destructor Destroy; override;
    procedure UnLock; virtual;
  end;

  // ���������������� ��������� ��� ������������ ����� �������� �������

  TThreadObject = class (TThreadEntity)
  private
    FObject: TObject;                           // ������ �������������
    FIsOwner: Boolean;
  protected
    procedure DoRelease; override;
  public
    constructor Create(AObject: TObject; AOwnObject: Boolean = False;
      ASyncClass: TSyncObjectClass = nil);
    function Lock: TObject;
    function TryLock: TObject;
  end;

  // ���������������� ��������� ��� ������������ ����� �������� ����������

  TThreadInterface = class (TThreadEntity)
  private
    FInterface: IUnknown;                       // ��������� �������������
  protected
    procedure DoRelease; override;
  public
    constructor Create(AInterface: IUnknown; ASyncClass: TSyncObjectClass = nil);
    function Lock: IUnknown;
    function TryLock: IUnknown;
  end;

  // ���������������� ��������� ��� ������������ ����� �������� ��������� �� ������

  TThreadMemory = class (TThreadEntity)
  private
    FMemory: Pointer;                           // ��������� �������������
  protected
    procedure DoRelease; override;
  public
    constructor Create(AMemory: Pointer; ASyncClass: TSyncObjectClass = nil);
    function Lock: Pointer;
    function TryLock: Pointer;
  end;

var
  CSWaitTimeout: Cardinal = 500;

implementation

uses
  System.Classes;

{ TCSSyncObject }

constructor TCSSyncObject.Create;
begin
  //inherited Create; //Abstract error raising
  FLock := TCriticalSection.Create;
end;

destructor TCSSyncObject.Destroy;
begin
  while FLock.WaitFor(CSWaitTimeout) = TWaitResult.wrTimeout do begin
    if TThread.Current.ThreadID = MainThreadID then begin
      CheckSynchronize; //?? only from main-thread created
    end else begin
      Break;
    end;
  end;
  FLock.Free;
  inherited Destroy;
end;

procedure TCSSyncObject.Lock;
begin
  FLock.Enter;
end;

function TCSSyncObject.TryLock: Boolean;
begin
  Result := FLock.TryEnter;
end;

procedure TCSSyncObject.UnLock;
begin
  FLock.Release;
end;

{ TMonSyncObject }

constructor TMonSyncObject.Create;
begin
  FLock := TObject.Create;
end;

destructor TMonSyncObject.Destroy;
begin
  TMonitor.PulseAll(FLock);
  FLock.Free;
  inherited Destroy;
end;

procedure TMonSyncObject.Lock;
begin
  TMonitor.Enter(FLock);
end;

function TMonSyncObject.TryLock: Boolean;
begin
  Result := TMonitor.TryEnter(FLock);
end;

procedure TMonSyncObject.UnLock;
begin
  TMonitor.Exit(FLock);
end;

{ TThreadEntity }

constructor TThreadEntity.Create(ASyncClass: TSyncObjectClass);
begin
  if ASyncClass <> nil then begin
    FSyncObject := ASyncClass.Create;
  end else begin
    FSyncObject := TCSSyncObject.Create;
  end;
end;

destructor TThreadEntity.Destroy;
begin
  FSyncObject.Free;
  DoRelease;
  inherited Destroy;
end;

procedure TThreadEntity.UnLock;
begin
  FSyncObject.UnLock;
end;

{ TThreadObject }

constructor TThreadObject.Create(AObject: TObject; AOwnObject: Boolean;
  ASyncClass: TSyncObjectClass);
begin
  inherited Create(ASyncClass);

  if AObject <> nil then begin
    FObject := AObject;
    FIsOwner := AOwnObject;
  end else begin
    FIsOwner := False;
  end;
end;

procedure TThreadObject.DoRelease;
begin
  if FIsOwner then begin
    FObject.Free
  end;
end;

function TThreadObject.Lock: TObject;
begin
  FSyncObject.Lock;
  Result := FObject;
end;

function TThreadObject.TryLock: TObject;
begin
  if FSyncObject.TryLock then begin
    Result := FObject
  end else begin
    Result := nil
  end;
end;

{ TThreadInterface }

constructor TThreadInterface.Create(AInterface: IInterface;
  ASyncClass: TSyncObjectClass);
begin
  inherited Create(ASyncClass);
  FInterface := AInterface;
end;

procedure TThreadInterface.DoRelease;
begin
  FInterface := nil;
end;

function TThreadInterface.Lock: IUnknown;
begin
  FSyncObject.Lock;
  Result := FInterface;
end;

function TThreadInterface.TryLock: IUnknown;
begin
  if FSyncObject.TryLock then begin
    Result := FInterface;
  end else begin
    Result := nil;
  end;
end;

{ TThreadMemory }

constructor TThreadMemory.Create(AMemory: Pointer; ASyncClass: TSyncObjectClass);
begin
  inherited Create(ASyncClass);
  FMemory := AMemory;
end;

procedure TThreadMemory.DoRelease;
begin
  FMemory := nil;
end;

function TThreadMemory.Lock: Pointer;
begin
  FSyncObject.Lock;
  Result := FMemory;
end;

function TThreadMemory.TryLock: Pointer;
begin
  if FSyncObject.TryLock then begin
    Result := FMemory;
  end else begin
    Result := nil;
  end;
end;

end.
