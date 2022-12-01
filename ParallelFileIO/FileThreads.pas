unit FileThreads;

interface

uses
  System.Classes, System.SyncObjs, System.Generics.Collections, System.SysUtils,
  ShrdObj;

type
  { Общий класс для потомков, работающих с файлом }

  TFileThread = class abstract(TThread)
  private
    FSharedObject: TSharedThreadObject;
    FSharedStream: TSharedThreadFileStream;
    FExecCount: UInt64;
  protected
    procedure Execute; override;
  end;

  { Класс пишущих в файл потоков }

  TFileWriterThread = class(TFileThread)
  protected
    procedure Execute; override;
  public
    constructor Create(AStream: TSharedThreadFileStream; AObject: TSharedThreadObject);
  end;

  { Класс читающего файл потока }

  TFileReaderThread = class(TFileThread)
  private
    FPos: UInt64;
    FQueue: TThreadedQueue<string>;
  protected
    procedure Execute; override;
  public
    constructor Create(AStream: TSharedThreadFileStream; AQueue: TThreadedQueue<string>;
      AObject: TSharedThreadObject);
  end;

implementation

{ TFileThread }

procedure TFileThread.Execute;
begin
  inherited;

  with FSharedObject.Lock as TThreadInfo do begin
    try
      ID := TThread.CurrentThread.ThreadID;
      ExecCount := FExecCount;
      DateTime := Now;
    finally
      FSharedObject.Unlock;
    end;
  end;
end;

{ TFileReaderThread }

constructor TFileReaderThread.Create(AStream: TSharedThreadFileStream;
  AQueue: TThreadedQueue<string>; AObject: TSharedThreadObject);
begin
  FSharedStream := AStream;
  FSharedObject := AObject;
  FQueue := AQueue;
  //FreeOnTerminate := True;
  inherited Create(False);
end;

procedure TFileReaderThread.Execute;
var
  s: string;
  ActualSize: NativeInt;
begin
  while not Terminated do begin
    TThread.Sleep(200);
    FSharedStream.Lock;                          //lock the shared object
    try
      if FPos < FSharedStream.Size then begin
        FSharedStream.Pos := FPos;               // actualize cursor position
        s := FSharedStream.ReadString;
        ActualSize := Length(s);
        Inc(FPos, ActualSize);                   // store position for next time
        Inc(FExecCount);
        FQueue.PushItem(string(s));
      end else begin
        ActualSize := 0;
      end;
    finally
      FSharedStream.UnLock;                      //unlock the shared object
    end;

    if ActualSize > 0 then begin
      inherited Execute;
    end;
  end;
end;

{ TFileWriterThread }

constructor TFileWriterThread.Create(AStream: TSharedThreadFileStream;
  AObject: TSharedThreadObject);
begin
  FSharedStream := AStream;
  FSharedObject := AObject;
  //FreeOnTerminate := True;
  inherited Create(False);
end;

procedure TFileWriterThread.Execute;
var
  s: string;
begin
  while not Terminated do begin
    TThread.Sleep(800);
    s := Format('THREAD %5d - %s', [TThread.CurrentThread.ThreadID, DatetimeToStr(Now)+#13#10]);
    FSharedStream.Lock;                           //lock the shared object
    try
      FSharedStream.Pos := FSharedStream.Size;    // actualize cursor position
      FSharedStream.WriteString(s);
    finally
      FSharedStream.UnLock;                       //unlock the shared object
    end;
    Inc(FExecCount);

    inherited Execute;
  end;
end;

end.
