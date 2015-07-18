(*$H+*)

unit fstore;

interface

type 
	PLine = ^TLine;
	TLine = record
		next : PLine;
		prev : PLine;
		content : string;
	end;
	TFStore = record
		filename : string;
		curpos : PLine;
		head : PLine;
		tail : PLine;
	end;

procedure fstore_free(f : TFStore);
function fstore_new : TFStore;
procedure fstore_open(var fs : TFStore; fn : string);
procedure fstore_write(fs : TFStore);

procedure fstore_insert(var f : TFStore; curline : PLine);
procedure fstore_insertline(var f : TFStore; curline : string);

function fstore_move(var f: TFStore; relpos : integer) : boolean;
function fstore_locate(var f : TFStore; s : string) : boolean;
procedure fstore_replace(var f : TFStore; s : string);
function fstore_print(var f : TFStore; count : integer) : boolean;
function fstore_delete(var f : TFStore; count : integer) : boolean;
function fstore_change(var f : TFStore; s1 : string; s2 : string; count : integer; global : boolean) : boolean;

implementation

procedure fstore_free(f : TFStore);
var tmp : PLine;
begin
	tmp := f.head;
	while tmp <> nil do
	begin
		f.head := f.head^.next;
		dispose(tmp);
		tmp := f.head;
	end;
end;

function fstore_new : TFStore;
var f : TFStore;
begin
	f.curpos := nil;
	f.head := nil;
	f.tail := nil;
	fstore_new := f;
end;

procedure fstore_open(var fs : TFStore; fn : string);
var f : Text;
	curline : string;
	x : PLine;
begin
	fs.filename := fn;
	assign(f, fn);
	reset(f);
	while not eof(f) do
	begin
		readln(f, curline);
		new(x);
		x^.content := curline;
		x^.next := nil;
		x^.prev := nil;
		fstore_insert(fs, x);
	end;
	close(f);
	fs.curpos := fs.head;
end;

procedure fstore_write(fs : TFStore);
var f : Text;
	p : PLine;
begin
	assign(f, fs.filename);
	rewrite(f);
	(* truncate(ff); *) (* TODO: check how to solve that *)
	p := fs.head;
	while p <> nil do
	begin
		writeln(f, p^.content);
		p := p^.next;
	end;
	close(f);
end;

procedure fstore_insert(var f : TFStore; curline : PLine);
begin
	if f.head <> nil then
	begin
		if f.curpos^.next <> nil then
			f.curpos^.next^.prev := curline;
		curline^.next := f.curpos^.next;
		curline^.prev := f.curpos;
		f.curpos^.next := curline;
		if f.curpos = f.tail then
			f.tail := f.curpos^.next;
		f.curpos := f.curpos^.next;
	end
	else
	begin
		f.head := curline;
		f.curpos := f.head;
		f.tail := f.head;
	end;
end;

procedure fstore_insertline(var f : TFStore; curline : string);
var x : PLine;
begin
	new(x);
	x^.content := curline;
	x^.prev := nil;
	x^.next := nil;
	fstore_insert(f, x);
end;

procedure fstore_replace(var f : TFStore; s : string);
begin
	if f.curpos <> nil then
		f.curpos^.content := s;
end;

function fstore_move(var f: TFStore; relpos : integer) : boolean;
begin
	if f.curpos <> nil then
	begin
		fstore_move := true;
		if relpos < 0 then
		begin
			relpos := -relpos;
			while (relpos > 0) and (f.curpos^.prev <> nil) do
			begin
				Dec(relpos);
				f.curpos := f.curpos^.prev;
			end;
		end
		else
		begin
			while (relpos > 0) and (f.curpos^.next <> nil) do
			begin
				Dec(relpos);
				f.curpos := f.curpos^.next;
			end;
			if f.curpos = nil then
				fstore_move := false;
		end;
	end;
end;

function fstore_locate(var f : TFStore; s : string) : boolean;
var found : boolean;
begin
	fstore_locate := true;
	found := false;

	while not found and (f.curpos <> nil) do
	begin
		if Pos(s, f.curpos^.content) <> 0 then
			found := true
		else
			f.curpos := f.curpos^.next;
	end;
	if f.curpos = nil then
	begin
		fstore_locate := false;
		f.curpos := f.tail;
	end;
end;

function fstore_print(var f : TFStore; count : integer) : boolean;
begin
	fstore_print := true;
	while (count > 0) and (f.curpos <> nil) do
	begin
		writeln(f.curpos^.content);
		Dec(count);
		f.curpos := f.curpos^.next;
	end;
	if f.curpos = nil then
	begin
		if count > 0 then
			fstore_print := false;
		f.curpos := f.tail;
	end;
end;

function fstore_delete(var f : TFStore; count : integer) : boolean;
var tmp : PLine;
begin
	fstore_delete := true;
	while (count > 0) do
	begin
		if f.curpos = f.head then
		begin
			tmp := f.curpos;
			f.curpos := f.curpos^.next;
			if f.curpos <> nil then
			begin
				f.curpos^.prev := nil;
				f.head := f.curpos;
			end
			else
			begin
				f.tail := nil;
				f.head := nil;
			end;
			dispose(tmp);
		end
		else if f.curpos = f.tail then
		begin
			tmp := f.curpos;
			f.curpos := f.curpos^.prev;
			if f.curpos <> nil then
			begin
				f.curpos^.next := nil;
				f.tail := f.curpos;
			end
			else
			begin
				f.tail := nil;
				f.head := nil;
			end;
			dispose(tmp);
		end
		else
		begin
			tmp := f.curpos;
			tmp^.prev^.next := tmp^.next;
			tmp^.next^.prev := tmp^.prev;
			f.curpos := tmp^.next;
			dispose(tmp);
		end;
		Dec(count);
	end;

	if f.curpos = nil then
	begin
		if count > 0 then
			fstore_delete := false;
		f.curpos := f.tail;
	end;
end;

procedure change_str(var s : string; s1 : string; s2 : string; global : boolean);
var i : integer;
	tmp : string;
begin
	if Length(s1)=0 then
		Insert(s2, s, 1)
	else
	begin
		if global then
		begin
			i := Pos(s1, s);
			if i <> 0 then
			begin
				Delete(s, i, Length(s1));
				Insert(s2, s, i);
				tmp := s;
				Delete(tmp, 1, Length(s2) + i - 1);
				Delete(s, Length(s2) + i, Length(s) - Length(s2) - i + 1);
				change_str(tmp, s1, s2, global); (* recursive search/replace to take care that wrong substitutions due to "self-similarity" don't take place *)
				s := s + tmp;
			end;
		end
		else
		begin
			i := Pos(s1, s);
			if i <> 0 then
			begin
				Delete(s, i, Length(s1));
				Insert(s2, s, i);
			end;
		end;
	end;
end;

function fstore_change(var f : TFStore; s1 : string; s2 : string; count : integer; global : boolean) : boolean;
begin
	fstore_change := false;
	while (count > 0) and (f.curpos <> nil) do
	begin
		change_str(f.curpos^.content, s1, s2, global);
		f.curpos := f.curpos^.next;
		Dec(count);
	end;

	if f.curpos = nil then
	begin
		if count > 0 then
			fstore_change := true;
		f.curpos := f.tail;
	end;
end;

end.
