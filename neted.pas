(********************************************************************)
(* An implementation of the "NETED" editor as specified by RFC 569. *)
(* (c) 2007 Andreas Krennmair <ak@synflood.at>                      *)
(********************************************************************)

(*$H+*)

program neted;

uses fstore;

const
	EditMode = 1;
	InputMode = 2;

function FExists(fn : string) : boolean;
var f : Text;
begin
{$i-}
	Assign(f, fn);
	Reset(f);
	if IOResult <> 0 then
		FExists := false
	else
	begin
		FExists := true;
		Close(f);
	end;
{$i+}
end;

procedure EofReached(cmd : string);
begin
	writeln('End of file reached by ' + cmd);
end;


procedure RunInputMode(var f : TFStore);
var curline : string;
begin
	writeln('Input.');
	readln(curline);
	while curline <> '.' do
	begin
		fstore_insertline(f, curline);
		readln(curline);
	end;
end;

function IsNumber(s : string) : boolean;
var i : integer;
begin
	IsNumber := true;
	for i := 1 to Length(s) do
	begin
		if not ((s[i] >= '0') and (s[i] <= '9')) then
			IsNumber := false;
	end;
end;

procedure RunChangeRequest(var f : TFStore; cmd : string);
var s1 : string;
	s2 : string;
	mstr : string;
	m : integer;
	g : boolean;
	do_change : boolean;
	slashpos : integer;
	i : integer;
	code : integer;
	savecmd : string;
begin
	m := 1;
	g := false;
	savecmd := cmd;

	do_change := false;

	Delete(cmd, 1, 2);
	if cmd[1] = '/' then
	begin
		Delete(cmd, 1, 1);
		slashpos := Pos('/', cmd);
		if slashpos > 0 then
		begin
			(* extract s1 *)
			s1 := cmd;
			Delete(s1, slashpos, Length(s1) - slashpos + 1);
			Delete(cmd, 1, slashpos - 1);
			if cmd[1] = '/' then
			begin
				Delete(cmd, 1, 1);
				slashpos := Pos('/', cmd);
				if slashpos > 0 then
				begin
					s2 := cmd;
					Delete(s2, slashpos, Length(s2) - slashpos + 1);
					Delete(cmd, 1, slashpos); (* delete the trailing slash, too *)
					do_change := true; (* we've parsed the minimum that we need for executing the change request *)

					i := 0;
					while (i < Length(cmd)) and (cmd[i + 1] = ' ') do
						Inc(i);
					if i > 0 then
						Delete(cmd, 1, i);

					mstr := cmd;
					i := 0;
					while (i < Length(mstr)) and (mstr[i + 1] <> ' ') do
						Inc(i);
					if i > 0 then
					begin
						Delete(mstr, i + 1, Length(mstr) - i);
						Delete(cmd, 1, Length(mstr) + 1); (* also remove the ' ' after the number *)
						Val(mstr, m, code);
						if code <> 0 then
							m := 1;
						if cmd = 'g' then
							g := true;
					end;
				end;
			end;
		end;
	end;

	if do_change then
	begin
		if not fstore_change(f, s1, s2, m, g) then
			EofReached(savecmd);
	end;
end;

procedure RunEditMode(var f : TFStore; var quit : boolean);
var cmd : string;
	tmp : string;
	quitloop : boolean;
	i : integer;
	code : integer;
begin
	quitloop := false;
	writeln('Edit');
	while not quitloop and not quit do
	begin
		readln(cmd);
		tmp := cmd;

		if cmd[1] = 'n' then
		begin
			Delete(tmp, 1, 2);
			if Length(tmp) > 0 then
			begin
				Val(tmp, i, code);
				if code <> 0 then
					writeln('Invalid number ' + tmp);
			end
			else
				i := 1;
			if not fstore_move(f, i) then
				EofReached(cmd);
		end
		else
		if cmd[1] = 'l' then
		begin
			Delete(tmp, 1, 2);
			if not fstore_locate(f, tmp) then
				EofReached(cmd);
		end
		else
		if cmd[1] = 't' then
		begin
			f.curpos := f.head;
		end
		else
		if cmd = 'b' then
		begin
			f.curpos := f.tail;
			quitloop := true;
		end
		else
		if cmd = '.' then
		begin
			quitloop := true;
		end
		else
		if cmd[1] = 'i' then
		begin
			Delete(tmp, 1, 2);
			fstore_insertline(f, tmp);
		end
		else
		if cmd[1] = 'r' then
		begin
			Delete(tmp, 1, 2);
			fstore_replace(f, tmp);
		end
		else
		if cmd[1] = 'p' then
		begin
			Delete(tmp, 1, 2);
			if Length(tmp) > 0 then
			begin
				Val(tmp, i, code);
				if code <> 0 then
					writeln('Invalid number ' + tmp);
			end
			else
				i := 1;
			if not fstore_print(f, i) then
				EofReached(cmd);
		end
		else
		if cmd[1] = 'c' then
		begin
			RunChangeRequest(f, cmd);
		end
		else
		if cmd[1] = 'd' then
		begin
			Delete(tmp, 1, 2);
			if (Length(tmp) > 0) then
			begin
				Val(tmp, i, code);
				if code <> 0 then
					writeln('Invalid number ' + tmp);
			end
			else
				i := 1;
			if not fstore_delete(f, i) then
				EofReached(cmd);
		end
		else
		if cmd = 'w' then
		begin
			fstore_write(f);
		end
		else if cmd = 'save' then
		begin
			fstore_write(f);
			quit := true;
		end;
	end; (* while *)
end;

var
	filename : string;
	mode : integer;
	fcontent : TFStore;
	quit : boolean;

begin
	quit := false;

	if ParamCount < 1 then
	begin
		writeln('No file specified.');
		exit;
	end;

	filename := ParamStr(1);

	if FExists(filename) then
	begin
		mode := EditMode;
		fstore_open(fcontent, filename);
	end
	else
	begin
		mode := InputMode;
		fcontent := fstore_new;
		fcontent.filename := filename;
		write('File ' + filename + ' not found. '); 
	end;

	while not quit do
	begin
		if (mode = InputMode) then
		begin
			RunInputMode(fcontent);
			mode := EditMode;
		end
		else
		begin
			RunEditMode(fcontent, quit);
			mode := InputMode;
		end;
	end;

	fstore_free(fcontent);

end.
