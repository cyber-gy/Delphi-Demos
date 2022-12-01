unit FileThrd;

interface

uses
  System.Classes, System.SyncObjs, Vcl.Graphics, ThmbObj;

const
  EVENT_TERMINATE_NAME = 'THREAD_TERMINATE'; // имя события

type
  // поток, подконтрольный внешнему событию остановки
  TListeningThread = class abstract(TThread)
  private
    FStopEvent: TEvent;               // событие срочной остановки
  protected
    procedure CheckStop;              // остановка по событию
  public
    constructor Create(CreateSuspended: Boolean);
    destructor Destroy; override;
  end;

  // поток, имеющий полномочия создавать событие остановки для всех
  TManagingThread = class abstract(TListeningThread)
  protected
    procedure StopAll;                // поднятие флага остановки
  end;

  // поток поиска файлов по указанному пути
  TDirBrowser = class(TListeningThread)
  private
    FList: TThumbList;                // объект другого потока
    FSrchPath: string;                // путь к файлам
    FSrchPattern: string;             // маска имён файлов
    FIncFileCount: NativeInt;         // размер списка отправляемых имён файлов
  protected
    procedure Execute; override;      // поиск и отправка имён файлов
  public
    constructor Create(const APath, APattern: string; AFileList: TThumbList;
      AIncFileCount: NativeInt);
  end;

  // поток создания гр. миниатюры из прочитанного файла
  TFileRender = class(TListeningThread)
  private
    FList: TThumbList;                // объект другого потока
    FBmpThumb: TBitmap;               // граф. миниатюра файла
  protected
    procedure LoadFromFile(const AFileName: string); // загрузка и создание миниатюры
    procedure Execute; override;      // отправка миниатюры и запрос след. файла
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
  // Установка флага завершения по внешнему событию
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
          // отправляем результаты порциями
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
  FBmpThumb := Vcl.Graphics.TBitmap.Create;     // свой внутренний рабочий холст
  FBmpThumb.Height := AThumbHeight;
  FBmpThumb.Width := AThumbWidth;
  FList := AFileList;                           // ссылка на объект хранилища
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
    EndOfList := not FList.FetchFilePath(FileName); // получение файла для обработки
  end else begin
    EndOfList := True;
  end;

  while not (Terminated or EndOfList) do begin
    if FileName > '' then begin
      LoadFromFile(FileName);                       // загрузка файла на внутреннюю
                                                    // миниатюру изображения
      if not FBmpThumb.Empty then begin
        FList.AddThumb(FileName, FBmpThumb);        // передача изображения в
      end;                                          // хранилище другого потока
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
  // Чтение заголовка файла
  f := FileOpen(AFileName, fmOpenRead);
  try
    if f > 0 then begin
      FileRead(f, i, 4);
    end;
  finally
    FileClose(f);
  end;

  // Определение формата файла и загрузка
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
    // Координаты нового изображения на холсте миниатюры
    if src.Width >= src.Height then begin
      w := FBmpThumb.Width;
      h := Round(FBmpThumb.Height * (src.Height / src.Width));
      x := 0; y := (FBmpThumb.Height - h) div 2;
    end else begin
      h := FBmpThumb.Height;
      w := Round(FBmpThumb.Width * (src.Width / src.Height));
      y := 0; x := (FBmpThumb.Width - w) div 2;
    end;
    // Блокируем холсты (а с ними и объекты рисования)
    // В сети настоятельно рекомендуется использовать потокобезопасные графические
    // объекты, например, из библиотеки Graphics32 или создавать свои напрямую
    // из WinApi, минуя объекты VCL.
    // Но для простоты демонстрационного проекта будет достаточно чётко
    // блокировать холсты на время работы.
    srcCanvas.Lock;
    FBmpThumb.Canvas.Lock;
    try
      // очистим места прежнего изображения
      if w >= h then begin
        FBmpThumb.Canvas.FillRect(System.Types.Rect(x, 0, w, y + 1));
        FBmpThumb.Canvas.FillRect(System.Types.Rect(x, y + h - 1, w, FBmpThumb.Height));
      end else begin
        FBmpThumb.Canvas.FillRect(System.Types.Rect(0, y, x + 1, h));
        FBmpThumb.Canvas.FillRect(System.Types.Rect(x + w - 1, 0, FBmpThumb.Width, h));
      end;
      // скопируем новое
      FBmpThumb.Canvas.StretchDraw(System.Types.Rect(x, y, x + w, y + h), src);
    finally
      FBmpThumb.Canvas.Unlock;
      srcCanvas.Unlock;
      src.Free;
    end;
  end;
end;

end.
