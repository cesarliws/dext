object FormMain: TFormMain
  Left = 0
  Top = 0
  Caption = 'Dext Framework - gRPC & TEntityDataSet Integration Demo'
  ClientHeight = 580
  ClientWidth = 900
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object ContentSplitter: TSplitter
    Left = 0
    Top = 377
    Width = 900
    Height = 3
    Cursor = crVSplit
    Align = alBottom
  end
  object TopPanel: TPanel
    Left = 0
    Top = 0
    Width = 900
    Height = 65
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object LoadButton: TButton
      Left = 16
      Top = 16
      Width = 150
      Height = 33
      Caption = 'Carregar (gRPC FetchAll)'
      TabOrder = 0
      OnClick = LoadButtonClick
    end
    object AddButton: TButton
      Left = 180
      Top = 16
      Width = 110
      Height = 33
      Caption = 'Inserir Empresa'
      TabOrder = 1
      OnClick = AddButtonClick
    end
    object DeleteButton: TButton
      Left = 300
      Top = 16
      Width = 110
      Height = 33
      Caption = 'Excluir Empresa'
      TabOrder = 2
      OnClick = DeleteButtonClick
    end
    object SaveButton: TButton
      Left = 420
      Top = 16
      Width = 230
      Height = 33
      Caption = 'Salvar Alterac'#245'es (gRPC ApplyChanges)'
      TabOrder = 3
      OnClick = SaveButtonClick
    end
    object CodeOnlyButton: TButton
      Left = 670
      Top = 16
      Width = 210
      Height = 33
      Caption = 'Demo Apenas C'#243'digo (gRPC)'
      TabOrder = 4
      OnClick = CodeOnlyButtonClick
    end
  end
  object LogsMemo: TMemo
    Left = 0
    Top = 380
    Width = 900
    Height = 200
    Align = alBottom
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 1
  end
  object CompanyDBGrid: TDBGrid
    Left = 0
    Top = 65
    Width = 900
    Height = 312
    Align = alClient
    DataSource = CompanyDataSource
    TabOrder = 2
    TitleFont.Charset = DEFAULT_CHARSET
    TitleFont.Color = clWindowText
    TitleFont.Height = -12
    TitleFont.Name = 'Segoe UI'
    TitleFont.Style = []
  end
  object CompanyDataSource: TDataSource
    Left = 40
    Top = 90
  end
end
