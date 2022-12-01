object MainForm: TMainForm
  Left = 0
  Top = 0
  Caption = 'MainForm'
  ClientHeight = 403
  ClientWidth = 850
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnClose = FormClose
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 120
  TextHeight = 16
  object LogMemo: TMemo
    Left = 474
    Top = 0
    Width = 376
    Height = 403
    Align = alRight
    ScrollBars = ssVertical
    TabOrder = 0
  end
  object GridPanel: TGridPanel
    AlignWithMargins = True
    Left = 3
    Top = 3
    Width = 468
    Height = 397
    Align = alClient
    BevelOuter = bvNone
    ColumnCollection = <
      item
        Value = 20.000000000000000000
      end
      item
        Value = 60.000000000000000000
      end
      item
        Value = 20.000000000000000000
      end>
    ControlCollection = <
      item
        Column = 1
        Control = StartButton
        Row = 4
      end
      item
        Column = 1
        Control = StopButton
        Row = 5
      end
      item
        Column = 1
        Control = InfoPanel
        Row = 1
      end
      item
        Column = 1
        Control = SyncObjGroup
        Row = 3
      end>
    RowCollection = <
      item
        Value = 20.000000000000000000
      end
      item
        SizeStyle = ssAbsolute
        Value = 96.000000000000000000
      end
      item
        Value = 60.000000000000000000
      end
      item
        SizeStyle = ssAbsolute
        Value = 72.000000000000000000
      end
      item
        SizeStyle = ssAbsolute
        Value = 36.000000000000000000
      end
      item
        SizeStyle = ssAbsolute
        Value = 36.000000000000000000
      end
      item
        Value = 20.000000000000000000
      end>
    TabOrder = 1
    object StartButton: TButton
      AlignWithMargins = True
      Left = 96
      Top = 296
      Width = 274
      Height = 30
      Align = alClient
      Caption = #1047#1072#1087#1091#1089#1090#1080#1090#1100' '#1087#1086#1090#1086#1082#1080
      TabOrder = 0
      OnClick = StartButtonClick
    end
    object StopButton: TButton
      AlignWithMargins = True
      Left = 96
      Top = 332
      Width = 274
      Height = 30
      Align = alClient
      Caption = #1054#1089#1090#1072#1085#1086#1074#1080#1090#1100' '#1087#1086#1090#1086#1082#1080
      Enabled = False
      TabOrder = 1
      OnClick = StopButtonClick
    end
    object InfoPanel: TPanel
      Left = 93
      Top = 31
      Width = 280
      Height = 96
      Align = alClient
      BevelOuter = bvNone
      DoubleBuffered = True
      ParentDoubleBuffered = False
      TabOrder = 2
      object CountLabel: TLabel
        AlignWithMargins = True
        Left = 3
        Top = 25
        Width = 274
        Height = 16
        Align = alTop
        Caption = #1050#1086#1083'-'#1074#1086' '#1086#1087#1077#1088#1072#1094#1080#1081':'
        Layout = tlCenter
        ExplicitWidth = 105
      end
      object IDLabel: TLabel
        AlignWithMargins = True
        Left = 3
        Top = 3
        Width = 274
        Height = 16
        Align = alTop
        Caption = 'ID '#1087#1086#1090#1086#1082#1072':'
        Layout = tlCenter
        ExplicitWidth = 61
      end
      object DateLabel: TLabel
        AlignWithMargins = True
        Left = 3
        Top = 47
        Width = 274
        Height = 46
        Align = alClient
        Caption = #1044#1072#1090#1072':'
        Layout = tlCenter
        ExplicitWidth = 34
        ExplicitHeight = 16
      end
    end
    object SyncObjGroup: TRadioGroup
      AlignWithMargins = True
      Left = 96
      Top = 224
      Width = 274
      Height = 66
      Align = alClient
      Caption = #1054#1073#1098#1077#1082#1090' '#1089#1080#1085#1093#1088#1086#1085#1080#1079#1072#1094#1080#1080':'
      ItemIndex = 0
      Items.Strings = (
        'TMonitor'
        'TCriticalSection')
      TabOrder = 3
    end
  end
  object UpdateTimer: TTimer
    Enabled = False
    Interval = 500
    OnTimer = UpdateTimerTimer
    Left = 16
    Top = 16
  end
end
