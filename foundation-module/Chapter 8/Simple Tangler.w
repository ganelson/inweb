[SimpleTangler::] Simple Tangler.

Unravelling (a simple version of) Inweb's literate programming notation to
access the tangled content.

@ Suppose we have a simple form of a web, in the sense of Inweb: one which
makes no use of macros, definitions or enumerations.[1] Because the syntax
used is a subset of Inweb syntax, there's no problem weaving such a web:
Inweb can be used for that. But now suppose we want to tangle the web, within
some application. We don't really want to embed the whole of Inweb into such
a program: something much simpler would surely be sufficient. And here it is.

[1] Why might we have this? Because kits of Inter code take this form.

@ The simple tangler is controlled using a parcel of settings. Note also the
|state|, which is not used by the reader itself, but instead allows the callback
functions to have a shared state of their own.

=
typedef struct simple_tangle_docket {
	void (*raw_callback)(struct text_stream *, struct simple_tangle_docket *);
	void (*command_callback)(struct text_stream *, struct text_stream *,
		struct text_stream *, struct simple_tangle_docket *);
	void (*bplus_callback)(struct text_stream *, struct simple_tangle_docket *);
	void (*error_callback)(char *, struct text_stream *);
	void *state;
	struct pathname *web_path;
} simple_tangle_docket;

@ =
simple_tangle_docket SimpleTangler::new_docket(
	void (*A)(struct text_stream *, struct simple_tangle_docket *),
	void (*B)(struct text_stream *, struct text_stream *,
		struct text_stream *, struct simple_tangle_docket *),
	void (*C)(struct text_stream *, struct simple_tangle_docket *),
	void (*D)(char *, struct text_stream *),
	pathname *web_path, void *initial_state) {
	simple_tangle_docket docket;
	docket.raw_callback = A;
	docket.command_callback = B;
	docket.bplus_callback = C;
	docket.error_callback = D;
	docket.state = initial_state;
	docket.web_path = web_path;
	return docket;
}

@ We can tangle either text already in memory, or a file (which the tangler
should open), or a section (which the tangler should find and open), or a
whole web of section files (ditto):

=
void SimpleTangler::tangle_text(simple_tangle_docket *docket, text_stream *text) {
	SimpleTangler::tangle_L1(docket, text, NULL, NULL, FALSE);
}

void SimpleTangler::tangle_file(simple_tangle_docket *docket, filename *F) {
	SimpleTangler::tangle_L1(docket, NULL, F, NULL, FALSE);
}

void SimpleTangler::tangle_section(simple_tangle_docket *docket, text_stream *leafname) {
	SimpleTangler::tangle_L1(docket, NULL, NULL, leafname, FALSE);
}

void SimpleTangler::tangle_web(simple_tangle_docket *docket) {
	SimpleTangler::tangle_L1(docket, NULL, NULL, NULL, TRUE);
}

@ =
void SimpleTangler::tangle_L1(simple_tangle_docket *docket, text_stream *text,
	filename *F, text_stream *leafname, int whole_web) {
	TEMPORARY_TEXT(T)
	SimpleTangler::tangle_L2(T, text, F, leafname, docket, whole_web);
	(*(docket->raw_callback))(T, docket);
	DISCARD_TEXT(T)
}

@ First, dispose of the "whole web" possibility.

=
void SimpleTangler::tangle_L2(OUTPUT_STREAM, text_stream *text, filename *F,
	text_stream *leafname, simple_tangle_docket *docket, int whole_web) {
	if (whole_web) {
		web_md *Wm = WebMetadata::get(docket->web_path, NULL, V2_SYNTAX, NULL, FALSE, TRUE, NULL);
		chapter_md *Cm;
		LOOP_OVER_LINKED_LIST(Cm, chapter_md, Wm->chapters_md) {
			section_md *Sm;
			LOOP_OVER_LINKED_LIST(Sm, section_md, Cm->sections_md) {
				filename *SF = Sm->source_file_for_section;
				SimpleTangler::tangle_L3(OUT, text, Sm->sect_title, docket, SF);
			}
		}
	} else {
		SimpleTangler::tangle_L3(OUT, text, leafname, docket, F);
	}
}

@ When tangling a file, we begin in |comment| mode; when tangling other matter,
not so much.

=
void SimpleTangler::tangle_L3(OUTPUT_STREAM, text_stream *text,
	text_stream *leafname, simple_tangle_docket *docket, filename *F) {
	int comment = FALSE;
	FILE *Input_File = NULL;
	if ((Str::len(leafname) > 0) || (F)) {
		@<Open the file@>;
		comment = TRUE;
	}
	@<Tangle the material@>;
	if (Input_File) fclose(Input_File);
}

@ Note that if we are looking for an explicit section -- say, |Juggling.i6t| --
from a web |W|, we translate that into the path |W/Sections/Juggling.i6t|.

@<Open the file@> =
	if (F) {
		Input_File = Filenames::fopen(F, "r");
	} else if (Str::len(leafname) > 0) {
		pathname *P = Pathnames::down(docket->web_path, I"Sections");
		Input_File = Filenames::fopen(Filenames::in(P, leafname), "r");
	}
	if (Input_File == NULL)
		(*(docket->error_callback))("unable to open the file '%S'", leafname);

@<Tangle the material@> =
	TEMPORARY_TEXT(command)
	TEMPORARY_TEXT(argument)
	int skip_part = FALSE, extract = FALSE;
	int col = 1, cr, sfp = 0;
	do {
		Str::clear(command);
		Str::clear(argument);
		@<Read next character@>;
		NewCharacter: if (cr == EOF) break;
		if (((cr == '@') || (cr == '=')) && (col == 1)) {
			int inweb_syntax = -1;
			if (cr == '=') @<Read the rest of line as an equals-heading@>
			else @<Read the rest of line as an at-heading@>;
			@<Act on the heading, going in or out of comment mode as appropriate@>;
			continue;
		}
		if (comment == FALSE) @<Deal with material which isn't commentary@>;
	} while (cr != EOF);
	DISCARD_TEXT(command)
	DISCARD_TEXT(argument)

@ Our text files are encoded as ISO Latin-1, not as Unicode UTF-8, so ordinary
|fgetc| is used, and no BOM marker is parsed. Lines are assumed to be terminated
with either |0x0a| or |0x0d|. (Since blank lines are harmless, we take no
trouble over |0a0d| or |0d0a| combinations.) The built-in template files, almost
always the only ones used, are line terminated |0x0a| in Unix fashion.

@<Read next character@> =
	if (Input_File) cr = fgetc(Input_File);
	else if (text) {
		cr = Str::get_at(text, sfp); if (cr == 0) cr = EOF; else sfp++;
	} else cr = EOF;
	col++; if ((cr == 10) || (cr == 13)) col = 0;

@ Here we see the limited range of Inweb syntaxes allowed; but some |@| and |=|
commands can be used, at least.

@d INWEB_PARAGRAPH_SYNTAX 1
@d INWEB_CODE_SYNTAX 2
@d INWEB_DASH_SYNTAX 3
@d INWEB_PURPOSE_SYNTAX 4
@d INWEB_FIGURE_SYNTAX 5
@d INWEB_EQUALS_SYNTAX 6
@d INWEB_EXTRACT_SYNTAX 7

@<Read the rest of line as an at-heading@> =
	TEMPORARY_TEXT(at_cmd)
	int committed = FALSE, unacceptable_character = FALSE;
	while (TRUE) {
		@<Read next character@>;
		if ((committed == FALSE) && ((cr == 10) || (cr == 13) || (cr == ' '))) {
			if (Str::eq_wide_string(at_cmd, L""))
				inweb_syntax = INWEB_PARAGRAPH_SYNTAX;
			else if (Str::eq_wide_string(at_cmd, L"p"))
				inweb_syntax = INWEB_PARAGRAPH_SYNTAX;
			else if (Str::eq_wide_string(at_cmd, L"h"))
				inweb_syntax = INWEB_PARAGRAPH_SYNTAX;
			else if (Str::eq_wide_string(at_cmd, L"c"))
				inweb_syntax = INWEB_CODE_SYNTAX;
			else if (Str::get_first_char(at_cmd) == '-')
				inweb_syntax = INWEB_DASH_SYNTAX;
			else if (Str::begins_with_wide_string(at_cmd, L"Purpose:"))
				inweb_syntax = INWEB_PURPOSE_SYNTAX;
			committed = TRUE;
			if (inweb_syntax == -1) {
				if (unacceptable_character == FALSE) {
					PUT_TO(OUT, '@');
					WRITE_TO(OUT, "%S", at_cmd);
					PUT_TO(OUT, cr);
					break;
				} else {
					LOG("heading begins: <%S>\n", at_cmd);
					(*(docket->error_callback))(
						"unknown '@...' marker at column 0: '%S'", at_cmd);
				}
			}
		}
		if (!(((cr >= 'A') && (cr <= 'Z')) || ((cr >= 'a') && (cr <= 'z'))
			|| ((cr >= '0') && (cr <= '9'))
			|| (cr == '-') || (cr == '>') || (cr == ':') || (cr == '_')))
			unacceptable_character = TRUE;
		if ((cr == 10) || (cr == 13)) break;
		PUT_TO(at_cmd, cr);
	}
	Str::copy(command, at_cmd);
	DISCARD_TEXT(at_cmd)

@<Read the rest of line as an equals-heading@> =
	TEMPORARY_TEXT(equals_cmd)
	while (TRUE) {
		@<Read next character@>;
		if ((cr == 10) || (cr == 13)) break;
		PUT_TO(equals_cmd, cr);
	}
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, equals_cmd, L" %(text%c*%) *")) {
		inweb_syntax = INWEB_EXTRACT_SYNTAX;
	} else if (Regexp::match(&mr, equals_cmd, L" %(figure%c*%) *")) {
		inweb_syntax = INWEB_FIGURE_SYNTAX;
	} else if (Regexp::match(&mr, equals_cmd, L" %(%c*%) *")) {
		(*(docket->error_callback))(
			"unsupported '= (...)' marker at column 0", NULL);
	} else {
		inweb_syntax = INWEB_EQUALS_SYNTAX;
	}
	Regexp::dispose_of(&mr);
	DISCARD_TEXT(equals_cmd)

@<Act on the heading, going in or out of comment mode as appropriate@> =
	switch (inweb_syntax) {
		case INWEB_PARAGRAPH_SYNTAX: {
			TEMPORARY_TEXT(heading_name)
			Str::copy_tail(heading_name, command, 2);
			int c;
			while (((c = Str::get_last_char(heading_name)) != 0) &&
				((c == ' ') || (c == '\t') || (c == '.')))
				Str::delete_last_character(heading_name);
			if (Str::len(heading_name) == 0)
				(*(docket->error_callback))("Empty heading name", NULL);
			DISCARD_TEXT(heading_name)
			extract = FALSE; 
			comment = TRUE; skip_part = FALSE;
			break;
		}
		case INWEB_CODE_SYNTAX:
			extract = FALSE; 
			if (skip_part == FALSE) comment = FALSE;
			break;
		case INWEB_EQUALS_SYNTAX:
			if (extract) {
				comment = TRUE; extract = FALSE;
			} else {
				if (skip_part == FALSE) comment = FALSE;
			}
			break;
		case INWEB_EXTRACT_SYNTAX:
			comment = TRUE; extract = TRUE;
			break;
		case INWEB_DASH_SYNTAX: break;
		case INWEB_PURPOSE_SYNTAX: break;
		case INWEB_FIGURE_SYNTAX: break;
	}

@<Deal with material which isn't commentary@> =
	if (cr == '{') {
		@<Read next character@>;
		if ((cr == '-') && (docket->command_callback)) {
			@<Read up to the next close brace as a braced command and argument@>;
			if (Str::get_first_char(command) == '!') continue;
			(*(docket->command_callback))(OUT, command, argument, docket);
			continue;
		} else { /* otherwise the open brace was a literal */
			PUT_TO(OUT, '{');
			goto NewCharacter;
		}
	}
	if ((cr == '(') && (docket->bplus_callback)) {
		@<Read next character@>;
		if (cr == '+') {
			@<Read up to the next plus close-bracket as an I7 expression@>;
			continue;
		} else { /* otherwise the open bracket was a literal */
			PUT_TO(OUT, '(');
			goto NewCharacter;
		}
	}
	PUT_TO(OUT, cr);

@ And here we read a normal command. The command name must not include |}|
or |:|. If there is no |:| then the argument is left unset (so that it will
be the empty string: see above). The argument must not include |}|.

@<Read up to the next close brace as a braced command and argument@> =
	Str::clear(command);
	Str::clear(argument);
	int com_mode = TRUE;
	while (TRUE) {
		@<Read next character@>;
		if ((cr == '}') || (cr == EOF)) break;
		if ((cr == ':') && (com_mode)) { com_mode = FALSE; continue; }
		if (com_mode) PUT_TO(command, cr);
		else PUT_TO(argument, cr);
	}

@ And similarly, for the |(+| ... |+)| notation which was once used to mark
I7 material within I6:

@<Read up to the next plus close-bracket as an I7 expression@> =
	TEMPORARY_TEXT(material)
	while (TRUE) {
		@<Read next character@>;
		if (cr == EOF) break;
		if ((cr == ')') && (Str::get_last_char(material) == '+')) {
			Str::delete_last_character(material); break; }
		PUT_TO(material, cr);
	}
	(*(docket->bplus_callback))(material, docket);
	DISCARD_TEXT(material)
