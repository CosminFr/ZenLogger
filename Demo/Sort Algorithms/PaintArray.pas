unit PaintArray;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Types, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.Samples.Spin, Vcl.ExtCtrls,
  Vcl.Buttons, System.Generics.Collections;

type
  TPaintArray = class(TPaintBox)
  private
    fMaxValue   : Integer;
    fLineCount  : Integer;
    fLineWeight,
    fValueWeight : Double;
    procedure SetMaxValue(const Value: Integer);
    function  GetValue(aIndex: Integer): Integer;
    procedure SetValue(aIndex: Integer; const Value: Integer);
    procedure SetLineCount(const Value: Integer);
  public
    DataArray : TIntegerDynArray;  //Public field not property to allow direct access from the thread!

    constructor Create(AOwner: TComponent; aParent: TWinControl); reintroduce;

    procedure Paint; override;
    procedure ClearLine(aIndex: Integer);
    procedure PaintLine(aIndex, aValue: Integer; aColor : TColor = clRed);
    procedure PaintSwap(aIndex1, aIndex2, aValue1, aValue2: Integer);
    procedure SetBounds(ALeft, ATop, AWidth, AHeight: Integer); override;
    procedure SetDataArray(aArray: TIntegerDynArray; aMaxValue: Integer);


    property Value[aIndex : Integer] : Integer read GetValue     write SetValue; default;
    property MaxValue     : Integer          read fMaxValue  write SetMaxValue;
    property LineCount    : Integer          read fLineCount  write SetLineCount;
  published

  end;

implementation

{ TPaintArray }

constructor TPaintArray.Create(AOwner: TComponent; aParent: TWinControl);
begin
  inherited Create(aOwner);
  Parent := aParent;
  Name   := 'pa'+ aParent.Name;
  Align  := alClient;
end;

procedure TPaintArray.Paint;
var
  I: Integer;
begin
  Canvas.Pen.Color   := clBtnFace;
  Canvas.Brush.Color := clBtnFace;
  Canvas.Rectangle(0, 0, Width, Height);
  for I := Low(DataArray) to High(DataArray) do
    PaintLine(I, DataArray[I]);
end;

procedure TPaintArray.ClearLine(aIndex: Integer);
begin
  Canvas.Pen.Color   := clBtnFace;
  Canvas.Brush.Color := clBtnFace;
  Canvas.Rectangle(0, Trunc(aIndex * fLineWeight), Width, Trunc((aIndex+1)* fLineWeight));
end;

procedure TPaintArray.PaintLine(aIndex, aValue: Integer; aColor : TColor = clRed);
begin
  Canvas.Pen.Color   := aColor;
  Canvas.Brush.Color := aColor;
  Canvas.Rectangle(0, Trunc(aIndex * fLineWeight), Trunc(aValue * fValueWeight), Trunc((aIndex+1)* fLineWeight));
end;

procedure TPaintArray.PaintSwap(aIndex1, aIndex2, aValue1, aValue2: Integer);
begin
  ClearLine(aIndex1);
  PaintLine(aIndex1, aValue2);
  ClearLine(aIndex2);
  PaintLine(aIndex2, aValue1);
end;

procedure TPaintArray.SetBounds(ALeft, ATop, AWidth, AHeight: Integer);
begin
  inherited;
  //Re-calculate weights after a resize!
  fLineWeight  := aHeight / fLineCount;
  fValueWeight := aWidth / fMaxValue;
end;

procedure TPaintArray.SetDataArray(aArray: TIntegerDynArray; aMaxValue: Integer);
begin
  fLineCount := Length(aArray);
  fMaxValue  := aMaxValue;

  SetLength(DataArray, fLineCount);
  DataArray    := Copy(aArray);
  fLineWeight  := Height / fLineCount;
  fValueWeight := Width / fMaxValue;
end;

procedure TPaintArray.SetLineCount(const Value: Integer);
begin
  fLineCount := Value;
  fLineWeight := Height / fLineCount;
end;

procedure TPaintArray.SetMaxValue(const Value: Integer);
begin
  fMaxValue := Value;
  fValueWeight := Width / fMaxValue;
end;

function TPaintArray.GetValue(aIndex: Integer): Integer;
begin
  Result := DataArray[aIndex];
end;

procedure TPaintArray.SetValue(aIndex: Integer; const Value: Integer);
begin
  DataArray[aIndex] := Value;
end;

end.
