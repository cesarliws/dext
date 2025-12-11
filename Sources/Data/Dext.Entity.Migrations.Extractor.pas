{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2025 Cesar Romero & Dext Contributors             }
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
{  Author:  Cesar Romero                                                    }
{  Created: 2025-12-08                                                      }
{                                                                           }
{***************************************************************************}
unit Dext.Entity.Migrations.Extractor;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Rtti,
  System.TypInfo,
  System.Generics.Collections,
  Dext.Entity, // Add concrete TDbContext
  Dext.Entity.Core,
  Dext.Entity.Mapping,
  Dext.Entity.Attributes,
  Dext.Entity.Migrations.Model;

type
  TDbContextModelExtractor = class
  public
    class function Extract(AContext: IDbContext): TSnapshotModel;
  end;

implementation

{ TDbContextModelExtractor }

class function TDbContextModelExtractor.Extract(AContext: IDbContext): TSnapshotModel;
var
  Ctx: TDbContext; // Cast to concrete class to access ModelBuilder
  ModelBuilder: TModelBuilder;
  Map: TEntityMap;
  Table: TSnapshotTable;
  PropMap: TPropertyMap;
  Col: TSnapshotColumn;
  RContext: TRttiContext;
  RType: TRttiType;
  RProp: TRttiProperty;
  
  // Helper to get all maps
  // Since TModelBuilder doesn't expose an iterator for maps, we might need to rely on 
  // registered entities if we had a list, or we need to modify TModelBuilder to expose Maps.
  // For now, let's assume we can access FMaps via RTTI or we add a property to TModelBuilder.
  // Wait, TModelBuilder has FMaps private.
  // We should add a property `Maps` to TModelBuilder in Dext.Entity.Mapping.pas.
  // But I can't modify it right now easily without breaking things or recompiling everything.
  // Let's use RTTI to access FMaps for now to avoid changing core interface if possible,
  // OR better: Update TModelBuilder to expose Maps. It's a reasonable change.
  // Let's update TModelBuilder first.
  
  // Assuming TModelBuilder has a Maps property (I will add it).
  Maps: TEnumerable<TEntityMap>; 
begin
  Result := TSnapshotModel.Create;
  
  if not (AContext is TDbContext) then
    Exit; // Should not happen
    
  Ctx := TDbContext(AContext);
  ModelBuilder := Ctx.ModelBuilder;
  
  // We need to iterate over all maps in ModelBuilder.
  // I will add `GetMaps` to TModelBuilder.
  Maps := ModelBuilder.GetMaps; 
  
  RContext := TRttiContext.Create;
  try
    for Map in Maps do
    begin
      Table := TSnapshotTable.Create;
      Table.Name := Map.TableName;
      
      RType := RContext.GetType(Map.EntityType);
      
      // If TableName is empty, check Attribute
      if Table.Name = '' then
      begin
         var Attr := RType.GetAttribute<TableAttribute>;
         if Attr <> nil then
           Table.Name := Attr.Name;
      end;

      // If still empty, derive from Class Name
      if Table.Name = '' then
      begin
        // Simple pluralization or just class name
        Table.Name := String(Map.EntityType.Name).Substring(1); // Remove 'T'
      end;
      
      // Iterate Properties
      for RProp in RType.GetProperties do
      begin
        // Skip non-mapped properties?
        // We need to check if it's mapped.
        // If Fluent Mapping exists, use it.
        // If Attributes exist, use them.
        // Default convention: Map all public read/write properties.
        
        if (RProp.Visibility < mvPublic) then Continue;
        
        // Check for [NotMapped] or Ignore()
        if Map.Properties.TryGetValue(RProp.Name, PropMap) then
        begin
          if PropMap.IsIgnored then Continue;
        end;
        
        // Create Column
        Col := TSnapshotColumn.Create;
        Col.Name := RProp.Name;
        
        // Apply Mapping Overrides
        if PropMap <> nil then
        begin
          if PropMap.ColumnName <> '' then Col.Name := PropMap.ColumnName;
          Col.IsPrimaryKey := PropMap.IsPK;
          Col.IsIdentity := PropMap.IsAutoInc;
          Col.IsNullable := not PropMap.IsRequired;
          Col.Length := PropMap.MaxLength;
        end;
        
        // Apply Attributes (if not overridden by Fluent)
        // Note: TEntityMap usually aggregates attributes during building, 
        // but if it doesn't, we check here.
        // Let's assume TEntityMap is the source of truth.
        
        // Determine Type
        // Use Dialect to map Delphi Type to SQL Type
        // Note: We need PTypeInfo.
        // TRttiProperty.PropertyType.Handle gives PTypeInfo.
        Col.ColumnType := AContext.Dialect.GetColumnType(RProp.PropertyType.Handle, Col.IsIdentity);
        
        Table.Columns.Add(Col);
      end;
      
      Result.Tables.Add(Table);
    end;
  finally
    RContext.Free;
  end;
end;

end.

