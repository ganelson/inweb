[Readme::] Readme Writeme.

To construct Readme and similar files.

@ This is a very simple generator for |README.md| files, written in Markdown
syntax, but with a few macro expansions of our own. The prototype file, which
uses these extra macros, is expanded to the final file, which does not.

As we scan through the prototype file, we keep track of this:

=
typedef struct write_state {
	struct text_stream *OUT;
	struct linked_list *known_macros; /* of |macro| */
	struct macro *current_definition;
	struct macro_tokens *stack_frame;
} write_state;

void Readme::write(filename *from, filename *to) {
	WRITE_TO(STDOUT, "write-me: %f --> %f\n", from, to);
	write_state ws;
	ws.current_definition = NULL;
	ws.known_macros = NEW_LINKED_LIST(macro);
	macro *V = Readme::new_macro(I"version", NULL, NULL);
	ADD_TO_LINKED_LIST(V, macro, ws.known_macros);
	macro *P = Readme::new_macro(I"purpose", NULL, NULL);
	ADD_TO_LINKED_LIST(P, macro, ws.known_macros);
	macro *A = Readme::new_macro(I"var", NULL, NULL);
	ADD_TO_LINKED_LIST(A, macro, ws.known_macros);
	ws.stack_frame = NULL;
	text_stream file_to;
	if (Streams::open_to_file(&file_to, to, UTF8_ENC) == FALSE)
		Errors::fatal_with_file("can't write readme file", to);
	ws.OUT = &file_to;
	TextFiles::read(from, FALSE, "unable to read template file", TRUE,
		&Readme::write_helper, NULL, (void *) &ws);
	Streams::close(&file_to);
}

@ The file consists of definitions of macros, made one at a time, and
starting with |@define| and finishing with |@end|, and actual material.

=
void Readme::write_helper(text_stream *text, text_file_position *tfp, void *state) {
	write_state *ws = (write_state *) state;
	text_stream *OUT = ws->OUT;

	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, text, L" *@end *")) {
		if (ws->current_definition == NULL)
			Errors::in_text_file("@end without @define", tfp);
		else ws->current_definition = NULL;
	} else if (ws->current_definition) {
		if (Str::len(ws->current_definition->content) > 0)
			WRITE_TO(ws->current_definition->content, "\n");
		WRITE_TO(ws->current_definition->content, "%S", text);
	} else if (Regexp::match(&mr, text, L" *@define (%i+)(%c*)")) {
		if (ws->current_definition)
			Errors::in_text_file("@define without @end", tfp);
		else {
			macro *M = Readme::new_macro(mr.exp[0], mr.exp[1], tfp);
			ws->current_definition = M;
			ADD_TO_LINKED_LIST(M, macro, ws->known_macros);
		}
	} else {
		Readme::expand_material(ws, OUT, text, tfp);
		Readme::expand_material(ws, OUT, I"\n", tfp);
	}
	Regexp::dispose_of(&mr);
}

@ The "content" of a macro is its definition, and the tokens are named
parameters.

=
typedef struct macro {
	struct text_stream *name;
	struct text_stream *content;
	struct macro_tokens tokens;
	MEMORY_MANAGEMENT
} macro;

macro *Readme::new_macro(text_stream *name, text_stream *tokens, text_file_position *tfp) {
	macro *M = CREATE(macro);
	M->name = Str::duplicate(name);
	M->tokens = Readme::parse_token_list(tokens, tfp);
	M->content = Str::new();
	return M;
}

typedef struct macro_tokens {
	struct macro *bound_to;
	struct text_stream *pars[8];
	int no_pars;
	struct macro_tokens *down;
	MEMORY_MANAGEMENT
} macro_tokens;

@ =
macro_tokens Readme::parse_token_list(text_stream *chunk, text_file_position *tfp) {
	macro_tokens mt;
	mt.no_pars = 0;
	mt.down = NULL;
	mt.bound_to = NULL;
	if (Str::get_first_char(chunk) == '(') {
		int x = 1, bl = 1, from = 1, quoted = FALSE;
		while ((bl > 0) && (Str::get_at(chunk, x) != 0)) {
			wchar_t c = Str::get_at(chunk, x);
			if (c == '\'') {
				quoted = quoted?FALSE:TRUE;
			} else if (quoted == FALSE) {
				if (c == '(') bl++;
				else if (c == ')') {
					bl--;
					if (bl == 0) @<Recognise token@>;
				} else if ((c == ',') && (bl == 1)) @<Recognise token@>;
			}
			x++;
		}
		Str::delete_n_characters(chunk, x);
	}
	return mt;
}

@ Quotes can be used in token lists so that literal commas and brackets can
be used without breaking the flow.

@<Recognise token@> =
	int n = mt.no_pars;
	if (n >= 8) Errors::in_text_file("too many parameters", tfp);
	else {
		mt.pars[n] = Str::new();
		for (int j=from; j<x; j++) PUT_TO(mt.pars[n], Str::get_at(chunk, j));
		Str::trim_white_space(mt.pars[n]);
		if ((Str::get_first_char(mt.pars[n]) == '\'') &&
			(Str::get_last_char(mt.pars[n]) == '\'')) {
			Str::delete_first_character(mt.pars[n]);
			Str::delete_last_character(mt.pars[n]);
		}
		mt.no_pars++;
	}
	from = x+1;

@ So much for creating macros. Now we can write the actual expander. As can
be seen, it passes material straight through, except for instances of the
notation |@name|, possibly followed by a bracketed list of parameters.

=
void Readme::expand_material(write_state *ws, text_stream *OUT, text_stream *text,
	text_file_position *tfp) {
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, text, L"(%c*?)@(%i+)(%c*)")) {
		Readme::expand_material(ws, OUT, mr.exp[0], tfp);
		macro_tokens mt = Readme::parse_token_list(mr.exp[2], tfp);
		mt.down = ws->stack_frame;
		ws->stack_frame = &mt;
		Readme::expand_at(ws, OUT, mr.exp[1], tfp);
		ws->stack_frame = mt.down;
		Readme::expand_material(ws, OUT, mr.exp[2], tfp);
	} else {
		WRITE("%S", text);
	}
	Regexp::dispose_of(&mr);
}

@ If we run into the notation |@something|, it's possible that |something| is
the name of a parameter somewhere in the current stack, either on the top
frame or on frames lower down. The first match wins... and if there are no
matches, then it must be a macro name.

=
void Readme::expand_at(write_state *ws, text_stream *OUT, text_stream *macro_name,
	text_file_position *tfp) {
	macro_tokens *stack = ws->stack_frame;
	while (stack) {
		macro *in = stack->bound_to;
		if (in)
			for (int n = 0; n < in->tokens.no_pars; n++)
				if (Str::eq(in->tokens.pars[n], macro_name)) {
					if (n < stack->no_pars) {
						Readme::expand_material(ws, OUT, stack->pars[n], tfp);
						return;
					}
				}
		stack = stack->down;
	}

	macro *M;
	LOOP_OVER_LINKED_LIST(M, macro, ws->known_macros)
		if (Str::eq(M->name, macro_name)) {
			ws->stack_frame->bound_to = M;
			Readme::expand_macro(ws, OUT, M, tfp);
			return;
		}
	Errors::in_text_file("no such @-command", tfp);
	WRITE_TO(STDERR, "(command is '%S')\n", macro_name);
}

@ So, then: suppose we have to expand |@example(5, gold rings)|. Then the
|macro_name| below is set to |example|, and the current stack frame contains the
values |5| and |gold rings|.

=
void Readme::expand_macro(write_state *ws, text_stream *OUT, macro *M, text_file_position *tfp) {
	if (Str::eq(M->name, I"version")) @<Perform built-in expansion of version macro@>
	else if (Str::eq(M->name, I"purpose")) @<Perform built-in expansion of purpose macro@>
	else if (Str::eq(M->name, I"var")) @<Perform built-in expansion of var macro@>
	else {
		ws->stack_frame->bound_to = M;
		Readme::expand_material(ws, OUT, M->content, tfp);
	}
}

@<Perform built-in expansion of version macro@> =
	if (ws->stack_frame->no_pars != 1)
		Errors::in_text_file("@version takes 1 parameter", tfp);
	else {
		TEMPORARY_TEXT(program);
		Readme::expand_material(ws, program, ws->stack_frame->pars[0], tfp);
		Readme::write_var(OUT, program, I"Version Number");
		DISCARD_TEXT(program);
	}

@<Perform built-in expansion of purpose macro@> =
	if (ws->stack_frame->no_pars != 1)
		Errors::in_text_file("@purpose takes 1 parameter", tfp);
	else {
		TEMPORARY_TEXT(program);
		Readme::expand_material(ws, program, ws->stack_frame->pars[0], tfp);
		Readme::write_var(OUT, program, I"Purpose");
		DISCARD_TEXT(program);
	}

@<Perform built-in expansion of var macro@> =
	if (ws->stack_frame->no_pars != 2)
		Errors::in_text_file("@var takes 2 parameters", tfp);
	else {
		TEMPORARY_TEXT(program);
		TEMPORARY_TEXT(bibv);
		Readme::expand_material(ws, program, ws->stack_frame->pars[0], tfp);
		Readme::expand_material(ws, bibv, ws->stack_frame->pars[1], tfp);
		Readme::write_var(OUT, program, bibv);
		DISCARD_TEXT(program);
		DISCARD_TEXT(bibv);
	}

@ An "asset" here is something for which we might want to write the version
number of, or some similar metadata for. Assets are usually webs, but can
also be a few other rather Inform-specific things; those have a more limited
range of bibliographic data, just the version and date (and we will not
assume that the version complies with any format).

=
typedef struct writeme_asset {
	struct text_stream *name;
	struct web *if_web;
	struct text_stream *date;
	struct text_stream *version;
	int next_is_version;
	MEMORY_MANAGEMENT
} writeme_asset;

void Readme::write_var(text_stream *OUT, text_stream *program, text_stream *datum) {
	writeme_asset *A = Readme::find_asset(program);
	if (A->if_web) WRITE("%S", Bibliographic::get_datum(A->if_web->md, datum));
	else if (Str::eq(datum, I"Build Date")) WRITE("%S", A->date);
	else if (Str::eq(datum, I"Version Number")) WRITE("%S", A->version);
}

@ That just leaves the business of inspecting assets to obtain their metadata.

=
writeme_asset *Readme::find_asset(text_stream *program) {
	writeme_asset *A;
	LOOP_OVER(A, writeme_asset) if (Str::eq(program, A->name)) return A;
	A = CREATE(writeme_asset);
	A->name = Str::duplicate(program);
	A->if_web = NULL;
	A->date = Str::new();
	A->version = Str::new();
	A->next_is_version = FALSE;
	@<Read in the asset@>;
	return A;
}

@<Read in the asset@> =
	if (Str::ends_with_wide_string(program, L".i7x")) {
		@<Read in the extension file@>;
	} else {
		filename *F = Filenames::in_folder(Pathnames::from_text(program), I"Contents.w");
		if (TextFiles::exists(F)) {
			A->if_web = Reader::load_web(Pathnames::from_text(program), NULL, NULL, FALSE,
				V2_SYNTAX, NULL, FALSE);
		} else {
			filename *I6_vn = Filenames::in_folder(
				Pathnames::subfolder(Pathnames::from_text(program), I"inform6"), I"header.h");
			if (TextFiles::exists(I6_vn)) @<Read in I6 source header file@>;
			filename *template_vn = Filenames::in_folder(Pathnames::from_text(program), I"(manifest).txt");
			if (TextFiles::exists(template_vn)) @<Read in template manifest file@>;
			filename *rmt_vn = Filenames::in_folder(Pathnames::from_text(program), I"README.txt");
			if (TextFiles::exists(rmt_vn)) @<Read in README file@>;
			rmt_vn = Filenames::in_folder(Pathnames::from_text(program), I"README.md");
			if (TextFiles::exists(rmt_vn)) @<Read in README file@>;
		}
	}

@<Read in the extension file@> =
	TextFiles::read(Filenames::from_text(program), FALSE, "unable to read extension", TRUE,
		&Readme::extension_harvester, NULL, A);

@<Read in I6 source header file@> =
	TextFiles::read(I6_vn, FALSE, "unable to read header file from I6 source", TRUE,
		&Readme::header_harvester, NULL, A);

@<Read in template manifest file@> =
	TextFiles::read(template_vn, FALSE, "unable to read manifest file from website template", TRUE,
		&Readme::template_harvester, NULL, A);

@<Read in README file@> =
	TextFiles::read(rmt_vn, FALSE, "unable to read README file from website template", TRUE,
		&Readme::readme_harvester, NULL, A);

@ The format for the contents section of a web is documented in Inweb.

=
void Readme::extension_harvester(text_stream *text, text_file_position *tfp, void *state) {
	writeme_asset *A = (writeme_asset *) state;
	match_results mr = Regexp::create_mr();
	if (Str::len(text) == 0) return;
	if (Regexp::match(&mr, text, L" *Version (%c*?) of %c*begins here. *"))
		A->version = Str::duplicate(mr.exp[0]);
	Regexp::dispose_of(&mr);
}

@ Explicit code to read from |header.h| in the Inform 6 repository.

=
void Readme::header_harvester(text_stream *text, text_file_position *tfp, void *state) {
	writeme_asset *A = (writeme_asset *) state;
	match_results mr = Regexp::create_mr();
	if (Str::len(text) == 0) return;
	if (Regexp::match(&mr, text, L"#define RELEASE_NUMBER (%c*?) *"))
		A->version = Str::duplicate(mr.exp[0]);
	if (Regexp::match(&mr, text, L"#define RELEASE_DATE \"(%c*?)\" *"))
		A->date = Str::duplicate(mr.exp[0]);
	Regexp::dispose_of(&mr);
}

@ Explicit code to read from the manifest file of a website template.

=
void Readme::template_harvester(text_stream *text, text_file_position *tfp, void *state) {
	writeme_asset *A = (writeme_asset *) state;
	match_results mr = Regexp::create_mr();
	if (Str::len(text) == 0) return;
	if (Regexp::match(&mr, text, L"%[INTERPRETERVERSION%]")) {
		A->next_is_version = TRUE;
	} else if (A->next_is_version) {
		A->version = Str::duplicate(text);
		A->next_is_version = FALSE;
	}
	Regexp::dispose_of(&mr);
}

@ And this is needed for |cheapglk| and |glulxe| in the Inform repository.

=
void Readme::readme_harvester(text_stream *text, text_file_position *tfp, void *state) {
	writeme_asset *A = (writeme_asset *) state;
	match_results mr = Regexp::create_mr();
	if (Str::len(text) == 0) return;
	if ((Regexp::match(&mr, text, L"CheapGlk Library: version (%c*?) *")) ||
		(Regexp::match(&mr, text, L"- Version (%c*?) *")))
		A->version = Str::duplicate(mr.exp[0]);
	Regexp::dispose_of(&mr);
}
