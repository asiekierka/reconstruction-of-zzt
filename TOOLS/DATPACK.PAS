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

program DatPack;
uses Dos;

const
	MAX_FILES = 24;
	MAX_HLP_LINE_LENGTH = 50;
	MAX_HLP_LINES = 1024;
type
	TResourceDataHeader = record
		EntryCount: integer;
		Name: array[1 .. MAX_FILES] of string[50];
		FileOffset: array[1 .. MAX_FILES] of longint;
	end;

var
	Hdr: TResourceDataHeader;

function UpCaseString(input: string): string;
	var
		i: integer;
	begin
		for i := 1 to Length(input) do
			input[i] := UpCase(input[i]);
		UpCaseString := input;
	end;

function GetFilename(s: string): string;
	var
		pos: integer;
	begin
		for pos := Length(s) downto 1 do begin
			if s[pos] = '\' then begin
				GetFilename := Copy(s, pos + 1, Length(s) - pos);
				Exit;
			end;
		end;
		GetFilename := s;
	end;

procedure PackFile;
	var
		i: integer;
		io: integer;
		f: file;
		fAddedFn: string;
		fAddedLine: string;
		fAddedLineCount: integer;
		fAdded: text;
		searchResult: SearchRec;
	procedure AddFile(filename: string);
		var
			isHelpFile: boolean;
		begin
			Hdr.Name[io] := UpCaseString(GetFilename(filename));
			Hdr.FileOffset[io] := FilePos(f);

			isHelpFile := (Pos('.HLP', Hdr.Name[io]) >= 1);

			WriteLn(' <- ', Hdr.Name[io]);

			fAddedLineCount := 1;
			Assign(fAdded, filename);
			Reset(fAdded);
			while not Eof(fAdded) do begin
				ReadLn(fAdded, fAddedLine);
				if isHelpFile and (Length(fAddedLine) > MAX_HLP_LINE_LENGTH) then begin
					WriteLn('Error: Line ', fAddedLineCount, ' too long! ',
					  Length(fAddedLine), ' > ', MAX_HLP_LINE_LENGTH);
					Write(filename);
					WriteLn(' has too long line!');
					Close(fAdded);
					Close(f);
					Exit;
				end;

				BlockWrite(f, fAddedLine, Length(fAddedLine) + 1);
				fAddedLineCount := fAddedLineCount + 1;

				if isHelpFile and (fAddedLineCount > MAX_HLP_LINES) then begin
					WriteLn('Error: Too many lines! Max = ', MAX_HLP_LINES);
					Close(fAdded);
					Close(f);
					Exit;
				end;
			end;

			Close(fAdded);
			fAddedLine := '@';
			BlockWrite(f, fAddedLine, Length(fAddedLine) + 1);

			io := io + 1;
			if io > MAX_FILES then begin
				Writeln('Error: Too many files! ', io,
	                          ' > ', MAX_FILES);
				exit;
			end;
		end;
	begin
		Assign(f, ParamStr(2));
		Rewrite(f, 1);
		BlockWrite(f, Hdr, SizeOf(Hdr));

                WriteLn('Packing ', ParamStr(2), '...');

		io := 1;
		for i := 3 to ParamCount do begin
			fAddedFn := ParamStr(i);
			if (Length(fAddedFn) > 0) and (fAddedFn[1] = '*') then begin
				FindFirst(fAddedFn, $21, searchResult);
				while DosError = 0 do begin
					AddFile(searchResult.Name);
					FindNext(searchResult);
				end;
			end else AddFile(fAddedFn);
		end;
		Hdr.EntryCount := io - 1;

		Seek(f, 0);
		BlockWrite(f, Hdr, SizeOf(Hdr));
		Close(f);

		WriteLn('Packed ', Hdr.EntryCount, '/', MAX_FILES, ' files.');
	end;

procedure UnpackFile;
	var
		i: integer;
		f: file;
		fLine: string;
		fWritten: file;
		fWriting: boolean;
	begin
		Assign(f, ParamStr(2));
		Reset(f, 1);
		BlockRead(f, Hdr, SizeOf(Hdr));

		if Hdr.EntryCount > MAX_FILES then begin
			Writeln('Error: Too many files! ', Hdr.EntryCount,
 			  ' > ', MAX_FILES, ' (Corrupt file?)');
			exit;
		end;

		Writeln('Unpacking ', ParamStr(2), '...');
		for i := 1 to Hdr.EntryCount do begin
			Writeln(' -> ', Hdr.Name[i]);

			Seek(f, Hdr.FileOffset[i]);
			Assign(fWritten, Hdr.Name[i]);
			Rewrite(fWritten, 1);

			fWriting := true;
			while fWriting do begin
				BlockRead(f, fLine, 1);
				if Length(fLine) > 0 then
					BlockRead(f, fLine[1], Length(fLine));
				if fLine = '@' then
					fWriting := false
				else begin
					fLine := fLine + #13#10;
					BlockWrite(fWritten, fLine[1], Length(fLine));
				end;
			end;

			Close(fWritten);
		end;

		Close(f);
	end;

begin
	Writeln('DATPACK - ZZT.DAT packing/unpacking tool');
	Writeln('Copyright (c) 2020 Adrian Siekierka');
	Writeln;
	if (ParamCount >= 2) and (ParamStr(1) = '/C') then
		PackFile
	else if (ParamCount >= 2) and (ParamStr(1) = '/X') then
		UnpackFile
	else begin
		Writeln('Usage: ');
		Writeln('  - Pack: DATPACK /C file.dat [*.* or files...]');
		Writeln('  - Unpack: DATPACK /X file.dat');
	end;
end.

