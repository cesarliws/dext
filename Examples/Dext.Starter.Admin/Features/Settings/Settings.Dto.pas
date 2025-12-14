unit Settings.Dto;

interface

uses
  Dext.Web;

type
  TSettingsProfileDto = record
    Name: string;
    Email: string;
  end;

  TSettingsPasswordDto = record
    [FromQuery('current_password')] // Should map from JSON field if names differ, but ideally we match JSON names. 
    // Wait, json-enc converts form fields to JSON properties. "current_password" in form -> "current_password" in JSON.
    // Delphi record fields are usually PascalCase. 
    // Dext Json Serializer is case-insensitive by default in our Binder settings?
    // Let's rely on standard binding. If form has "current_password", JSON has "current_password".
    // We should probably name record fields "CurrentPassword" and rely on deserializer mapping "current_password" -> "CurrentPassword".
    // Or we stick to exact names or use attributes if Dext supports [JsonProperty] or similar.
    // Dext.Json seems simple. Let's use PascalCase fields and assume Case Insensitivity or update Form input names to match PascalCase (easier).
    // Actually, converting Form naming (snake_case) to PascalCase is cleaner.
    // So I will update HTML forms to match PascalCase or use CamelCase (name="currentPassword"). 
    // Let's check Dext.Json behavior. Binder used TDextSettings.Default.WithCaseInsensitive.
    // So "current_password" -> "CurrentPassword" might NOT work directly if it expects "CurrentPassword" or "currentpassword".
    // "current_password" (snake) vs "CurrentPassword" (pascal) -> Remove underscore? No, standard insensitive check usually just ignores case, not underscores.
    // SAFE BET: Rename HTML input fields to match Record field names (case insensitive).
    
    CurrentPassword: string;
    NewPassword: string;
    ConfirmPassword: string;
    
    // To be safe I will update HTML input names to "CurrentPassword", etc.
  end;

implementation

end.
