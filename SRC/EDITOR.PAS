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
{$V-}
unit Editor;

interface
	uses GameVars, TxtWind;
	procedure EditorLoop;
	procedure HighScoresLoad;
	procedure HighScoresSave;
	procedure HighScoresDisplay(linePos: integer);
	procedure EditorOpenEditTextWindow(var state: TTextWindowState);
	procedure EditorEditHelpFile;
	procedure HighScoresAdd(score: integer);
	function EditorGetBoardName(boardId: integer; titleScreenIsNone: boolean): TString50;
	function EditorSelectBoard(title: string; currentBoard: integer; titleScreenIsNone: boolean): integer;

implementation
uses Dos, Crt, Video, Sounds, Input, Elements, Oop, Game;

type
	TDrawMode = (DrawingOff, DrawingOn, TextEntry);
const
	NeighborBoardStrs: array[0 .. 3] of string[20] =
		('       Board '#24, '       Board '#25, '       Board '#27, '       Board '#26);

procedure EditorAppendBoard;
	begin
		if World.BoardCount < MAX_BOARD then begin
			BoardClose;

			World.BoardCount := World.BoardCount + 1;
			World.Info.CurrentBoard := World.BoardCount;
			World.BoardLen[World.BoardCount] := 0;
			BoardCreate;

			TransitionDrawToBoard;

			repeat
				PopupPromptString('Room'#39's Title:', Board.Name);
			until Length(Board.Name) <> 0;

			TransitionDrawToBoard;
		end;
	end;

procedure EditorLoop;
	var
		selectedCategory: integer;
		elemMenuColor: integer;
		wasModified: boolean;
		editorExitRequested: boolean;
		drawMode: TDrawMode;
		cursorX, cursorY: integer;
		cursorPattern, cursorColor: integer;
		i, iElem: integer;
		canModify: boolean;
		unk1: array[0 .. 49] of byte;
		copiedStat: TStat;
		copiedHasStat: boolean;
		copiedTile: TTile;
		copiedX, copiedY: integer;
		cursorBlinker: integer;

	procedure EditorDrawSidebar;
		var
			i: integer;
			copiedChr: byte;
		begin
			SidebarClear;
			SidebarClearLine(1);
			VideoWriteText(61, 0, $1F, '     - - - -       ');
			VideoWriteText(62, 1, $70, '  ZZT Editor   ');
			VideoWriteText(61, 2, $1F, '     - - - -       ');
			VideoWriteText(61, 4, $70, ' L ');
			VideoWriteText(64, 4, $1F, ' Load');
			VideoWriteText(61, 5, $30, ' S ');
			VideoWriteText(64, 5, $1F, ' Save');
			VideoWriteText(70, 4, $70, ' H ');
			VideoWriteText(73, 4, $1E, ' Help');
			VideoWriteText(70, 5, $30, ' Q ');
			VideoWriteText(73, 5, $1F, ' Quit');
			VideoWriteText(61, 7, $70, ' B ');
			VideoWriteText(65, 7, $1F, ' Switch boards');
			VideoWriteText(61, 8, $30, ' I ');
			VideoWriteText(65, 8, $1F, ' Board Info');
			VideoWriteText(61, 10, $70, '  f1   ');
			VideoWriteText(68, 10, $1F, ' Item');
			VideoWriteText(61, 11, $30, '  f2   ');
			VideoWriteText(68, 11, $1F, ' Creature');
			VideoWriteText(61, 12, $70, '  f3   ');
			VideoWriteText(68, 12, $1F, ' Terrain');
			VideoWriteText(61, 13, $30, '  f4   ');
			VideoWriteText(68, 13, $1F, ' Enter text');
			VideoWriteText(61, 15, $70, ' Space ');
			VideoWriteText(68, 15, $1F, ' Plot');
			VideoWriteText(61, 16, $30, '  Tab  ');
			VideoWriteText(68, 16, $1F, ' Draw mode');
			VideoWriteText(61, 18, $70, ' P ');
			VideoWriteText(64, 18, $1F, ' Pattern');
			VideoWriteText(61, 19, $30, ' C ');
			VideoWriteText(64, 19, $1F, ' Color:');

			{ Colors }
			for i := 9 to 15 do
				VideoWriteText(61 + i, 22, i, #219);

			{ Patterns }
			for i := 1 to EditorPatternCount do
				VideoWriteText(61 + i, 22, $0F, ElementDefs[EditorPatterns[i]].Character);

			if ElementDefs[copiedTile.Element].HasDrawProc then
				ElementDefs[copiedTile.Element].DrawProc(copiedX, copiedY, copiedChr)
			else
				copiedChr := Ord(ElementDefs[copiedTile.Element].Character);
			VideoWriteText(62 + EditorPatternCount, 22, copiedTile.Color, Chr(copiedChr));

			VideoWriteText(61, 24, $1F, ' Mode:');
		end;

	procedure EditorDrawTileAndNeighborsAt(x, y: integer);
		var
			i, ix, iy: integer;
		begin
			BoardDrawTile(x, y);
			for i := 0 to 3 do begin
				ix := x + NeighborDeltaX[i];
				iy := y + NeighborDeltaY[i];
				if (ix >= 1) and (ix <= BOARD_WIDTH) and (iy >= 1) and (iy <= BOARD_HEIGHT) then
					BoardDrawTile(ix, iy);
			end;
		end;

	procedure EditorUpdateSidebar;
		begin
			if drawMode = DrawingOn then
				VideoWriteText(68, 24, $9E, 'Drawing on ')
			else if drawMode = TextEntry then
				VideoWriteText(68, 24, $9E, 'Text entry ')
			else if drawMode = DrawingOff then
				VideoWriteText(68, 24, $1E, 'Drawing off');

			VideoWriteText(72, 19, $1E, ColorNames[cursorColor - 8]);
			VideoWriteText(61 + cursorPattern, 21, $1F, #31);
			VideoWriteText(61 + cursorColor, 21, $1F, #31);
		end;

	procedure EditorDrawRefresh;
		var
			boardNumStr: string;
		begin
			BoardDrawBorder;
			EditorDrawSidebar;
			Str(World.Info.CurrentBoard, boardNumStr);
			TransitionDrawToBoard;

			if Length(Board.Name) <> 0 then
				VideoWriteText((59 - Length(Board.Name)) div 2, 0, $70, ' ' + Board.Name + ' ')
			else
				VideoWriteText(26, 0, $70, ' Untitled ');
		end;

	procedure EditorSetAndCopyTile(x, y, element, color: byte);
		begin
			Board.Tiles[x][y].Element := element;
			Board.Tiles[x][y].Color := color;

			copiedTile := Board.Tiles[x][y];
			copiedHasStat := false;
			copiedX := x;
			copiedY := y;

			EditorDrawTileAndNeighborsAt(x, y);
		end;

	procedure EditorAskSaveChanged;
		begin
			InputKeyPressed := #0;
			if wasModified then
				if SidebarPromptYesNo('Save first? ', true) then
					if InputKeyPressed <> KEY_ESCAPE then
						GameWorldSave('Save world', LoadedGameFileName, '.ZZT');
			World.Info.Name := LoadedGameFileName;
		end;

	function EditorPrepareModifyTile(x, y: integer): boolean;
		begin
			wasModified := true;
			EditorPrepareModifyTile := BoardPrepareTileForPlacement(x, y);
			EditorDrawTileAndNeighborsAt(x, y);
		end;

	function EditorPrepareModifyStatAtCursor: boolean;
		begin
			if Board.StatCount < MAX_STAT then
				EditorPrepareModifyStatAtCursor := EditorPrepareModifyTile(cursorX, cursorY)
			else
				EditorPrepareModifyStatAtCursor := false;
		end;

	procedure EditorPlaceTile(x, y: integer);
		begin
			with Board.Tiles[x][y] do begin
				if cursorPattern <= EditorPatternCount then begin
					if EditorPrepareModifyTile(x, y) then begin
						Element := EditorPatterns[cursorPattern];
						Color := cursorColor;
					end;
				end else if copiedHasStat then begin
					if EditorPrepareModifyStatAtCursor then begin
						AddStat(x, y, copiedTile.Element, copiedTile.Color, copiedStat.Cycle, copiedStat);
					end
				end else begin
					if EditorPrepareModifyTile(x, y) then begin
						Board.Tiles[x][y] := copiedTile;
					end;
				end;

				EditorDrawTileAndNeighborsAt(x, y);
			end;
		end;

	procedure EditorEditBoardInfo;
		var
			state: TTextWindowState;
			i: integer;
			numStr: string[50];
			exitRequested: boolean;

		function BoolToString(val: boolean): string;
			begin
				if val then
					BoolToString := 'Yes'
				else
					BoolToString := 'No ';
			end;

		begin
			state.Title := 'Board Information';
			TextWindowDrawOpen(state);
			state.LinePos := 1;
			state.LineCount := 9;
			state.Selectable := true;
			exitRequested := false;
			for i := 1 to state.LineCount do
				New(state.Lines[i]);

			repeat
				state.Selectable := true;
				state.LineCount := 10;
				for i := 1 to state.LineCount do
					New(state.Lines[i]);

				state.Lines[1]^ := '         Title: ' + Board.Name;

				Str(Board.Info.MaxShots, numStr);
				state.Lines[2]^ := '      Can fire: ' + numStr + ' shots.';

				state.Lines[3]^ := ' Board is dark: ' + BoolToString(Board.Info.IsDark);

				for i := 4 to 7 do begin
					state.Lines[i]^ := NeighborBoardStrs[i - 4] + ': ' +
						EditorGetBoardName(Board.Info.NeighborBoards[i - 4], true);
				end;

				state.Lines[8]^ := 'Re-enter when zapped: ' + BoolToString(Board.Info.ReenterWhenZapped);

				Str(Board.Info.TimeLimitSec, numStr);
				state.Lines[9]^ := '  Time limit, 0=None: ' + numStr + ' sec.';

				state.Lines[10]^ := '          Quit!';

				TextWindowSelect(state, false, false);
				if (InputKeyPressed = KEY_ENTER) and (state.LinePos >= 1) and (state.LinePos <= 8) then
					wasModified := true;
				if (InputKeyPressed = KEY_ENTER) then
					case state.LinePos of
						1: begin
							PopupPromptString('New title for board:', Board.Name);
							exitRequested := true;
							TextWindowDrawClose(state);
						end;
						2: begin
							Str(Board.Info.MaxShots, numStr);
							SidebarPromptString('Maximum shots?', '', numStr, PROMPT_NUMERIC);
							if Length(numStr) <> 0 then
								Val(numStr, Board.Info.MaxShots, i);
							EditorDrawSidebar;
						end;
						3: begin
							Board.Info.IsDark := not Board.Info.IsDark;
						end;
						4, 5, 6, 7: begin
							Board.Info.NeighborBoards[state.LinePos - 4]
								:= EditorSelectBoard(
									NeighborBoardStrs[state.LinePos - 4],
									Board.Info.NeighborBoards[state.LinePos - 4],
									true
								);
							if Board.Info.NeighborBoards[state.LinePos - 4] > World.BoardCount then
								EditorAppendBoard;
							exitRequested := true;
						end;
						8: begin
							Board.Info.ReenterWhenZapped := not Board.Info.ReenterWhenZapped;
						end;
						9: begin
							Str(Board.Info.TimeLimitSec, numStr);
							SidebarPromptString('Time limit?', ' Sec', numStr, PROMPT_NUMERIC);
							if Length(numStr) <> 0 then
								Val(numStr, Board.Info.TimeLimitSec, i);
							EditorDrawSidebar;
						end;
						10: begin
							exitRequested := true;
							TextWindowDrawClose(state);
						end;
					end
				else begin
					exitRequested := true;
					TextWindowDrawClose(state);
				end;
			until exitRequested;

			TextWindowFree(state);
		end;

	procedure EditorEditStatText(statId: integer; prompt: string);
		var
			state: TTextWindowState;
			iLine, iChar: integer;
			unk1: array[0 .. 51] of byte;
			dataChar: char;
			dataPtr: pointer;
		begin
			with Board.Stats[statId] do begin
				state.Title := prompt;
				TextWindowDrawOpen(state);
				state.Selectable := false;
				CopyStatDataToTextWindow(statId, state);

				if DataLen > 0 then begin
					FreeMem(Data, DataLen);
					DataLen := 0;
				end;

				EditorOpenEditTextWindow(state);

				for iLine := 1 to state.LineCount do
					DataLen := DataLen + Length(state.Lines[iLine]^) + 1;
				GetMem(Data, DataLen);

				dataPtr := Data;
				for iLine := 1 to state.LineCount do begin
					for iChar := 1 to Length(state.Lines[iLine]^) do begin
						dataChar := state.Lines[iLine]^[iChar];
						Move(dataChar, dataPtr^, 1);
						AdvancePointer(dataPtr, 1);
					end;

					dataChar := #13;
					Move(dataChar, dataPtr^, 1);
					AdvancePointer(dataPtr, 1);
				end;

				TextWindowFree(state);
				TextWindowDrawClose(state);
				InputKeyPressed := #0;
			end;
		end;

	procedure EditorEditStat(statId: integer);
		var
			element: byte;
			i: integer;
			categoryName: string;
			selectedBoard: byte;
			iy: integer;
			promptByte: byte;

		procedure EditorEditStatSettings(selected: boolean);
			begin
				with Board.Stats[statId] do begin
					InputKeyPressed := #0;
					iy := 9;

					if Length(ElementDefs[element].Param1Name) <> 0 then begin
						if Length(ElementDefs[element].ParamTextName) = 0 then begin
							SidebarPromptSlider(selected, 63, iy, ElementDefs[element].Param1Name, P1);
						end else begin
							if P1 = 0 then
								P1 := World.EditorStatSettings[element].P1;
							BoardDrawTile(X, Y);
							SidebarPromptCharacter(selected, 63, iy, ElementDefs[element].Param1Name, P1);
							BoardDrawTile(X, Y);
						end;
						if selected then
							World.EditorStatSettings[element].P1 := P1;
						iy := iy + 4;
					end;

					if (InputKeyPressed <> KEY_ESCAPE) and
						(Length(ElementDefs[element].ParamTextName) <> 0) then
					begin
						if selected then
							EditorEditStatText(statId, ElementDefs[element].ParamTextName);
					end;

					if (InputKeyPressed <> KEY_ESCAPE) and
						(Length(ElementDefs[element].Param2Name) <> 0) then
					begin
						promptByte := (P2 mod $80);
						SidebarPromptSlider(selected, 63, iy, ElementDefs[element].Param2Name, promptByte);
						if selected then begin
							P2 := (P2 and $80) + promptByte;
							World.EditorStatSettings[element].P2 := P2;
						end;
						iy := iy + 4;
					end;

					if (InputKeyPressed <> KEY_ESCAPE) and
						(Length(ElementDefs[element].ParamBulletTypeName) <> 0) then
					begin
						promptByte := (P2) div $80;
						SidebarPromptChoice(selected, iy, ElementDefs[element].ParamBulletTypeName,
							'Bullets Stars', promptByte);
						if selected then begin
							P2 := (P2 mod $80) + (promptByte * $80);
							World.EditorStatSettings[element].P2 := P2;
						end;
						iy := iy + 4;
					end;

					if (InputKeyPressed <> KEY_ESCAPE) and
						(Length(ElementDefs[element].ParamDirName) <> 0) then
					begin
						SidebarPromptDirection(selected, iy, ElementDefs[element].ParamDirName,
							StepX, StepY);
						if selected then begin
							World.EditorStatSettings[element].StepX := StepX;
							World.EditorStatSettings[element].StepY := StepY;
						end;
						iy := iy + 4;
					end;

					if (InputKeyPressed <> KEY_ESCAPE) and
						(Length(ElementDefs[element].ParamBoardName) <> 0) then
					begin
						if selected then begin
							selectedBoard := EditorSelectBoard(ElementDefs[element].ParamBoardName, P3, true);
							if selectedBoard <> 0 then begin
								P3 := selectedBoard;
								World.EditorStatSettings[element].P3 := World.Info.CurrentBoard;
								if P3 > World.BoardCount then begin
									EditorAppendBoard;
									copiedHasStat := false;
									copiedTile.Element := 0;
									copiedTile.Color := $0F;
								end;
								World.EditorStatSettings[element].P3 := P3;
							end else begin
								InputKeyPressed := KEY_ESCAPE;
							end;
							iy := iy + 4;
						end else begin
							VideoWriteText(63, iy, $1F, 'Room: ' + Copy(EditorGetBoardName(P3, true), 1, 10));
						end;
					end;
				end;
			end;

		begin
			with Board.Stats[statId] do begin
				SidebarClear;

				element := Board.Tiles[X][Y].Element;
				wasModified := true;

				categoryName := '';
				for i := 0 to element do begin
					if (ElementDefs[i].EditorCategory = ElementDefs[element].EditorCategory)
						and (Length(ElementDefs[i].CategoryName) <> 0) then
					begin
						categoryName := ElementDefs[i].CategoryName;
					end;
				end;

				VideoWriteText(64, 6, $1E, categoryName);
				VideoWriteText(64, 7, $1F, ElementDefs[element].Name);

				EditorEditStatSettings(false);
				EditorEditStatSettings(true);

				if InputKeyPressed <> KEY_ESCAPE then begin
					copiedHasStat := true;
					copiedStat := Board.Stats[statId];
					copiedTile := Board.Tiles[X][Y];
					copiedX := X;
					copiedY := Y;
				end;
			end;
		end;

	procedure EditorTransferBoard;
		var
			i: byte;
			f: file;
		label TransferEnd;
		begin
			i := 1;
			SidebarPromptChoice(true, 3, 'Transfer board:', 'Import Export', i);
			if InputKeyPressed <> KEY_ESCAPE then begin
				if i = 0 then begin
					SidebarPromptString('Import board', '.BRD', SavedBoardFileName, PROMPT_ALPHANUM);
					if (InputKeyPressed <> KEY_ESCAPE) and (Length(SavedBoardFileName) <> 0) then begin
						Assign(f, SavedBoardFileName + '.BRD');
						Reset(f, 1);
						if DisplayIOError then goto TransferEnd;

						BoardClose;
						FreeMem(World.BoardData[World.Info.CurrentBoard], World.BoardLen[World.Info.CurrentBoard]);
						BlockRead(f, World.BoardLen[World.Info.CurrentBoard], 2);
						if not DisplayIOError then begin
							GetMem(World.BoardData[World.Info.CurrentBoard], World.BoardLen[World.Info.CurrentBoard]);
							BlockRead(f, World.BoardData[World.Info.CurrentBoard]^,
								World.BoardLen[World.Info.CurrentBoard]);
						end;

						if DisplayIOError then begin
							World.BoardLen[World.Info.CurrentBoard] := 0;
							BoardCreate;
							EditorDrawRefresh;
						end else begin
							BoardOpen(World.Info.CurrentBoard);
							EditorDrawRefresh;
							for i := 0 to 3 do
								Board.Info.NeighborBoards[i] := 0;
						end;
					end;
				end else if i = 1 then begin
					SidebarPromptString('Export board', '.BRD', SavedBoardFileName, PROMPT_ALPHANUM);
					if (InputKeyPressed <> KEY_ESCAPE) and (Length(SavedBoardFileName) <> 0) then begin
						Assign(f, SavedBoardFileName + '.BRD');
						Rewrite(f, 1);
						if DisplayIOError then goto TransferEnd;

						BoardClose;
						BlockWrite(f, World.BoardLen[World.Info.CurrentBoard], 2);
						BlockWrite(f, World.BoardData[World.Info.CurrentBoard]^,
							World.BoardLen[World.Info.CurrentBoard]);
						BoardOpen(World.Info.CurrentBoard);

						if DisplayIOError then begin
						end else begin
							Close(f);
						end;
					end;
				end;
			end;
		TransferEnd:
			EditorDrawSidebar;
		end;

	procedure EditorFloodFill(x, y: integer; from: TTile);
		var
			i: integer;
			tileAt: TTile;
			toFill, filled: byte;
			xPosition: array[0 .. 255] of integer;
			yPosition: array[0 .. 255] of integer;
		begin
			toFill := 1;
			filled := 0;
			while toFill <> filled do begin
				tileAt := Board.Tiles[x][y];
				EditorPlaceTile(x, y);
				if (Board.Tiles[x][y].Element <> tileAt.Element)
					or (Board.Tiles[x][y].Color <> tileAt.Color) then
					for i := 0 to 3 do
						with Board.Tiles[x + NeighborDeltaX[i]][y + NeighborDeltaY[i]] do begin
							if (Element = from.Element)
								and ((from.Element = 0) or (Color = from.Color)) then
							begin
								xPosition[toFill] := x + NeighborDeltaX[i];
								yPosition[toFill] := y + NeighborDeltaY[i];
								toFill := toFill + 1;
							end;
						end;

				filled := filled + 1;
				x := xPosition[filled];
				y := yPosition[filled];
			end;
		end;

	begin
		if World.Info.IsSave or (WorldGetFlagPosition('SECRET') >= 0) then begin
			WorldUnload;
			WorldCreate;
		end;
		InitElementsEditor;
		CurrentTick := 0;
		wasModified := false;
		cursorX := 30;
		cursorY := 12;
		drawMode := DrawingOff;
		cursorPattern := 1;
		cursorColor := $0E;
		cursorBlinker := 0;
		copiedHasStat := false;
		copiedTile.Element := 0;
		copiedTile.Color := $0F;

		if World.Info.CurrentBoard <> 0 then
			BoardChange(World.Info.CurrentBoard);

		EditorDrawRefresh;
		if World.BoardCount = 0 then
			EditorAppendBoard;

		editorExitRequested := false;
		repeat
			if drawMode = DrawingOn then
				EditorPlaceTile(cursorX, cursorY);
			InputUpdate;
			if (InputKeyPressed = #0) and (InputDeltaX = 0) and (InputDeltaY = 0) and not InputShiftPressed then begin
				if SoundHasTimeElapsed(TickTimeCounter, 15) then
					cursorBlinker := (cursorBlinker + 1) mod 3;
				if cursorBlinker = 0  then
					BoardDrawTile(cursorX, cursorY)
				else
					VideoWriteText(cursorX - 1, cursorY - 1, $0F, #197);
				EditorUpdateSidebar;
			end else begin
				BoardDrawTile(cursorX, cursorY);
			end;

			if drawMode = TextEntry then begin
				if (InputKeyPressed >= #32) and (InputKeyPressed < #128) then begin
					if EditorPrepareModifyTile(cursorX, cursorY) then begin
						Board.Tiles[cursorX][cursorY].Element := (cursorColor - 9) + E_TEXT_MIN;
						Board.Tiles[cursorX][cursorY].Color := Ord(InputKeyPressed);
						EditorDrawTileAndNeighborsAt(cursorX, cursorY);
						InputDeltaX := 1;
						InputDeltaY := 0;
					end;
					InputKeyPressed := #0;
				end else if (InputKeyPressed = KEY_BACKSPACE) and (cursorX > 1)
					and EditorPrepareModifyTile(cursorX - 1, cursorY) then
				begin
						cursorX := cursorX - 1;
				end else if (InputKeyPressed = KEY_ENTER) or (InputKeyPressed = KEY_ESCAPE) then begin
					drawMode := DrawingOff;
					InputKeyPressed := #0;
				end;
			end;

			with Board.Tiles[cursorX][cursorY] do begin
				if InputShiftPressed or (InputKeyPressed = ' ') then begin
					InputShiftAccepted := true;
					if (Element = 0)
						or (ElementDefs[Element].PlaceableOnTop and copiedHasStat and (cursorPattern > EditorPatternCount))
						or (InputDeltaX <> 0) or (InputDeltaY <> 0) then
					begin
						EditorPlaceTile(cursorX, cursorY);
					end else begin
						canModify := EditorPrepareModifyTile(cursorX, cursorY);
						if canModify then
							Board.Tiles[cursorX][cursorY].Element := 0;
					end;
				end;

				if (InputDeltaX <> 0) or (InputDeltaY <> 0) then begin
					cursorX := cursorX + InputDeltaX;
					if cursorX < 1 then
						cursorX := 1;
					if cursorX > BOARD_WIDTH then
						cursorX := BOARD_WIDTH;

					cursorY := cursorY + InputDeltaY;
					if cursorY < 1 then
						cursorY := 1;
					if cursorY > BOARD_HEIGHT then
						cursorY := BOARD_HEIGHT;

					VideoWriteText(cursorX - 1, cursorY - 1, $0F, #197);
					if (InputKeyPressed = #0) and InputJoystickEnabled then
						Delay(70);
					InputShiftAccepted := false;
				end;

				case UpCase(InputKeyPressed) of
					'`': EditorDrawRefresh;
					'P': begin
						VideoWriteText(62, 21, $1F, '       ');
						if cursorPattern <= EditorPatternCount then
							cursorPattern := cursorPattern + 1
						else
							cursorPattern := 1;
					end;
					'C': begin
						VideoWriteText(72, 19, $1E, '       ');
						VideoWriteText(69, 21, $1F, '        ');
						if (cursorColor mod $10) <> $0F then
							cursorColor := cursorColor + 1
						else
							cursorColor := ((cursorColor div $10) * $10) + 9;
					end;
					'L': begin
						EditorAskSaveChanged;
						if (InputKeyPressed <> KEY_ESCAPE) and GameWorldLoad('.ZZT') then begin
							if World.Info.IsSave or (WorldGetFlagPosition('SECRET') >= 0) then begin
								if not DebugEnabled then begin
									SidebarClearLine(3);
									SidebarClearLine(4);
									SidebarClearLine(5);
									VideoWriteText(63, 4, $1E, 'Can not edit');
									if World.Info.IsSave then
										VideoWriteText(63, 5, $1E, 'a saved game!')
									else
										VideoWriteText(63, 5, $1E, '  ' + World.Info.Name + '!');
									PauseOnError;
									WorldUnload;
									WorldCreate;
								end;
							end;
							wasModified := false;
							EditorDrawRefresh;
						end;
						EditorDrawSidebar;
					end;
					'S': begin
						GameWorldSave('Save world:', LoadedGameFileName, '.ZZT');
						if InputKeyPressed <> KEY_ESCAPE then
							wasModified := false;
						EditorDrawSidebar;
					end;
					'Z': begin
						if SidebarPromptYesNo('Clear board? ', false) then begin
							for i := Board.StatCount downto 1 do
								RemoveStat(i);
							BoardCreate;
							EditorDrawRefresh;
						end else begin
							EditorDrawSidebar;
						end;
					end;
					'N': begin
						if SidebarPromptYesNo('Make new world? ', false) and (InputKeyPressed <> KEY_ESCAPE) then begin
							EditorAskSaveChanged;
							if (InputKeyPressed <> KEY_ESCAPE) then begin
								WorldUnload;
								WorldCreate;
								EditorDrawRefresh;
								wasModified := false;
							end;
						end;
						EditorDrawSidebar;
					end;
					'Q', KEY_ESCAPE: begin
						editorExitRequested := true;
					end;
					'B': begin
						i := EditorSelectBoard('Switch boards', World.Info.CurrentBoard, false);
						if (InputKeyPressed <> KEY_ESCAPE) then begin
							if (i > World.BoardCount) then
								if SidebarPromptYesNo('Add new board? ', false) then
									EditorAppendBoard;
							BoardChange(i);
							EditorDrawRefresh;
						end;
						EditorDrawSidebar;
					end;
					'?': begin
						GameDebugPrompt;
						EditorDrawSidebar;
					end;
					KEY_TAB: begin
						if drawMode = DrawingOff then
							drawMode := DrawingOn
						else
							drawMode := DrawingOff;
					end;
					KEY_F1, KEY_F2, KEY_F3: begin
						VideoWriteText(cursorX - 1, cursorY - 1, $0F, #197);
						for i := 3 to 20 do
							SidebarClearLine(i);
						case InputKeyPressed of
							KEY_F1: selectedCategory := CATEGORY_ITEM;
							KEY_F2: selectedCategory := CATEGORY_CREATURE;
							KEY_F3: selectedCategory := CATEGORY_TERRAIN;
						end;
						i := 3; { Y position for text writing }
						for iElem := 0 to MAX_ELEMENT do begin
							if ElementDefs[iElem].EditorCategory = selectedCategory then begin
								if Length(ElementDefs[iElem].CategoryName) <> 0 then begin
									i := i + 1;
									VideoWriteText(65, i, $1E, ElementDefs[iElem].CategoryName);
									i := i + 1;
								end;

								VideoWriteText(61, i, ((i mod 2) shl 6) + $30, ' ' + ElementDefs[iElem].EditorShortcut + ' ');
								VideoWriteText(65, i, $1F, ElementDefs[iElem].Name);
								if ElementDefs[iElem].Color = COLOR_CHOICE_ON_BLACK then
									elemMenuColor := (cursorColor mod $10) + $10
								else if ElementDefs[iElem].Color = COLOR_WHITE_ON_CHOICE then
									elemMenuColor := (cursorColor * $10) - $71
								else if ElementDefs[iElem].Color = COLOR_CHOICE_ON_CHOICE then
									elemMenuColor := ((cursorColor - 8) * $11) + 8
								else if (ElementDefs[iElem].Color and $70) = $00 then
									elemMenuColor := (ElementDefs[iElem].Color mod $10) + $10
								else
									elemMenuColor := ElementDefs[iElem].Color;
								VideoWriteText(78, i, elemMenuColor, ElementDefs[iElem].Character);

								i := i + 1;
							end;
						end;
						InputReadWaitKey;
						for iElem := 1 to MAX_ELEMENT do begin
							if (ElementDefs[iElem].EditorCategory = selectedCategory)
								and (ElementDefs[iElem].EditorShortcut = UpCase(InputKeyPressed)) then
							begin
								if iElem = E_PLAYER then begin
									if EditorPrepareModifyTile(cursorX, cursorY) then
										MoveStat(0, cursorX, cursorY);
								end else begin
									if ElementDefs[iElem].Color = COLOR_CHOICE_ON_BLACK then
										elemMenuColor := cursorColor
									else if ElementDefs[iElem].Color = COLOR_WHITE_ON_CHOICE then
										elemMenuColor := (cursorColor * $10) - $71
									else if ElementDefs[iElem].Color = COLOR_CHOICE_ON_CHOICE then
										elemMenuColor := ((cursorColor - 8) * $11) + 8
									else
										elemMenuColor := ElementDefs[iElem].Color;

									if ElementDefs[iElem].Cycle = -1 then begin
										if EditorPrepareModifyTile(cursorX, cursorY) then
											EditorSetAndCopyTile(cursorX, cursorY, iElem, elemMenuColor);
									end else begin
										if EditorPrepareModifyStatAtCursor then begin
											AddStat(cursorX, cursorY, iElem, elemMenuColor,
												ElementDefs[iElem].Cycle, StatTemplateDefault);
											with Board.Stats[Board.StatCount] do begin
												if Length(ElementDefs[iElem].Param1Name) <> 0 then
													P1 := World.EditorStatSettings[iElem].P1;
												if Length(ElementDefs[iElem].Param2Name) <> 0 then
													P2 := World.EditorStatSettings[iElem].P2;
												if Length(ElementDefs[iElem].ParamDirName) <> 0 then begin
													StepX := World.EditorStatSettings[iElem].StepX;
													StepY := World.EditorStatSettings[iElem].StepY;
												end;
												if Length(ElementDefs[iElem].ParamBoardName) <> 0 then
													P3 := World.EditorStatSettings[iElem].P3;
											end;
											EditorEditStat(Board.StatCount);
											if InputKeyPressed = KEY_ESCAPE then
												RemoveStat(Board.StatCount);
										end;
									end;
								end;
							end;
						end;
						EditorDrawSidebar;
					end;
					KEY_F4: begin
						if drawMode <> TextEntry then
							drawMode := TextEntry
						else
							drawMode := DrawingOff;
					end;
					'H': begin
						TextWindowDisplayFile('editor.hlp', 'World editor help');
					end;
					'X': begin
						EditorFloodFill(cursorX, cursorY, Board.Tiles[cursorX][cursorY]);
					end;
					'!': begin
						EditorEditHelpFile;
						EditorDrawSidebar;
					end;
					'T': begin
						EditorTransferBoard;
					end;
					KEY_ENTER: begin
						if GetStatIdAt(cursorX, cursorY) >= 0 then begin
							EditorEditStat(GetStatIdAt(cursorX, cursorY));
							EditorDrawSidebar;
						end else begin
							copiedHasStat := false;
							copiedTile := Board.Tiles[cursorX][cursorY];
						end;
					end;
					'I': begin
						EditorEditBoardInfo;
						TransitionDrawToBoard;
					end;
				end;
			end;

			if editorExitRequested then begin
				EditorAskSaveChanged;
				if InputKeyPressed = KEY_ESCAPE then begin
					editorExitRequested := false;
					EditorDrawSidebar;
				end;
			end;
		until editorExitRequested;

		InputKeyPressed := #0;
		InitElementsGame;
	end;

procedure HighScoresLoad;
	var
		f: file of THighScoreList;
		i: integer;
	begin
		Assign(f, World.Info.Name + '.HI');
		Reset(f);
		if IOResult = 0 then begin
			Read(f, HighScoreList);
		end;
		Close(f);
		if IOResult <> 0 then begin
			for i := 1 to 30 do begin
				HighScoreList[i].Name := '';
				HighScoreList[i].Score := -1;
			end;
		end;
	end;

procedure HighScoresSave;
	var
		f: file of THighScoreList;
	begin
		Assign(f, World.Info.Name + '.HI');
		Rewrite(f);
		Write(f, HighScoreList);
		Close(f);
		if DisplayIOError then begin
		end else begin
		end;
	end;

{$F+}

procedure HighScoresInitTextWindow(var state: TTextWindowState);
	var
		i: integer;
		scoreStr: string;
	begin
		TextWindowInitState(state);
		TextWindowAppend(state, 'Score  Name');
		TextWindowAppend(state, '-----  ----------------------------------');
		for i := 1 to HIGH_SCORE_COUNT do begin
			if Length(HighScoreList[i].Name) <> 0 then begin
				Str(HighScoreList[i].Score:5, scoreStr);
				TextWindowAppend(state, scoreStr + '  ' + HighScoreList[i].Name);
			end;
		end;
	end;

procedure HighScoresDisplay(linePos: integer);
	var
		state: TTextWindowState;
	begin
		state.LinePos := linePos;
		HighScoresInitTextWindow(state);
		if (state.LineCount > 2) then begin
			state.Title := 'High scores for ' + World.Info.Name;
			TextWindowDrawOpen(state);
			TextWindowSelect(state, false, true);
			TextWindowDrawClose(state);
		end;
		TextWindowFree(state);
	end;

procedure EditorOpenEditTextWindow(var state: TTextWindowState);
	begin
		SidebarClear;
		VideoWriteText(61, 4, $30, ' Return ');
		VideoWriteText(64, 5, $1F, ' Insert line');
		VideoWriteText(61, 7, $70, ' Ctrl-Y ');
		VideoWriteText(64, 8, $1F, ' Delete line');
		VideoWriteText(61, 10, $30, ' Cursor keys ');
		VideoWriteText(64, 11, $1F, ' Move cursor');
		VideoWriteText(61, 13, $70, ' Insert ');
		VideoWriteText(64, 14, $1F, ' Insert mode: ');
		VideoWriteText(61, 16, $30, ' Delete ');
		VideoWriteText(64, 17, $1F, ' Delete char');
		VideoWriteText(61, 19, $70, ' Escape ');
		VideoWriteText(64, 20, $1F, ' Exit editor');
		TextWindowEdit(state);
	end;

procedure EditorEditHelpFile;
	var
		textWindow: TTextWindowState;
		filename: string[50];
	begin
		filename := '';
		SidebarPromptString('File to edit', '.HLP', filename, PROMPT_ALPHANUM);
		if Length(filename) <> 0 then begin
			TextWindowOpenFile('*' + filename + '.HLP', textWindow);
			textWindow.Title := 'Editing ' + filename;
			TextWindowDrawOpen(textWindow);
			EditorOpenEditTextWindow(textWindow);
			TextWindowSaveFile(filename + '.HLP', textWindow);
			TextWindowFree(textWindow);
			TextWindowDrawClose(textWindow);
		end;
	end;

procedure HighScoresAdd(score: integer);
	var
		textWindow: TTextWindowState;
		name: string[50];
		i, listPos: integer;
	begin
		listPos := 1;
		while (listPos <= 30) and (score < HighScoreList[listPos].Score) do
			listPos := listPos + 1;
		if (listPos <= 30) and (score > 0) then begin
			for i := 29 downto listPos do
				HighScoreList[i + 1] := HighScoreList[i];
			HighScoreList[listPos].Score := score;
			HighScoreList[listPos].Name := '-- You! --';

			HighScoresInitTextWindow(textWindow);
			textWindow.LinePos := listPos;
			textWindow.Title := 'New high score for ' + World.Info.Name;
			TextWindowDrawOpen(textWindow);
			TextWindowDraw(textWindow, false, false);

			name := '';
			PopupPromptString('Congratulations!  Enter your name:', name);
			HighScoreList[listPos].Name := name;
			HighScoresSave;

			TextWindowDrawClose(textWindow);
			TransitionDrawToBoard;
			TextWindowFree(textWindow);
		end;
	end;

function EditorGetBoardName(boardId: integer; titleScreenIsNone: boolean): TString50;
	var
		boardData: pointer;
		copiedName: string[50];
	begin
		if (boardId = 0) and titleScreenIsNone then
			EditorGetBoardName := 'None'
		else if (boardId = World.Info.CurrentBoard) then
			EditorGetBoardName := Board.Name
		else begin
			boardData := World.BoardData[boardId];
			Move(boardData^, copiedName, SizeOf(copiedName));
			EditorGetBoardName := copiedName;
		end;
	end;

function EditorSelectBoard(title: string; currentBoard: integer; titleScreenIsNone: boolean): integer;
	var
		unk1: string;
		i: integer;
		unk2: integer;
		textWindow: TTextWindowState;
	begin
		textWindow.Title := title;
		textWindow.LinePos := currentBoard + 1;
		textWindow.Selectable := true;
		textWindow.LineCount := 0;
		for i := 0 to World.BoardCount do begin
			TextWindowAppend(textWindow, EditorGetBoardName(i, titleScreenIsNone));
		end;
		TextWindowAppend(textWindow, 'Add new board');
		TextWindowDrawOpen(textWindow);
		TextWindowSelect(textWindow, false, false);
		TextWindowDrawClose(textWindow);
		TextWindowFree(textWindow);
		if InputKeyPressed = KEY_ESCAPE then
			EditorSelectBoard := 0
		else
			EditorSelectBoard := textWindow.LinePos - 1;
	end;

begin
end.
