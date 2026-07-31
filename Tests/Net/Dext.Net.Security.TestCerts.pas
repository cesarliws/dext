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
{  Author:  Cesar Romero & Antigravity AI                                   }
{  Created: 2026-07-23                                                      }
{                                                                           }
{  Test certificates provider for automated Dext SSL unit tests.             }
{                                                                           }
{***************************************************************************}
unit Dext.Net.Security.TestCerts;

{$I Dext.inc}

interface

uses
  System.SysUtils,
  System.IOUtils;

const
  TEST_SERVER_CRT_PEM =
    '-----BEGIN CERTIFICATE-----' + sLineBreak +
    'MIIDgzCCAmugAwIBAgIUUa5VeBjPda6fsCJAA8FDNSt8gUgwDQYJKoZIhvcNAQEL' + sLineBreak +
    'BQAwUTELMAkGA1UEBhMCQlIxCzAJBgNVBAgMAlNQMRIwEAYDVQQHDAlTYW8gUGF1' + sLineBreak +
    'bG8xDTALBgNVBAoMBERleHQxEjAQBgNVBAMMCWxvY2FsaG9zdDAeFw0yNjAxMDIx' + sLineBreak +
    'NDM4NDRaFw0zNTEyMzExNDM4NDRaMFExCzAJBgNVBAYTAkJSMQswCQYDVQQIDAJT' + sLineBreak +
    'UDESMBAGA1UEBwwJU2FvIFBhdWxvMQ0wCwYDVQQKDAREZXh0MRIwEAYDVQQDDAls' + sLineBreak +
    'b2NhbGhvc3QwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCUYJTCUsKs' + sLineBreak +
    'x0sHv7LekeG/Tl7738TI5z46aFiRPR/gmVyy+8L8YJAW5qFrmczM2NHLtkqUOTgM' + sLineBreak +
    'OoSTfdxL0rw+mXUXTcjg/QV901tr+Lmq8AucvU1zJRwc9kHQcOHm9uEfiKZGIAzq' + sLineBreak +
    '5V8ijCQiMnOGkeGrjilveg+72Cg7Ws0dCqikr+mBB9wtS+KH4rR5y9QQ5QWsjd4H' + sLineBreak +
    'HV7kUFSiiNGGM5uOniVIKohyBVTKT94Pq3Vi98QNHe+1ITqro1AwxtX3MwHpWSby' + sLineBreak +
    'YBdrhbdvfbkjIOAUim2s76v7t1LS3ELxNogPNKTZlPrMdvLijpLRL9lWa4aJmT8M' + sLineBreak +
    'Dc1lZAV5DvpPAgMBAAGjUzBRMB0GA1UdDgQWBBTIAEI3lmMDKHeS0fHtCYjlG2Ux' + sLineBreak +
    'ijAfBgNVHSMEGDAWgBTIAEI3lmMDKHeS0fHtCYjlG2UxijAPBgNVHRMBAf8EBTAD' + sLineBreak +
    'AQH/MA0GCSqGSIb3DQEBCwUAA4IBAQAwHPzoUEjZcgAUONGcI1AGOfS7Ajz1UCEs' + sLineBreak +
    'sc0PyQJip3p7s2BjbtoLf5q1t7FzlQkjbWsbt1g+IOV6pAu+dstBsvhHKyYzKERA' + sLineBreak +
    'o9mm+jhumvEO/p39JucOZknv3iUFXfR/yOwJEG0WXBX2VgqIuIi7cZv5PPeOcmsK' + sLineBreak +
    '4VwDrxGMpSTiqcxgf3UtGY0pfhK3vNZ05WtYDulr/ZckkKp4R6RJT2FyPP/HiQEu' + sLineBreak +
    'd4ruzXnRO1I+PQcz2ekDRipnM7MSWv1XWih+4Wkg6Td2HUw23/Sh/pedIe/V9Oi2' + sLineBreak +
    'oKbLZfVja3qSBZzfRgd9viJPICF5vIdCOjK1mXXQjPNQmdK0PMTf' + sLineBreak +
    '-----END CERTIFICATE-----' + sLineBreak;

  TEST_SERVER_KEY_PEM =
    '-----BEGIN PRIVATE KEY-----' + sLineBreak +
    'MIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQCUYJTCUsKsx0sH' + sLineBreak +
    'v7LekeG/Tl7738TI5z46aFiRPR/gmVyy+8L8YJAW5qFrmczM2NHLtkqUOTgMOoST' + sLineBreak +
    'fdxL0rw+mXUXTcjg/QV901tr+Lmq8AucvU1zJRwc9kHQcOHm9uEfiKZGIAzq5V8i' + sLineBreak +
    'jCQiMnOGkeGrjilveg+72Cg7Ws0dCqikr+mBB9wtS+KH4rR5y9QQ5QWsjd4HHV7k' + sLineBreak +
    'UFSiiNGGM5uOniVIKohyBVTKT94Pq3Vi98QNHe+1ITqro1AwxtX3MwHpWSbyYBdr' + sLineBreak +
    'hbdvfbkjIOAUim2s76v7t1LS3ELxNogPNKTZlPrMdvLijpLRL9lWa4aJmT8MDc1l' + sLineBreak +
    'ZAV5DvpPAgMBAAECggEARmmI3qjAmpaezAgUPZv0CcGKwLOBoqdeOACBmzbrFD4j' + sLineBreak +
    'KArijrrSVhPPYY0ki8eO08HnpWx75Q22EXomW1MfowNW9h6jJ+Xav8nXtibcETsF' + sLineBreak +
    '/7Uz9mMTcskIFX8kLONWlQzXfyrBho0f9viTQyk2+pLrCWsWzcCai9V5ziT6dn95' + sLineBreak +
    'dkTAl4PqqIxZnX7bIvYOEzglFhNcCnXMrEujlsZ/VAN9nLGavOwkcK/GrUnj2NER' + sLineBreak +
    'yMt0R7VpEVSj+GC/sGkWvcCGZD71Cx6fQ6dcvsyRqBQAgjW5eU4RA4pDDAIicJE2' + sLineBreak +
    'RgLzRE+usfUS3/wsDQbi3AmjLoTKSVCeidmy2whMjQKBgQDREEn65a66OmkG6hI/' + sLineBreak +
    'PT3zmPBxfqwdhoLGeD8wsYYeFnmr33TVust1tFZFKENB3LP4knH7vgo4ORs2U+q8' + sLineBreak +
    'R8i9xBrhsysGgH0l63qzH/1V7f8uzzRFDSpoDe6GRAAKoUviu2y13lznhOJRWR9t' + sLineBreak +
    'ymGB+dvm0ycVDB2i2Z1GftYBWwKBgQC1sGhk9rAGloSGYb3uoVuzwONA3Q7yBQtB' + sLineBreak +
    '1u++FkotYEC4TlzZFPa4lYVqYAysxXHf/tvyqo4MmVvBs4YWAGu/YmKsEI06ziNo' + sLineBreak +
    'ikPu/F/VMcjEpl7Inf8SWr/EvXkZHy+BuHk+TQTPa0HdqZgBQWfdmofvGEWiR6iv' + sLineBreak +
    'pL6Joc/pHQKBgBt3SmDeAACTX+z6n38TaqowM5aVj8MpQtEURyj8iaQ2S7Ha35yc' + sLineBreak +
    't9I06QiY640hk7tacgMiynDsf7i5eaNWwva7ZtS0Fzj5dHeg4jPaRgweAmKB8loI' + sLineBreak +
    'CsQ04FtfX6oF2tRkzzlth0MbYChTzx87cWgEDXHb18yaFOKqOFFkpHT1AoGAPYjF' + sLineBreak +
    'koxKCbEoqSqpXQyhNjv5u5oi2a0DpwTYpZR/Auc6hDFmGM+Uz+c0DFcDc/BbJPX4' + sLineBreak +
    'IDPLcFDwVqYqn4D8/RChQo1Ih8YRD/LkFyi6fEYkLRX7vA5muRyrHkLdpLh/KnwD' + sLineBreak +
    '9Cm5m1ZENIKfzK0ONGuF5mBeFRwX8YTmU07OT7ECgYBD4rAXHjbIWlsj2jRuk9U3' + sLineBreak +
    '4laETEhDqZ0g9wtqZt9FpIrPHC8YhrOQmQVkxog8ZWxvxC4JJiK9xQf9KEDHdDWY' + sLineBreak +
    'jkcg0fBaLpjjvLL/xlhXYzpDTJiLvVycsgT5M0sds8Dqc1JnS+DsC2LsAWxqgkcd' + sLineBreak +
    'XyvkLuz1E0UN4OEh1mVyNQ==' + sLineBreak +
    '-----END PRIVATE KEY-----' + sLineBreak;

procedure EnsureTestCertificates(out ACertPath, AKeyPath: string);

implementation

procedure EnsureTestCertificates(out ACertPath, AKeyPath: string);
begin
  ACertPath := TPath.Combine(TPath.GetTempPath, 'dext_test_server.crt');
  AKeyPath := TPath.Combine(TPath.GetTempPath, 'dext_test_server.key');

  if not FileExists(ACertPath) then
    TFile.WriteAllText(ACertPath, TEST_SERVER_CRT_PEM);

  if not FileExists(AKeyPath) then
    TFile.WriteAllText(AKeyPath, TEST_SERVER_KEY_PEM);
end;

end.
