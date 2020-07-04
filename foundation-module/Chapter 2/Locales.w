[Locales::] Locales.

Locales are what operating-system people call the text encodings used when
interacting with them: in filenames, or when printing to the console.

@ We will support two different locales:

@e SHELL_LOCALE from 0
@e CONSOLE_LOCALE

=
char *Locales::name(int L) {
	switch (L) {
		case SHELL_LOCALE: return "shell";
		case CONSOLE_LOCALE: return "console";
	}
	return "";
}

int Locales::parse_locale(char *name) {
	for (int i=0; i<NO_DEFINED_LOCALE_VALUES; i++)
		if (strcmp(name, Locales::name(i)) == 0)
			return i;
	return -1;
}

@ The encodings for each locale are stored in the following global array.
The value |-1| means "platform", that is, "the default value for the current
operating system".

=
int locales_unset = TRUE;
int locale_settings[NO_DEFINED_LOCALE_VALUES];

int Locales::get(int L) {
	if ((L < 0) || (L >= NO_DEFINED_LOCALE_VALUES)) Errors::fatal("locale out of range");
	if (locales_unset) return Locales::platform_locale();
	if (locale_settings[L] >= 0) return locale_settings[L];
	return Locales::platform_locale();
}

void Locales::set(int L, int E) {
	if ((L < 0) || (L >= NO_DEFINED_LOCALE_VALUES)) Errors::fatal("locale out of range");
	if (locales_unset) {
		for (int i=0; i<NO_DEFINED_LOCALE_VALUES; i++) locale_settings[i] = -1;
		locales_unset = FALSE;
	}
	locale_settings[L] = E;
}

@ The possible encodings have names. We must do everything here with |char *|
and without any higher-level //foundation// facilities, because locale-setting
has to be done extremely early in the run (since it affects how command line
arguments are read).

Note that new encodings could only be added here if matching changes were made
to //Streams//.

=
int Locales::parse_encoding(char *name) {
	if (strcmp(name, "platform") == 0) return -1;
	if (strcmp(name, "iso-latin1") == 0) return FILE_ENCODING_ISO_STRF;
	if (strcmp(name, "utf-8") == 0) return FILE_ENCODING_UTF8_STRF;
	return 0;
}

@ This can only run after locales have safely been set, since it probably
writes to |STDOUT|, whose encoding depends on locale. For example, //inweb//
calls this in response to |-verbose|.

=
void Locales::write_locales(OUTPUT_STREAM) {
	WRITE("Locales are: ");
	for (int i=0; i<NO_DEFINED_LOCALE_VALUES; i++) {
		if (i > 0) WRITE(", ");
		WRITE("%s = ", Locales::name(i));
		Locales::write_locale(OUT, Locales::get(i));
	}
	WRITE("\n");
}

void Locales::write_locale(OUTPUT_STREAM, int L) {
	switch (L) {
		case -1:
			WRITE("platform (= ");
			Locales::write_locale(OUT, Locales::platform_locale());
			WRITE(")"); break;
		case FILE_ENCODING_ISO_STRF: WRITE("iso-latin1"); break;
		case FILE_ENCODING_UTF8_STRF: WRITE("utf-8"); break;
		default: WRITE("?"); break;
	}
}

@ And this is how we determine the default; see //POSIX Platforms// and
//Windows Platform// for these |LOCALE_IS_*| constants.

=
int Locales::platform_locale(void) {
	#ifdef LOCALE_IS_ISO
	return FILE_ENCODING_ISO_STRF;
	#endif
	#ifndef LOCALE_IS_ISO
		#ifdef LOCALE_IS_UTF8
		return FILE_ENCODING_UTF8_STRF;
		#endif
		#ifndef LOCALE_IS_UTF8
		Errors::fatal("built without either LOCALE_IS_ISO or LOCALE_IS_UTF8");
		return FILE_ENCODING_UTF8_STRF;
		#endif
	#endif
}

@ This unlovely function parses a comma-separated list of assignments in
the form |LOCALE=ENCODING|, returning |TRUE| if this was syntactically valid
and |FALSE| if not.

=
int Locales::set_locales(char *text) {
	if (text == NULL) return FALSE;
	for (int at=0; ((at >= 0) && (text[at])); ) {
		int c = -1;
		for (int i=at; text[i]; i++) if (text[i] == '=') { c = i; break; }
		if (c == -1) return FALSE;
		if (c-at >= 16) return FALSE;
		char L1[16], L2[16];
		for (int i=0; i<16; i++) { L1[i] = 0; L2[i] = 0; }
		for (int i=0; i<c-at; i++) L1[i] = (char) tolower((int) text[at+i]);
		int next_at = -1;
		for (int i=0; (text[c+1+i]) && (i<16); i++) {
			if (text[c+1+i] == ',') { next_at = c+1+i+1; break; }
			L2[i] = (char) tolower((int) text[c+1+i]);
		}
		int L = Locales::parse_locale(L1), E = Locales::parse_encoding(L2);
		if ((L < 0) || (L >= NO_DEFINED_LOCALE_VALUES)) return FALSE;
		if (E == 0) return FALSE;
		Locales::set(L, E);
		at = next_at;
	}
	return TRUE;
}
