{***************************************************************************}
{           Dext Framework - Indy SSL Interfaces                            }
{***************************************************************************}
unit Dext.Web.Indy.SSL.Interfaces;

interface

uses
  IdCustomHTTPServer, IdServerIOHandler;

type
  { IIndySSLHandler
    Abstracts the creation and configuration of the Indy IOHandler for SSL.
    Implementations can wrap IdSSLOpenSSL, TaurusTLS, etc. }
  IIndySSLHandler = interface
    ['{F4AA5B7C-8D9E-4012-A3B4-C5D6E7F80910}']
    { Configures and returns an IOHandler for the given server.
      Note: The returned object is typically owned by the server or needs to be managed.
      Usually, returning it allows immediate assignment to FHTTPServer.IOHandler. }
    function CreateIOHandler(AServer: TIdCustomHTTPServer): TIdServerIOHandler;
  end;

implementation

end.
