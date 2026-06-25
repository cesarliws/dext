object FormMain: TFormMain
  Left = 0
  Top = 0
  Caption = 'Dext MCP VCL Database Demo'
  ClientHeight = 490
  ClientWidth = 780
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object PanelTop: TPanel
    Left = 0
    Top = 0
    Width = 780
    Height = 65
    Align = alTop
    BevelOuter = bvNone
    Color = clWhite
    ParentBackground = False
    TabOrder = 0
    object LabelPort: TLabel
      Left = 20
      Top = 24
      Width = 31
      Height = 15
      Caption = 'Porta:'
    end
    object EditPort: TEdit
      Left = 57
      Top = 20
      Width = 72
      Height = 23
      TabOrder = 0
      Text = '3031'
    end
    object BtnStart: TButton
      Left = 145
      Top = 19
      Width = 110
      Height = 25
      Caption = 'Iniciar Servidor'
      TabOrder = 1
      OnClick = BtnStartClick
    end
    object BtnStop: TButton
      Left = 265
      Top = 19
      Width = 110
      Height = 25
      Caption = 'Parar Servidor'
      TabOrder = 2
      OnClick = BtnStopClick
    end
  end
  object PanelLeft: TPanel
    Left = 0
    Top = 65
    Width = 430
    Height = 425
    Align = alLeft
    BevelOuter = bvNone
    TabOrder = 1
    object LabelDB: TLabel
      Left = 10
      Top = 10
      Width = 174
      Height = 15
      Caption = 'Banco de Dados (Participantes):'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object DBGrid1: TDBGrid
      Left = 10
      Top = 35
      Width = 410
      Height = 380
      DataSource = DataSource1
      TabOrder = 0
      TitleFont.Charset = DEFAULT_CHARSET
      TitleFont.Color = clWindowText
      TitleFont.Height = -12
      TitleFont.Name = 'Segoe UI'
      TitleFont.Style = []
      Columns = <
        item
          Expanded = False
          FieldName = 'id'
          Title.Caption = 'ID'
          Width = 35
          Visible = True
        end
        item
          Expanded = False
          FieldName = 'nome'
          Title.Caption = 'Nome'
          Width = 140
          Visible = True
        end
        item
          Expanded = False
          FieldName = 'email'
          Title.Caption = 'E-mail'
          Width = 140
          Visible = True
        end
        item
          Expanded = False
          FieldName = 'sorteado'
          Title.Caption = 'Sorteado'
          Width = 60
          Visible = True
        end>
    end
  end
  object PanelRight: TPanel
    Left = 430
    Top = 65
    Width = 350
    Height = 425
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 2
    object LabelLogs: TLabel
      Left = 10
      Top = 10
      Width = 110
      Height = 15
      Caption = 'Console de Eventos:'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object MemoLogs: TMemo
      Left = 10
      Top = 35
      Width = 330
      Height = 380
      ScrollBars = ssVertical
      TabOrder = 0
    end
  end
  object FDConnection: TFDConnection
    Left = 48
    Top = 120
  end
  object FDPhysSQLiteDriverLink1: TFDPhysSQLiteDriverLink
    Left = 144
    Top = 120
  end
  object FDGUIxWaitCursor1: TFDGUIxWaitCursor
    Provider = 'Console'
    Left = 240
    Top = 120
  end
  object DataSource1: TDataSource
    Left = 48
    Top = 192
  end
  object FDTableParticipantes: TFDTable
    Left = 144
    Top = 192
  end
end
