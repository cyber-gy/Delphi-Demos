unit FileThrd;

interface

uses
  System.Classes, System.SyncObjs, Vcl.Graphics, ThmbObj;

const
  EVENT_TERMINATE_NAME = 'THREAD_TERMINATE'; // ��� �������

type
  // �����, �������������� �������� ������� ���������
  TListeningThread = class abstract(TThread)
  private
    FStopEvent: TEvent;               // ������� ������� ���������
  protected
    procedure CheckStop;              // ��������� �� �������
  public
    constructor Create(CreateSuspended: Boolean);
    destructor Destroy; override;
  end;

  // �����, ������� ���������� ��������� ������� ��������� ��� ����
  TManagingThread = class abstract(TListeningThread)
  protected
    procedure StopAll;                // �������� ����� ���������
  end;

  // ����� ������ ������ �� ���������� ����
  TDirBrowser = class(TListeningThread)
  private
    FList: TThumbList;                // ������ ������� ������
    FSrchPath: string;                // ���� � ������
    FSrchPattern: string;             // ����� ��� ������
    FIncFileCount: NativeInt;         // ������ ������ ������������ ��� ������
  protected
    procedure Execute; override;      // ����� � �������� ��� ������
  public
    constructor Create(const APath, APattern: string; AFileList: TThumbList;
      AIncFileCount: NativeInt);
  end;

  // ����� �������� ��. ��������� �� ������������ �����
  TFileRender = class(TListeningThread)
  private
    FList: TThumbList;                // ������ ������� ������
    FBmpThumb: TBitmap;               // ����. ��������� �����
  protected
    procedure LoadFromFile(const AFileName: string); // �������� � �������� ���������
    procedure Execute; override;      // �������� ��������� � ������ ����. �����
  public
    constructor Create(const AThumbHeight, AThumbWidth: Integer;
      AFileList: TThumbList);
    destructor Destroy; override;
  end;

implementation

uses
  System.SysUtils, System.IOUtils, System.Types,
  Winapi.Windows, // supress hint
  Vcl.Imaging.jpeg, Vcl.Imaging.pngimage;

{ TListeningThread }

constructor TListeningThread.Create(CreateSuspended: Boolean);
begin
  FStopEvent := TEvent.Create(nil, True, False, EVENT_TERMINATE_NAME);
  inherited Create(CreateSuspended);
end;

destructor TListeningThread.Destroy;
begin
  FStopEvent.Free;
  inherited Destroy;
end;

procedure TListeningThread.CheckStop;
begin
  // ��������� ����� ���������� �� �������� �������
  if FStopEvent.WaitFor(10) = wrSignaled then begin
    Terminate;
  end;
end;

{ TManagingThread }

procedure TManagingThread.StopAll;
begin
  if not (FStopEvent.WaitFor(10) = wrSignaled) then begin
    FStopEvent.SetEvent;
  end;
end;

{ DirBowser }

constructor TDirBrowser.Create(const APath, APattern: string;
  AFileList: TThumbList; AIncFileCount: NativeInt);
begin
  FSrchPath := APath;
  FSrchPattern := APattern;
  FList := AFileList;
  FIncFileCount := AIncFileCount;
  FreeOnTerminate := True;
  inherited Create(True);
  Priority := tpLower;
end;

procedure TDirBrowser.Execute;
var
  FileList: TStringDynArray;
  i, SendCount: NativeInt;
begin
  SetLength(FileList, FIncFileCount);
  i := 0; SendCount := 0;
  try
    FileList := TDirectory.GetFiles(FSrchPath, FSrchPattern,
      function (const Path: string; const SearchRec: TSearchRec): Boolean
      begin
        CheckStop;
        Result := not Terminated;
        if Result and (SearchRec.Attr and System.SysUtils.faDirectory = 0) then begin
          FileList[i] := TPath.Combine(Path, SearchRec.Name);
          // ���������� ���������� ��������
          if i = FIncFileCount - 1 then begin
            Inc(SendCount, i);
            i := 0;
            FList.AddFiles(FileList);
          end else begin
            Inc(i);
          end;
        end else begin
          Exit
        end;
      end
    );

    if not Terminated and (SendCount < High(FileList)) then begin
      FileList := Copy(FileList, SendCount, SendCount + i);
      FList.AddFiles(FileList);
    end;
  finally
    Finalize(FileList);
  end;
end;

{ TFileRender }

constructor TFileRender.Create(const AThumbHeight, AThumbWidth: Integer;
  AFileList: TThumbList);
begin
  FBmpThumb := Vcl.Graphics.TBitmap.Create;     // ���� ���������� ������� �����
  FBmpThumb.Height := AThumbHeight;
  FBmpThumb.Width := AThumbWidth;
  FList := AFileList;                           // ������ �� ������ ���������
  FreeOnTerminate := True;
  inherited Create(True);
  Priority := tpLower;
end;

destructor TFileRender.Destroy;
begin
  FBmpThumb.Free;
  inherited Destroy;
end;

procedure TFileRender.Execute;
var
  FileName: string;
  EndOfList: Boolean;
begin
  CheckStop;

  if not Terminated then begin
    EndOfList := not FList.FetchFilePath(FileName); // ��������� ����� ��� ���������
  end else begin
    EndOfList := True;
  end;

  while not (Terminated or EndOfList) do begin
    if FileName > '' then begin
      LoadFromFile(FileName);                       // �������� ����� �� ����������
                                                    // ��������� �����������
      if not FBmpThumb.Empty then begin
        FList.AddThumb(FileName, FBmpThumb);        // �������� ����������� �
      end;                                          // ��������� ������� ������
    end else begin
      Sleep(100);
    end;

    EndOfList := not FList.FetchFilePath(FileName);
    CheckStop;
  end;
end;

procedure TFileRender.LoadFromFile(const AFileName: string);
var
  f: Integer;
  i: Integer;
  x, y,
  h, w: NativeInt;
  src: Vcl.Graphics.TGraphic;
  srcCanvas: Vcl.Graphics.TCanvas;
begin
  // ������ ��������� �����
  f := FileOpen(AFileName, fmOpenRead);
  try
    if f > 0 then begin
      FileRead(f, i, 4);
    end;
  finally
    FileClose(f);
  end;

  // ����������� ������� ����� � ��������
  case i and $FFFF of
    $4D42: begin
      src := Vcl.Graphics.TBitmap.Create;
      src.LoadFromFile(AFileName);
      srcCanvas := Vcl.Graphics.TBitmap(src).Canvas;
    end;
    $D8FF: begin
      src := Vcl.Imaging.jpeg.TJPEGImage.Create;
      src.LoadFromFile(AFileName);
      srcCanvas := Vcl.Imaging.jpeg.TJPEGImage(src).Canvas;
    end;
  else
    if i = $474E5089 then begin
      src := Vcl.Imaging.PngImage.TPngImage.Create;
      src.LoadFromFile(AFileName);
      srcCanvas := Vcl.Imaging.PngImage.TPngImage(src).Canvas;
    end else begin
      src := nil;
      srcCanvas := nil;
    end;
  end;

  if src <> nil then begin
    // ���������� ������ ����������� �� ������ ���������
    if src.Width >= src.Height then begin
      w := FBmpThumb.Width;
      h := Round(FBmpThumb.Height * (src.Height / src.Width));
      x := 0; y := (FBmpThumb.Height - h) div 2;
    end else begin
      h := FBmpThumb.Height;
      w := Round(FBmpThumb.Width * (src.Width / src.Height));
      y := 0; x := (FBmpThumb.Width - w) div 2;
    end;
    // ��������� ������ (� � ���� � ������� ���������)
    // � ���� ������������ ������������� ������������ ���������������� �����������
    // �������, ��������, �� ���������� Graphics32 ��� ��������� ���� ��������
    // �� WinApi, ����� ������� VCL.
    // �� ��� �������� ����������������� ������� ����� ���������� �����
    // ����������� ������ �� ����� ������.
    srcCanvas.Lock;
    FBmpThumb.Canvas.Lock;
    try
      // ������� ����� �������� �����������
      if w >= h then begin
        FBmpThumb.Canvas.FillRect(System.Types.Rect(x, 0, w, y + 1));
        FBmpThumb.Canvas.FillRect(System.Types.Rect(x, y + h - 1, w, FBmpThumb.Height));
      end else begin
        FBmpThumb.Canvas.FillRect(System.Types.Rect(0, y, x + 1, h));
        FBmpThumb.Canvas.FillRect(System.Types.Rect(x + w - 1, 0, FBmpThumb.Width, h));
      end;
      // ��������� �����
      FBmpThumb.Canvas.StretchDraw(System.Types.Rect(x, y, x + w, y + h), src);
    finally
      FBmpThumb.Canvas.Unlock;
      srcCanvas.Unlock;
      src.Free;
    end;
  end;
end;

end.
