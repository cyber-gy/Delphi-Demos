unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  System.Generics.Collections,
  FileThreads, ShrdObj;

type
  TMainForm = class(TForm)
    LogMemo: TMemo;
    StartButton: TButton;
    StopButton: TButton;
    UpdateTimer: TTimer;
    GridPanel: TGridPanel;
    IDLabel: TLabel;
    CountLabel: TLabel;
    DateLabel: TLabel;
    InfoPanel: TPanel;
    SyncObjGroup: TRadioGroup;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure UpdateTimerTimer(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure StopButtonClick(Sender: TObject);
    procedure StartButtonClick(Sender: TObject);
  private
    FFile: TSharedThreadFileStream;        // разделяемый объект работы с файлом
    FThreads: TObjectList<TThread>;        // список потоков
    FQueue: TThreadedQueue<string>;        // очередь с данными из файла
    FSharedObject: TSharedThreadObject;    // разделяемый информационный объект
    procedure StopThreads;                 // остановка и удаление всех потоков
    procedure UpdateControls;
  public
    { Public declarations }
  end;

var
  MainForm: TMainForm;

implementation

{$R *.dfm}

uses
  System.SyncObjs;

procedure TMainForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  StopThreads;
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  FQueue := TThreadedQueue<string>.Create(10, 1000, 100);
  FThreads := TObjectList<TThread>.Create;
  FThreads.OwnsObjects := False;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  StopThreads;
  FThreads.Free;
  FQueue.Free;
end;

procedure TMainForm.StartButtonClick(Sender: TObject);
const
  MaxWriters = 2;   // кол-во пишущих в файл потоков
var
  i: NativeInt;
  Thrd: TThread;
begin
  case SyncObjGroup.ItemIndex of
    0: begin
      FSharedObject := TMonSharedThreadObject.Create;
      FFile := TMonSharedThreadFileStream.Create('OutputFile.txt',
        fmCreate or fmShareDenyNone);
    end
  else
    FSharedObject := TCSSharedThreadObject.Create;
    FFile := TCSSharedThreadFileStream.Create('OutputFile.txt',
      fmCreate or fmShareDenyNone);
  end;

  UpdateTimer.Enabled := True;
  UpdateControls;
  LogMemo.Clear;

  // создаём потоки-писатели
  i := 1;
  while i <= MaxWriters do begin
    Thrd := TFileWriterThread.Create(FFile, FSharedObject);
    FThreads.Add(Thrd);
    Inc(i);
  end;
  // поток, читающий из файла
  FThreads.Add(TFileReaderThread.Create(FFile, FQueue, FSharedObject));
end;

procedure TMainForm.StopButtonClick(Sender: TObject);
begin
  StopThreads;                                 // остановка потоков
  UpdateControls;                              // обновление интерфейса
end;

procedure TMainForm.StopThreads;
var
  Thrd: TThread;
begin
  UpdateTimer.Enabled := False;

  { уничтожение всех потоков }
  for Thrd in FThreads do begin
    Thrd.Terminate;
    Thrd.WaitFor;
    Thrd.Free;
  end;
  FThreads.Clear;
  FreeAndNil(FSharedObject);
  FreeAndNil(FFile);
end;

procedure TMainForm.UpdateControls;
begin
  StartButton.Enabled := not UpdateTimer.Enabled;
  SyncObjGroup.Enabled := StartButton.Enabled;
  StopButton.Enabled := UpdateTimer.Enabled;
end;

procedure TMainForm.UpdateTimerTimer(Sender: TObject);
var
  s: string;
  inf: TThreadInfo;
begin
  // обработка очереди данных из файла
  LogMemo.Lines.BeginUpdate;
  try
    while FQueue.PopItem(s) = TWaitResult.wrSignaled do begin
      LogMemo.Lines.Append(TrimRight(s));
    end;
  finally
    LogMemo.Lines.EndUpdate;
  end;

  // обновление информации из разделяемого общего объекта
  inf := FSharedObject.TryLock;
  if inf <> nil then begin
    try
      IDLabel.Caption := 'ID потока: ' + IntToStr(inf.ID);
      CountLabel.Caption := 'Кол-во операций: ' + IntToStr(inf.ExecCount);
      DateLabel.Caption := 'Послед. операция: ' + DateTimeToStr(inf.DateTime);
      InfoPanel.Update;
    finally
      FSharedObject.UnLock;
    end;
  end;
  // обработка событий GUI основной формы
  Application.HandleMessage;
end;
end.
