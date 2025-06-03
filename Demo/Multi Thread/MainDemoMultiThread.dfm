object frmMain: TfrmMain
  Left = 0
  Top = 0
  Margins.Left = 4
  Margins.Top = 4
  Margins.Right = 4
  Margins.Bottom = 4
  Caption = 'Zen Logger Demo'
  ClientHeight = 789
  ClientWidth = 1263
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -18
  Font.Name = 'Segoe UI'
  Font.Style = []
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnShow = FormShow
  PixelsPerInch = 144
  TextHeight = 25
  object grdResults: TDBGrid
    Left = 0
    Top = 222
    Width = 1263
    Height = 567
    Margins.Left = 5
    Margins.Top = 5
    Margins.Right = 5
    Margins.Bottom = 5
    Align = alClient
    DataSource = dsResults
    TabOrder = 0
    TitleFont.Charset = DEFAULT_CHARSET
    TitleFont.Color = clWindowText
    TitleFont.Height = -18
    TitleFont.Name = 'Segoe UI'
    TitleFont.Style = []
    Columns = <
      item
        Expanded = False
        FieldName = 'Kind'
        Visible = True
      end
      item
        Expanded = False
        FieldName = 'KindName'
        Visible = True
      end
      item
        Expanded = False
        FieldName = 'ThreadID'
        Visible = True
      end
      item
        Expanded = False
        FieldName = 'StartTime'
        Visible = True
      end
      item
        Expanded = False
        FieldName = 'EndTime'
        Visible = True
      end
      item
        Expanded = False
        FieldName = 'LogTime'
        Visible = True
      end
      item
        Expanded = False
        FieldName = 'FlushTime'
        Visible = True
      end
      item
        Expanded = False
        FieldName = 'TotalTime'
        Visible = True
      end>
  end
  object pnlTest: TPanel
    Left = 0
    Top = 126
    Width = 1263
    Height = 96
    Margins.Left = 5
    Margins.Top = 5
    Margins.Right = 5
    Margins.Bottom = 5
    Align = alTop
    BevelInner = bvRaised
    BevelOuter = bvLowered
    TabOrder = 1
    DesignSize = (
      1263
      96)
    object lblLogKind: TLabel
      Left = 16
      Top = 14
      Width = 70
      Height = 25
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Caption = 'Log Kind'
    end
    object lblDataCount: TLabel
      Left = 630
      Top = 14
      Width = 89
      Height = 25
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Caption = 'No of rows'
    end
    object lblThreadCount: TLabel
      Left = 282
      Top = 14
      Width = 113
      Height = 25
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Caption = 'No of Threads'
    end
    object lblWorkload: TLabel
      Left = 806
      Top = 14
      Width = 77
      Height = 25
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Caption = 'Workload'
    end
    object edDataCount: TSpinEdit
      Left = 630
      Top = 40
      Width = 151
      Height = 36
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Increment = 100
      MaxLength = 7
      MaxValue = 9999900
      MinValue = 10
      TabOrder = 1
      Value = 100
    end
    object btnRun: TBitBtn
      Left = 901
      Top = 10
      Width = 350
      Height = 72
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Anchors = [akLeft, akTop, akRight]
      Caption = 'Run Tests'
      Constraints.MinWidth = 150
      TabOrder = 2
      OnClick = btnRunClick
    end
    object edThreadCount: TSpinEdit
      Left = 282
      Top = 40
      Width = 113
      Height = 36
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      MaxLength = 1
      MaxValue = 9
      MinValue = 1
      TabOrder = 3
      Value = 2
    end
    object cbSameFile: TCheckBox
      Left = 422
      Top = 24
      Width = 179
      Height = 26
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Caption = 'Log to Same File'
      Checked = True
      State = cbChecked
      TabOrder = 4
      OnClick = cate
    end
    object edWorkload: TSpinEdit
      Left = 806
      Top = 40
      Width = 77
      Height = 36
      Hint = 'Add Sleep(X) to simulate a workload between log entries'
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      MaxLength = 3
      MaxValue = 999
      MinValue = 0
      ParentShowHint = False
      ShowHint = True
      TabOrder = 5
      Value = 0
    end
    object cbSameLogger: TCheckBox
      Left = 422
      Top = 60
      Width = 179
      Height = 26
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Caption = 'Use same Logger'
      Checked = True
      State = cbChecked
      TabOrder = 6
    end
    object cbLogKind: TComboBox
      Left = 16
      Top = 40
      Width = 256
      Height = 33
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Style = csDropDownList
      DropDownWidth = 218
      ItemIndex = 1
      TabOrder = 0
      Text = 'Standard'
      StyleElements = [seBorder]
      Items.Strings = (
        'Null'
        'Standard'
        'Console'
        'Async'
        'ThreadSafe'
        'Mock')
    end
  end
  object cpgConfig: TCategoryPanelGroup
    Left = 0
    Top = 0
    Width = 1263
    Height = 126
    Margins.Left = 5
    Margins.Top = 5
    Margins.Right = 5
    Margins.Bottom = 5
    HorzScrollBar.Visible = False
    VertScrollBar.Tracking = True
    VertScrollBar.Visible = False
    Align = alTop
    HeaderFont.Charset = DEFAULT_CHARSET
    HeaderFont.Color = clWindowText
    HeaderFont.Height = -18
    HeaderFont.Name = 'Segoe UI'
    HeaderFont.Style = []
    HeaderHeight = 36
    TabOrder = 2
    object cpnlConfig: TCategoryPanel
      Top = 0
      Height = 121
      Margins.Left = 5
      Margins.Top = 5
      Margins.Right = 5
      Margins.Bottom = 5
      Caption = 'Default Zen Logger Demo Options'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -18
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      TabOrder = 0
      OnCollapse = cpnlConfigCollapse
      OnExpand = cpnlConfigExpand
      object pnlConfig: TPanel
        Left = 0
        Top = 0
        Width = 1257
        Height = 85
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Align = alTop
        BevelInner = bvRaised
        BevelOuter = bvLowered
        TabOrder = 0
        DesignSize = (
          1257
          85)
        object lblPath: TLabel
          Left = 16
          Top = 11
          Width = 69
          Height = 25
          Margins.Left = 5
          Margins.Top = 5
          Margins.Right = 5
          Margins.Bottom = 5
          Caption = 'Log Path'
        end
        object SpeedButton1: TSpeedButton
          Left = 565
          Top = 42
          Width = 35
          Height = 34
          Margins.Left = 5
          Margins.Top = 5
          Margins.Right = 5
          Margins.Bottom = 5
          Anchors = [akTop, akRight]
          Caption = '. . .'
          ExplicitLeft = 540
        end
        object lblLevel: TLabel
          Left = 992
          Top = 12
          Width = 74
          Height = 25
          Margins.Left = 5
          Margins.Top = 5
          Margins.Right = 5
          Margins.Bottom = 5
          Anchors = [akTop, akRight]
          Caption = 'Log Level'
          ExplicitLeft = 967
        end
        object lblDaysKeep: TLabel
          Left = 1135
          Top = 11
          Width = 105
          Height = 25
          Margins.Left = 5
          Margins.Top = 5
          Margins.Right = 5
          Margins.Bottom = 5
          Anchors = [akTop, akRight]
          Caption = 'Days to Keep'
          ExplicitLeft = 1110
        end
        object edPath: TButtonedEdit
          Left = 16
          Top = 41
          Width = 549
          Height = 33
          Margins.Left = 5
          Margins.Top = 5
          Margins.Right = 5
          Margins.Bottom = 5
          Anchors = [akLeft, akTop, akRight]
          BevelKind = bkFlat
          BevelOuter = bvNone
          LeftButton.Visible = True
          RightButton.Visible = True
          TabOrder = 0
        end
        object edName: TLabeledEdit
          Left = 626
          Top = 42
          Width = 357
          Height = 33
          Margins.Left = 5
          Margins.Top = 5
          Margins.Right = 5
          Margins.Bottom = 5
          Anchors = [akTop, akRight]
          EditLabel.Width = 82
          EditLabel.Height = 25
          EditLabel.Margins.Left = 17
          EditLabel.Margins.Top = 17
          EditLabel.Margins.Right = 17
          EditLabel.Margins.Bottom = 17
          EditLabel.Caption = 'Log Name'
          TabOrder = 1
          Text = ''
        end
        object cbLogLevel: TComboBox
          Left = 992
          Top = 42
          Width = 133
          Height = 33
          Margins.Left = 5
          Margins.Top = 5
          Margins.Right = 5
          Margins.Bottom = 5
          Style = csDropDownList
          Anchors = [akTop, akRight]
          ItemIndex = 3
          TabOrder = 2
          Text = '3 - Info'
          Items.Strings = (
            '0 - None'
            '1 - Error'
            '2 - Warning'
            '3 - Info'
            '4 - Debug'
            '5 - Trace')
        end
        object edDaylsKeep: TSpinEdit
          Left = 1135
          Top = 40
          Width = 113
          Height = 36
          Margins.Left = 5
          Margins.Top = 5
          Margins.Right = 5
          Margins.Bottom = 5
          Anchors = [akTop, akRight]
          MaxLength = 2
          MaxValue = 99
          MinValue = 1
          TabOrder = 3
          Value = 2
        end
      end
    end
  end
  object cdsResults: TClientDataSet
    Aggregates = <>
    Params = <>
    Left = 138
    Top = 438
    object cdsResultsID: TIntegerField
      FieldName = 'ID'
      KeyFields = 'ID'
      Required = True
      Visible = False
    end
    object cdsResultsKind: TIntegerField
      DisplayLabel = 'Kind #'
      FieldName = 'Kind'
      Required = True
    end
    object cdsResultsKindName: TStringField
      DisplayLabel = 'Log Kind'
      FieldName = 'KindName'
    end
    object cdsResultsThreadId: TIntegerField
      DisplayLabel = 'Thread #'
      FieldName = 'ThreadID'
    end
    object cdsResultsStartTime: TDateTimeField
      DisplayLabel = 'Start Time'
      FieldName = 'StartTime'
      DisplayFormat = 'hh:nn:ss.zzz'
    end
    object cdsResultsEndTime: TDateTimeField
      DisplayLabel = 'End Time'
      FieldName = 'EndTime'
      DisplayFormat = 'hh:nn:ss.zzz'
    end
    object cdsResultsLogTime: TIntegerField
      DisplayLabel = 'Log Time'
      FieldName = 'LogTime'
      DisplayFormat = '####,000" ms"'
    end
    object cdsResultsFlushTime: TIntegerField
      DisplayLabel = 'Flush Time'
      FieldName = 'FlushTime'
      DisplayFormat = '####,000" ms"'
    end
    object cdsResultsTotalTime: TIntegerField
      DisplayLabel = 'Total Time'
      FieldName = 'TotalTime'
      DisplayFormat = '####,000" ms"'
    end
  end
  object dsResults: TDataSource
    DataSet = cdsResults
    Left = 258
    Top = 438
  end
  object ImageList: TImageList
    Left = 384
    Top = 12
  end
  object OpenDialog: TOpenDialog
    Options = [ofHideReadOnly, ofPathMustExist, ofEnableSizing]
    Left = 216
    Top = 12
  end
  object TimerTestRunning: TTimer
    Enabled = False
    Interval = 100
    OnTimer = TimerTestRunningTimer
    Left = 660
    Top = 348
  end
end
