unit Dext.Core.Activator;

interface

uses
  System.Rtti,
  System.SysUtils,
  System.TypInfo,
  Dext.DI.Interfaces;

type
  TActivator = class
  public
    class function CreateInstance(AClass: TClass; const AArgs: array of TValue): TObject; overload;
    class function CreateInstance(AProvider: IServiceProvider; AClass: TClass; const AArgs: array of TValue): TObject; overload;
    class function CreateInstance<T: class>(const AArgs: array of TValue): T; overload;
  end;

implementation

{ TActivator }

class function TActivator.CreateInstance(AClass: TClass; const AArgs: array of TValue): TObject;
var
  Context: TRttiContext;
  TypeObj: TRttiType;
  Method: TRttiMethod;
  Params: TArray<TRttiParameter>;
  Args: TArray<TValue>;
  I: Integer;
  Matched: Boolean;
begin
  // Simple case: no arguments
  if Length(AArgs) = 0 then
  begin
    Result := AClass.Create;
    Exit;
  end;

  Context := TRttiContext.Create;
  try
    TypeObj := Context.GetType(AClass);
    if TypeObj = nil then
      raise EArgumentException.CreateFmt('RTTI information not found for class %s', [AClass.ClassName]);

    for Method in TypeObj.GetMethods do
    begin
      if Method.IsConstructor then
      begin
        Params := Method.GetParameters;
        if Length(Params) = Length(AArgs) then
        begin
          Matched := True;
          for I := 0 to High(Params) do
          begin
            // Skip check if argument is empty/nil (TValue.Empty)
            if AArgs[I].IsEmpty then Continue;

            // Check for type compatibility
            if AArgs[I].Kind <> Params[I].ParamType.TypeKind then
            begin
              // Allow Interface <-> Interface
              if (AArgs[I].Kind = tkInterface) and (Params[I].ParamType.TypeKind = tkInterface) then
                Continue;
              
              // Allow Class <-> Class
              if (AArgs[I].Kind = tkClass) and (Params[I].ParamType.TypeKind = tkClass) then
                Continue;

              Matched := False;
              Break;
            end;
            
            // For records and other exact types, check TypeInfo
            if (AArgs[I].Kind = tkRecord) and (AArgs[I].TypeInfo <> Params[I].ParamType.Handle) then
            begin
               Matched := False;
               Break;
            end;
          end;

          if Matched then
          begin
            SetLength(Args, Length(AArgs));
            for I := 0 to High(AArgs) do
              Args[I] := AArgs[I];

            // Invoke constructor on the class reference
            Result := Method.Invoke(AClass, Args).AsObject;
            Exit;
          end;
        end;
      end;
    end;

    raise EArgumentException.CreateFmt('No compatible constructor found for class %s', [AClass.ClassName]);
  finally
    Context.Free;
  end;
end;

class function TActivator.CreateInstance(AProvider: IServiceProvider; AClass: TClass; const AArgs: array of TValue): TObject;
var
  Context: TRttiContext;
  TypeObj: TRttiType;
  Method: TRttiMethod;
  Params: TArray<TRttiParameter>;
  Args: TArray<TValue>;
  I: Integer;
  Matched: Boolean;
  ParamType: TRttiType;
  ServiceType: TServiceType;
  ResolvedService: TValue;
begin
  Context := TRttiContext.Create;
  try
    TypeObj := Context.GetType(AClass);
    if TypeObj = nil then
      raise EArgumentException.CreateFmt('RTTI not found for %s', [AClass.ClassName]);

    for Method in TypeObj.GetMethods do
    begin
      if Method.IsConstructor then
      begin
        Params := Method.GetParameters;
        SetLength(Args, Length(Params));
        Matched := True;

        for I := 0 to High(Params) do
        begin
          // 1. Check explicit args (positional)
          if I < Length(AArgs) then
          begin
             Args[I] := AArgs[I];
             Continue;
          end;

          // 2. Resolve from DI
          ParamType := Params[I].ParamType;
          ResolvedService := TValue.Empty;

          if ParamType.TypeKind = tkInterface then
          begin
             var Guid := TRttiInterfaceType(ParamType).GUID;
             ServiceType := TServiceType.FromInterface(Guid);
             var Intf := AProvider.GetServiceAsInterface(ServiceType);
             if Intf <> nil then
               ResolvedService := TValue.From(Intf);
          end
          else if ParamType.TypeKind = tkClass then
          begin
             var Cls := TRttiInstanceType(ParamType).MetaclassType;
             ServiceType := TServiceType.FromClass(Cls);
             var Obj := AProvider.GetService(ServiceType);
             if Obj <> nil then
               ResolvedService := TValue.From(Obj);
          end;

          if not ResolvedService.IsEmpty then
            Args[I] := ResolvedService
          else
          begin
            // Not found and not in AArgs -> Match failed
            Matched := False;
            Break;
          end;
        end;

        if Matched then
        begin
          Result := Method.Invoke(AClass, Args).AsObject;
          Exit;
        end;
      end;
    end;

    raise EArgumentException.CreateFmt('No compatible constructor found for %s using DI', [AClass.ClassName]);
  finally
    Context.Free;
  end;
end;

class function TActivator.CreateInstance<T>(const AArgs: array of TValue): T;
var
  Ctx: TRttiContext;
  TypeObj: TRttiType;
begin
  Ctx := TRttiContext.Create;
  try
    TypeObj := Ctx.GetType(TypeInfo(T));
    if (TypeObj <> nil) and (TypeObj.IsInstance) then
      Result := T(CreateInstance(TypeObj.AsInstance.MetaclassType, AArgs))
    else
      raise EArgumentException.Create('Type parameter T must be a class type');
  finally
    Ctx.Free;
  end;
end;

end.
