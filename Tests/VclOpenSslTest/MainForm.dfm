object frmMain: TfrmMain
  Left = 0
  Top = 0
  Caption = 'Dext Framework - OpenSSL & Cryptography Test'
  ClientHeight = 441
  ClientWidth = 624
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  TextHeight = 15
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 624
    Height = 81
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object lblTitle: TLabel
      Left = 16
      Top = 13
      Width = 350
      Height = 21
      Caption = 'OpenSSL vs System.Hash vs Windows CNG'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -16
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object btnTestIndyOpenSSL: TButton
      Left = 16
      Top = 45
      Width = 130
      Height = 25
      Caption = 'Test Indy OpenSSL'
      TabOrder = 0
      OnClick = btnTestIndyOpenSSLClick
    end
    object btnTestSystemHash: TButton
      Left = 160
      Top = 45
      Width = 130
      Height = 25
      Caption = 'Test System.Hash'
      TabOrder = 1
      OnClick = btnTestSystemHashClick
    end
    object btnTestWindowsCNG: TButton
      Left = 304
      Top = 45
      Width = 130
      Height = 25
      Caption = 'Test Windows CNG'
      TabOrder = 2
      OnClick = btnTestWindowsCNGClick
    end
  end
  object memoLogs: TMemo
    Left = 0
    Top = 81
    Width = 624
    Height = 360
    Align = alClient
    Color = 3355443
    Font.Charset = ANSI_CHARSET
    Font.Color = clWhite
    Font.Height = -12
    Font.Name = 'Consolas'
    Font.Style = []
    ParentFont = False
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 1
  end
end
