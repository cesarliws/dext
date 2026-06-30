unit Dext.Threading.ProcessorGroups;

interface

uses
  System.SysUtils
  {$IFDEF MSWINDOWS}
  , Winapi.Windows
  {$ENDIF};

type
  /// <summary>
  ///   Represents a Windows processor group index and its logical processor affinity mask.
  /// </summary>
  TDextProcessorGroupAffinity = record
    /// <summary>The index of the processor group.</summary>
    Group: Word;
    /// <summary>A bitmask representing the logical processors within the group.</summary>
    Mask: NativeUInt;
  end;

  {$IFDEF MSWINDOWS}
  /// <summary>
  ///   WinAPI GROUP_AFFINITY structure representation.
  /// </summary>
  TGroupAffinity = record
    /// <summary>A bitmask specifying the processors in the group.</summary>
    Mask: NativeUInt;
    /// <summary>The processor group index.</summary>
    Group: Word;
    /// <summary>Reserved fields for OS alignment.</summary>
    Reserved: array[0..2] of Word;
  end;
  /// <summary>Pointer to TGroupAffinity structure.</summary>
  PGroupAffinity = ^TGroupAffinity;
  {$ENDIF}

/// <summary>
///   Retrieves the total number of logical processors across all active processor groups.
/// </summary>
function GetSystemLogicalProcessorCount: Integer;

/// <summary>
///   Retrieves the number of active processor groups on the system.
/// </summary>
function GetSystemActiveProcessorGroupCount: Word;

/// <summary>
///   Retrieves the number of active logical processors in a specific processor group.
/// </summary>
/// <param name="AGroup">The index of the processor group.</param>
function GetSystemActiveProcessorCountForGroup(AGroup: Word): Integer;

/// <summary>
///   Calculates and retrieves the processor group affinity configuration for a given worker index.
/// </summary>
/// <param name="AWorkerIndex">The zero-based index of the worker thread.</param>
/// <param name="AAffinity">Output parameter receiving the calculated affinity structure.</param>
function GetProcessorGroupAffinityForWorker(AWorkerIndex: Integer; out AAffinity: TDextProcessorGroupAffinity): Boolean;

{$IFDEF MSWINDOWS}
/// <summary>
///   Sets the processor group affinity for the specified thread using the Windows API.
/// </summary>
function SetThreadGroupAffinity(hThread: THandle; const GroupAffinity: TGroupAffinity; PreviousGroupAffinity: PGroupAffinity): BOOL;

/// <summary>
///   Applies the specified group affinity to a thread handle.
/// </summary>
/// <param name="AThreadHandle">Handle of the thread.</param>
/// <param name="AAffinity">The affinity structure to apply.</param>
function ApplyGroupAffinityToThread(AThreadHandle: THandle; const AAffinity: TDextProcessorGroupAffinity): Boolean; overload;

/// <summary>
///   Applies group affinity to a thread handle using group index and processor mask.
/// </summary>
/// <param name="AThreadHandle">Handle of the thread.</param>
/// <param name="AGroupIndex">The processor group index.</param>
/// <param name="AMask">The processor mask.</param>
function ApplyGroupAffinityToThread(AThreadHandle: THandle; AGroupIndex: Word; AMask: NativeUInt): Boolean; overload;
{$ENDIF}

implementation

const
  ALL_PROCESSOR_GROUPS = $FFFF;
  BITS_PER_NATIVE_UINT = SizeOf(NativeUInt) * 8;

{$IFDEF MSWINDOWS}
type
  TGetActiveProcessorGroupCountFunc = function: Word; stdcall;
  TGetActiveProcessorCountFunc = function(GroupNumber: Word): DWORD; stdcall;
  TSetThreadGroupAffinityFunc = function(hThread: THandle; const GroupAffinity: TGroupAffinity; PreviousGroupAffinity: PGroupAffinity): BOOL; stdcall;

var
  GGetActiveProcessorGroupCount: TGetActiveProcessorGroupCountFunc = nil;
  GGetActiveProcessorCount: TGetActiveProcessorCountFunc = nil;
  GSetThreadGroupAffinity: TSetThreadGroupAffinityFunc = nil;

procedure LoadProcessorGroupApis;
var
  Kernel: HMODULE;
begin
  Kernel := GetModuleHandle('kernel32.dll');
  if Kernel = 0 then
    Kernel := LoadLibrary('kernel32.dll');

  if Kernel <> 0 then
  begin
    @GGetActiveProcessorGroupCount := GetProcAddress(Kernel, 'GetActiveProcessorGroupCount');
    @GGetActiveProcessorCount := GetProcAddress(Kernel, 'GetActiveProcessorCount');
    @GSetThreadGroupAffinity := GetProcAddress(Kernel, 'SetThreadGroupAffinity');
  end;
end;
{$ENDIF}

function ProcessorMaskForCount(ACount: Integer): NativeUInt;
begin
  if ACount <= 0 then
    Exit(0);

  if ACount >= BITS_PER_NATIVE_UINT then
    Result := NativeUInt(not NativeUInt(0))
  else
    Result := (NativeUInt(1) shl ACount) - 1;
end;

function GetSystemActiveProcessorGroupCount: Word;
begin
  Result := 1;
  {$IFDEF MSWINDOWS}
  if Assigned(GGetActiveProcessorGroupCount) then
  begin
    Result := GGetActiveProcessorGroupCount();
    if Result = 0 then
      Result := 1;
  end;
  {$ENDIF}
end;

function GetSystemActiveProcessorCountForGroup(AGroup: Word): Integer;
begin
  {$IFDEF MSWINDOWS}
  if Assigned(GGetActiveProcessorCount) then
  begin
    Result := Integer(GGetActiveProcessorCount(AGroup));
    if Result > 0 then
      Exit;
  end;
  {$ENDIF}

  if AGroup = 0 then
    Result := CPUCount
  else
    Result := 0;
end;

function GetSystemLogicalProcessorCount: Integer;
{$IFDEF MSWINDOWS}
var
  Count: Integer;
  i: Word;
  GroupCount: Word;
{$ENDIF}
begin
  Result := 0;

  {$IFDEF MSWINDOWS}
  if Assigned(GGetActiveProcessorCount) then
  begin
    Count := Integer(GGetActiveProcessorCount(ALL_PROCESSOR_GROUPS));
    if Count > 0 then
      Exit(Count);

    GroupCount := GetSystemActiveProcessorGroupCount;
    for i := 0 to GroupCount - 1 do
      Inc(Result, GetSystemActiveProcessorCountForGroup(i));
  end;
  {$ENDIF}

  if Result <= 0 then
    Result := CPUCount;

  if Result <= 0 then
    Result := 1;
end;

function GetProcessorGroupAffinityForWorker(AWorkerIndex: Integer; out AAffinity: TDextProcessorGroupAffinity): Boolean;
var
  i: Word;
  GroupCount: Word;
  GroupProcessorCount: Integer;
  ProcessorOrdinal: Integer;
  TotalProcessors: Integer;
begin
  AAffinity.Group := 0;
  AAffinity.Mask := ProcessorMaskForCount(GetSystemActiveProcessorCountForGroup(0));

  TotalProcessors := GetSystemLogicalProcessorCount;
  if (AWorkerIndex < 0) or (TotalProcessors <= 0) then
    Exit(False);

  ProcessorOrdinal := AWorkerIndex mod TotalProcessors;
  GroupCount := GetSystemActiveProcessorGroupCount;

  for i := 0 to GroupCount - 1 do
  begin
    GroupProcessorCount := GetSystemActiveProcessorCountForGroup(i);
    if GroupProcessorCount <= 0 then
      Continue;

    if ProcessorOrdinal < GroupProcessorCount then
    begin
      AAffinity.Group := i;
      AAffinity.Mask := ProcessorMaskForCount(GroupProcessorCount);
      Exit(AAffinity.Mask <> 0);
    end;

    Dec(ProcessorOrdinal, GroupProcessorCount);
  end;

  Result := AAffinity.Mask <> 0;
end;

{$IFDEF MSWINDOWS}
function SetThreadGroupAffinity(hThread: THandle; const GroupAffinity: TGroupAffinity; PreviousGroupAffinity: PGroupAffinity): BOOL;
begin
  if Assigned(GSetThreadGroupAffinity) then
    Result := GSetThreadGroupAffinity(hThread, GroupAffinity, PreviousGroupAffinity)
  else
    Result := False;
end;

function ApplyGroupAffinityToThread(AThreadHandle: THandle; const AAffinity: TDextProcessorGroupAffinity): Boolean;
begin
  Result := ApplyGroupAffinityToThread(AThreadHandle, AAffinity.Group, AAffinity.Mask);
end;

function ApplyGroupAffinityToThread(AThreadHandle: THandle; AGroupIndex: Word; AMask: NativeUInt): Boolean;
var
  GroupAffinity: TGroupAffinity;
begin
  if (AThreadHandle = 0) or (AMask = 0) or not Assigned(GSetThreadGroupAffinity) then
    Exit(False);

  FillChar(GroupAffinity, SizeOf(GroupAffinity), 0);
  GroupAffinity.Group := AGroupIndex;
  GroupAffinity.Mask := AMask;
  Result := SetThreadGroupAffinity(AThreadHandle, GroupAffinity, nil);
end;
{$ENDIF}

initialization
  {$IFDEF MSWINDOWS}
  LoadProcessorGroupApis;
  {$ENDIF}

end.
