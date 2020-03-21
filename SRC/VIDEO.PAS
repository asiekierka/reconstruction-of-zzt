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
unit Video;

interface
	type
		TVideoLine = string[80];
		TVideoWriteTextProc = procedure(x, y, color: byte; text: TVideoLine);
	const
		PORT_CGA_PALETTE = $03D9;
	var
		VideoWriteText: TVideoWriteTextProc;
		VideoMonochrome: boolean;
	function VideoConfigure: boolean;
	procedure VideoInstall(columns, borderColor: integer);
	procedure VideoUninstall;
	procedure VideoShowCursor;
	procedure VideoHideCursor;
	procedure VideoSetBorderColor(value: integer);
	procedure VideoMove(x, y, chars: integer; data: pointer; toVideo: boolean);

implementation
uses Crt, Dos;
var
	VideoColumns: integer;
	VideoBorderColor: integer;
	VideoTextSegment: word;
	VideoTextPointer: pointer;
	VideoCursorVisible: boolean;

{$F+}

procedure VideoWriteTextCO80(x, y, color: byte; text: TVideoLine);
	begin
		inline(
			$1E/                 { PUSH DS }
			$1E/                 { PUSH DS }
			$8A/$86/y/           { MOV AL, byte ptr [BP + y] }
			$B3/$50/             { MOV BL, 0x50 }
			$F6/$E3/             { MUL BL }
			$2B/$DB/             { SUB BX, BX }
			$8A/$9E/x/           { MOV BL, byte ptr [BP + x] }
			$03/$C3/             { ADD AX, BX }
			$03/$C0/             { ADD AX, AX }
			$8B/$F8/             { MOV DI, AX }
			$BE/$00/$00/         { MOV SI, 0x0 }
			$8A/$BE/color/       { MOV BH, byte ptr [BP + color] }
			$8A/$8E/text/        { MOV CL, byte ptr [BP + text] }
			$22/$C9/             { AND CL, CL }
			$74/$3E/             { JZ label_0084 }
			$2B/$C0/             { SUB AX, AX }
			$8E/$D8/             { MOV DS, AX }
			$A0/$0449/           { MOV AL, [BiosBDA.VideoMode] }
			$1F/                 { POP DS }
			$2C/$07/             { SUB AL, 0x7 }
			$74/$22/             { JZ label_0074 }
			$BA/$B800/           { MOV DX, 0xB800 }
			$8E/$DA/             { MOV DS, DX }
			$BA/$03DA/           { MOV DX, 0x03DA }
			{ label_005a }
			$46/                 { INC SI }
			$8A/$9A/text/        { MOV BL, byte ptr [BP + SI + text] }
			{ label_005f }
			$EC/                 { IN AL, DX }
			$A8/$01/             { TEST AL, 0x1 }
			$75/$FB/             { JNZ label_005f }
			$FA/                 { CLI }
			{ label_0065 }
			$EC/                 { IN AL, DX }
			$A8/$01/             { TEST AL, 0x1 }
			$74/$FB/             { JZ label_0065 }
			$89/$1D/             { MOV word ptr [bufIdx], BX }
			$47/$47/             { INC bufIdx x 2 }
			$E2/$EA/             { LOOP label_005a }
			$2A/$C0/             { SUB AL, AL }
			$74/$10/             { JZ label_0084 }
			{ label_0074 }
			$BA/$B000/           { MOV DX, 0xB000 }
			$8E/$DA/             { MOV DS, DX }
			{ label_0079 }
			$46/                 { INC SI }
			$8A/$9A/text/        { MOV BL, byte ptr [BP + SI + text] }
			$89/$1D/             { MOV word ptr [bufIdx], BX }
			$47/$47/             { INC bufIdx x 2 }
			$E2/$F5/             { LOOP label_0079 }
			{ label_0084 }
			$1F/                 { POP DS }
			$FB                  { STI }
		);
	end;

procedure VideoWriteTextCO40(x, y, color: byte; text: TVideoLine);
	begin
		inline(
			$1E/                 { PUSH DS }
			$1E/                 { PUSH DS }
			$8A/$86/y/           { MOV AL, byte ptr [BP + y] }
			$B3/$28/             { MOV BL, 0x28 }
			$F6/$E3/             { MUL BL }
			$2B/$DB/             { SUB BX, BX }
			$8A/$9E/x/           { MOV BL, byte ptr [BP + x] }
			$03/$C3/             { ADD AX, BX }
			$03/$C0/             { ADD AX, AX }
			$8B/$F8/             { MOV DI, AX }
			$BE/$00/$00/         { MOV SI, 0x0 }
			$8A/$BE/color/       { MOV BH, byte ptr [BP + color] }
			$8A/$8E/text/        { MOV CL, byte ptr [BP + text] }
			$22/$C9/             { AND CL, CL }
			$74/$3E/             { JZ label_0084 }
			$2B/$C0/             { SUB AX, AX }
			$8E/$D8/             { MOV DS, AX }
			$A0/$0449/           { MOV AL, [BiosBDA.VideoMode] }
			$1F/                 { POP DS }
			$2C/$07/             { SUB AL, 0x7 }
			$74/$22/             { JZ label_0074 }
			$BA/$B800/           { MOV DX, 0xB800 }
			$8E/$DA/             { MOV DS, DX }
			$BA/$03DA/           { MOV DX, 0x03DA }
			{ label_005a }
			$46/                 { INC SI }
			$8A/$9A/text/        { MOV BL, byte ptr [BP + SI + text] }
			{ label_005f }
			$EC/                 { IN AL, DX }
			$A8/$01/             { TEST AL, 0x1 }
			$75/$FB/             { JNZ label_005f }
			$FA/                 { CLI }
			{ label_0065 }
			$EC/                 { IN AL, DX }
			$A8/$01/             { TEST AL, 0x1 }
			$74/$FB/             { JZ label_0065 }
			$89/$1D/             { MOV word ptr [bufIdx], BX }
			$47/$47/             { INC bufIdx x 2 }
			$E2/$EA/             { LOOP label_005a }
			$2A/$C0/             { SUB AL, AL }
			$74/$10/             { JZ label_0084 }
			{ label_0074 }
			$BA/$B000/           { MOV DX, 0xB000 }
			$8E/$DA/             { MOV DS, DX }
			{ label_0079 }
			$46/                 { INC SI }
			$8A/$9A/text/        { MOV BL, byte ptr [BP + SI + text] }
			$89/$1D/             { MOV word ptr [bufIdx], BX }
			$47/$47/             { INC bufIdx x 2 }
			$E2/$F5/             { LOOP label_0079 }
			{ label_0084 }
			$1F/                 { POP DS }
			$FB                  { STI }
		);
	end;

procedure VideoWriteTextBW80(x, y, color: byte; text: TVideoLine);
	begin
		if (color and $08) = $08 then begin
			if (color and $F0) = 0 then
				color := $0F
			else
				color := $7F;
		end else begin
			if (color and $07) <> 0 then
				color := $07
			else
				color := $70;
		end;
		inline(
			$1E/                 { PUSH DS }
			$1E/                 { PUSH DS }
			$8A/$86/y/           { MOV AL, byte ptr [BP + y] }
			$B3/$50/             { MOV BL, 0x50 }
			$F6/$E3/             { MUL BL }
			$2B/$DB/             { SUB BX, BX }
			$8A/$9E/x/           { MOV BL, byte ptr [BP + x] }
			$03/$C3/             { ADD AX, BX }
			$03/$C0/             { ADD AX, AX }
			$8B/$F8/             { MOV DI, AX }
			$BE/$00/$00/         { MOV SI, 0x0 }
			$8A/$BE/color/       { MOV BH, byte ptr [BP + color] }
			$8A/$8E/text/        { MOV CL, byte ptr [BP + text] }
			$22/$C9/             { AND CL, CL }
			$74/$3E/             { JZ label_0084 }
			$2B/$C0/             { SUB AX, AX }
			$8E/$D8/             { MOV DS, AX }
			$A0/$0449/           { MOV AL, [BiosBDA.VideoMode] }
			$1F/                 { POP DS }
			$2C/$07/             { SUB AL, 0x7 }
			$74/$22/             { JZ label_0074 }
			$BA/$B800/           { MOV DX, 0xB800 }
			$8E/$DA/             { MOV DS, DX }
			$BA/$03DA/           { MOV DX, 0x03DA }
			{ label_005a }
			$46/                 { INC SI }
			$8A/$9A/text/        { MOV BL, byte ptr [BP + SI + text] }
			{ label_005f }
			$EC/                 { IN AL, DX }
			$A8/$01/             { TEST AL, 0x1 }
			$75/$FB/             { JNZ label_005f }
			$FA/                 { CLI }
			{ label_0065 }
			$EC/                 { IN AL, DX }
			$A8/$01/             { TEST AL, 0x1 }
			$74/$FB/             { JZ label_0065 }
			$89/$1D/             { MOV word ptr [bufIdx], BX }
			$47/$47/             { INC bufIdx x 2 }
			$E2/$EA/             { LOOP label_005a }
			$2A/$C0/             { SUB AL, AL }
			$74/$10/             { JZ label_0084 }
			{ label_0074 }
			$BA/$B000/           { MOV DX, 0xB000 }
			$8E/$DA/             { MOV DS, DX }
			{ label_0079 }
			$46/                 { INC SI }
			$8A/$9A/text/        { MOV BL, byte ptr [BP + SI + text] }
			$89/$1D/             { MOV word ptr [bufIdx], BX }
			$47/$47/             { INC bufIdx x 2 }
			$E2/$F5/             { LOOP label_0079 }
			{ label_0084 }
			$1F/                 { POP DS }
			$FB                  { STI }
		);
	end;

procedure VideoWriteTextBW40(x, y, color: byte; text: TVideoLine);
	begin
		if (color and $08) = $08 then begin
			if (color and $F0) = 0 then
				color := $0F
			else
				color := $7F;
		end else begin
			if (color and $07) <> 0 then
				color := $07
			else
				color := $70;
		end;
		inline(
			$1E/                 { PUSH DS }
			$1E/                 { PUSH DS }
			$8A/$86/y/           { MOV AL, byte ptr [BP + y] }
			$B3/$28/             { MOV BL, 0x28 }
			$F6/$E3/             { MUL BL }
			$2B/$DB/             { SUB BX, BX }
			$8A/$9E/x/           { MOV BL, byte ptr [BP + x] }
			$03/$C3/             { ADD AX, BX }
			$03/$C0/             { ADD AX, AX }
			$8B/$F8/             { MOV DI, AX }
			$BE/$00/$00/         { MOV SI, 0x0 }
			$8A/$BE/color/       { MOV BH, byte ptr [BP + color] }
			$8A/$8E/text/        { MOV CL, byte ptr [BP + text] }
			$22/$C9/             { AND CL, CL }
			$74/$3E/             { JZ label_0084 }
			$2B/$C0/             { SUB AX, AX }
			$8E/$D8/             { MOV DS, AX }
			$A0/$0449/           { MOV AL, [BiosBDA.VideoMode] }
			$1F/                 { POP DS }
			$2C/$07/             { SUB AL, 0x7 }
			$74/$22/             { JZ label_0074 }
			$BA/$B800/           { MOV DX, 0xB800 }
			$8E/$DA/             { MOV DS, DX }
			$BA/$03DA/           { MOV DX, 0x03DA }
			{ label_005a }
			$46/                 { INC SI }
			$8A/$9A/text/        { MOV BL, byte ptr [BP + SI + text] }
			{ label_005f }
			$EC/                 { IN AL, DX }
			$A8/$01/             { TEST AL, 0x1 }
			$75/$FB/             { JNZ label_005f }
			$FA/                 { CLI }
			{ label_0065 }
			$EC/                 { IN AL, DX }
			$A8/$01/             { TEST AL, 0x1 }
			$74/$FB/             { JZ label_0065 }
			$89/$1D/             { MOV word ptr [bufIdx], BX }
			$47/$47/             { INC bufIdx x 2 }
			$E2/$EA/             { LOOP label_005a }
			$2A/$C0/             { SUB AL, AL }
			$74/$10/             { JZ label_0084 }
			{ label_0074 }
			$BA/$B000/           { MOV DX, 0xB000 }
			$8E/$DA/             { MOV DS, DX }
			{ label_0079 }
			$46/                 { INC SI }
			$8A/$9A/text/        { MOV BL, byte ptr [BP + SI + text] }
			$89/$1D/             { MOV word ptr [bufIdx], BX }
			$47/$47/             { INC bufIdx x 2 }
			$E2/$F5/             { LOOP label_0079 }
			{ label_0084 }
			$1F/                 { POP DS }
			$FB                  { STI }
		);
	end;

{$F-}

function VideoConfigure: boolean;
	var
		charTyped: Char;
	begin
		charTyped := ' ';
		if LastMode = 7 then begin
			VideoWriteText := VideoWriteTextBW80;
			VideoMonochrome := true;
		end else begin
			Writeln;
			Write('  Video mode:  C)olor,  M)onochrome?  ');
			repeat
				repeat until KeyPressed;
				charTyped := UpCase(ReadKey);
			until charTyped in [#27, 'C', 'M'];
			case charTyped of
				'C': VideoMonochrome := false;
				'M': VideoMonochrome := true;
				#27: VideoMonochrome := (LastMode = 7);
			end;
		end;
		VideoConfigure := charTyped <> #27;
	end;

procedure VideoInstall(columns, borderColor: integer);
	var
		regs: Registers;
	begin
		regs.AX := $1201;
		regs.BL := $30;
		Intr($10, regs);

		if not VideoMonochrome then
			TextBackground(borderColor);

		VideoColumns := columns;
		if VideoMonochrome then begin
			if LastMode in [0, 1, 2, 3] then begin
				if columns = 80 then begin
					TextMode(BW80);
					VideoWriteText := VideoWriteTextBW80;
				end else begin
					TextMode(BW40);
					VideoWriteText := VideoWriteTextBW40;
				end;
			end else begin
				VideoWriteText := VideoWriteTextBW80;
				TextMode(7);
				VideoColumns := 80;
			end;
		end else begin
			if VideoColumns = 80 then begin
				TextMode(CO80);
				VideoWriteText := VideoWriteTextCO80;
			end else begin
				TextMode(CO40);
				VideoWriteText := VideoWriteTextCO40;
			end;
			if not VideoMonochrome then
				TextBackground(borderColor);
			ClrScr;
		end;
		if not VideoCursorVisible then
			VideoHideCursor;
		VideoSetBorderColor(borderColor);
	end;

procedure VideoUninstall;
	var
		regs: Registers;
	begin
		regs.AX := $1201;
		regs.BL := $30;
		Intr($10, regs);
		TextBackground(0);
		VideoColumns := 80;
		if VideoMonochrome then
			TextMode(BW80)
		else
			TextMode(CO80);
		VideoSetBorderColor(0);
		ClrScr;
	end;

procedure VideoSetCursorShape(value: integer);
	var
		regs: Registers;
	begin
		regs.AH := $01;
		regs.CX := value;
		Intr($10, regs);
	end;

procedure VideoShowCursor;
	begin
		VideoSetCursorShape($0607);
		VideoCursorVisible := true;
	end;

procedure VideoHideCursor;
	begin
		VideoSetCursorShape($2000);
		VideoCursorVisible := false;
	end;

procedure VideoSetBorderColor(value: integer);
	begin
		Port[PORT_CGA_PALETTE] := value;
		VideoBorderColor := value;
	end;

procedure VideoMove(x, y, chars: integer; data: pointer; toVideo: boolean);
	var
		offset: integer;
	begin
		offset := (y * VideoColumns + x) * 2;
		VideoWriteTextCO80(0, 0, 0, '');
		if toVideo then
			Move(data^, Ptr(VideoTextSegment, offset)^, chars * 2)
		else
			Move(Ptr(VideoTextSegment, offset)^, data^, chars * 2);
	end;


begin
	VideoBorderColor := 0;
	VideoColumns := 80;
	VideoWriteText := VideoWriteTextBW80;
	if LastMode = 7 then begin
		VideoTextSegment := $B000;
		VideoMonochrome := true;
	end else begin
		VideoTextSegment := $B800;
		VideoMonochrome := false;
	end;
	VideoTextPointer := Ptr(VideoTextSegment, $0000);
	VideoCursorVisible := true;
end.
