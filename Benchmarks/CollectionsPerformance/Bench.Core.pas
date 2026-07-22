unit Bench.Core;

interface

uses
  System.SysUtils, System.Diagnostics, System.Classes, System.Generics.Collections,
  System.Generics.Defaults;

type
  TBenchResult = record
    Category: string; // List, Dictionary, etc.
    Scenario: string;
    DataType: string;
    Size: Integer;
    RTL_ms: Double;
    Dext_ms: Double;
  end;

  TBenchmark = class
  private
    FResults: TList<TBenchResult>;
    FCurrentCategory: string;
    FCurrentScenario: string;
    FCurrentDataType: string;
    FCurrentSize: Integer;
  public
    constructor Create;
    destructor Destroy; override;

    procedure StartScenario(const ACategory, AScenario, ADataType: string; ASize: Integer);
    procedure AddResult(const ALibrary: string; AMilliseconds: Double);

    procedure SaveToMarkdown(const AFilename: string);
    procedure PrintResults;
  end;

implementation

{ TBenchmark }

constructor TBenchmark.Create;
begin
  FResults := TList<TBenchResult>.Create;
end;

destructor TBenchmark.Destroy;
begin
  FResults.Free;
  inherited;
end;

procedure TBenchmark.StartScenario(const ACategory, AScenario, ADataType: string; ASize: Integer);
begin
  FCurrentCategory := ACategory;
  FCurrentScenario := AScenario;

  if (Pos('<', ADataType) = 0) then
  begin
    if ACategory = 'List' then
      FCurrentDataType := 'TList<' + ADataType + '>'
    else if (ACategory = 'Dictionary') or (ACategory = 'Dict') then
      FCurrentDataType := 'TDictionary<' + ADataType + ', string>'
    else
      FCurrentDataType := ADataType;
  end
  else
    FCurrentDataType := ADataType;

  FCurrentSize := ASize;
end;

procedure TBenchmark.AddResult(const ALibrary: string; AMilliseconds: Double);
var
  Result: TBenchResult;
  Found: Boolean;
  I: Integer;
begin
  Found := False;
  for I := 0 to FResults.Count - 1 do
  begin
    if (FResults[I].Scenario = FCurrentScenario) and
       (FResults[I].DataType = FCurrentDataType) and
       (FResults[I].Size = FCurrentSize) then
    begin
      Result := FResults[I];
      if ALibrary = 'RTL' then Result.RTL_ms := AMilliseconds
      else Result.Dext_ms := AMilliseconds;
      FResults[I] := Result;
      Found := True;
      Break;
    end;
  end;

  if not Found then
  begin
    FillChar(Result, SizeOf(Result), 0);
    Result.Category := FCurrentCategory;
    Result.Scenario := FCurrentScenario;
    Result.DataType := FCurrentDataType;
    Result.Size := FCurrentSize;
    if ALibrary = 'RTL' then Result.RTL_ms := AMilliseconds
    else Result.Dext_ms := AMilliseconds;
    FResults.Add(Result);
  end;
end;

procedure TBenchmark.PrintResults;
var
  Res: TBenchResult;
  Diff: Double;
begin
  Writeln(Format('%-20s | %-10s | %-10s | %-10s | %-10s | %-10s',
    ['Scenario', 'Type', 'Size', 'RTL (ms)', 'Dext (ms)', 'Diff']));
  Writeln(StringOfChar('-', 85));

  for Res in FResults do
  begin
    if Res.RTL_ms > 0 then
      Diff := (Res.Dext_ms / Res.RTL_ms) * 100
    else
      Diff := 0;

    Writeln(Format('%-20s | %-10s | %d | %10.4f | %10.4f | %8.1f%%',
      [Res.Scenario, Res.DataType, Res.Size, Res.RTL_ms, Res.Dext_ms, Diff]));
  end;
end;

procedure TBenchmark.SaveToMarkdown(const AFilename: string);
var
  Lines: TStringList;
  Res: TBenchResult;
  Diff: Double;
  CurrentCat: string;
  HasBottlenecks: Boolean;
begin
  // Sort by Category to group properly
  FResults.Sort(TComparer<TBenchResult>.Construct(
    function(const L, R: TBenchResult): Integer
    begin
      Result := CompareStr(L.Category, R.Category);
      if Result = 0 then
      begin
        Result := CompareStr(L.Scenario, R.Scenario);
        if Result = 0 then
        begin
          Result := CompareStr(L.DataType, R.DataType);
          if Result = 0 then
            Result := L.Size - R.Size;
        end;
      end;
    end));

  Lines := TStringList.Create;
  try
    Lines.Add('# Performance Results');
    Lines.Add(Format('Generated on: %s', [DateTimeToStr(Now)]));

    // Section 1: Bottlenecks (> 100%) - Grouped for focused analysis
    HasBottlenecks := False;
    for Res in FResults do
    begin
      if (Res.RTL_ms > 0) and ((Res.Dext_ms / Res.RTL_ms) * 100 > 100) then
      begin
        HasBottlenecks := True;
        Break;
      end;
    end;

    if HasBottlenecks then
    begin
      Lines.Add('');
      Lines.Add('## Bottlenecks (> 100%)');
      Lines.Add('');
      Lines.Add('| Category | Scenario | Type | Size | RTL (ms) | Dext (ms) | Ratio % | Status |');
      Lines.Add('| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |');
      for Res in FResults do
      begin
        Diff := 0;
        if Res.RTL_ms > 0 then Diff := (Res.Dext_ms / Res.RTL_ms) * 100;

        if Diff > 100 then
          Lines.Add(Format('| %s | **%s** | **`%s`** | %d | %.4f | %.4f | **%.1f%%** | 🔴 Needs Optimization |',
            [Res.Category, Res.Scenario, Res.DataType, Res.Size, Res.RTL_ms, Res.Dext_ms, Diff]));
      end;
    end;

    // Section 2: Full Results
    CurrentCat := '';
    for Res in FResults do
    begin
      if Res.Category <> CurrentCat then
      begin
        CurrentCat := Res.Category;
        Lines.Add('');
        Lines.Add('## ' + CurrentCat);
        Lines.Add('');
        Lines.Add('| Scenario | Type | Size | RTL (ms) | Dext (ms) | Ratio % |');
        Lines.Add('| :--- | :--- | :--- | :--- | :--- | :--- |');
      end;

      Diff := 0;
      if Res.RTL_ms > 0 then Diff := (Res.Dext_ms / Res.RTL_ms) * 100;

      if Diff > 100 then
        Lines.Add(Format('| **%s** | **`%s`** | %d | %.4f | %.4f | **%.1f%%** |',
          [Res.Scenario, Res.DataType, Res.Size, Res.RTL_ms, Res.Dext_ms, Diff]))
      else
        Lines.Add(Format('| %s | `%s` | %d | %.4f | %.4f | %.1f%% |',
          [Res.Scenario, Res.DataType, Res.Size, Res.RTL_ms, Res.Dext_ms, Diff]));
    end;
    Lines.Add('');

    Lines.SaveToFile(AFilename);
  finally
    Lines.Free;
  end;
end;

end.
