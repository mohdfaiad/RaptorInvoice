unit mainform;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  ActnList, StdCtrls, RzEdit, RzTabs, Db, VolgaTbl, RzCommon, RzPrgres,
  ExtCtrls, RzDlgBtn, RzShellDialogs, RzStatus, uBinaryData;

type
  TForm1 = class(TForm)
    RzDialogButtons1: TRzDialogButtons;
    RzFrameController1: TRzFrameController;
    dba: TVolgaTable;
    RzPageControl1: TRzPageControl;
    TabSheet1: TRzTabSheet;
    ActionList1: TActionList;
    DoStart: TAction;
    Panel1: TPanel;
    RzMemo1: TRzMemo;
    FolderDialog: TRzSelectFolderDialog;
    Dbb: TVolgaTable;
    lbStatus: TRzStatusPane;
    Programdata: TBinaryData;
    procedure DoStartExecute(Sender: TObject);
  private
    Procedure DoUpdate;
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.DFM}

  procedure TForm1.DoStartExecute(Sender: TObject);
  Begin
    try
      DoUpdate;
    finally
      lbStatus.Caption:='Venter';
    end;
  end;

  Procedure TForm1.DoUpdate;
  var
    FFilename:  String;
    FTempFile:  String;
    x:          Integer;
  begin
    DoStart.Enabled:=False;

    lbStatus.Caption:='Velg mappe';
    If not FolderDialog.Execute then
    Begin
      DoStart.Enabled:=True;
      exit;
    end;

    (* lokaliser fakturadata filen *)
    lbStatus.Caption:='Lokaliserer faktura database';
    FFilename:=IncludeTrailingBackSlash(FolderDialog.SelectedFolder.PathName) + 'data\faktura.d';
    If not FileExists(FFilename) then
    Begin
      Application.MessageBox('Faktura databasen ble desverre ikke funnet.'#13'Husk at du m� velge hovedmappen til programmet','Fant ikke database',MB_OK);
      DoStart.Enabled:=True;
      exit;
    end;

    (* pr�ve og �pne database *)
    lbStatus.Caption:='�pner database';
    try
      dba.Password:='88upsbe';
      dba.tablename:=FFilename;
      dba.Open;
    except
      on exception do
      Begin
        Application.MessageBox('Det oppstod et problem ved � �pne database filen.'#13'Filen kan v�re skadet. Ring v�rt service nummber for hjelp.','Klarte ikke � �pne database',MB_OK);
        DoStart.Enabled:=True;
        exit;
      end;
    end;

    (* sjekke om databasen er av den gamle sorten *)
    lbStatus.Caption:='Analyserer versjon og felter';
    If dba.Fields.FindField('dinref')<>NIL then
    Begin
      dba.close;
      Application.MessageBox('Databasen er allerede oppdatert!','Raptor Faktura',MB_OK);
      DoStart.Enabled:=True;
      exit;
    end;

    (* bygge filnavn til temp fil *)
    FTempFile:=IncludeTrailingBackSlash(FolderDialog.SelectedFolder.PathName) + 'data\_temp.d';
    If FileExists(FTempFile) then
    DeleteFile(FTempFile);

    (* hente "default" felter - og putte de over i v�rt "temp" dataset *)
    lbStatus.Caption:='Bygger midlertidig database';
    for x:=1 to dba.FieldCount do
    Dbb.FieldDefs.Add
      (
      dba.Fields[x-1].FieldName,
      dba.Fields[x-1].DataType,
      dba.Fields[x-1].Size
      );

    (* legge til nye felter *)
    dbb.fielddefs.add('minref',ftString,64);
    dbb.FieldDefs.Add('dinref',ftString,64);

    (* skape temp database *)
    try
      (* password og slikt *)
      dbb.Password:='88upsbe';
      dbb.Active:=True;
      dbb.SaveToFile(FTempFile);
      dbb.close;
    except
      on exception do
      Begin
        dba.close;
        Application.MessageBox('Det oppstod et problem under konvertering.'#13'Kontakt JuraSoft','Raptor Faktura',MB_OK);
        DoStart.Enabled:=True;
        exit;
      end;
    end;

    (* �pne v�rt "temp" dataset *)
    try
      dbb.tablename:=FTempFile;
      dbb.Password:='88upsbe';
      dbb.Open;
    except
      on exception do
      Begin
        dba.active:=False;

        If fileexists(FTempFile) then
        DeleteFile(FTempFile);
        Application.MessageBox('Det oppstod et problem under konvertering.'#13'Kontakt JuraSoft','Raptor Faktura',MB_OK);
        DoStart.Enabled:=True;
        exit;
      end;
    end;

    (* flytte over data *)
    lbStatus.Caption:='Flytter informasjon';
    try
      try
        dbb.BatchMove(dba);
        dbb.ApplyUpdates;
      except
        on exception do
        Begin
          If fileexists(FTempFile) then
          DeleteFile(FTempFile);

          Application.MessageBox('Det oppstod et problem under konvertering.'#13'Kontakt JuraSoft','Raptor Faktura',MB_OK);
          DoStart.Enabled:=True;
          exit;
        end;
      end;
    finally
      dba.close;
      dbb.close;
    end;

    try
      lbStatus.Caption:='Oppdaterer programvaren';
      
      (* oppdatere programvaren *)
      FTempFile:=IncludeTrailingBackSlash(FolderDialog.SelectedFolder.PathName) + 'raptor.exe';
      try
        If fileexists(FTempFile) then
        DeleteFile(FTempFile);

        Programdata.SaveToFile(FTempFile);
      except
        on exception do
        Application.MessageBox('Fikk ikke tilgang p� programmet!'#13'OBS: Raptor m� ikke v�re i bruk n�r du oppdaterer!','Raptor Faktura',MB_OK);
      end;

    finally
      lbStatus.Caption:='Bytter database med ny versjon';
      Renamefile(FFilename,ExtractFilePath(FFilename) + '_FakturaBackup.dat');
      RenameFile(FTempFile,ExtractFilePath(FTempFile) + 'faktura.d');
    end;

    Application.MessageBox('Oppdateringen er fullf�rt','Raptor Faktura',MB_OK);
  end;

end.
