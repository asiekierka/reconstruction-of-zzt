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
unit TxtWind;

interface
	uses Video;
	const
		MAX_TEXT_WINDOW_LINES = 1024;
		MAX_RESOURCE_DATA_FILES = 24;
	type
		TTextWindowLine = string[50];
		TTextWindowState = record
			Selectable: boolean;
			LineCount: integer;
			LinePos: integer;
			Lines: array[1 .. MAX_TEXT_WINDOW_LINES] of ^TTextWindowLine;
			Hyperlink: string[20];
			Title: TTextWindowLine;
			LoadedFilename: string[50];
			ScreenCopy: array[1 .. 25] of string[160];
		end;
		TResourceDataHeader = record
			EntryCount: integer;
			Name: array[1 .. MAX_RESOURCE_DATA_FILES] of string[50];
			FileOffset: array[1 .. MAX_RESOURCE_DATA_FILES] of longint;
		end;
	var
		TextWindowX, TextWindowY: integer;
		TextWindowWidth, TextWindowHeight: integer;
		TextWindowStrInnerEmpty: TVideoLine;
		TextWindowStrText: TVideoLine;
		TextWindowStrInnerLine: TVideoLine;
		TextWindowStrTop: TVideoLine;
		TextWindowStrBottom: TVideoLine;
		TextWindowStrSep: TVideoLine;
		TextWindowStrInnerSep: TVideoLine;
		TextWindowStrInnerArrows: TVideoLine;
		TextWindowRejected: boolean;
		ResourceDataFileName: string[50];
		ResourceDataHeader: TResourceDataHeader;
		OrderPrintId: ^string;
	procedure TextWindowInitState(var state: TTextWindowState);
	procedure TextWindowDrawOpen(var state: TTextWindowState);
	procedure TextWindowDrawClose(var state: TTextWindowState);
	procedure TextWindowDraw(var state: TTextWindowState; withoutFormatting, viewingFile: boolean);
	procedure TextWindowAppend(var state: TTextWindowState; line: TTextWindowLine);
	procedure TextWindowFree(var state: TTextWindowState);
	procedure TextWindowSelect(var state: TTextWindowState; hyperlinkAsSelect, viewingFile: boolean);
	procedure TextWindowEdit(var state: TTextWindowState);
	procedure TextWindowOpenFile(filename: TTextWindowLine; var state: TTextWindowState);
	procedure TextWindowSaveFile(filename: TTextWindowLine; var state: TTextWindowState);
	procedure TextWindowDisplayFile(filename, title: string);
	procedure TextWindowInit(x, y, width, height: integer);

implementation
uses Crt, Input, Printer;

function UpCaseString(input: string): string;
	var
		i: integer;
	begin
		for i := 1 to Length(input) do
			input[i] := UpCase(input[i]);
		UpCaseString := input;
	end;

procedure TextWindowInitState(var state: TTextWindowState);
	begin
		with state do begin
			LineCount := 0;
			LinePos := 1;
			LoadedFilename := '';
		end;
	end;

procedure TextWindowDrawTitle(color: integer; title: TTextWindowLine);
	begin
		VideoWriteText(TextWindowX + 2, TextWindowY + 1, color, TextWindowStrInnerEmpty);
		VideoWriteText(TextWindowX + ((TextWindowWidth - Length(title)) div 2), TextWindowY + 1, color, title);
	end;

procedure TextWindowDrawOpen(var state: TTextWindowState);
	var
		ix, iy: integer;
	begin
		with state do begin
			for iy := 1 to (TextWindowHeight + 1) do
				VideoMove(TextWindowX, iy + TextWindowY - 1, TextWindowWidth, @ScreenCopy[iy], false);

			for iy := (TextWindowHeight div 2) downto 0 do begin
				VideoWriteText(TextWindowX, TextWindowY + iy + 1, $0F, TextWindowStrText);
				VideoWriteText(TextWindowX, TextWindowY + TextWindowHeight - iy - 1, $0F, TextWindowStrText);
				VideoWriteText(TextWindowX, TextWindowY + iy, $0F, TextWindowStrTop);
				VideoWriteText(TextWindowX, TextWindowY + TextWindowHeight - iy, $0F, TextWindowStrBottom);
				Delay(25);
			end;

			VideoWriteText(TextWindowX, TextWindowY + 2, $0F, TextWindowStrSep);
			TextWindowDrawTitle($1E, Title);
		end;
	end;

procedure TextWindowDrawClose(var state: TTextWindowState);
	var
		ix, iy: integer;
		unk1, unk2: integer;
	begin
		with state do begin
			for iy := 0 to (TextWindowHeight div 2) do begin
				VideoWriteText(TextWindowX, TextWindowY + iy, $0F, TextWindowStrTop);
				VideoWriteText(TextWindowX, TextWindowY + TextWindowHeight - iy, $0F, TextWindowStrBottom);
				Delay(18);
				VideoMove(TextWindowX, TextWindowY + iy, TextWindowWidth,
					@ScreenCopy[iy + 1], true);
				VideoMove(TextWindowX, TextWindowY + TextWindowHeight - iy, TextWindowWidth,
					@ScreenCopy[(TextWindowHeight - iy) + 1], true);
			end;
		end;
	end;

procedure TextWindowDrawLine(var state: TTextWindowState; lpos: integer; withoutFormatting, viewingFile: boolean);
	var
		lineY: integer;
		textOffset, textColor, textX: integer;
	begin
		with state do begin
			lineY := ((TextWindowY + lpos) - LinePos) + (TextWindowHeight div 2) + 1;
			if lpos = LinePos then
				VideoWriteText(TextWindowX + 2, lineY, $1C, TextWindowStrInnerArrows)
			else
				VideoWriteText(TextWindowX + 2, lineY, $1E, TextWindowStrInnerEmpty);
			if (lpos > 0) and (lpos <= LineCount) then begin
				if withoutFormatting then begin
					VideoWriteText(TextWindowX + 4, lineY, $1E, Lines[lpos]^);
				end else begin
					textOffset := 1;
					textColor := $1E;
					textX := TextWindowX + 4;
					if Length(state.Lines[lpos]^) > 0 then begin
						case state.Lines[lpos]^[1] of
							'!': begin
								textOffset := Pos(';', Lines[lpos]^) + 1;
								VideoWriteText(textX + 2, lineY, $1D, #16);
								textX := textX + 5;
								textColor := $1F;
							end;
							':': begin
								textOffset := Pos(';', Lines[lpos]^) + 1;
								textColor := $1F;
							end;
							'$': begin
								textOffset := 2;
								textColor := $1F;
								textX := (textX - 4) + ((TextWindowWidth - Length(Lines[lpos]^)) div 2);
							end;
						end;
					end;
					if textOffset > 0 then begin
						VideoWriteText(textX, lineY, textColor,
							Copy(Lines[lpos]^, textOffset,Length(Lines[lpos]^) - textOffset + 1));
					end;
				end;
			end else if (lpos = 0) or (lpos = (state.LineCount + 1)) then begin
				VideoWriteText(TextWindowX + 2, lineY, $1E, TextWindowStrInnerSep);
			end else if (lpos = -4) and viewingFile then begin
				VideoWriteText(TextWindowX + 2, lineY, $1A, '   Use            to view text,');
				VideoWriteText(TextWindowX + 2 + 7, lineY, $1F, #24' '#25', Enter');
			end else if (lpos = -3) and viewingFile then begin
				VideoWriteText(TextWindowX + 2 + 1, lineY, $1A, '                 to print.');
				VideoWriteText(TextWindowX + 2 + 12, lineY, $1F, 'Alt-P');
			end;
		end;
	end;

procedure TextWindowDraw(var state: TTextWindowState; withoutFormatting, viewingFile: boolean);
	var
		i: integer;
		unk1: integer;
	begin
		for i := 0 to (TextWindowHeight - 4) do
			TextWindowDrawLine(state, state.LinePos - (TextWindowHeight div 2) + i + 2,
				withoutFormatting, viewingFile);
		TextWindowDrawTitle($1E, state.Title);
	end;

procedure TextWindowAppend(var state: TTextWindowState; line: TTextWindowLine);
	begin
		with state do begin
			LineCount := LineCount + 1;
			New(Lines[LineCount]);
			Lines[LineCount]^ := line;
		end;
	end;

procedure TextWindowFree(var state: TTextWindowState);
	begin
		with state do begin
			while LineCount > 0 do begin
				Dispose(Lines[LineCount]);
				LineCount := LineCount - 1;
			end;
			LoadedFilename := '';
		end;
	end;

procedure TextWindowPrint(var state: TTextWindowState);
	var
		iLine, iChar: integer;
		line: string;
	begin
		with state do begin
			Rewrite(Lst);
			for iLine := 1 to LineCount do begin
				line := Lines[iLine]^;
				if Length(line) > 0 then begin
					case line[1] of
						'$': begin
							Delete(line, 1, 1);
							for iChar := ((80 - Length(line)) div 2) downto 1 do
								line := ' ' + line;
						end;
						'!', ':': begin
							iChar := Pos(';', line);
							if iChar > 0 then
								Delete(line, 1, iChar)
							else
								line := '';
						end;
					else
						line := '          ' + line
					end;
				end;
				WriteLn(Lst, line);
				if IOResult <> 0 then begin
					Close(Lst);
					exit;
				end;
			end;
			if LoadedFilename = 'ORDER.HLP' then begin
				WriteLn(Lst, OrderPrintId^);
			end;
			Write(Lst, Chr(12) { form feed });
			Close(Lst);
		end;
	end;

procedure TextWindowSelect(var state: TTextWindowState; hyperlinkAsSelect, viewingFile: boolean);
	var
		newLinePos: integer;
		unk1: integer;
		iLine, iChar: integer;
		pointerStr: string[20];
	label LabelMatched;
	label LabelNotMatched;
	begin
		with state do begin
			TextWindowRejected := false;
			Hyperlink := '';
			TextWindowDraw(state, false, viewingFile);
			repeat
				InputUpdate;
				newLinePos := LinePos;
				if InputDeltaY <> 0 then begin
					newLinePos := newLinePos + InputDeltaY;
				end else if InputShiftPressed or (InputKeyPressed = KEY_ENTER) then begin
					InputShiftAccepted := true;
					if (Lines[LinePos]^[1]) = '!' then begin
						pointerStr := Copy(Lines[LinePos]^, 2, Length(Lines[LinePos]^) - 1);

						if Pos(';', pointerStr) > 0 then begin
							pointerStr := Copy(pointerStr, 1, Pos(';', pointerStr) - 1);
						end;

						if pointerStr[1] = '-' then begin
							Delete(pointerStr, 1, 1);
							TextWindowFree(state);
							TextWindowOpenFile(pointerStr, state);
							if state.LineCount = 0 then
								exit
							else begin
								viewingFile := true;
								newLinePos := LinePos;
								TextWindowDraw(state, false, viewingFile);
								InputKeyPressed := #0;
								InputShiftPressed := false;
							end;
						end else begin
							if hyperlinkAsSelect then begin
								Hyperlink := pointerStr;
							end else begin
								pointerStr := ':' + pointerStr;
								for iLine := 1 to LineCount do begin
									if Length(pointerStr) > Length(Lines[iLine]^) then begin
									end else begin
										for iChar := 1 to Length(pointerStr) do begin
											if UpCase(pointerStr[iChar]) <> UpCase(Lines[iLine]^[iChar]) then
												goto LabelNotMatched;
										end;
										newLinePos := iLine;
										InputKeyPressed := #0;
										InputShiftPressed := false;
										goto LabelMatched;
									LabelNotMatched:
									end;
								end;
							end;
						end;
					end;
				end else begin
					if InputKeyPressed = KEY_PAGE_UP then
						newLinePos := LinePos - TextWindowHeight + 4
					else if InputKeyPressed = KEY_PAGE_DOWN then
						newLinePos := LinePos + TextWindowHeight - 4
					else if InputKeyPressed = KEY_ALT_P then
						TextWindowPrint(state);
				end;

			LabelMatched:
				if newLinePos < 1 then
					newLinePos := 1
				else if newLinePos > state.LineCount then
					newLinePos := LineCount;

				if newLinePos <> LinePos then begin
					LinePos := newLinePos;
					TextWindowDraw(state, false, viewingFile);
					if (Lines[LinePos]^[1]) = '!' then
						if hyperlinkAsSelect then
							TextWindowDrawTitle($1E, #174'Press ENTER to select this'#175)
						else
							TextWindowDrawTitle($1E, #174'Press ENTER for more info'#175);
				end;
				if InputJoystickMoved then begin
					Delay(35);
				end;
			until (InputKeyPressed = KEY_ESCAPE) or (InputKeyPressed = KEY_ENTER) or InputShiftPressed;
			if InputKeyPressed = KEY_ESCAPE then begin
				InputKeyPressed := #0;
				TextWindowRejected := true;
			end;
		end;
	end;

procedure TextWindowEdit(var state: TTextWindowState);
	var
		newLinePos: integer;
		insertMode: boolean;
		charPos: integer;
		i: integer;
	procedure DeleteCurrLine;
		var
			i: integer;
		begin
			with state do begin
				if LineCount > 1 then begin
					Dispose(Lines[LinePos]);
					for i := (LinePos + 1) to LineCount do
						Lines[i - 1] := Lines[i];

					LineCount := LineCount - 1;
					if LinePos > LineCount then
						newLinePos := LineCount
					else
						TextWindowDraw(state, true, false);
				end else begin
					Lines[1]^ := '';
				end;
			end;
		end;
	begin
		with state do begin
			if LineCount = 0 then
				TextWindowAppend(state, '');
			insertMode := true;
			LinePos := 1;
			charPos := 1;
			TextWindowDraw(state, true, false);
			repeat
				if insertMode then
					VideoWriteText(77, 14, $1E, 'on ')
				else
					VideoWriteText(77, 14, $1E, 'off');

				if charPos >= (Length(Lines[LinePos]^) + 1) then begin
					charPos := Length(Lines[LinePos]^) + 1;
					VideoWriteText(charPos + TextWindowX + 3,
						TextWindowY + (TextWindowHeight div 2) + 1,
						$70, ' ');
				end else begin
					VideoWriteText(charPos + TextWindowX + 3,
						TextWindowY + (TextWindowHeight div 2) + 1,
						$70, Lines[LinePos]^[charPos]);
				end;
				InputReadWaitKey;
				newLinePos := LinePos;
				case InputKeyPressed of
					KEY_UP: newLinePos := LinePos - 1;
					KEY_DOWN: newLinePos := LinePos + 1;
					KEY_PAGE_UP: newLinePos := LinePos - TextWindowHeight + 4;
					KEY_PAGE_DOWN: newLinePos := LinePos + TextWindowHeight - 4;
					KEY_RIGHT: begin
						charPos := charPos + 1;
						if charPos > (Length(Lines[LinePos]^) + 1) then begin
							charPos := 1;
							newLinePos := LinePos + 1;
						end;
					end;
					KEY_LEFT: begin
						charPos := charPos - 1;
						if charPos < 1 then begin
							charPos := TextWindowWidth;
							newLinePos := LinePos - 1;
						end;
					end;
					KEY_ENTER: begin
						if LineCount < MAX_TEXT_WINDOW_LINES then begin
							for i := LineCount downto (LinePos + 1) do
								Lines[i + 1] := Lines[i];

							New(Lines[LinePos + 1]);
							Lines[LinePos + 1]^
								:= Copy(Lines[LinePos]^, charPos, Length(Lines[LinePos]^) - charPos + 1);
							Lines[LinePos]^
								:= Copy(Lines[LinePos]^, 1, charPos - 1);

							newLinePos := LinePos + 1;
							charPos := 1;
							LineCount := LineCount + 1;
						end;
					end;
					KEY_BACKSPACE: begin
						if charPos > 1 then begin
							Lines[LinePos]^ :=
								Copy(Lines[LinePos]^, 1, charPos - 2)
								+ Copy(Lines[LinePos]^, charPos, Length(Lines[LinePos]^) - charPos + 1);
							charPos := charPos - 1;
						end else if Length(Lines[LinePos]^) = 0 then begin
							DeleteCurrLine;
							newLinePos := LinePos - 1;
							charPos := TextWindowWidth;
						end;
					end;
					KEY_INSERT: begin
						insertMode := not insertMode;
					end;
					KEY_DELETE: begin
						Lines[LinePos]^ :=
							Copy(Lines[LinePos]^, 1, charPos - 1)
							+ Copy(Lines[LinePos]^, charPos + 1, Length(Lines[LinePos]^) - charPos);
					end;
					KEY_CTRL_Y: begin
						DeleteCurrLine;
					end;
				else
					if (InputKeyPressed >= #32) and (charPos < (TextWindowWidth - 7)) then begin
						if not insertMode then begin
							Lines[LinePos]^ := Copy(Lines[LinePos]^, 1, charPos - 1)
								+ InputKeyPressed
								+ Copy(Lines[LinePos]^, charPos + 1, Length(Lines[LinePos]^) - charPos);
							charPos := charPos + 1;
						end else begin
							if Length(Lines[LinePos]^) < (TextWindowWidth - 8) then begin
								Lines[LinePos]^ := Copy(Lines[LinePos]^, 1, charPos - 1)
									+ InputKeyPressed
									+ Copy(Lines[LinePos]^, charPos, Length(Lines[LinePos]^) - charPos + 1);
								charPos := charPos + 1;
							end;
						end;
					end;
				end;

				if newLinePos < 1 then
					newLinePos := 1
				else if newLinePos > LineCount then
					newLinePos := LineCount;

				if newLinePos <> LinePos then begin
					LinePos := newLinePos;
					TextWindowDraw(state, true, false);
				end else begin
					TextWindowDrawLine(state, LinePos, true, false);
				end;
			until InputKeyPressed = KEY_ESCAPE;

			if Length(Lines[LineCount]^) = 0 then begin
				Dispose(Lines[LineCount]);
				LineCount := LineCount - 1;
			end;
		end;
	end;

procedure TextWindowOpenFile(filename: TTextWindowLine; var state: TTextWindowState);
	var
		f: file;
		tf: text;
		i: integer;
		entryPos: integer;
		retVal: boolean;
		line: ^string;
		lineLen: byte;
	begin
		with state do begin
			retVal := true;
			for i := 1 to Length(filename) do
				retVal := retVal and (filename[i] <> '.');
			if retVal then
				filename := filename + '.HLP';

			if filename[1] = '*' then begin
				filename := Copy(filename, 2, Length(filename) - 1);
				entryPos := -1;
			end else begin
				entryPos := 0;
			end;

			TextWindowInitState(state);
			LoadedFilename := UpCaseString(filename);
			if ResourceDataHeader.EntryCount = 0 then begin
				Assign(f, ResourceDataFileName);
				Reset(f, 1);
				if IOResult = 0 then
					BlockRead(f, ResourceDataHeader, SizeOf(ResourceDataHeader));
				if IOResult <> 0 then
					ResourceDataHeader.EntryCount := -1;
				Close(f);
			end;

			if entryPos = 0 then begin
				for i := 1 to ResourceDataHeader.EntryCount do begin
					if UpCaseString(ResourceDataHeader.Name[i]) = UpCaseString(filename) then
						entryPos := i;
				end;
			end;

			if entryPos <= 0 then begin
				Assign(tf, filename);
				Reset(tf);
				while (IOResult = 0) and (not Eof(tf)) do begin
					Inc(LineCount);
					New(Lines[LineCount]);
					ReadLn(tf, Lines[LineCount]^);
				end;
				Close(tf);
			end else begin
				Assign(f, ResourceDataFilename);
				Reset(f, 1);
				Seek(f, ResourceDataHeader.FileOffset[entryPos]);
				if IOResult = 0 then begin
					retVal := true;
					while (IOResult = 0) and retVal do begin
						Inc(LineCount);
						New(Lines[LineCount]);

						BlockRead(f, Lines[LineCount]^, 1);
						line := Ptr(Seg(Lines[LineCount]^), Ofs(Lines[LineCount]^) + 1);
						lineLen := Ord(Lines[LineCount]^[0]);
						if lineLen = 0 then begin
							Lines[LineCount]^ := '';
						end else begin
							BlockRead(f, line^, Ord(Lines[LineCount]^[0]));
						end;

						if Lines[LineCount]^ = '@' then begin
							retVal := false;
							Lines[LineCount]^ := '';
						end;
					end;
					Close(f);
				end;
			end;
		end;
	end;

procedure TextWindowSaveFile(filename: TTextWindowLine; var state: TTextWindowState);
	var
		f: text;
		i: integer;
	begin
		with state do begin
			Assign(f, filename);
			Rewrite(f);
			if IOResult <> 0 then exit;

			for i := 1 to LineCount do begin
				WriteLn(f, Lines[i]^);
				if IOResult <> 0 then exit;
			end;

			Close(f);
		end;
	end;

procedure TextWindowDisplayFile(filename, title: string);
	var
		state: TTextWindowState;
	begin
		state.Title := title;
		TextWindowOpenFile(filename, state);
		state.Selectable := false;
		if state.LineCount > 0 then begin
			TextWindowDrawOpen(state);
			TextWindowSelect(state, false, true);
			TextWindowDrawClose(state);
		end;
		TextWindowFree(state);
	end;

procedure TextWindowInit(x, y, width, height: integer);
	var
		i: integer;
	begin
		TextWindowX := x;
		TextWindowWidth := width;
		TextWindowY := y;
		TextWindowHeight := height;
		TextWindowStrInnerEmpty := '';
		TextWindowStrInnerLine := '';
		for i := 1 to (TextWindowWidth - 5) do begin
			TextWindowStrInnerEmpty := TextWindowStrInnerEmpty + ' ';
			TextWindowStrInnerLine := TextWindowStrInnerLine + #205;
		end;
		TextWindowStrTop    := #198#209 + TextWindowStrInnerLine  + #209 + #181;
		TextWindowStrBottom := #198#207 + TextWindowStrInnerLine  + #207 + #181;
		TextWindowStrSep    :=  ' '#198 + TextWindowStrInnerLine  + #181 + ' ';
		TextWindowStrText   :=  ' '#179 + TextWindowStrInnerEmpty + #179 + ' ';
		TextWindowStrInnerArrows := TextWindowStrInnerEmpty;
		TextWindowStrInnerArrows[1] := #175;
		TextWindowStrInnerArrows[Length(TextWindowStrInnerArrows)] := #174;
		TextWindowStrInnerSep := TextWindowStrInnerEmpty;
		for i := 1 to (TextWindowWidth div 5) do
			TextWindowStrInnerSep[i * 5 + ((TextWindowWidth mod 5) div 2)] := #7;
	end;

begin
	ResourceDataFileName := '';
	ResourceDataHeader.EntryCount := 0;
end.
