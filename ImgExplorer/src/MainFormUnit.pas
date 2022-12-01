unit MainFormUnit;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ComCtrls, System.ImageList,
  Vcl.ImgList, Vcl.ExtCtrls, Vcl.StdCtrls, Vcl.Samples.Spin, System.Actions,
  Vcl.ActnList, Vcl.StdActns,
  MngThrd;

type
  TMainForm = class(TForm)
    BrowsePathEdit: TLabeledEdit;
    MainPanel: TPanel;
    MainSplitter: TSplitter;
    ImageThumbs: TImageList;
    ThumbList: TListView;
    SearchButton: TButton;
    StopButton: TButton;
    ThrdCountEdit: TSpinEdit;
    ThreadCountLabel: TLabel;
    Button1: TButton;
    ActionList1: TActionList;
    BrowseForFolderAction: TBrowseForFolder;
    procedure SearchButtonClick(Sender: TObject);
    procedure StopButtonClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure BrowseForFolderActionAccept(Sender: TObject);
  private
    FDefaultThumb: TBitmap;                        // картинка эскиза по-умолчанию
    FImgThread: TThread;                           // поток обработки эскизов
    FStopThreads: TThreadEvent;                    // флаг остановки потоков
    procedure ThreadTerminated(Sender: TObject);
  public
    procedure RefreshControls;                     // обновление интерфейса
  end;

var
  MainForm: TMainForm;

implementation

{$R *.dfm}

procedure TMainForm.StopButtonClick(Sender: TObject);
begin
  if (FImgThread <> nil) and not FStopThreads.Enabled then begin
    FStopThreads.Enabled := True;
  end;
end;

procedure TMainForm.ThreadTerminated(Sender: TObject);
begin
  FImgThread := nil;
  RefreshControls;
end;

procedure TMainForm.BrowseForFolderActionAccept(Sender: TObject);
begin
  if Sender is TBrowseForFolder then begin
    BrowsePathEdit.Text := TBrowseForFolder(Sender).Folder;
  end;
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  FDefaultThumb := TBitmap.Create;
  ImageThumbs.GetBitmap(0, FDefaultThumb);
  FStopThreads := TThreadEvent.Create;
  RefreshControls;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FStopThreads.Free;
  FDefaultThumb.Free;
end;

procedure TMainForm.RefreshControls;
begin
  SearchButton.Enabled := FImgThread = nil;
  ThrdCountEdit.Enabled := SearchButton.Enabled;
  BrowseForFolderAction.Enabled := SearchButton.Enabled;
  StopButton.Enabled := not SearchButton.Enabled;
  BrowsePathEdit.Enabled := SearchButton.Enabled;
end;

procedure TMainForm.SearchButtonClick(Sender: TObject);
var
  i: Nativeint;
begin
  // очистка данных
  ThumbList.Items.Clear;
  i := ImageThumbs.Count - 1;
  while i > 0 do begin
    ImageThumbs.Delete(i);
    Dec(i);
  end;
  // сброс флага остановки
  if FStopThreads.Enabled then begin
    FStopThreads.Enabled := False;
  end;
  // запускаем управл€ющий поток поиска файлов и обработки эскизов
  FImgThread := TThumbManager.Create(BrowsePathEdit.Text, FDefaultThumb,
    ImageThumbs, ThumbList.Items, ThrdCountEdit.Value);
  FImgThread.OnTerminate := ThreadTerminated;
  // обновл€ем интерфейс
  RefreshControls;
end;

end.
