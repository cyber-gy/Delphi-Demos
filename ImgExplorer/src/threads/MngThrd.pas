unit MngThrd;

interface

uses
  System.Classes, System.Generics.Collections, System.SyncObjs,
  Vcl.Controls, Vcl.ComCtrls, Vcl.Graphics,
  ThmbObj, FileThrd;

type
  // адаптер для модуля основного потока
  TThreadEvent = class(TObject)
  private
    FEvent: TEvent;
    function GetEnabled: Boolean;
    procedure SetEnabled(const Value: Boolean);
  public
    constructor Create;
    destructor Destroy; override;
    property Enabled: Boolean read GetEnabled write SetEnabled;
  end;

  // данные по миниатюрам
  TThumbData = record
    index: Integer;
    image: TBitmap;
  end;

  // поток, управляющий всем сбором данных
  TThumbManager = class(TManagingThread)
  private
    FList: TThumbList;                                // полученные данные о файлах
    FDefThumb: TBitmap;                               // объект осн. потока
    FImgList: TImageList;                             // компонент VCL
    FViewItems: TListItems;                           // компонент VCL
    FImgQueue: TThreadedQueue<TThumbData>;            // очередь отправки снимков
    FStrQueue: TThreadedQueue<string>;                // очередь отправки имён файлов

    FSearcher: TDirBrowser;                           // поток поиска файлов
    FRenders: TList;                                  // список потоков, читающих файлы

    FRendersSection: TCriticalSection;                // секция синхронизации списка потоков
    FSendStrSection,                                  // секции синхронизации
    FSendImgSection: TCriticalSection;                // потоков отправки данных

    procedure SearcherFinish(Sender: TObject);        // завершение поиска файлов
    procedure RenderFinish(Sender: TObject);          // завершение создания миниатюр
  protected
    procedure SendFilename;                           // отправка имён файлов
    procedure SendThumb;                              // отправка снимков файлов
    procedure StopChildThreads;                       // завершение дочерних потоков
    procedure Execute; override;
  public
    constructor Create(const AFilePath: string; ADefaultImage: TBitmap;
      AImages: TImageList; AViewItems: TListItems; ARenderCount: NativeInt);
    destructor Destroy; override;
  end;

implementation

uses
  System.Types, System.SysUtils, SyncCntnrs;

{ TThreadEvent }

constructor TThreadEvent.Create;
begin
  FEvent := TEvent.Create(nil, True, False, EVENT_TERMINATE_NAME);
end;

destructor TThreadEvent.Destroy;
begin
  FEvent.Free;
  inherited Destroy;
end;

function TThreadEvent.GetEnabled: Boolean;
begin
  Result := FEvent.WaitFor(10) = wrSignaled;
end;

procedure TThreadEvent.SetEnabled(const Value: Boolean);
begin
  if Value then begin
    FEvent.SetEvent;
  end else begin
    FEvent.ResetEvent;
  end;
end;

{ TThumbManager }

constructor TThumbManager.Create(const AFilePath: string; ADefaultImage: TBitmap;
  AImages: TImageList; AViewItems: TListItems; ARenderCount: NativeInt);
const
  MaxRenderCount = 10;
var
  t: TThread;
  i: NativeInt;
begin
  // Список с данными обработки файлов
  FList := TThumbList.Create;

  // Очереди по отправке данных файлов
  FImgQueue := TThreadedQueue<TThumbData>.Create(20, 100, 100);
  FStrQueue := TThreadedQueue<string>.Create(20, 100, 100);

  // Критическая секция работы со списком потоков
  FRendersSection := TCriticalSection.Create;

  // Критические секции для отправки данных
  FSendStrSection := TCriticalSection.Create;
  FSendImgSection := TCriticalSection.Create;

  // Объекты основного потока
  FDefThumb := ADefaultImage;
  FImgList := AImages;
  FViewItems := AViewItems;

  // Создание потока поиска файлов
  FSearcher := TDirBrowser.Create(AFilePath,
    //'\.(bmp|jpg|jpeg|png)$', FList, 10);
    '*.jpg', FList, 10);
  FSearcher.OnTerminate := SearcherFinish;

  // Текущий поток
  FreeOnTerminate := True;
  inherited Create(False);
  Priority := tpLower;

  // Запуск поиска файлов
  FSearcher.Start;

  // Разумно ограничиванием число потоков
  if ARenderCount > MaxRenderCount then begin
    ARenderCount := MaxRenderCount;
  end;
  // Создание и запуск формирования миниатюр
  FRenders := TList.Create;
  i := 0;
  while i < ARenderCount do begin
    t := TFileRender.Create(FImgList.Height, FImgList.Width, FList);
    t.OnTerminate := RenderFinish;
    // если первые потоки уже завершились и начали удалять себя из списка
    FRendersSection.Enter;
    try
      FRenders.Add(t);
    finally
      FRendersSection.Leave;
    end;
    t.Start;
    Inc(i);
  end;
end;

destructor TThumbManager.Destroy;
begin
  StopChildThreads;
  FRenders.Free;
  FList.Free;
  FStrQueue.Free;
  FImgQueue.Free;
  FSendStrSection.Free;
  FSendImgSection.Free;
  FRendersSection.Free;
  inherited Destroy;
end;

procedure TThumbManager.Execute;
var
  s: string;
  td: TThumbData;
  wr: System.Types.TWaitResult;
  eol: Boolean;                 // end of list
  NoValueCount: NativeInt;
begin
  NoValueCount := 0;
  repeat
    // отдаём найденные имена файлов в основной поток
    repeat
      eol := not FList.ReadFilePath(s);
      wr := wrTimeout;
      if s > '' then begin
        while not eol and (wr = wrTimeOut) do begin
          wr := FStrQueue.PushItem(s);
          case wr of
            wrSignaled: SendFilename;
            wrTimeout: Sleep(10);
          else
            // write log
            Terminate;
          end;
        end;
      end else begin
        Inc(NoValueCount);
      end;

      CheckStop;
    until Terminated or (s = '') or eol;

    // отдаём готовые миниатюры в основной поток
    repeat
      eol := not FList.FetchFileThumb(td.index, td.image);
      wr := wrTimeout;
      if td.index >= 0 then begin
        while not eol and (wr = wrTimeout) do begin
          wr := FImgQueue.PushItem(td);
          case wr of
            wrSignaled: SendThumb;
            wrTimeout: Sleep(100);
          else
            // write log
            Terminate;
          end;
        end;
      end else begin
        Inc(NoValueCount);
      end;

      // если много пустых проходов, передадим инициативу
      if NoValueCount > 10 then begin
        NoValueCount := 0;
        Sleep(100);
      end;

      CheckStop;
    until Terminated or (td.index < 0);
  until Terminated or eol;

  StopChildThreads;
end;

procedure TThumbManager.RenderFinish(Sender: TObject);
begin
  FRendersSection.Enter;
  try
    FRenders.Remove(Sender)
  finally
    FRendersSection.Leave;
  end;
end;

procedure TThumbManager.SearcherFinish(Sender: TObject);
begin
  FSearcher := nil;
  FList.IsFull := True;
end;

procedure TThumbManager.SendFilename;
var
  s: string;
begin
  // Ставим в очередь отправку имени файла
  Queue(procedure begin
    if (FStrQueue.PopItem(s) = wrSignaled) and (s > '') then begin
      { В текущей реализации файлы ищет и добавляет только один поток. }
      { Но для формальной правильности и с расчётом на будущее, используем секцию. }
      FSendStrSection.Enter;
      FImgList.BeginUpdate;
      try
        with FViewItems.Add do begin
          Caption := ExtractFileName(s);
          ImageIndex := FImgList.Add(FDefThumb, nil);
        end;
      finally
        FImgList.EndUpdate;
        FSendStrSection.Leave;
      end;
    end;
  end)
end;

procedure TThumbManager.SendThumb;
var
  td: TThumbData;
begin
  // Ставим в очередь отправку миниатюры
  Queue(procedure begin
    if (FImgQueue.PopItem(td) = wrSignaled) and (td.index >= 0) then begin
      FSendImgSection.Enter;
      FImgList.BeginUpdate;
      td.image.Canvas.Lock;
      try
        FImgList.Replace(td.index + 1, td.image, nil);
      finally
        td.image.Canvas.Unlock;
        FImgList.EndUpdate;
        FSendImgSection.Leave;
      end;
      FViewItems[td.index].ImageIndex := td.index + 1;
    end;
  end);
end;

procedure TThumbManager.StopChildThreads;
begin
  // сигнал принудительной остановки
  StopAll;

  while FSearcher <> nil do begin
    Sleep(100);
  end;

  while FRenders.Count > 0 do begin
    Sleep(100);
  end;
  FRenders.Clear;
end;

end.
