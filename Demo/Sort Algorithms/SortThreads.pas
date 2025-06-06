unit SortThreads;

interface

uses
  Classes, Graphics, ExtCtrls, Types, Diagnostics,
  PaintArray, ZenLogger;

type

{ TSortThread }

  TSortThread = class(TThread)
  private
    fArray   : TPaintArray;
    fLogger  : ILogger;
    fSkipGUI : Boolean;
    fA, fB, fI, fJ: Integer;
    fStopwatch : TStopwatch;
    procedure DoVisualSwap;
    procedure DoUpdate;
  protected
    procedure Execute; override;
    procedure ArraySwap(var aArray: TIntegerDynArray; I, J: Integer);
    procedure Swap(I, J: Integer);
    procedure Update(A, I: Integer);
    procedure VisualSwap(A, B, I, J: Integer);
    procedure Sort(var aArray: TIntegerDynArray); virtual; abstract;
    function  DebugArrayAsStr(aArray: TIntegerDynArray; aLo, aHi: Integer): String;

    procedure SelectSort(var aArray: TIntegerDynArray; aLo, aHi: Integer);
  public
    constructor Create(const aPaintArray: TPaintArray; aLogger : ILogger; aOnDone: TNotifyEvent);
    function SortTime: Integer;
  end;

{ TBubbleSort }

  TBubbleSort = class(TSortThread)
  protected
    procedure Sort(var aArray: TIntegerDynArray); override;
  end;

{ TQuickSort }

  TQuickSort = class(TSortThread)
  protected
    procedure QuickSort(var aArray: TIntegerDynArray; iLo, iHi: Integer);
    procedure Sort(var aArray: TIntegerDynArray); override;
  end;

{ TSelectionSort }

  TSelectionSort = class(TSortThread)
  protected
    procedure Sort(var aArray: TIntegerDynArray); override;
  end;

{ TInsertionSort }

  TInsertionSort = class(TSortThread)
  protected
    procedure InsertSort(var aSource: TIntegerDynArray; aLo, aHi: Integer);
    procedure Sort(var aArray: TIntegerDynArray); override;
  end;

{ TMergeSort }

  TMergeSort = class(TSortThread)
  protected
    procedure MergeBack(var aSource, aCopy: TIntegerDynArray; aLo, aMid, aHi: Integer);
    procedure MergePartition(var aSource, aCopy: TIntegerDynArray; aLo, aHi: Integer);
    procedure Sort(var aArray: TIntegerDynArray); override;
  end;


//Bad idea to use global variables from thread! This is only used in constructor to skip adding new param...
var
  Prevent_GUI_Updates : Boolean;

implementation

uses
  SysUtils, Threading;

const
  MERGE_SWAP_THRESHOLD = 5;

{ TSortThread }

constructor TSortThread.Create(const aPaintArray: TPaintArray; aLogger : ILogger; aOnDone: TNotifyEvent);
begin
  inherited Create(False);
  fLogger  := aLogger;
  fArray   := aPaintArray;
  fSkipGUI := Prevent_GUI_Updates;
  FreeOnTerminate := True;
  OnTerminate     := aOnDone;
end;

{ Since DoVisualSwap uses a VCL component (i.e., the TPaintBox) it should never
  be called directly by this thread.  DoVisualSwap should be called by passing
  it to the Synchronize method which causes DoVisualSwap to be executed by the
  main VCL thread, avoiding multi-thread conflicts. See VisualSwap for an
  example of calling Synchronize. }

procedure TSortThread.DoVisualSwap;
begin
  fArray.PaintSwap(fI, fJ, fA, fB);
end;

function TSortThread.DebugArrayAsStr(aArray: TIntegerDynArray; aLo, aHi: Integer): String;
var
  i : Integer;
begin
  Result := '[';
  for i := aLo to aHi do
    Result := Result + IntToStr(aArray[i]) + ', ';
  Result[Length(Result) -1] := ']';  //replace last comma with closing bracket.
end;

procedure TSortThread.DoUpdate;
begin
  fArray.ClearLine(fI);
  fArray.PaintLine(fI, fA);
end;

{ VisusalSwap is a wrapper on DoVisualSwap making it easier to use.  The
  parameters are copied to instance variables so they are accessable
  by the main VCL thread when it executes DoVisualSwap }

procedure TSortThread.VisualSwap(A, B, I, J: Integer);
begin
  if fSkipGUI then
    Exit;
  fA := A;
  fB := B;
  fI := I;
  fJ := J;
  Synchronize(DoVisualSwap);
end;

procedure TSortThread.Update(A, I: Integer);
begin
  if fSkipGUI then
    Exit;
  fA := A;
  fI := I;
  Synchronize(DoUpdate);
end;

{ The Execute method is called when the thread starts }

procedure TSortThread.Execute;
begin
  var Log := GetTraceLogger(ClassName, 'Execute', fLogger).Trace;
  fStopwatch := TStopwatch.StartNew;
  Sort(fArray.DataArray);
  fStopwatch.Stop;
  fLogger.Flush;
end;

function TSortThread.SortTime: Integer;
begin
  Result := fStopwatch.ElapsedMilliseconds;
end;

procedure TSortThread.ArraySwap(var aArray: TIntegerDynArray; I, J: Integer);
var
  Dummy: Integer;
begin
  var Log := GetTraceLogger(ClassName, 'ArraySwap', fLogger).Trace;
  Log.Debug('Swapping %d, %d', [I, J]);
  Dummy     := aArray[I];
  aArray[I] := aArray[J];
  aArray[J] := Dummy;
end;

procedure TSortThread.Swap(I, J: Integer);
begin
  VisualSwap(fArray[I], fArray[J], I, J);
  ArraySwap(fArray.DataArray, I, J);
end;

procedure TSortThread.SelectSort(var aArray: TIntegerDynArray; aLo, aHi: Integer);
var
  I, J, K: Integer;
begin
  for I := aLo to aHi -1 do begin
    //"Small" optimisation vs Buble sort: find smallest value and only swap that one
    K := I;
    for J := I +1 to aHi do
      if aArray[K] > aArray[J] then
      begin
        K := J;
        if Terminated then Exit;
      end;
    if K > I then
      ArraySwap(aArray, I, K);
  end;
end;


{ TBubbleSort }

procedure TBubbleSort.Sort(var aArray: TIntegerDynArray);
var
  I, J: Integer;
begin
  for I := Low(aArray) to High(aArray) - 1 do
    for J := High(aArray) downto I + 1 do
      if aArray[I] > aArray[J] then
      begin
        Swap(I, J);
        if Terminated then Exit;
      end;
end;

{ TSelectionSort }

procedure TSelectionSort.Sort(var aArray: TIntegerDynArray);
var
  I, J, K: Integer;
begin
  for I := Low(aArray) to High(aArray) -1 do begin
    //"Small" optimisation vs Buble sort: find smallest value and only swap that one
    K := I;
    for J := I +1 to High(aArray) do
      if aArray[K] > aArray[J] then
      begin
        K := J;
        if Terminated then Exit;
      end;
    if K > I then
      Swap(I, K);
  end;
end;

{ TQuickSort }

procedure TQuickSort.QuickSort(var aArray: TIntegerDynArray; iLo, iHi: Integer);
var
  Lo, Hi, Mid: Integer;
begin
  if Terminated then Exit;
  Lo := iLo;
  Hi := iHi;
  Mid := aArray[(Lo + Hi) div 2];
  repeat
    while aArray[Lo] < Mid do Inc(Lo);
    while aArray[Hi] > Mid do Dec(Hi);
    if Lo <= Hi then
    begin
      Swap(Lo, Hi);
      Inc(Lo);
      Dec(Hi);
    end;
  until Lo > Hi;
  if Hi > iLo then QuickSort(aArray, iLo, Hi);
  if Lo < iHi then QuickSort(aArray, Lo, iHi);
end;

procedure TQuickSort.Sort(var aArray: TIntegerDynArray);
begin
  QuickSort(aArray, Low(aArray), High(aArray));
end;

{ TMergeSort }

procedure TMergeSort.MergeBack(var aSource, aCopy: TIntegerDynArray; aLo, aMid, aHi: Integer);
var
  i,j,k:Integer;
  Log : ILogger;
begin
  if Terminated then Exit;
  Log := GetTraceLogger(ClassName, 'MergeBack', fLogger);
  Log.Debug('MergeBack called with aLo=%d, aMid=%d, aHi=%d, Array=%s', [aLo, aMid, aHi, DebugArrayAsStr(aSource, aLo, aHi)]);
  i := aLo; j := aMid;
  for k := aLo to aHi do
    if (i < aMid) and ((aCopy[i] <= aCopy[j]) or (j > aHi)) then begin
      aSource[k] := aCopy[i];
      Update(aSource[k], k);
      Inc(i);
    end else if (j <= aHi) then begin
      aSource[k] := aCopy[j];
      Update(aSource[k], k);
      Inc(j);
    end;
  //update working copy to be used on the way back to top
  for k := aLo to aHi do
    aCopy[k] := aSource[k];
  Log.Debug('MergeBack Result for  aLo=%d, aMid=%d, aHi=%d, Array=%s', [aLo, aMid, aHi, DebugArrayAsStr(aSource, aLo, aHi)]);
end;

procedure TMergeSort.MergePartition(var aSource, aCopy: TIntegerDynArray; aLo, aHi: Integer);
var
  iMid: Integer;
  Log : ILogger;
begin
  if Terminated then Exit;
  Log := GetTraceLogger(ClassName, 'MergePartition', fLogger).Trace;
//  Log.Debug('MergePartition called with aLo=%d, aHi=%d, Array=%s', [aLo, aHi, DebugArrayAsStr(aCopy, aLo, aHi)]);
  if (aHi - aLo < MERGE_SWAP_THRESHOLD) then begin
    SelectSort(aCopy, aLo, aHi);  //use faster sort for short partitions!
  end else if (aLo +1 = aHi) then begin
    //only 2 elements => swap if needed
    if (aCopy[aLo] > aCopy[aHi]) then begin
      iMid := aCopy[aLo];
      aCopy[aLo] := aCopy[aHi];
      aCopy[aHi] := iMid;
    end;
  end else if (aLo < aHi) then begin
    iMid := (aLo + aHi) div 2;
    MergePartition(aSource, aCopy, aLo, iMid);      //From aArray into WorkCopy
    MergePartition(aSource, aCopy, iMid, aHi);
    MergeBack(aSource, aCopy, aLo, iMid, aHi);    //Merge back from WorkCopy into aArray
  end;
end;

procedure TMergeSort.Sort(var aArray: TIntegerDynArray);
var
  aWorkCopy : TIntegerDynArray;
begin
  SetLength(aWorkCopy, Length(aArray));
  aWorkCopy := Copy(aArray);
  MergePartition(aArray, aWorkCopy, Low(aArray), High(aArray));
end;

{ TInsertionSort }

procedure TInsertionSort.InsertSort(var aSource: TIntegerDynArray; aLo, aHi: Integer);
var
  I, J, V: Integer;
begin
  var Log := GetTraceLogger(ClassName, 'InsertSort', fLogger).Trace;
//  Log.Debug('InsertSort called with aLo=%d, aHi=%d, Array=%s', [aLo, aHi, DebugArrayAsStr(aSource, aLo, aHi)]);
  for I := aLo +1 to aHi do begin
    J := I;
    V := aSource[I];
    while (J > aLo) and (aSource[J-1] > V) do begin
      //aSource[J]:= aSource[J-1];
      Swap(J, J-1);
      Dec(j);
      if Terminated then Exit;
    end;
    aSource[J]:= V;
    Update(V, J);
  end;
end;

procedure TInsertionSort.Sort(var aArray: TIntegerDynArray);
begin
  InsertSort(aArray, Low(aArray), High(aArray));
end;


initialization
  Prevent_GUI_Updates := False;
finalization

end.

