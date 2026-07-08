{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2026 Cesar Romero & Dext Contributors             }
{                                                                           }
{           Licensed under the Apache License, Version 2.0 (the "License"); }
{           you may not use this file except in compliance with the License.}
{           You may obtain a copy of the License at                         }
{                                                                           }
{               http://www.apache.org/licenses/LICENSE-2.0                  }
{                                                                           }
{           Unless required by applicable law or agreed to in writing,      }
{           software distributed under the License is distributed on an     }
{           "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,    }
{           either express or implied. See the License for the specific     }
{           language governing permissions and limitations under the        }
{           License.                                                        }
{                                                                           }
{***************************************************************************}
{                                                                           }
{  Author:  Cesar Romero & Dext Contributors                                }
{  Created: 2026-07-07                                                      }
{                                                                           }
{  Description:                                                             }
{    Attributes for gRPC annotation and Protobuf member serialization.      }
{                                                                           }
{***************************************************************************}
unit Dext.Grpc.Attributes;

interface

uses
  System.SysUtils;

type
  GrpcMessageAttribute = class(TCustomAttribute)
  end;

  ProtoMemberAttribute = class(TCustomAttribute)
  private
    FTag: Integer;
  public
    constructor Create(ATag: Integer);
    property Tag: Integer read FTag;
  end;

  GrpcServiceAttribute = class(TCustomAttribute)
  private
    FServiceName: string;
  public
    constructor Create(const AServiceName: string);
    property ServiceName: string read FServiceName;
  end;

  GrpcMethodAttribute = class(TCustomAttribute)
  private
    FGrpcMethodName: string;
  public
    constructor Create(const AGrpcMethodName: string);
    property GrpcMethodName: string read FGrpcMethodName;
  end;

implementation

{ ProtoMemberAttribute }

constructor ProtoMemberAttribute.Create(ATag: Integer);
begin
  FTag := ATag;
end;

{ GrpcServiceAttribute }

constructor GrpcServiceAttribute.Create(const AServiceName: string);
begin
  FServiceName := AServiceName;
end;

{ GrpcMethodAttribute }

constructor GrpcMethodAttribute.Create(const AGrpcMethodName: string);
begin
  FGrpcMethodName := AGrpcMethodName;
end;

end.
