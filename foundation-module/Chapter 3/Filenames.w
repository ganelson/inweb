[Filenames::] Filenames.

Names of hypothetical or real files in the filing system.

@h Storage.
Filename objects behave much like pathname ones, but they have their own
structure in order that the two are distinct C types. Individual filenames
are a single instance of the following. (Note that the text part is stored
as Unicode code points, regardless of what text encoding the locale has.)

=
typedef struct filename {
	struct pathname *pathname_of_location;
	struct text_stream *leafname;
	CLASS_DEFINITION
} filename;

@h Creation.
A filename is made by supplying a pathname and a leafname.

=
filename *Filenames::in(pathname *P, text_stream *file_name) {
	return Filenames::primitive(file_name, 0, Str::len(file_name), P);
}

filename *Filenames::primitive(text_stream *S, int from, int to, pathname *P) {
	filename *F = CREATE(filename);
	F->pathname_of_location = P;
	if (to-from <= 0)
		internal_error("empty intermediate pathname");
	F->leafname = Str::new_with_capacity(to-from+1);
	string_position pos = Str::at(S, from);
	for (int i = from; i < to; i++, pos = Str::forward(pos))
		PUT_TO(F->leafname, Str::get(pos));
	return F;
}

@h Strings to filenames.
The following takes a textual name and returns a filename.

=
filename *Filenames::from_text(text_stream *path) {
	int i = 0, pos = -1;
	LOOP_THROUGH_TEXT(at, path) {
		if (Platform::is_folder_separator(Str::get(at))) pos = i;
		i++;
	}
	pathname *P = NULL;
	if (pos >= 0) {
		TEMPORARY_TEXT(PT)
		Str::substr(PT, Str::at(path, 0), Str::at(path, pos));
		P = Pathnames::from_text(PT);
		DISCARD_TEXT(PT)
	}
	return Filenames::primitive(path, pos+1, Str::len(path), P);
}

filename *Filenames::from_text_relative(pathname *from, text_stream *path) {
	filename *F = Filenames::from_text(path);
	if (from) {
		if (F->pathname_of_location == NULL) F->pathname_of_location = from;
		else {
			pathname *P = F->pathname_of_location;
			while ((P) && (P->pathname_of_parent)) P = P->pathname_of_parent;
			P->pathname_of_parent = from;
		}
	}
	return F;
}

@h The writer.
And conversely:

=
void Filenames::writer(OUTPUT_STREAM, char *format_string, void *vF) {
	filename *F = (filename *) vF;
	if (F == NULL) WRITE("<no file>");
	else {
		if (F->pathname_of_location) {
			Pathnames::writer(OUT, format_string, (void *) F->pathname_of_location);
			if (format_string[0] == '/') PUT('/');
			else PUT(FOLDER_SEPARATOR);
		}
		WRITE("%S", F->leafname);
	}
}

@ And again relative to a given pathname:

=
void Filenames::to_text_relative(OUTPUT_STREAM, filename *F, pathname *P) {
	TEMPORARY_TEXT(ft)
	TEMPORARY_TEXT(pt)
	WRITE_TO(ft, "%f", F);
	WRITE_TO(pt, "%p", P);
	int n = Str::len(pt);
	if ((Str::prefix_eq(ft, pt, n)) && (Platform::is_folder_separator(Str::get_at(ft, n)))) {
		Str::delete_n_characters(ft, n+1);
		WRITE("%S", ft);
	} else {
		if (P == NULL) {
			WRITE("%S", ft);
		} else {
			WRITE("..%c", FOLDER_SEPARATOR);
			Filenames::to_text_relative(OUT, F, Pathnames::up(P));
		}
	}
	DISCARD_TEXT(ft)
	DISCARD_TEXT(pt)
}

@h Reading off the directory.

=
pathname *Filenames::up(filename *F) {
	if (F == NULL) return NULL;
	return F->pathname_of_location;
}

@h Reading off the leafname.

=
filename *Filenames::without_path(filename *F) {
	return Filenames::in(NULL, F->leafname);
}

text_stream *Filenames::get_leafname(filename *F) {
	if (F == NULL) return NULL;
	return F->leafname;
}

void Filenames::write_unextended_leafname(OUTPUT_STREAM, filename *F) {
	LOOP_THROUGH_TEXT(pos, F->leafname) {
		inchar32_t c = Str::get(pos);
		if (c == '.') return;
		PUT(c);
	}
}

@h Filename extensions.
The following is cautiously written because of an oddity in Windows's handling
of filenames, which are allowed to have trailing dots or spaces, in a way
which isn't necessarily visible to the user, who may have added these by
an accidental brush of the keyboard. Thus |frog.jpg .| should be treated
as equivalent to |frog.jpg| when deciding the likely file format.

=
void Filenames::write_extension(OUTPUT_STREAM, filename *F) {
	int on = FALSE;
	LOOP_THROUGH_TEXT(pos, F->leafname) {
		inchar32_t c = Str::get(pos);
		if (c == '.') on = TRUE;
		if (on) PUT(c);
	}
}

filename *Filenames::set_extension(filename *F, text_stream *extension) {
	TEMPORARY_TEXT(NEWLEAF)
	LOOP_THROUGH_TEXT(pos, F->leafname) {
		inchar32_t c = Str::get(pos);
		if (c == '.') break;
		PUT_TO(NEWLEAF, c);
	}
	if (Str::len(extension) > 0) {
		if (Str::get_first_char(extension) != '.') WRITE_TO(NEWLEAF, ".");
		WRITE_TO(NEWLEAF, "%S", extension);
	}
	filename *N = Filenames::in(F->pathname_of_location, NEWLEAF);
	DISCARD_TEXT(NEWLEAF)
	return N;
}

@h Guessing file formats.
The following guesses the file format from its file extension:

@d FORMAT_PERHAPS_HTML 1
@d FORMAT_PERHAPS_JPEG 2
@d FORMAT_PERHAPS_PNG 3
@d FORMAT_PERHAPS_OGG 4
@d FORMAT_PERHAPS_AIFF 5
@d FORMAT_PERHAPS_MIDI 6
@d FORMAT_PERHAPS_MOD 7
@d FORMAT_PERHAPS_GLULX 8
@d FORMAT_PERHAPS_ZCODE 9
@d FORMAT_PERHAPS_SVG 10
@d FORMAT_PERHAPS_GIF 11
@d FORMAT_UNRECOGNISED 0

=
int Filenames::guess_format(filename *F) {
	TEMPORARY_TEXT(EXT)
	Filenames::write_extension(EXT, F);
	TEMPORARY_TEXT(NORMALISED)
	LOOP_THROUGH_TEXT(pos, EXT) {
		inchar32_t c = Str::get(pos);
		if (c != ' ') PUT_TO(NORMALISED, Characters::tolower(c));
	}
	DISCARD_TEXT(EXT)

	int verdict = FORMAT_UNRECOGNISED;
	if (Str::eq_wide_string(NORMALISED, U".html")) verdict = FORMAT_PERHAPS_HTML;
	else if (Str::eq_wide_string(NORMALISED, U".htm")) verdict = FORMAT_PERHAPS_HTML;
	else if (Str::eq_wide_string(NORMALISED, U".jpg")) verdict = FORMAT_PERHAPS_JPEG;
	else if (Str::eq_wide_string(NORMALISED, U".jpeg")) verdict = FORMAT_PERHAPS_JPEG;
	else if (Str::eq_wide_string(NORMALISED, U".png")) verdict = FORMAT_PERHAPS_PNG;
	else if (Str::eq_wide_string(NORMALISED, U".ogg")) verdict = FORMAT_PERHAPS_OGG;
	else if (Str::eq_wide_string(NORMALISED, U".aiff")) verdict = FORMAT_PERHAPS_AIFF;
	else if (Str::eq_wide_string(NORMALISED, U".aif")) verdict = FORMAT_PERHAPS_AIFF;
	else if (Str::eq_wide_string(NORMALISED, U".midi")) verdict = FORMAT_PERHAPS_MIDI;
	else if (Str::eq_wide_string(NORMALISED, U".mid")) verdict = FORMAT_PERHAPS_MIDI;
	else if (Str::eq_wide_string(NORMALISED, U".mod")) verdict = FORMAT_PERHAPS_MOD;
	else if (Str::eq_wide_string(NORMALISED, U".svg")) verdict = FORMAT_PERHAPS_SVG;
	else if (Str::eq_wide_string(NORMALISED, U".gif")) verdict = FORMAT_PERHAPS_GIF;
	else if (Str::len(NORMALISED) > 0) {
		if ((Str::get(Str::at(NORMALISED, 0)) == '.') &&
			(Str::get(Str::at(NORMALISED, 1)) == 'z') &&
			(Characters::isdigit(Str::get(Str::at(NORMALISED, 2)))) &&
			(Str::len(NORMALISED) == 3))
			verdict = FORMAT_PERHAPS_ZCODE;
		else if (Str::get(Str::back(Str::end(NORMALISED))) == 'x')
			verdict = FORMAT_PERHAPS_GLULX;
	}
	DISCARD_TEXT(NORMALISED)
	return verdict;
}

@h Opening.
These files are wrappers for |fopen|, the traditional C library call, but
referring to the file by filename structure rather than a textual name. Note
that we must transcode the filename to whatever the locale expects before
we call |fopen|, which is the main reason for the wrapper.

=
FILE *Filenames::fopen(filename *F, char *usage) {
	char transcoded_pathname[4*MAX_FILENAME_LENGTH];
	TEMPORARY_TEXT(FN)
	WRITE_TO(FN, "%f", F);
	Str::copy_to_locale_string(transcoded_pathname, FN, 4*MAX_FILENAME_LENGTH);
	DISCARD_TEXT(FN)
	return fopen(transcoded_pathname, usage);
}

FILE *Filenames::fopen_caseless(filename *F, char *usage) {
	char transcoded_pathname[4*MAX_FILENAME_LENGTH];
	TEMPORARY_TEXT(FN)
	WRITE_TO(FN, "%f", F);
	Str::copy_to_locale_string(transcoded_pathname, FN, 4*MAX_FILENAME_LENGTH);
	DISCARD_TEXT(FN)
	return CIFilingSystem::fopen(transcoded_pathname, usage);
}

@h Comparing.
Not as easy as it seems. The following is a slow but effective way to
compare two filenames by seeing if they have the same canonical form
when printed out.

=
int Filenames::eq(filename *F1, filename *F2) {
	if (F1 == F2) return TRUE;
	TEMPORARY_TEXT(T1)
	TEMPORARY_TEXT(T2)
	WRITE_TO(T1, "%f", F1);
	WRITE_TO(T2, "%f", F2);
	int rv = Str::eq(T1, T2);
	DISCARD_TEXT(T1)
	DISCARD_TEXT(T2)
	return rv;
}

int Filenames::eq_insensitive(filename *F1, filename *F2) {
	if (F1 == F2) return TRUE;
	TEMPORARY_TEXT(T1)
	TEMPORARY_TEXT(T2)
	WRITE_TO(T1, "%f", F1);
	WRITE_TO(T2, "%f", F2);
	int rv = Str::eq_insensitive(T1, T2);
	DISCARD_TEXT(T1)
	DISCARD_TEXT(T2)
	return rv;
}

@h Timestamps and sizes.

=
time_t Filenames::timestamp(filename *F) {
	char transcoded_pathname[4*MAX_FILENAME_LENGTH];
	TEMPORARY_TEXT(FN)
	WRITE_TO(FN, "%f", F);
	Str::copy_to_locale_string(transcoded_pathname, FN, 4*MAX_FILENAME_LENGTH);
	time_t t = Platform::timestamp(transcoded_pathname);
	DISCARD_TEXT(FN)
	return t;
}

int Filenames::size(filename *F) {
	char transcoded_pathname[4*MAX_FILENAME_LENGTH];
	TEMPORARY_TEXT(FN)
	WRITE_TO(FN, "%f", F);
	Str::copy_to_locale_string(transcoded_pathname, FN, 4*MAX_FILENAME_LENGTH);
	int t = (int) Platform::size(transcoded_pathname);
	DISCARD_TEXT(FN)
	return t;
}

@h Renaming.
If this succeeds, the filename |F| is altered to match the new name, and
the function returns |TRUE|; if not, |F| is unchanged, and |FALSE|.

=
int Filenames::rename(filename *F, text_stream *new_name) {
	text_stream *old_name = Filenames::get_leafname(F);
	if (Str::eq(old_name, new_name)) return TRUE;
	filename *G = Filenames::in(Filenames::up(F), new_name);
	TEMPORARY_TEXT(old_path)
	TEMPORARY_TEXT(new_path)
	WRITE_TO(old_path, "%f", F);
	WRITE_TO(new_path, "%f", G);
	char old_name_written_out[4*MAX_FILENAME_LENGTH];
	Str::copy_to_locale_string(old_name_written_out, old_path, 4*MAX_FILENAME_LENGTH);
	char new_name_written_out[4*MAX_FILENAME_LENGTH];
	Str::copy_to_locale_string(new_name_written_out, new_path, 4*MAX_FILENAME_LENGTH);
	int rv = Platform::rename_file(old_name_written_out, new_name_written_out);
	if (rv) {
		Str::clear(F->leafname);
		Str::copy(F->leafname, new_name);
	}
	DISCARD_TEXT(old_path)
	DISCARD_TEXT(new_path)
	return rv;
}

@h Copying.

=
void Filenames::copy_file(filename *from, filename *to) {
	TEMPORARY_TEXT(from_path)
	TEMPORARY_TEXT(to_path)
	WRITE_TO(from_path, "%f", from);
	WRITE_TO(to_path, "%f", to);
	char from_name_written_out[4*MAX_FILENAME_LENGTH];
	Str::copy_to_locale_string(from_name_written_out, from_path, 4*MAX_FILENAME_LENGTH);
	char to_name_written_out[4*MAX_FILENAME_LENGTH];
	Str::copy_to_locale_string(to_name_written_out, to_path, 4*MAX_FILENAME_LENGTH);
	Platform::copy_file(from_name_written_out, to_name_written_out);
	DISCARD_TEXT(from_path)
	DISCARD_TEXT(to_path)
}

@h Moving.

=
int Filenames::move_file(filename *from, filename *to) {
	TEMPORARY_TEXT(from_path)
	TEMPORARY_TEXT(to_path)
	WRITE_TO(from_path, "%f", from);
	WRITE_TO(to_path, "%f", to);
	char from_name_written_out[4*MAX_FILENAME_LENGTH];
	Str::copy_to_locale_string(from_name_written_out, from_path, 4*MAX_FILENAME_LENGTH);
	char to_name_written_out[4*MAX_FILENAME_LENGTH];
	Str::copy_to_locale_string(to_name_written_out, to_path, 4*MAX_FILENAME_LENGTH);
	int rv = Platform::rename_file(from_name_written_out, to_name_written_out);
	DISCARD_TEXT(from_path)
	DISCARD_TEXT(to_path)
	return rv;
}
