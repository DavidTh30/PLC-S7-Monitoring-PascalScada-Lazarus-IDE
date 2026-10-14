unit uabout;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, StdCtrls, ExtCtrls, LCLVersion;

const
  AppName = 'Siemens S7 PLC Online Monitor';
  AppVersion = '1.0.0';
  PascalScadaVersion = '0.7.7';

type

  { TfrmAbout }

  TfrmAbout = class(TForm)
    bvlLine: TBevel;
    btnOK: TButton;
    lblBuilt: TLabel;
    lblDescription: TLabel;
    lblTitle: TLabel;
    lblVersion: TLabel;
    pnlHeader: TPanel;
    procedure FormCreate(Sender: TObject);
  end;

procedure ShowAboutDialog;

implementation

{$R *.lfm}

procedure ShowAboutDialog;
begin
  with TfrmAbout.Create(Application.MainForm) do
  try
    ShowModal;
  finally
    Free;
  end;
end;

{ TfrmAbout }

procedure TfrmAbout.FormCreate(Sender: TObject);
begin
  lblTitle.Caption := AppName;
  lblVersion.Caption := 'Version ' + AppVersion;
  lblDescription.Caption :=
    'Online monitoring of Siemens S7-300 / 400 / 1200 / 1500 PLCs over ' +
    'ISO-on-TCP (port 102). Read and write I, Q, M and DB variables, ' +
    'trend them on a live chart and export the data to CSV.';
  lblBuilt.Caption :=
    'Built with:' + LineEnding +
    '  PascalSCADA ' + PascalScadaVersion + LineEnding +
    '  TAChart' + LineEnding +
    '  Lazarus ' + lcl_version + '  /  Free Pascal ' + {$I %FPCVERSION%} + LineEnding +
    '  Target: ' + {$I %FPCTARGETCPU%} + '-' + {$I %FPCTARGETOS%} + LineEnding +
    LineEnding +
    'Build date: ' + {$I %DATE%} + ' ' + {$I %TIME%};
end;

end.
