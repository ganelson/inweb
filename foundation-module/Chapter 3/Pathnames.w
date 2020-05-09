[Pathnames::] Pathnames.

Locations of hypothetical or real directories in the filing system.

@h About pathnames.
We use the word "pathname" to mean a file-system location of a directory,
and "filename" to mean a location of a file. For example:
= (text)
	/Users/rblackmore/Documents/Fireball
=
is a pathname, whereas
= (text)
	/Users/rblackmore/Documents/Fireball/whoosh.aiff
=
is a filename. All references to directory locations in the filing system will be
held internally as |pathname| objects, and all references to file locations as
|filename| objects. Once created, these are never destroyed or modified,
so that it's safe to store a pointer to a pathname or filename anywhere.

Note that a pathname may well be hypothetical, that is, it may well
describe a directory which doesn't exist on disc.

A full path is a linked list, but reverse-ordered: thus,
= (text)
	/Users/rblackmore/Documents/
=
would be represented as a pointer to the |pathname| for "Documents", which
in turn points to one for "rblackmore", which in turn points to "/Users".
Thus the root of the filing system is represented by the null pointer.

Each |pathname| can represent only a single level in the hierarchy, and
its textual name is not allowed to contain the |FOLDER_SEPARATOR| character,
with just one exception: the |pathname| at the end of the chain is allowed
to begin with |FOLDER_SEPARATOR| to denote that it's at the root of the
host file system.

=
typedef struct pathname {
	struct text_stream *intermediate;
	struct pathname *pathname_of_parent;
	int known_to_exist; /* corresponds to a directory in the filing system */
	CLASS_DEFINITION
} pathname;

@h Home directory.
We get the path to the user's home directory from the environment variable
|HOME|, if it exists.

=
pathname *home_path = NULL;
void Pathnames::start(void) {
	char *home = (char *) (Platform::getenv("HOME"));
	if (home) {
		text_stream *H = Str::new_from_locale_string(home);
		home_path = Pathnames::from_text(H);
		home_path->known_to_exist = TRUE;
	}
}

@h Installation directory.

=
pathname *installation_path = NULL;
void Pathnames::set_installation_path(pathname *P) {
	installation_path = P;
}
pathname *Pathnames::installation_path(const char *V, text_stream *def) {
	if (installation_path) return installation_path;
	wchar_t where[4*MAX_FILENAME_LENGTH];
	where[0] = 0;
	Platform::where_am_i(where, 4*MAX_FILENAME_LENGTH);
	if (where[0]) {
		text_stream *v = Str::new_from_wide_string(where);
		filename *F = Filenames::from_text(v);
		pathname *P = Filenames::up(F);
		if ((P) && (Str::eq(P->intermediate, I"Tangled")))
			P = P->pathname_of_parent;
		return P;
	}
	if (V) {
		char *val = Platform::getenv(V);
		if ((val) && (val[0])) {
			text_stream *v = Str::new_from_locale_string(val);
			return Pathnames::from_text(v);
		}
	}
	if (def) return Pathnames::from_text(def);
	return NULL;
}

@h Creation.
A subdirectory is made by taking an existing pathname (or possible |NULL|) and
then going one level deeper, using the supplied name.

=
pathname *Pathnames::down(pathname *P, text_stream *dir_name) {
	return Pathnames::primitive(dir_name, 0, Str::len(dir_name), P);
}

pathname *Pathnames::primitive(text_stream *str, int from, int to, pathname *par) {
	pathname *P = CREATE(pathname);
	P->pathname_of_parent = par;
	P->known_to_exist = FALSE;
	if (to-from <= 0) internal_error("empty intermediate pathname");
	P->intermediate = Str::new_with_capacity(to-from+1);
	if (str)
		for (int i = from; i < to; i++)
			PUT_TO(P->intermediate, Str::get(Str::at(str, i)));
	return P;
}

@h Text to pathnames.
The following takes a text of a name and returns a pathname,
possibly relative to the home directory. Empty directory names are ignored
except possibly for an initial slash, so for example |paris/roubaix|,
|paris//roubaix| and |paris/roubaix/| are indistinguishable here, but
|/paris/roubaix| is different.

=
pathname *Pathnames::from_text(text_stream *path) {
	return Pathnames::from_text_relative(NULL, path);
}

pathname *Pathnames::from_text_relative(pathname *P, text_stream *path) {
	pathname *at = P;
	int i = 0, pos = 0;
	if ((Str::get(Str::start(path))) && (P == NULL)) i++;
	for (; i < Str::len(path); i++)
		if (Str::get(Str::at(path, i)) == FOLDER_SEPARATOR) {
			if (i > pos) at = Pathnames::primitive(path, pos, i, at);
			pos = i+1;
		}
	if (i > pos) at = Pathnames::primitive(path, pos, i, at);
	return at;
}

@h Writer.
Conversely, by the miracle of depth-first recursion:

=
void Pathnames::writer(OUTPUT_STREAM, char *format_string, void *vP) {
	pathname *P = (pathname *) vP;
	int divider = FOLDER_SEPARATOR;
	if (format_string[0] == '/') divider = '/';
	if (P) Pathnames::writer_r(OUT, P, divider); else WRITE(".");
}

void Pathnames::writer_r(OUTPUT_STREAM, pathname *P, int divider) {
	if (P->pathname_of_parent) {
		Pathnames::writer_r(OUT, P->pathname_of_parent, divider);
		PUT(divider);
	}
	WRITE("%S", P->intermediate);
}

@h Relative pathnames.
Occasionally we want to shorten a pathname relative to another one:
for example,
= (text)
	/Users/rblackmore/Documents/Fireball/tablature
=
relative to
= (text)
	/Users/rblackmore/Documents/
=
would be
= (text)
	Fireball/tablature
=
Note that this does not correctly handle symlinks, |.|, |..| and so on,
so it's probably not wise to use it with filenames typed in at the command
line.

=
void Pathnames::to_text_relative(OUTPUT_STREAM, pathname *P, pathname *R) {
	TEMPORARY_TEXT(rt);
	TEMPORARY_TEXT(pt);
	WRITE_TO(rt, "%p", R);
	WRITE_TO(pt, "%p", P);
	int n = Str::len(pt);
	if ((Str::prefix_eq(rt, pt, n)) && (Str::get_at(rt, n)==FOLDER_SEPARATOR)) {
		Str::delete_n_characters(rt, n+1);
		WRITE("%S", rt);
	} else internal_error("pathname not relative to pathname");
	DISCARD_TEXT(rt);
	DISCARD_TEXT(pt);
}

pathname *Pathnames::up(pathname *P) {
	if (P == NULL) internal_error("can't go up from root directory");
	return P->pathname_of_parent;
}

text_stream *Pathnames::directory_name(pathname *P) {
	if (P == NULL) return NULL;
	return P->intermediate;
}

@h Relative URLs.
Suppose a web page in the directory at |from| wants to link to a page in
the directory |to|. The following composes a minimal-length URL to do so:
possibly, if they are in fact the same directory, an empty one.

=
void Pathnames::relative_URL(OUTPUT_STREAM, pathname *from, pathname *to) {
	TEMPORARY_TEXT(url);
	int found = FALSE;
	for (pathname *P = to; P && (found == FALSE); P = Pathnames::up(P)) {
		TEMPORARY_TEXT(PT);
		WRITE_TO(PT, "%p", P);
		int q_up_count = 0;
		for (pathname *Q = from; Q && (found == FALSE); Q = Pathnames::up(Q)) {
			TEMPORARY_TEXT(QT);
			WRITE_TO(QT, "%p", Q);
			if (Str::eq(PT, QT)) {
				for (int i=0; i<q_up_count; i++) WRITE_TO(url, "../");
				TEMPORARY_TEXT(FPT);
				WRITE_TO(FPT, "%p", to);
				Str::substr(url, Str::at(FPT, Str::len(PT) + 1), Str::end(FPT));
				found = TRUE;
			}
			DISCARD_TEXT(QT);
			q_up_count++;
		}
		DISCARD_TEXT(PT);
	}
	if (found == FALSE) {
		for (pathname *Q = from; Q; Q = Pathnames::up(Q)) WRITE_TO(url, "../");
		WRITE_TO(url, "%p", to);
	}
	WRITE("%S", url);
	if ((Str::len(url) > 0) && (Str::get_last_char(url) != '/')) WRITE("/");
	DISCARD_TEXT(url);
}

@h Existence in the file system.
Just because we have a pathname, it doesn't follow that any directory exists
on the file system with that path.

=
int Pathnames::create_in_file_system(pathname *P) {
	if (P == NULL) return TRUE; /* the root of the file system always exists */
	if (P->known_to_exist) return TRUE;
	char transcoded_pathname[4*MAX_FILENAME_LENGTH];
	TEMPORARY_TEXT(pn);
	WRITE_TO(pn, "%p", P);
	Str::copy_to_locale_string(transcoded_pathname, pn, 4*MAX_FILENAME_LENGTH);
	DISCARD_TEXT(pn);
	P->known_to_exist = Platform::mkdir(transcoded_pathname);
	return P->known_to_exist;
}

@h Directory synchronisation.
Both pathnames here represent directories which do exist. The function makes
the |dest| tree an exact copy of the |source| tree (and therefore deletes
anything different which was originally in |dest|).

=
void Pathnames::rsync(pathname *source, pathname *dest) {
	char transcoded_source[4*MAX_FILENAME_LENGTH];
	TEMPORARY_TEXT(pn);
	WRITE_TO(pn, "%p", source);
	Str::copy_to_locale_string(transcoded_source, pn, 4*MAX_FILENAME_LENGTH);
	DISCARD_TEXT(pn);
	char transcoded_dest[4*MAX_FILENAME_LENGTH];
	TEMPORARY_TEXT(pn2);
	WRITE_TO(pn2, "%p", dest);
	Str::copy_to_locale_string(transcoded_dest, pn2, 4*MAX_FILENAME_LENGTH);
	DISCARD_TEXT(pn2);
	Platform::rsync(transcoded_source, transcoded_dest);
}
