unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, Menus, ComCtrls,
  StdCtrls, Buttons, LazSerial, Synaser, CRC;

type

  { TFormVectrexCartridgeProgrammer }

  TFormVectrexCartridgeProgrammer = class(TForm)
    BitBtn1: TBitBtn;
    BitBtn2: TBitBtn;
    ButtonCOMRefresh: TBitBtn;
    ButtonCOMConnect: TBitBtn;
    ButtonCOMDisconnect: TBitBtn;
    ButtonReadRom: TBitBtn;
    ButtonWriteEEPROM: TBitBtn;
    ComboBoxSize: TComboBox;
    ComboBoxCOM: TComboBox;
    GroupBoxLog: TGroupBox;
    GroupBoxControl: TGroupBox;
    LabelCRC: TLabel;
    LabelCOM: TLabel;
    LabelSize: TLabel;
    LazSerial: TLazSerial;
    MemoHexView: TMemo;
    MemoLog: TMemo;
    OpenDialog: TOpenDialog;
    PageControl1: TPageControl;
    ProgressBar: TProgressBar;
    SaveDialog: TSaveDialog;
    StaticTextFile: TStaticText;
    TabReadWrite: TTabSheet;
    TabHexView: TTabSheet;
    TabAbout: TTabSheet;
    ToolBarLog: TToolBar;
    ToolButtonClearLog: TToolButton;
    ToolButtonAutoScroll: TToolButton;
    procedure BitBtn1Click(Sender: TObject);
    procedure BitBtn2Click(Sender: TObject);
    procedure ButtonClearLogClick(Sender: TObject);
    procedure ButtonCOMConnectClick(Sender: TObject);
    procedure ButtonCOMDisconnectClick(Sender: TObject);
    procedure ButtonCOMRefreshClick(Sender: TObject);
    procedure ButtonReadRomClick(Sender: TObject);
    procedure ButtonWriteEEPROMClick(Sender: TObject);
    procedure CheckBoxAutoScrollChange(Sender: TObject);
    procedure ComboBoxSizeChange(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure LazSerialRxData(Sender: TObject);
    procedure ToolButtonClearLogClick(Sender: TObject);
  private
    procedure LoadHexView(Sender: TObject);
  public

  end;

type
  TReadThread = class(TThread)
  private
    buffer4: array[0..3] of byte;
    progress: integer;
    procedure ReadSerial;
    procedure MemoLogError;
    procedure ProgressBar;
    procedure LoadHexView;
  protected
    procedure Execute; override;
  public
    Constructor Create(CreateSuspended : boolean);
  end;

type
  TWriteThread = class(TThread)
  private
    buffer4: array[0..3] of byte;
    buffer64: array[0..63] of byte;
    progress: integer;
    procedure WriteSerial4;
    procedure WriteSerial64;
    procedure MemoLogError;
    procedure ProgressBar;
  protected
    procedure Execute; override;
  public
    Constructor Create(CreateSuspended : boolean);
  end;

var
  FormVectrexCartridgeProgrammer: TFormVectrexCartridgeProgrammer;

implementation

{$R *.lfm}

{ TFormVectrexCartridgeProgrammer }

var
  BufferROM: array[0..32767] of byte;
  SizeRom: LongInt;
  SerialData: String;
  OperationInProgress: integer;
  CurrentCode: Byte;
  Address: integer;

constructor TReadThread.Create(CreateSuspended : boolean);
  begin
    FreeOnTerminate := True;
    inherited Create(CreateSuspended);
  end;

procedure TReadThread.ReadSerial;
begin
  FormVectrexCartridgeProgrammer.LazSerial.WriteBuffer(buffer4, 4);
  FormVectrexCartridgeProgrammer.MemoLog.Append(Format('%.2X%.2X%.2X%.2X', [buffer4[0], buffer4[1],buffer4[2],buffer4[3]]));
end;

procedure TReadThread.MemoLogError;
begin
  FormVectrexCartridgeProgrammer.MemoLog.Lines.Append('ERROR: Timeout');
end;

procedure TReadThread.ProgressBar;
begin
  FormVectrexCartridgeProgrammer.ProgressBar.Position:= progress;
end;

procedure TReadThread.LoadHexView;
begin
  FormVectrexCartridgeProgrammer.LoadHexView(Self);
end;

procedure TReadThread.Execute;
var
  i: integer;
begin
  i:= 0;
  while i < SizeRom do begin
    buffer4[0]:= $06;
    buffer4[1]:= i div 256;
    buffer4[2]:= i and $00FF;
    buffer4[3]:= 64;
    OperationInProgress:= 100;
    Synchronize(@ReadSerial);
    while OperationInProgress > 1 do begin
      dec(OperationInProgress);
      Sleep(1);
      end;
    if OperationInProgress = 1 then begin
      Synchronize(@MemoLogError);
      Break;
      end;
    i:= i + 64;
    progress:= i * 100 div SizeRom;
    Synchronize(@ProgressBar);
    if progress = 100 then
      Synchronize(@LoadHexView);
    end;
end;

constructor TWriteThread.Create(CreateSuspended : boolean);
  begin
    FreeOnTerminate := True;
    inherited Create(CreateSuspended);
  end;

procedure TWriteThread.WriteSerial4;
begin
  FormVectrexCartridgeProgrammer.LazSerial.WriteBuffer(buffer4, 4);
  FormVectrexCartridgeProgrammer.MemoLog.Append(Format('%.2X%.2X%.2X%.2X', [buffer4[0], buffer4[1],buffer4[2],buffer4[3]]));
end;

procedure TWriteThread.WriteSerial64;
begin
  FormVectrexCartridgeProgrammer.LazSerial.WriteBuffer(buffer64, 64);
  FormVectrexCartridgeProgrammer.MemoLog.Append('Send Block');
end;

procedure TWriteThread.MemoLogError;
begin
  FormVectrexCartridgeProgrammer.MemoLog.Lines.Append('ERROR: Timeout');
end;

procedure TWriteThread.ProgressBar;
begin
  FormVectrexCartridgeProgrammer.ProgressBar.Position:= progress;
end;

procedure TWriteThread.Execute;
var
  i, j: integer;
begin
  i:= 0;
  while i < SizeRom do begin
    buffer4[0]:= $02;
    buffer4[1]:= i div 256;
    buffer4[2]:= i and $00FF;
    buffer4[3]:= 64;
    Synchronize(@WriteSerial4);
    for j:= 0 to 63 do
      buffer64[j]:= BufferROM[i + j];
    Synchronize(@WriteSerial64);
    Sleep(100);
    i:= i + 64;
    progress:= i * 100 div SizeRom;
    Synchronize(@ProgressBar);
  end;
end;

procedure TFormVectrexCartridgeProgrammer.LoadHexView(Sender: TObject);
var
  i, i16: integer;
begin
  MemoHexView.Clear;
  for i:= 0 to SizeRom div 16 do begin
    i16:= i * 16;
    MemoHexView.Lines.Append(Format('%.4X   %.2X %.2X %.2X %.2X %.2X %.2X %.2X %.2X %.2X %.2X %.2X %.2X %.2X %.2X %.2X %.2X',
      [i16, BufferROM[i16], BufferROM[i16 + 1], BufferROM[i16 + 2], BufferROM[i16 + 3], BufferROM[i16 + 4], BufferROM[i16 + 5], BufferROM[i16 + 6], BufferROM[i16 + 7], BufferROM[i16 + 8],
      BufferROM[i16 + 9], BufferROM[i16 + 10], BufferROM[i16 + 11], BufferROM[i16 + 12], BufferROM[i16 + 13], BufferROM[i16 + 14], BufferROM[i16 + 15]]));
    end;

end;

procedure TFormVectrexCartridgeProgrammer.BitBtn1Click(Sender: TObject);
var
  F: File of byte;
  FileName: String;
  SizeFile, i: integer;
begin
  if OpenDialog.Execute then begin
    FileName:= OpenDialog.FileName;
    if FileExists(FileName) then begin
      AssignFile(F, FileName);
      Reset(F);
      SizeFile:= FileSize(F);
      case SizeFile of
        1..1024:      begin ComboBoxSize.ItemIndex:= 1; SizeRom:= 1024; end;
        1025..2048:   begin ComboBoxSize.ItemIndex:= 2; SizeRom:= 2048; end;
        2049..4096:   begin ComboBoxSize.ItemIndex:= 3; SizeRom:= 4096; end;
        4097..8192:   begin ComboBoxSize.ItemIndex:= 4; SizeRom:= 8192; end;
        8193..16324:  begin ComboBoxSize.ItemIndex:= 5; SizeRom:= 16324; end;
        16325..32768: begin ComboBoxSize.ItemIndex:= 6; SizeRom:= 32768; end;
        else begin
          MessageDlg('Error', 'Incorect file size !', mtError, [mbClose], 0);
          Exit;
          end;
        end;
      for i:= 0 to 32767 do
        BufferROM[i]:= 0;
      StaticTextFile.Caption:= FileName;
      BlockRead(F, BufferROM, SizeFile);
      CloseFile(F);
      LabelCRC.Caption:= 'CRC : ' + IntToHex(crc32(0, @BufferROM[1], SizeRom), 8);
      LoadHexView(self);
      end;
    end;
end;

procedure TFormVectrexCartridgeProgrammer.BitBtn2Click(Sender: TObject);
var
  F: File of byte;
  FileName: String;
begin
  if SaveDialog.Execute then begin
    FileName:= SaveDialog.FileName;
    AssignFile(F, FileName);
    Rewrite(F);
    BlockWrite(F, BufferROM, SizeRom);
    CloseFile(F);
  end;
end;

procedure TFormVectrexCartridgeProgrammer.ButtonClearLogClick(Sender: TObject);
begin

end;

procedure TFormVectrexCartridgeProgrammer.ButtonCOMConnectClick(Sender: TObject
  );
begin
  LazSerial.Device:= ComboBoxCOM.Items[ComboBoxCOM.ItemIndex];
  LazSerial.Open;
  if LazSerial.Active then begin
    ButtonCOMRefresh.Enabled:= false;
    ButtonCOMConnect.Enabled:= false;
    ButtonCOMDisconnect.Enabled:= true;
    end;
end;

procedure TFormVectrexCartridgeProgrammer.ButtonCOMDisconnectClick(
  Sender: TObject);
begin
  LazSerial.Close;
  ButtonCOMRefresh.Enabled:= true;
  ButtonCOMConnect.Enabled:= true;
  ButtonCOMDisconnect.Enabled:= false;
end;

procedure TFormVectrexCartridgeProgrammer.ButtonCOMRefreshClick(Sender: TObject
  );
begin
  LazSerial.Close;
  ComboBoxCOM.Items.CommaText:= GetSerialPortNames;
  ComboBoxCOM.ItemIndex:= 0;
end;

procedure TFormVectrexCartridgeProgrammer.ButtonReadRomClick(Sender: TObject);
var
  ReadThread: TReadThread;
  buffer4: array[0..3] of byte;
  i, j: integer;
  TempSerialData: String;
begin
  ReadThread:= TReadThread.Create(True);
  ReadThread.Start;
{  i:= 0;
  while i < SizeRom do begin
    buffer4[0]:= $06;
    buffer4[1]:= i div 256;
    buffer4[2]:= i and $00FF;
    buffer4[3]:= 64;
    OperationInProgress:= 100;
    LazSerial.WriteBuffer(buffer4, 4);
    MemoLog.Append(Format('%.2X%.2X%.2X%.2X', [buffer4[0], buffer4[1],buffer4[2],buffer4[3]]));
    OperationInProgress:= 100;
    while not LazSerial.DataAvailable and (OperationInProgress > 1) do begin
      Dec(OperationInProgress);
      Sleep(1);
      end;
    TempSerialData:= LazSerial.ReadData;
    while (Length(TempSerialData) < 68) and (OperationInProgress > 1) do
      if LazSerial.DataAvailable then
        TempSerialData:= TempSerialData + LazSerial.ReadData
      else
        Dec(OperationInProgress);
    if OperationInProgress > 1 then begin
      address:= (Ord(TempSerialData[2]) shl 8) + Ord(TempSerialData[3]);
      for j:= 0 to Length(TempSerialData) - 5 do
        BufferROM[address + j]:= Ord(TempSerialData[j + 5]);
      MemoLog.Append(Format('Return %.2X%.2X%.2X%.2X', [Ord(TempSerialData[1]), Ord(TempSerialData[2]), Ord(TempSerialData[3]), Ord(TempSerialData[4])]));
      MemoLog.Append(Format('Read block of address %.4X', [address]));
      MemoLog.Lines.Append(Format('%.2X %.2X %.2X %.2X %.2X %.2X %.2X %.2X %.2X %.2X %.2X %.2X %.2X %.2X %.2X %.2X',
                                  [BufferROM[address], BufferROM[address + 1], BufferROM[address + 2], BufferROM[address + 3], BufferROM[address + 4], BufferROM[address + 5],
                                   BufferROM[address + 6], BufferROM[address + 7], BufferROM[address + 8], BufferROM[address + 9], BufferROM[address + 10],
                                   BufferROM[address + 11], BufferROM[address + 12], BufferROM[address + 13], BufferROM[address + 14], BufferROM[address + 15]]));
      end
    else begin
      MemoLog.Lines.Append('ERROR: Timeout');
      Exit;
      end;
    i:= i + 64;
    ProgressBar.Position:= i * 100 div SizeRom;
    end; }
  //LoadHexView(self);
end;

procedure TFormVectrexCartridgeProgrammer.ButtonWriteEEPROMClick(Sender: TObject);
var
  WriteThread: TWriteThread;
//begin
//  WriteThread:= TWriteThread.Create(True);
//  WriteThread.Start;
var
  i, j: integer;
  buffer4: array[0..3] of byte;
  buffer64: array[0..63] of byte;
begin
  i:= 0;
  while i < SizeRom do begin
    buffer4[0]:= $02;
    buffer4[1]:= i div 256;
    buffer4[2]:= i and $00FF;
    buffer4[3]:= 64;
    LazSerial.WriteBuffer(buffer4, 4);
    for j:= 0 to 63 do
      buffer64[j]:= BufferROM[i + j];
    MemoLog.Append(Format('%.2X%.2X%.2X%.2X', [buffer4[0], buffer4[1],buffer4[2],buffer4[3]]));
    //Sleep(100);
    LazSerial.WriteBuffer(buffer64, 64);
    Sleep(200);
    i:= i + 64;
  end;
end;

procedure TFormVectrexCartridgeProgrammer.CheckBoxAutoScrollChange(Sender: TObject);
begin

end;

procedure TFormVectrexCartridgeProgrammer.ComboBoxSizeChange(Sender: TObject);
begin
  case ComboBoxSize.ItemIndex of
    1: SizeRom:= 1024;
    2: SizeRom:= 2048;
    3: SizeRom:= 4096;
    4: SizeRom:= 8192;
    5: SizeRom:= 16324;
    6: SizeRom:= 32768;
    end;
end;

procedure TFormVectrexCartridgeProgrammer.FormActivate(Sender: TObject);
begin
  ComboBoxCOM.Items.CommaText:= GetSerialPortNames;
  ComboBoxCOM.ItemIndex:= 0;
end;

procedure TFormVectrexCartridgeProgrammer.LazSerialRxData(Sender: TObject);
var
  i: integer;
begin
  if CurrentCode = $06 then
    SerialData:= SerialData + LazSerial.ReadData
  else
    SerialData:= LazSerial.ReadData;
  CurrentCode:= Ord(SerialData[1]);
  MemoLog.Append(Format('Return: %d bytes', [Length(SerialData)]));
  case CurrentCode of
    $01: Sleep(1);// Write Single Byte
    $02: begin// Write Page Mode
         MemoLog.Append('Return Write Page OK');
         end;
    $03: Sleep(1);// Write Protect
    $04: Sleep(1);// Write Unprotect
    $05: Sleep(1);// Read Single Byte
    $06: begin // Read Page Mode
           if Length(SerialData) >= Ord(SerialData[4]) + 4 then begin
             address:= (Ord(SerialData[2]) shl 8) + Ord(SerialData[3]);
             for i:= 0 to Length(SerialData) - 5 do
               BufferROM[address + i]:= Ord(SerialData[i + 5]);
             MemoLog.Append(Format('Return %.2X%.2X%.2X%.2X', [Ord(SerialData[1]), Ord(SerialData[2]), Ord(SerialData[3]), Ord(SerialData[4])]));
             MemoLog.Append(Format('Read block of address %.4X', [address]));
             MemoLog.Lines.Append(Format('%.2X %.2X %.2X %.2X %.2X %.2X %.2X %.2X %.2X %.2X %.2X %.2X %.2X %.2X %.2X %.2X',
                                         [BufferROM[address], BufferROM[address + 1], BufferROM[address + 2], BufferROM[address + 3], BufferROM[address + 4], BufferROM[address + 5],
                                          BufferROM[address + 6], BufferROM[address + 7], BufferROM[address + 8], BufferROM[address + 9], BufferROM[address + 10],
                                          BufferROM[address + 11], BufferROM[address + 12], BufferROM[address + 13], BufferROM[address + 14], BufferROM[address + 15]]));
             end
           else
             Exit;
         end;
    $12: begin// Write Page Mode
         MemoLog.Append('Return Write Page Waiting Data');
         end;
    $E2: begin// Write Page Mode
         MemoLog.Append('Return Write Page Error');
         end;
    $E6: MemoLog.Append(Format('ERROR reading memory at address %.2X%.2X', [Ord(SerialData[2]), Ord(SerialData[3])]));
  else
    MemoLog.Append(Format('ERROR unknow opcode %.2X', [Ord(SerialData[1])]));
  end;
  CurrentCode:= $00;
  OperationInProgress:= 0;
end;

procedure TFormVectrexCartridgeProgrammer.ToolButtonClearLogClick(
  Sender: TObject);
begin
  MemoLog.Clear;
end;

end.

