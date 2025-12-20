{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Global Configuration & Compiler Directives                      }
{                                                                           }
{***************************************************************************}

{$IFNDEF DEXT_INC}
{$DEFINE DEXT_INC}

//---------------------------------------------------------------------------
// Compiler Features
//---------------------------------------------------------------------------

// System.Hash unit (Introduced in Delphi XE8 / CompilerVersion 29.0)
{$IF CompilerVersion >= 29.0}
  {$DEFINE DEXT_HAS_SYSTEM_HASH}
{$IFEND}

//---------------------------------------------------------------------------
// User Overrides
//---------------------------------------------------------------------------

// Define DEXT_FORCE_INDY_HASH in your project options or here
// to force usage of Indy for hashing even on newer Delphi versions.
{$IFDEF DEXT_FORCE_INDY_HASH}
  {$UNDEF DEXT_HAS_SYSTEM_HASH}
{$ENDIF}

// Define DEXT_ENABLE_SSL to enable HTTPS/SSL support in the framework.
// Note: Requires OpenSSL libraries (libeay32.dll, ssleay32.dll) or compatible provider.
{$DEFINE DEXT_ENABLE_SSL}
// {.$DEFINE DEXT_ENABLE_TAURUS_TLS}

//---------------------------------------------------------------------------
// Database Drivers
//---------------------------------------------------------------------------

// Enable/Disable specific database drivers to avoid unnecessary dependencies.
// Useful for Delphi Professional/Community editions.
{$DEFINE DEXT_ENABLE_DB_SQLITE}
// {.$DEFINE DEXT_ENABLE_DB_POSTGRES}
// {.$DEFINE DEXT_ENABLE_DB_MYSQL}
// {.$DEFINE DEXT_ENABLE_DB_MSSQL}
// {.$DEFINE DEXT_ENABLE_DB_ORACLE}
// {.$DEFINE DEXT_ENABLE_DB_FIREBIRD}
// {.$DEFINE DEXT_ENABLE_DB_ODBC}

{$ENDIF}
