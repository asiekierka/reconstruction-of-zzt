{
	Copyright (c) 2020 Adrian Siekierka

	Based on a reconstruction of code from ZZT,
	Copyright 1991 Epic MegaGames, used with permission.

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.
}

{$I-}
{$M 49152,163840,655360}
program ZZT;
uses Crt, Dos, Video, Keys, Sounds, Input, TxtWind, GameVars, Elements, Editor, Oop, Game;

procedure ParseArguments;
	var
		i: integer;
		pArg: string;
	begin
		for i := 1 to ParamCount do begin
			pArg := ParamStr(i);
			if pArg[1] = '/' then begin
				case UpCase(pArg[2]) of
					'T': begin
						SoundTimeCheckCounter := 0;
						UseSystemTimeForElapsed := false;
					end;
					'R': ResetConfig := true;
				end;
			end else begin
				StartupWorldFileName := pArg;
				if (Length(StartupWorldFileName) > 4) and (StartupWorldFileName[Length(StartupWorldFileName) - 3] = '.') then begin
					StartupWorldFileName := Copy(StartupWorldFileName, 1, Length(StartupWorldFileName) - 4);
				end;
			end;
		end;
	end;

procedure GameConfigure;
	var
		unk1: integer;
		joystickEnabled, mouseEnabled: boolean;
		cfgFile: text;
	begin
		ParsingConfigFile := true;
		EditorEnabled := true;
		ConfigRegistration := '';
		ConfigWorldFile := '';
		GameVersion := '3.2';

		Assign(cfgFile, 'zzt.cfg');
		Reset(cfgFile);
		if IOResult = 0 then begin
			Readln(cfgFile, ConfigWorldFile);
			Readln(cfgFile, ConfigRegistration);
		end;
		if ConfigWorldFile[1] = '*' then begin
			EditorEnabled := false;
			ConfigWorldFile := Copy(ConfigWorldFile, 2, Length(ConfigWorldFile) - 1);
		end;
		if Length(ConfigWorldFile) <> 0 then begin
			StartupWorldFileName := ConfigWorldFile;
		end;

		InputInitDevices;
		joystickEnabled := InputJoystickEnabled;
		mouseEnabled := InputMouseEnabled;

		ParsingConfigFile := false;

		Window(1, 1, 80, 25);
		TextBackground(Black);
		ClrScr;
		TextColor(White);
		TextColor(White);
		Writeln;
		Writeln('                                 <=-  ZZT  -=>');
		TextColor(Yellow);
		if Length(ConfigRegistration) = 0 then
			Writeln('                             Shareware version 3.2')
		else
			Writeln('                                  Version  3.2');
		Writeln('                            Created by Tim Sweeney');
		GotoXY(1, 7);
		TextColor(Blue);
		Write('================================================================================');
		GotoXY(1, 24);
		Write('================================================================================');
		TextColor(White);
		GotoXY(30, 7);
		Write(' Game Configuration ');
		GotoXY(1, 25);
		Write(' Copyright (c) 1991 Epic MegaGames                         Press ... to abort');
		TextColor(Black);
		TextBackground(LightGray);
		GotoXY(66, 25);
		Write('ESC');
		Window(1, 8, 80, 23);
		TextColor(Yellow);
		TextBackground(Black);
		ClrScr;
		TextColor(Yellow);
		if not InputConfigure then
			GameTitleExitRequested := true
		else begin
			TextColor(LightGreen);
			if not VideoConfigure then
				GameTitleExitRequested := true;
		end;
		Window(1, 1, 80, 25);
	end;

begin
	WorldFileDescCount := 7;
	WorldFileDescKeys[1] := 'TOWN';
	WorldFileDescValues[1] := 'TOWN       The Town of ZZT';
	WorldFileDescKeys[2] := 'DEMO';
	WorldFileDescValues[2] := 'DEMO       Demo of the ZZT World Editor';
	WorldFileDescKeys[3] := 'CAVES';
	WorldFileDescValues[3] := 'CAVES      The Caves of ZZT';
	WorldFileDescKeys[4] := 'DUNGEONS';
	WorldFileDescValues[4] := 'DUNGEONS   The Dungeons of ZZT';
	WorldFileDescKeys[5] := 'CITY';
	WorldFileDescValues[5] := 'CITY       Underground City of ZZT';
	WorldFileDescKeys[6] := 'BEST';
	WorldFileDescValues[6] := 'BEST       The Best of ZZT';
	WorldFileDescKeys[7] := 'TOUR';
	WorldFileDescValues[7] := 'TOUR       Guided Tour ZZT'#39's Other Worlds';

	Randomize;
	SetCBreak(false);
	InitialTextAttr := TextAttr;

	StartupWorldFileName := 'TOWN';
	ResourceDataFileName := 'ZZT.DAT';
	ResetConfig := false;
	GameTitleExitRequested := false;
	GameConfigure;
	ParseArguments;

	if not GameTitleExitRequested then begin
		VideoInstall(80, Blue);
		OrderPrintId := @GameVersion;
		TextWindowInit(5, 3, 50, 18);
		New(IoTmpBuf);

		VideoHideCursor;
		ClrScr;

		TickSpeed := 4;
		DebugEnabled := false;
		SavedGameFileName := 'SAVED';
		SavedBoardFileName := 'TEMP';
		GenerateTransitionTable;
		WorldCreate;

		GameTitleLoop;

		Dispose(IoTmpBuf);
	end;

	SoundUninstall;
	SoundClearQueue;

	VideoUninstall;
	Port[PORT_CGA_PALETTE] := 0;
	TextAttr := InitialTextAttr;
	ClrScr;

	if Length(ConfigRegistration) = 0 then begin
		GamePrintRegisterMessage;
	end else begin
		Writeln;
		Writeln('  Registered version -- Thank you for playing ZZT.');
		Writeln;
	end;

	VideoShowCursor;
end.
