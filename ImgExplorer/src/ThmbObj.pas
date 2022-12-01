unit ThmbObj;

interface

uses
  System.Classes, System.Types, Vcl.Graphics,
  SyncCntnrs;

type
  TThumbState = (tsNone, tsDeclared, tsLocked, tsRendered, tsPublished);
  TThumbStates = set of TThumbState;

  TThumbList = class
  private
    FThumbState: array of TThumbStates;                            // States of files images
    FSyncObj: TThreadObject;                                       // Synchronize object with list
    FFirstRawIndex: Integer;                                       //
    FFirstRenderIndex: Integer;
    FIsFull: Boolean;
    procedure SetFull(const Value: Boolean);
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddFiles(AList: TStringDynArray);                    // Add filenames to list
    procedure AddThumb(const AFileName: string; AThumb: TBitmap);  // Add image by filename
    function FetchFilePath(out AValue: string): Boolean;           // Get free filename
    function FetchFileThumb(out AIndex: Integer;
      var AImage: TBitmap): Boolean;                               // Get file image
    function ReadFilePath(out AValue: string): Boolean;            // Get filename
    property IsFull: Boolean read FIsFull write SetFull;           // Finish list extend sign
  end;

implementation

{ TThumbManager }

procedure TThumbList.AddFiles(AList: TStringDynArray);
var
  List: TStrings;
  i, j, k: Integer;
begin
  List := TStrings(FSyncObj.Lock);
  try
    i := List.Count;
    j := i + Length(AList);

    SetLength(FThumbState, j);
    k := 0;
    while i < j do begin
      List.Add(AList[k]);
      FThumbState[i] := [];
      Inc(i);
      Inc(k);
    end;
  finally
    FSyncObj.UnLock;
  end;
end;

procedure TThumbList.AddThumb(const AFileName: string; AThumb: TBitmap);
var
  List: TStrings;
  bmp: TBitmap;
  i: NativeInt;
begin
  List := TStrings(FSyncObj.Lock);
  try
    i := List.IndexOf(AFileName);
    if (i >= 0) and (List.Objects[i] = nil) then begin
      bmp := TBitmap.Create;
      bmp.Canvas.Lock;
      AThumb.Canvas.Lock;
      try
        bmp.Assign(AThumb);
        bmp.FreeImage;  // create copy instead reference
      finally
        AThumb.Canvas.Unlock;
        bmp.Canvas.Unlock;
      end;
      List.Objects[i] := bmp;
      Exclude(FThumbState[i], tsLocked);
      Include(FThumbState[i], tsRendered);
    end;
  finally
    FSyncObj.UnLock;
  end;
end;

constructor TThumbList.Create;
var
  List: TStringList;
begin
  List := TStringList.Create;
  List.OwnsObjects := True;
  List.Sorted := True;
  List.Duplicates := dupIgnore;

  FSyncObj := TThreadObject.Create(List, True, TCSSyncObject);
end;

destructor TThumbList.Destroy;
begin
  FSyncObj.Free;
  inherited;
end;

function TThumbList.FetchFilePath(out AValue: string): Boolean;
var
  i, j: NativeInt;
  List: TStrings;
begin
  Result := True;
  List := TStrings(FSyncObj.Lock);
  i := FFirstRawIndex;
  try
    j := List.Count;
    while (i < j) and not (FThumbState[i] * [tsLocked, tsRendered, tsPublished] = []) do begin
      Inc(i);
    end;
    if i < j then begin
      Include(FThumbState[i], tsLocked);
      AValue := List[i];
      while (FFirstRawIndex < j) and (tsLocked in FThumbState[FFirstRawIndex]) do begin
        Inc(FFirstRawIndex);
      end;
    end else begin
      AValue := '';
      Result := not (FIsFull and (FFirstRenderIndex >= j));
    end;
  finally
    FSyncObj.UnLock;
  end;
end;

function TThumbList.FetchFileThumb(out AIndex: Integer; var AImage: TBitmap): Boolean;
var
  CompleteThumb: TThumbStates;
  i, j: NativeInt;
  List: TStrings;
begin
  Result := True;
  List := TStrings(FSyncObj.Lock);
  CompleteThumb := [tsRendered, tsPublished];
  i := FFirstRenderIndex;
  try
    j := List.Count;
    while (i < j) and not ((tsRendered in FThumbState[i])
      and ([tsLocked,tsPublished] * FThumbState[i] = [])) do
    begin
      Inc(i);
    end;
    if i < j then begin
      Include(FThumbState[i], tsPublished);
      AIndex := i;
      AImage := TBitmap(List.Objects[i]);
      while (FFirstRenderIndex < j) and (FThumbState[FFirstRenderIndex] *
        CompleteThumb = CompleteThumb) do
      begin
        Inc(FFirstRenderIndex);
      end;
    end else begin
      AIndex := -1;
      AImage := nil;
      Result := not (FIsFull and (FFirstRenderIndex >= j));
    end;
  finally
    FSyncObj.UnLock;
  end;
end;

function TThumbList.ReadFilePath(out AValue: string): Boolean;
var
  i, j: NativeInt;
  List: TStrings;
begin
  Result := True;
  List := TStrings(FSyncObj.Lock);
  i := 0;
  try
    j := List.Count;
    while (i < j) and (tsDeclared in FThumbState[i]) do begin
      Inc(i);
    end;
    if (i < j) and not (tsDeclared in FThumbState[i]) then begin
      Include(FThumbState[i], tsDeclared);
      AValue := List[i];
    end else begin
      AValue := '';
      Result := not FIsFull;
    end;
  finally
    FSyncObj.UnLock;
  end;
end;

procedure TThumbList.SetFull(const Value: Boolean);
begin
  if not FIsFull and Value then begin
    FIsFull := Value;
  end;
end;

end.
