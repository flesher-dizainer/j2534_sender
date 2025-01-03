object MainForm: TMainForm
  Left = 0
  Top = 0
  Caption = 'J2534_Logger'
  ClientHeight = 525
  ClientWidth = 632
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OnClose = FormClose
  OnCreate = FormCreate
  TextHeight = 15
  object StatusBar1: TStatusBar
    Left = 0
    Top = 506
    Width = 632
    Height = 19
    Panels = <
      item
        Text = '123'
        Width = 50
      end
      item
        Text = 'Lambda'
        Width = 100
      end
      item
        Text = 'Msg Wbo'
        Width = 200
      end>
    ExplicitTop = 497
    ExplicitWidth = 626
  end
  object PageControl1: TPageControl
    Left = 0
    Top = 0
    Width = 632
    Height = 506
    ActivePage = TabSheet1
    Align = alClient
    TabOrder = 1
    ExplicitWidth = 626
    ExplicitHeight = 497
    object TabSheet1: TTabSheet
      Caption = 'Main'
      DesignSize = (
        624
        476)
      object ComboBoxDll: TComboBox
        Left = 3
        Top = 3
        Width = 206
        Height = 23
        Style = csDropDownList
        TabOrder = 0
      end
      object ComboBoxDiag: TComboBox
        Left = 3
        Top = 64
        Width = 206
        Height = 23
        Style = csDropDownList
        TabOrder = 1
      end
      object CheckListBoxDiag: TCheckListBox
        Left = 3
        Top = 125
        Width = 206
        Height = 308
        Anchors = [akLeft, akTop, akBottom]
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -17
        Font.Name = 'Segoe UI'
        Font.Style = []
        ItemHeight = 23
        ParentFont = False
        TabOrder = 2
        ExplicitHeight = 299
      end
      object Memo1: TMemo
        Left = 215
        Top = 125
        Width = 396
        Height = 342
        Anchors = [akLeft, akTop, akRight, akBottom]
        TabOrder = 3
        ExplicitWidth = 390
        ExplicitHeight = 333
      end
      object ButtonConnect: TButton
        Left = 3
        Top = 32
        Width = 87
        Height = 25
        Caption = #1055#1086#1076#1082#1083#1102#1095#1080#1090#1100
        TabOrder = 4
        OnClick = ButtonConnectClick
      end
      object Button1: TButton
        Left = 96
        Top = 32
        Width = 113
        Height = 25
        Caption = #1054#1090#1082#1083#1102#1095#1080#1090#1100
        TabOrder = 5
      end
      object ButtonSetDiag: TButton
        Left = 3
        Top = 94
        Width = 75
        Height = 25
        Caption = #1042#1099#1073#1088#1072#1090#1100
        TabOrder = 6
        OnClick = ButtonSetDiagClick
      end
      object ButtonStartDiag: TButton
        Left = 3
        Top = 442
        Width = 103
        Height = 25
        Anchors = [akLeft, akBottom]
        Caption = #1057#1090#1072#1088#1090
        TabOrder = 7
        ExplicitTop = 433
      end
      object ButtonStopDiag: TButton
        Left = 112
        Top = 442
        Width = 97
        Height = 25
        Anchors = [akLeft, akBottom]
        Caption = #1057#1090#1086#1087
        TabOrder = 8
        ExplicitTop = 433
      end
      object CBWbo: TComboBox
        Left = 227
        Top = 3
        Width = 206
        Height = 23
        Style = csDropDownList
        TabOrder = 9
      end
      object Button2: TButton
        Left = 227
        Top = 32
        Width = 75
        Height = 25
        Caption = #1042#1082#1083' '#1064#1044#1050
        TabOrder = 10
        OnClick = Button2Click
      end
      object CBPortWbo: TComboBox
        Left = 439
        Top = 3
        Width = 145
        Height = 23
        Style = csDropDownList
        ItemIndex = 0
        TabOrder = 11
        Text = 'No Com Ports'
        Items.Strings = (
          'No Com Ports')
      end
    end
    object TabSheet2: TTabSheet
      Caption = 'Data'
      ImageIndex = 1
    end
  end
  object Timer1: TTimer
    Enabled = False
    Interval = 1
    OnTimer = Timer1Timer
    Left = 404
    Top = 178
  end
end
