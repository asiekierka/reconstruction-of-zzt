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
unit Oop;

interface
	uses GameVars;
	function WorldGetFlagPosition(name: TString50): integer;
	procedure WorldSetFlag(name: TString50);
	procedure WorldClearFlag(name: TString50);
	function OopSend(statId: integer; sendLabel: string; ignoreLock: boolean): boolean;
	procedure OopExecute(statId: integer; var position: integer; name: TString50);

implementation
uses Sounds, TxtWind, Game, Elements;

procedure OopError(statId: integer; message: string);
	begin
		with Board.Stats[statId] do begin
			DisplayMessage(200, 'ERR: ' + message);
			SoundQueue(5, #80#10);
			DataPos := -1;
		end;
	end;

procedure OopReadChar(statId: integer; var position: integer);
	begin
		with Board.Stats[statId] do begin
			if (position >= 0) and (position < DataLen) then begin
				Move(Ptr(Seg(Data^), Ofs(Data^) + position)^, OopChar, 1);
				Inc(position);
			end else begin
				OopChar := #0
			end;
		end;
	end;

procedure OopReadWord(statId: integer; var position: integer);
	begin
		OopWord := '';
		repeat
			OopReadChar(statId, position);
		until OopChar <> ' ';
		OopChar := UpCase(OopChar);
		if (OopChar < '0') or (OopChar > '9') then begin
			while ((OopChar >= 'A') and (OopChar <= 'Z')) or (OopChar = ':')
				or ((OopChar >= '0') and (OopChar <= '9')) or (OopChar = '_') do
			begin
				OopWord := OopWord + OopChar;
				OopReadChar(statId, position);
				OopChar := UpCase(OopChar);
			end;
		end;
		if position > 0 then
			Dec(position);
	end;

procedure OopReadValue(statId: integer; var position: integer);
	var
		s: string[20];
		code: integer;
	begin
		s := '';
		repeat
			OopReadChar(statId, position)
		until OopChar <> ' ';

		OopChar := UpCase(OopChar);
		while (OopChar >= '0') and (OopChar <= '9') do begin
			s := s + OopChar;
			OopReadChar(statId, position);
			OopChar := UpCase(OopChar);
		end;

		if position > 0 then
			position := position - 1;

		if Length(s) <> 0 then
			Val(s, OopValue, code)
		else
			OopValue := -1;
	end;

procedure OopSkipLine(statId: integer; var position: integer);
	begin
		repeat
			OopReadChar(statId, position);
		until (OopChar = #0) or (OopChar = #13);
	end;

function OopParseDirection(statId: integer; var position: integer; var dx, dy: integer): boolean;
	begin
		with Board.Stats[statId] do begin
			OopParseDirection := true;

			if (OopWord = 'N') or (OopWord = 'NORTH') then begin
				dx := 0;
				dy := -1;
			end else if (OopWord = 'S') or (OopWord = 'SOUTH') then begin
				dx := 0;
				dy := 1;
			end else if (OopWord = 'E') or (OopWord = 'EAST') then begin
				dx := 1;
				dy := 0;
			end else if (OopWord = 'W') or (OopWord = 'WEST') then begin
				dx := -1;
				dy := 0;
			end else if (OopWord = 'I') or (OopWord = 'IDLE') then begin
				dx := 0;
				dy := 0;
			end else if (OopWord = 'SEEK') then begin
				CalcDirectionSeek(X, Y, dx, dy);
			end else if (OopWord = 'FLOW') then begin
				dx := StepX;
				dy := StepY;
			end else if (OopWord = 'RND') then begin
				CalcDirectionRnd(dx, dy)
			end else if (OopWord = 'RNDNS') then begin
				dx := 0;
				dy := Random(2) * 2 - 1;
			end else if (OopWord = 'RNDNE') then begin
				dx := Random(2);
				if dx = 0 then dy := -1 else dy := 0;
			end else if (OopWord = 'CW') then begin
				OopReadWord(statId, position);
				OopParseDirection := OopParseDirection(statId, position, dy, dx);
				dx := -dx;
			end else if (OopWord = 'CCW') then begin
				OopReadWord(statId, position);
				OopParseDirection := OopParseDirection(statId, position, dy, dx);
				dy := -dy;
			end else if (OopWord = 'RNDP') then begin
				OopReadWord(statId, position);
				OopParseDirection := OopParseDirection(statId, position, dy, dx);
				if Random(2) = 0 then
					dx := -dx
				else
					dy := -dy;
			end else if (OopWord = 'OPP') then begin
				OopReadWord(statId, position);
				OopParseDirection := OopParseDirection(statId, position, dx, dy);
				dx := -dx;
				dy := -dy;
			end else begin
				dx := 0;
				dy := 0;
				OopParseDirection := false;
			end;
		end;
	end;

procedure OopReadDirection(statId: integer; var position: integer; var dx, dy: integer);
	begin
		OopReadWord(statId, position);
		if not OopParseDirection(statId, position, dx, dy) then
			OopError(statId, 'Bad direction');
	end;

function OopFindString(statId: integer; s: string): integer;
	var
		pos, wordPos, cmpPos: integer;
	label NoMatch;
	begin
		with Board.Stats[statId] do begin
			pos := 0;
			while pos <= DataLen do begin
				wordPos := 1;
				cmpPos := pos;
				repeat
					OopReadChar(statId, cmpPos);
					if UpCase(s[wordPos]) <> UpCase(OopChar) then
						goto NoMatch;
					wordPos := wordPos + 1;
				until wordPos > Length(s);

				{ string matches }
				OopReadChar(statId, cmpPos);
				OopChar := UpCase(OopChar);
				if ((OopChar >= 'A') and (OopChar <= 'Z')) or (OopChar = '_') then begin
					{ word continues, match invalid }
				end else begin
					{ word complete, match valid }
					OopFindString := pos;
					exit;
				end;

			NoMatch:
				pos := pos + 1;
			end;
			OopFindString := -1;
		end;
	end;

function OopIterateStat(statId: integer; var iStat: integer; lookup: string): boolean;
	var
		pos: integer;
		found: boolean;
	begin
		iStat := iStat + 1;
		found := false;

		if lookup = 'ALL' then begin
			if iStat <= Board.StatCount then
				found := true;
		end else if lookup = 'OTHERS' then begin
			if iStat <= Board.StatCount then begin
				if iStat <> statId then
					found := true
				else begin
					iStat := iStat + 1;
					found := (iStat <= Board.StatCount);
				end;
			end;
		end else if lookup = 'SELF' then begin
			if (statId > 0) and (iStat <= statId) then begin
				iStat := statId;
				found := true;
			end;
		end else begin
			while (iStat <= Board.StatCount) and not found do begin
				if Board.Stats[iStat].Data <> nil then begin
					pos := 0;
					OopReadChar(iStat, pos);
					if OopChar = '@' then begin
						OopReadWord(iStat, pos);
						if OopWord = lookup then
							found := true;
					end;
				end;

				if not found then
					iStat := iStat + 1;
			end;
		end;

		OopIterateStat := found;
	end;

function OopFindLabel(statId: integer; sendLabel: string; var iStat, iDataPos: integer; labelPrefix: string): boolean;
	var
		targetSplitPos: integer;
		unk1: integer;
		targetLookup: string[20];
		objectMessage: string[20];
		foundStat: boolean;
	label FindNextStat;
	begin
		foundStat := false;
		targetSplitPos := Pos(':', sendLabel);
		if targetSplitPos <= 0 then begin
			{ if there is no target, we only check statId }
			if iStat < statId then begin
				objectMessage := sendLabel;
				iStat := statId;
				targetSplitPos := 0;
				foundStat := true;
			end;
		end else begin
			targetLookup := Copy(sendLabel, 1, targetSplitPos - 1);
			objectMessage := Copy(sendLabel, targetSplitPos + 1, Length(sendLabel) - targetSplitPos);
		FindNextStat:
			foundStat := OopIterateStat(statId, iStat, targetLookup);
		end;

		if foundStat then begin
			if objectMessage = 'RESTART' then begin
				iDataPos := 0;
			end else begin
				iDataPos := OopFindString(iStat, labelPrefix + objectMessage);
				{ if lookup target exists, there may be more stats }
				if (iDataPos < 0) and (targetSplitPos > 0) then
					goto FindNextStat;
			end;
			foundStat := iDataPos >= 0;
		end;

		OopFindLabel := foundStat;
	end;

function WorldGetFlagPosition(name: TString50): integer;
	var
		i: integer;
	begin
		WorldGetFlagPosition := -1;
		for i := 1 to MAX_FLAG do begin
			if World.Info.Flags[i] = name then
				WorldGetFlagPosition := i;
		end;
	end;

procedure WorldSetFlag(name: TString50);
	var
		i: integer;
	begin
		if WorldGetFlagPosition(name) < 0 then begin
			i := 1;
			while (i < MAX_FLAG) and (Length(World.Info.Flags[i]) <> 0) do
				i := i + 1;
			World.Info.Flags[i] := name;
		end;
	end;

procedure WorldClearFlag(name: TString50);
	var
		i: integer;
	begin
		if WorldGetFlagPosition(name) >= 0 then
			World.Info.Flags[WorldGetFlagPosition(name)] := '';
	end;

function OopStringToWord(input: TString50): TString50;
	var
		output: TString50;
		i: integer;
	begin
		output := '';
		for i := 1 to Length(input) do begin
			if ((input[i] >= 'A') and (input[i] <= 'Z'))
				or ((input[i] >= '0') and (input[i] <= '9')) then
				output := output + input[i]
			else if ((input[i] >= 'a') and (input[i] <= 'z')) then
				output := output + Chr(Ord(input[i]) - $20);
		end;
		OopStringToWord := output;
	end;

function OopParseTile(var statId, position: integer; var tile: TTile): boolean;
	var
		i: integer;
	label ColorFound;
	begin
		OopParseTile := false;
		tile.Color := 0;

		OopReadWord(statId, position);
		for i := 1 to 7 do begin
			if OopWord = OopStringToWord(ColorNames[i]) then begin
				tile.Color := i + $08;
				OopReadWord(statId, position);
				goto ColorFound;
			end;
		end;
	ColorFound:

		for i := 0 to MAX_ELEMENT do begin
			if OopWord = OopStringToWord(ElementDefs[i].Name) then begin
				OopParseTile := true;
				tile.Element := i;
				exit;
			end;
		end;
	end;

function GetColorForTileMatch(var tile: TTile): byte;
	begin
		if ElementDefs[tile.Element].Color < COLOR_SPECIAL_MIN then
			GetColorForTileMatch := ElementDefs[tile.Element].Color and $07
		else if ElementDefs[tile.Element].Color = COLOR_WHITE_ON_CHOICE then
			GetColorForTileMatch := ((tile.Color shr 4) and $0F) + 8
		else
			GetColorForTileMatch := (tile.Color and $0F);
	end;

function FindTileOnBoard(var x, y: integer; tile: TTile): boolean;
	begin
		FindTileOnBoard := false;
		while true do begin
			x := x + 1;
			if x > BOARD_WIDTH then begin
				x := 1;
				y := y + 1;
				if y > BOARD_HEIGHT then
					exit;
			end;

			if Board.Tiles[x][y].Element = tile.Element then
				if ((tile.Color = 0) or (GetColorForTileMatch(Board.Tiles[x][y]) = tile.Color)) then begin
					FindTileOnBoard := true;
					exit;
				end;
		end;
	end;

procedure OopPlaceTile(x, y: integer; var tile: TTile);
	var
		color: byte;
	begin
		if Board.Tiles[x][y].Element <> E_PLAYER then begin
			color := tile.Color;
			if ElementDefs[tile.Element].Color < COLOR_SPECIAL_MIN then
				color := ElementDefs[tile.Element].Color
			else begin
				if color = 0 then
					color := Board.Tiles[x][y].Color;

				if color = 0 then
					color := $0F;

				if ElementDefs[tile.Element].Color = COLOR_WHITE_ON_CHOICE then
					color := ((color - 8) * $10) + $0F;
			end;

			if Board.Tiles[x][y].Element = tile.Element then
				Board.Tiles[x][y].Color := color
			else begin
				BoardDamageTile(x, y);
				if ElementDefs[tile.Element].Cycle >= 0 then begin
					AddStat(x, y, tile.Element, color, ElementDefs[tile.Element].Cycle, StatTemplateDefault);
				end else begin
					Board.Tiles[x][y].Element := tile.Element;
					Board.Tiles[x][y].Color := color;
				end;
			end;

			BoardDrawTile(x, y);
		end;
	end;

function OopCheckCondition(statId: integer; var position: integer): boolean;
	var
		deltaX, deltaY: integer;
		tile: TTile;
		ix, iy: integer;
	begin
		with Board.Stats[statId] do begin
			if OopWord = 'NOT' then begin
				OopReadWord(statId, position);
				OopCheckCondition := not OopCheckCondition(statId, position);
			end else if OopWord = 'ALLIGNED' then begin
				OopCheckCondition := (X = Board.Stats[0].X) or (Y = Board.Stats[0].Y);
			end else if OopWord = 'CONTACT' then begin
				OopCheckCondition := (Sqr(X - Board.Stats[0].X) + Sqr(Y - Board.Stats[0].Y)) = 1;
			end else if OopWord = 'BLOCKED' then begin
				OopReadDirection(statId, position, deltaX, deltaY);
				OopCheckCondition := not ElementDefs[Board.Tiles[X + deltaX][Y + deltaY].Element].Walkable;
			end else if OopWord = 'ENERGIZED' then begin
				OopCheckCondition := World.Info.EnergizerTicks > 0;
			end else if OopWord = 'ANY' then begin
				if not OopParseTile(statId, position, tile) then
					OopError(statId, 'Bad object kind');

				ix := 0;
				iy := 1;
				OopCheckCondition := FindTileOnBoard(ix, iy, tile);
			end else begin
				OopCheckCondition := WorldGetFlagPosition(OopWord) >= 0;
			end;
		end;
	end;

function OopReadLineToEnd(statId: integer; var position: integer) : string;
	var
		s: string;
	begin
		s := '';
		OopReadChar(statId, position);
		while (OopChar <> #0) and (OopChar <> #13) do begin
			s := s + OopChar;
			OopReadChar(statId, position);
		end;
		OopReadLineToEnd := s;
	end;

function OopSend(statId: integer; sendLabel: string; ignoreLock: boolean): boolean;
	var
		iDataPos, iStat: integer;
		ignoreSelfLock: boolean;
	begin
		if statId < 0 then begin
			{ if statId is negative, label send will always succeed on self }
			{ this is used for in-game events (f.e. TOUCH, SHOT) }
			statId := -statId;
			ignoreSelfLock := true;
		end else begin
			ignoreSelfLock := false;
		end;

		OopSend := false;
		iStat := 0;

		while OopFindLabel(statId, sendLabel, iStat, iDataPos, #13':') do begin
			if ((Board.Stats[iStat].P2 = 0) or (ignoreLock)) or ((statId = iStat) and not ignoreSelfLock) then begin
				if iStat = statId then
					OopSend := true;

				Board.Stats[iStat].DataPos := iDataPos;
			end;
		end;
	end;

procedure OopExecute(statId: integer; var position: integer; name: TString50);
	var
		textWindow: TTextWindowState;
		textLine: string;
		deltaX, deltaY: integer;
		ix, iy: integer;
		stopRunning: boolean;
		replaceStat: boolean;
		endOfProgram: boolean;
		replaceTile: TTile;
		namePosition: integer;
		lastPosition: integer;
		repeatInsNextTick: boolean;
		lineFinished: boolean;
		labelPtr: pointer;
		labelDataPos: integer;
		labelStatId: integer;
		counterPtr: ^integer;
		counterSubtract: boolean;
		bindStatId: integer;
		insCount: integer;
		argTile: TTile;
		argTile2: TTile;
	label StartParsing;
	label ReadInstruction;
	label ReadCommand;
	begin
		with Board.Stats[statId] do begin
		StartParsing:
			TextWindowInitState(textWindow);
			textWindow.Selectable := false;
			stopRunning := false;
			repeatInsNextTick := false;
			replaceStat := false;
			endOfProgram := false;
			insCount := 0;
			repeat
		ReadInstruction:
				lineFinished := true;
				lastPosition := position;
				OopReadChar(statId, position);

				{ skip labels }
				while OopChar = ':' do begin
					repeat
						OopReadChar(statId, position);
					until (OopChar = #0) or (OopChar = #13);
					OopReadChar(statId, position);
				end;

				if OopChar = #39 { apostrophe } then begin
					OopSkipLine(statId, position);
				end else if OopChar = '@' then begin
					OopSkipLine(statId, position);
				end else if (OopChar = '/') or (OopChar = '?') then begin
					if OopChar = '/' then
						repeatInsNextTick := true;

					OopReadWord(statId, position);
					if OopParseDirection(statId, position, deltaX, deltaY) then begin
						if (deltaX <> 0) or (deltaY <> 0) then begin
							if not ElementDefs[Board.Tiles[X + deltaX][Y + deltaY].Element].Walkable then
								ElementPushablePush(X + deltaX, Y + deltaY, deltaX, deltaY);

							if ElementDefs[Board.Tiles[X + deltaX][Y + deltaY].Element].Walkable then begin
								MoveStat(statId, X + deltaX, Y + deltaY);
								repeatInsNextTick := false;
							end;
						end else begin
							repeatInsNextTick := false;
						end;

						OopReadChar(statId, position);
						if OopChar <> #13 then
							Dec(position);

						stopRunning := true;
					end else begin
						OopError(statId, 'Bad direction');
					end;
				end else if OopChar = '#' then begin
		ReadCommand:
					OopReadWord(statId, position);
					if OopWord = 'THEN' then
						OopReadWord(statId, position);
					if Length(OopWord) = 0 then
						goto ReadInstruction;
					Inc(insCount);
					if Length(OopWord) <> 0 then begin
						if OopWord = 'GO' then begin
							OopReadDirection(statId, position, deltaX, deltaY);

							if not ElementDefs[Board.Tiles[X + deltaX][Y + deltaY].Element].Walkable then
								ElementPushablePush(X + deltaX, Y + deltaY, deltaX, deltaY);

							if ElementDefs[Board.Tiles[X + deltaX][Y + deltaY].Element].Walkable then begin
								MoveStat(statId, X + deltaX, Y + deltaY);
							end else begin
								repeatInsNextTick := true;
							end;

							stopRunning := true;
						end else if OopWord = 'TRY' then begin
							OopReadDirection(statId, position, deltaX, deltaY);

							if not ElementDefs[Board.Tiles[X + deltaX][Y + deltaY].Element].Walkable then
								ElementPushablePush(X + deltaX, Y + deltaY, deltaX, deltaY);

							if ElementDefs[Board.Tiles[X + deltaX][Y + deltaY].Element].Walkable then begin
								MoveStat(statId, X + deltaX, Y + deltaY);
								stopRunning := true;
							end else begin
								goto ReadCommand;
							end;
						end else if OopWord = 'WALK' then begin
							OopReadDirection(statId, position, deltaX, deltaY);
							StepX := deltaX;
							StepY := deltaY;
						end else if OopWord = 'SET' then begin
							OopReadWord(statId, position);
							WorldSetFlag(OopWord);
						end else if OopWord = 'CLEAR' then begin
							OopReadWord(statId, position);
							WorldClearFlag(OopWord);
						end else if OopWord = 'IF' then begin
							OopReadWord(statId, position);
							if OopCheckCondition(statId, position) then
								goto ReadCommand;
						end else if OopWord = 'SHOOT' then begin
							OopReadDirection(statId, position, deltaX, deltaY);
							if BoardShoot(E_BULLET, X, Y, deltaX, deltaY, SHOT_SOURCE_ENEMY) then
								SoundQueue(2, #48#1#38#1);
							stopRunning := true;
						end else if OopWord = 'THROWSTAR' then begin
							OopReadDirection(statId, position, deltaX, deltaY);
							if BoardShoot(E_STAR, X, Y, deltaX, deltaY, SHOT_SOURCE_ENEMY) then
								begin end;
							stopRunning := true;
						end else if (OopWord = 'GIVE') or (OopWord = 'TAKE') then begin
							if OopWord = 'TAKE' then
								counterSubtract := true
							else
								counterSubtract := false;

							OopReadWord(statId, position);
							if OopWord = 'HEALTH' then
								counterPtr := @World.Info.Health
							else if OopWord = 'AMMO' then
								counterPtr := @World.Info.Ammo
							else if OopWord = 'GEMS' then
								counterPtr := @World.Info.Gems
							else if OopWord = 'TORCHES' then
								counterPtr := @World.Info.Torches
							else if OopWord = 'SCORE' then
								counterPtr := @World.Info.Score
							else if OopWord = 'TIME' then
								counterPtr := @World.Info.BoardTimeSec
							else
								counterPtr := nil;

							if counterPtr <> nil then begin
								OopReadValue(statId, position);
								if OopValue > 0 then begin
									if counterSubtract then
										OopValue := -OopValue;

									if (counterPtr^ + OopValue) >= 0 then begin
										counterPtr^ := counterPtr^ + OopValue;
									end else begin
										goto ReadCommand;
									end;
								end;
							end;

							GameUpdateSidebar;
						end else if OopWord = 'END' then begin
							position := -1;
							OopChar := #0;
						end else if OopWord = 'ENDGAME' then begin
							World.Info.Health := 0;
						end else if OopWord = 'IDLE' then begin
							stopRunning := true;
						end else if OopWord = 'RESTART' then begin
							position := 0;
							lineFinished := false;
						end else if OopWord = 'ZAP' then begin
							OopReadWord(statId, position);

							labelStatId := 0;
							while OopFindLabel(statId, OopWord, labelStatId, labelDataPos, #13':') do begin
								labelPtr := Board.Stats[labelStatId].Data;
								AdvancePointer(labelPtr, labelDataPos + 1);

								Char(labelPtr^) := #39;
							end;
						end else if OopWord = 'RESTORE' then begin
							OopReadWord(statId, position);

							labelStatId := 0;
							while OopFindLabel(statId, OopWord, labelStatId, labelDataPos, #13#39) do
								repeat
									labelPtr := Board.Stats[labelStatId].Data;
									AdvancePointer(labelPtr, labelDataPos + 1);

									Char(labelPtr^) := ':';

									labelDataPos := OopFindString(labelStatId, #13#39 + OopWord + #13);
								until labelDataPos <= 0;
						end else if OopWord = 'LOCK' then begin
							P2 := 1;
						end else if OopWord = 'UNLOCK' then begin
							P2 := 0;
						end else if OopWord = 'SEND' then begin
							OopReadWord(statId, position);
							if OopSend(statId, OopWord, false) then
								lineFinished := false;
						end else if OopWord = 'BECOME' then begin
							if OopParseTile(statId, position, argTile) then begin
								replaceStat := true;
								replaceTile.Element := argTile.Element;
								replaceTile.Color := argTile.Color;
							end else begin
								OopError(statId, 'Bad #BECOME');
							end;
						end else if OopWord = 'PUT' then begin
							OopReadDirection(statId, position, deltaX, deltaY);
							if (deltaX = 0) and (deltaY = 0) then
								OopError(statId, 'Bad #PUT')
							else if not OopParseTile(statId, position, argTile) then
								OopError(statId, 'Bad #PUT')
							else if ((X + deltaX) > 0)
								and ((X + deltaX) <= BOARD_WIDTH)
								and ((Y + deltaY) > 0)
								and ((Y + deltaY) < BOARD_HEIGHT) then
							begin
								if not ElementDefs[Board.Tiles[X + deltaX][Y + deltaY].Element].Walkable then
									ElementPushablePush(X + deltaX, Y + deltaY, deltaX, deltaY);

								OopPlaceTile(X + deltaX, Y + deltaY, argTile);
							end;
						end else if OopWord = 'CHANGE' then begin
							if not OopParseTile(statId, position, argTile) then
								OopError(statId, 'Bad #CHANGE');
							if not OopParseTile(statId, position, argTile2) then
								OopError(statId, 'Bad #CHANGE');

							ix := 0;
							iy := 1;
							if (argTile2.Color = 0)
								and (ElementDefs[argTile2.Element].Color < COLOR_SPECIAL_MIN)
							then
								argTile2.Color := ElementDefs[argTile2.Element].Color;

							while FindTileOnBoard(ix, iy, argTile) do
								OopPlaceTile(ix, iy, argTile2);
						end else if OopWord = 'PLAY' then begin
							textLine := SoundParse(OopReadLineToEnd(statId, position));
							if Length(textLine) <> 0 then
								SoundQueue(-1, textLine);
							lineFinished := false;
						end else if OopWord = 'CYCLE' then begin
							OopReadValue(statId, position);
							if OopValue > 0 then
								Cycle := OopValue;
						end else if OopWord = 'CHAR' then begin
							OopReadValue(statId, position);
							if (OopValue > 0) and (OopValue <= 255) then begin
								P1 := OopValue;
								BoardDrawTile(X, Y);
							end;
						end else if OopWord = 'DIE' then begin
							replaceStat := true;
							replaceTile.Element := E_EMPTY;
							replaceTile.Color := $0F;
						end else if OopWord = 'BIND' then begin
							OopReadWord(statId, position);
							bindStatId := 0;
							if OopIterateStat(statId, bindStatId, OopWord) then begin
								FreeMem(Data, DataLen);
								Data := Board.Stats[bindStatId].Data;
								DataLen := Board.Stats[bindStatId].DataLen;
								position := 0;
							end;
						end else begin
							textLine := OopWord;
							if OopSend(statId, OopWord, false) then begin
								lineFinished := false;
							end else begin
								if Pos(':', textLine) <= 0 then begin
									OopError(statId, 'Bad command ' + textLine);
								end;
							end;
						end;
					end;

					if lineFinished then
						OopSkipLine(statId, position);
				end else if OopChar = #13 then begin
					if textWindow.LineCount > 0 then
						TextWindowAppend(textWindow, '');
				end else if OopChar = #0 then begin
					endOfProgram := true;
				end else begin
					textLine := OopChar + OopReadLineToEnd(statId, position);
					TextWindowAppend(textWindow, textLine);
				end;
			until endOfProgram or stopRunning or repeatInsNextTick or replaceStat or (insCount > 32);

			if repeatInsNextTick then
				position := lastPosition;

			if OopChar = #0 then
				position := -1;

			if textWindow.LineCount > 1 then begin
				namePosition := 0;
				OopReadChar(statId, namePosition);
				if OopChar = '@' then begin
					name := OopReadLineToEnd(statId, namePosition);
				end;

				if Length(name) = 0 then
					name := 'Interaction';

				textWindow.Title := name;
				TextWindowDrawOpen(textWindow);
				TextWindowSelect(textWindow, true, false);
				TextWindowDrawClose(textWindow);
				TextWindowFree(textWindow);

				if Length(textWindow.Hyperlink) <> 0 then
					if OopSend(statId, textWindow.Hyperlink, false) then
						goto StartParsing;
			end else if textWindow.LineCount = 1 then begin
				DisplayMessage(200, textWindow.Lines[1]^);
				TextWindowFree(textWindow);
			end;

			if replaceStat then begin
				ix := X;
				iy := Y;
				DamageStat(statId);
				OopPlaceTile(ix, iy, replaceTile);
			end;
		end;
	end;

begin
end.
