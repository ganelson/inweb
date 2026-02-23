[WCL::] Web Control Language.

To parse configuration files for different aspects of literate programming.

@h Declaration types.
Inweb's customisability has caused it to accumulate many different forms of
configuration file, each initially with its own syntax and conventions.
One of the changes made by Inweb 9 was to unify these, or at any rate some of
them, into a single set of conventions which we will internally call
"Web Control Language", or WCL.

A valid chunk of WCL consists of declarations, which can be nested. The following
constants enumerate the possible declaration types: |MISCELLANY_WCLTYPE| is a
special type meaning "this is a list of declarations of possibly different types".

@e MISCELLANY_WCLTYPE from 0
@e COLONY_WCLTYPE
@e WEB_WCLTYPE
@e LANGUAGE_WCLTYPE
@e NOTATION_WCLTYPE
@e NAVIGATION_WCLTYPE
@e PATTERN_WCLTYPE
@e CONVENTIONS_WCLTYPE

@e NO_WCLMODIFIER from 0
@e PAGE_WCLMODIFIER

=
void WCL::write_type(OUTPUT_STREAM, int t) {
	switch (t) {
		case MISCELLANY_WCLTYPE:  WRITE("Miscellany"); break;
		case COLONY_WCLTYPE:      WRITE("Colony"); break;
		case WEB_WCLTYPE:         WRITE("Web"); break;
		case LANGUAGE_WCLTYPE:    WRITE("Language"); break;
		case NOTATION_WCLTYPE:    WRITE("Notation"); break;
		case NAVIGATION_WCLTYPE:  WRITE("Navigation"); break;
		case PATTERN_WCLTYPE:     WRITE("Pattern"); break;
		case CONVENTIONS_WCLTYPE: WRITE("Conventions"); break;
		default:                  WRITE("<unknown-declaration-type>"); break;
	}
}

@ It is not true that anything can contain anything else: in fact, the rules
for nesting declarations are quite restrictive.

=
int WCL::can_contain(int outer_type, int type) {
	switch (outer_type) {
		case MISCELLANY_WCLTYPE:
			if (type != MISCELLANY_WCLTYPE) return TRUE;
			break;
		case COLONY_WCLTYPE:
			if ((type != MISCELLANY_WCLTYPE) && (type != COLONY_WCLTYPE)) return TRUE;
			break;
		case WEB_WCLTYPE:
			if ((type == LANGUAGE_WCLTYPE) || (type == NOTATION_WCLTYPE) || (type == CONVENTIONS_WCLTYPE)) return TRUE;
			break;
		case LANGUAGE_WCLTYPE:
		case NOTATION_WCLTYPE:
			if (type == CONVENTIONS_WCLTYPE) return TRUE;
			break;
	}
	return FALSE;
}

@h Declarations.
Because declarations can nest, they are collectively a forest. Each declaration
contains a list of its nested children, and a link to its parent (called its |scope|).
If a declaration is not nested in any other, its parental link is |NULL|.

=
typedef struct wcl_declaration {
	int declaration_type;
	int modifier;
	int inbuilt;
	struct text_stream *name;
	struct text_file_position declaration_position;
	struct text_file_position body_position;
	int closure_column;
	struct linked_list *declaration_lines; /* of text_stream */
	struct linked_list *surplus_lines; /* of text_stream */
	struct linked_list *declarations; /* of wcl_declaration */
	struct linked_list *errors; /* of wcl_error */
	struct wcl_declaration *scope;
	struct pathname *associated_path;
	struct filename *associated_file;
	struct general_pointer object_declared;
	int external_resources_loaded;
	CLASS_DEFINITION
} wcl_declaration;

wcl_declaration *WCL::new(int type) {
	wcl_declaration *D = CREATE(wcl_declaration);
	D->declaration_type = type;
	D->modifier = NO_WCLMODIFIER;
	D->inbuilt = FALSE;
	D->name = Str::new();
	D->closure_column = 0;
	D->declaration_position = TextFiles::nowhere();
	D->body_position = TextFiles::nowhere();
	D->declaration_lines = NEW_LINKED_LIST(text_stream);
	D->surplus_lines = NEW_LINKED_LIST(text_stream);
	D->declarations = NEW_LINKED_LIST(wcl_declaration);
	D->errors = NEW_LINKED_LIST(wcl_error);
	D->scope = NULL; /* meaning, global scope */
	D->object_declared = NULL_GENERAL_POINTER;
	D->associated_path = NULL;
	D->associated_file = NULL;
	D->external_resources_loaded = FALSE;
	return D;
}

void WCL::flag_as_inbuilt(wcl_declaration *C) {
	C->inbuilt = TRUE;
	wcl_declaration *X;
	LOOP_OVER_LINKED_LIST(X, wcl_declaration, C->declarations)
		WCL::flag_as_inbuilt(X);
}

@h Nesting.
This makes |C| a declaration nested within |P|:

=
void WCL::place_within(wcl_declaration *C, wcl_declaration *P) {
	ADD_TO_LINKED_LIST(C, wcl_declaration, P->declarations);
	C->scope = P;
}

@ To merge a miscellany into |M| is to merge each of its ingredients in turn.
The following looks potentially recursive in an exciting way, but in fact
miscellanies shouldn't ever be nested, so it shouldn't go more than one
call deep.

=
void WCL::merge_within(wcl_declaration *D, wcl_declaration *M) {
	if (D == NULL) return;
	if (D->declaration_type == MISCELLANY_WCLTYPE) {
		wcl_declaration *X;
		LOOP_OVER_LINKED_LIST(X, wcl_declaration, D->declarations)
			WCL::merge_within(X, M);
	} else {
		if (WCL::can_contain(M->declaration_type, D->declaration_type))
			WCL::place_within(D, M);
		else PRINT("Nope! %d, %d\n", M->declaration_type, D->declaration_type);
	}	
}

@h Errors.
Errors in parsing WCL files are accumulated under the relevant declarations:

=
typedef struct wcl_error {
	struct text_file_position tfp;
	struct text_stream *message;
	CLASS_DEFINITION
} wcl_error;

wcl_error *WCL::error(wcl_declaration *D, text_file_position *tfp, text_stream *msg) {
	wcl_error *E = CREATE(wcl_error);
	E->tfp = *tfp;
	E->message = Str::duplicate(msg);
	ADD_TO_LINKED_LIST(E, wcl_error, D->errors);
	return E;
}

@ They will only be reported to the console on request:

=
void WCL::report_errors(wcl_declaration *D) {
	wcl_error *E;
	LOOP_OVER_LINKED_LIST(E, wcl_error, D->errors) {
		Errors::in_text_file_S(E->message, &(E->tfp));
		#ifdef THIS_IS_INWEB
		no_inweb_errors++;
		#endif
	}
	wcl_declaration *X;
	LOOP_OVER_LINKED_LIST(X, wcl_declaration, D->declarations)
		WCL::report_errors(X);
}

@ Doctrinally, a declaration is only correct if both it and all of its child
declarations are without flaw, so this is a recursive count:

=
int WCL::count_errors(wcl_declaration *D) {
	int no_errors = 0;
	if (D) {
		no_errors += LinkedLists::len(D->errors);
		wcl_declaration *X;
		LOOP_OVER_LINKED_LIST(X, wcl_declaration, D->declarations)
			no_errors += WCL::count_errors(X);
	}
	return no_errors;
}

int WCL::is_correct(wcl_declaration *D) {
	if (WCL::count_errors(D) == 0) return TRUE;
	return FALSE;
}

int WCL::is_incorrect(wcl_declaration *D) {
	if (WCL::count_errors(D) > 0) return TRUE;
	return FALSE;
}

@h Naming.
Each declaration has a name. Sometimes this is made explicit in its declaration,
but it can also sometimes be given within the body of the declaration in some
way, which means that it's possible for the name to come from two different
sources, and therefore even possible to hit a contradiction.

Calling this function resolves the issue. The return value is |TRUE| if
all has been made well, and |FALSE| if the two possibilities conflicted.

=
int WCL::check_name(wcl_declaration *D, text_stream *supposed_name) {
	if (Str::len(D->name) == 0) {
		WRITE_TO(D->name, "%S", supposed_name);
		return TRUE;
	}
	if (Str::eq_insensitive(D->name, supposed_name)) return TRUE;
	return FALSE;
}

@h Reading for type only.
Reading a chunk of WCL from a file begins with breaking it down into a hierarchy
of declarations, each containing a list of source lines which we will make no
attempt to understand. This is called "reading for type only", because the main
thing it tells us is what kind of thing is being declared.

=
wcl_declaration *WCL::read_for_type_only(filename *F, int presumed) {
	wcl_declaration *D = WCL::read_for_type_only_forgivingly(F, presumed);
	int N = WCL::count_errors(D);
	if (N == 1) WRITE_TO(STDERR, "An error was found in the WCL file %f:\n", F);
	if (N > 1) WRITE_TO(STDERR, "Errors were found in the WCL file %f:\n", F);
	WCL::report_errors(D);
	if (N > 0) D = NULL;
	return D;
}

@ Everything here is made exasperatingly tricky by the fact that the outermost
level of the file can consist of formal declarations, like so:
= (text)
	Language "C" {
		...
	}
=
but can also just be lines outside of braces, in which case clearly it's a
declaration of some sort, but we don't know what type. That's where the
"presumption" comes in -- basically context meaning "if you don't know what
this is, assume it's a language". A presumption of |MISCELLANY_WCLTYPE| means
no presumption at all.

=
typedef struct wcl_scanner {
	struct wcl_declaration *D;
	int margin;
} wcl_scanner;

wcl_declaration *WCL::read_for_type_only_forgivingly(filename *F, int presumed) {
	wcl_declaration *D = WCL::new(MISCELLANY_WCLTYPE);
	D->closure_column = -1;
	D->declaration_position = TextFiles::at(F, 1);
	D->body_position = TextFiles::at(F, 1);
	wcl_scanner scanner;
	scanner.D = D;
	scanner.margin = -1;
	TextFiles::read(F, FALSE, "can't open web control language file",
		TRUE, WCL::read_line, NULL, (void *) (&scanner));
	@<Throw errors for unclosed declarations@>;
	@<Impose the assumed type on the outermost declaration@>;
	@<If we have a miscellany which wraps a singleton, throw away the wrapper@>;
	@<If we have a miscellany with source lines at the outer level, throw errors@>;
	D->scope = NULL;
	D->associated_file = F;
	return D;
}

@<Throw errors for unclosed declarations@> =
	for (wcl_declaration *X = scanner.D; X; X = X->scope)
		if (X != D)
			WCL::error(X->scope, &(X->declaration_position),
				I"declaration still open at end of file");

@ We will only follow the presumed type if it's possible to reconcile that
with the apparent contents. Note that no type can contain other
declarations of the same type as itself.

@<Impose the assumed type on the outermost declaration@> =
	if (presumed != MISCELLANY_WCLTYPE) {
		int forbid_assumption = FALSE;
		wcl_declaration *X;
		LOOP_OVER_LINKED_LIST(X, wcl_declaration, D->declarations)
			if (WCL::can_contain(presumed, X->declaration_type) == FALSE)
				forbid_assumption = TRUE;
		if (forbid_assumption == FALSE) {
			D->declaration_type = presumed;
			if ((presumed == WEB_WCLTYPE) && (WCL::contents_page_file(F) == FALSE))
				D->modifier = PAGE_WCLMODIFIER;
		}
	}

@<If we have a miscellany which wraps a singleton, throw away the wrapper@> =
	if ((LinkedLists::len(D->declarations) == 1) &&
		(LinkedLists::len(D->errors) == 0) &&
		(LinkedLists::len(D->declaration_lines) == 0) &&
		(LinkedLists::len(D->surplus_lines) == 0)) {
		wcl_declaration *X, *first_X = NULL;
		LOOP_OVER_LINKED_LIST(X, wcl_declaration, D->declarations)
			if (first_X == NULL) first_X = X;
		D = first_X; D->scope = NULL;
	}

@<If we have a miscellany with source lines at the outer level, throw errors@> =
	if (D->declaration_type == MISCELLANY_WCLTYPE) {
		if ((LinkedLists::len(D->declaration_lines) > 0) ||
			(LinkedLists::len(D->surplus_lines) > 0)) {
			TEMPORARY_TEXT(msg)
			WRITE_TO(msg, "file contains %d line(s) outside of braced definitions",
				LinkedLists::len(D->declaration_lines) + LinkedLists::len(D->surplus_lines));
			WCL::error(D, &(D->declaration_position), msg);
			DISCARD_TEXT(msg)
			D->declaration_lines = NEW_LINKED_LIST(text_stream);
			D->surplus_lines = NEW_LINKED_LIST(text_stream);
		}
	}

@ Okay, so the reader-for-type feeds lines from the source file into the following
function, one by one:

=
void WCL::read_line(text_stream *line, text_file_position *tfp, void *v_state) {
	wcl_scanner *scanner = (wcl_scanner *) v_state;
	int skip_line = FALSE;

	TEMPORARY_TEXT(tail)
	int spaces = 0;
	@<Divide line up as initial white space and a tail@>;

	TEMPORARY_TEXT(trimmed)
	if (Str::begins_with(line, I"//")) skip_line = TRUE;
	else if (Str::len(tail) > 0) @<Trim the line according to the correct indentation@>;

	if (spaces == scanner->margin) {
		int new_declaration_type = -1, new_declaration_modifier = NO_WCLMODIFIER;
		TEMPORARY_TEXT(name)
		@<See if this line opens a new declaration@>;
		if (new_declaration_type != -1) {
			int outer_type = scanner->D->declaration_type;
			if (WCL::can_contain(outer_type, new_declaration_type) == FALSE)
				@<Throw a hierarchy error@>;
			wcl_declaration *ND;
			@<Create the new declaration object for this block@>;
			WCL::place_within(ND, scanner->D);
			scanner->D = ND;
			scanner->margin = -1; /* meaning, we don't know its body indentation yet */
			skip_line = TRUE;
		}
	}

	if (skip_line == FALSE) @<Add this line to the declaration body@>;
	DISCARD_TEXT(tail)
	DISCARD_TEXT(trimmed)
}

@ WCL follows Pythonesque indentation conventions. A tab is worth 4 spaces,
but if tabs are mixed in with spaces, then they advance us only to the next
tab stop position.

The remainder of the line after the initial white space is written to |tail|.

@<Divide line up as initial white space and a tail@> =
	int past_head = FALSE;
	LOOP_THROUGH_TEXT(pos, line) {
		inchar32_t c = Str::get(pos);
		if (past_head == FALSE) {
			if (c == ' ') { spaces++; continue; }
			if (c == '\t') { spaces = 4*(spaces/4) + 4; continue; }
		}
		past_head = TRUE;
		PUT_TO(tail, c);
	}

@ The tricky point here is that if we read a line with 14 initial spaces,
say, then only some of those spaces should be trimmed away. Suppose we're
reading this:
= (text)
	Gadget "box" {
		  whatever
		       this is {
		    }
	}
=
When we get to the "whatever" line, it's indented by 6 spaces. That establishes
that the whole declaration of "box" will be indented 6; and so the next line
will be trimmed so that it consists of five spaces and then the words "this is".
(This is why the string |trimmed| is not the same as the string |tail|, which
contains just the words "this is.)

We ignore the first "}" because it's in the wrong column, and close the 
declaration only at the second "}", which is in the right one.

@<Trim the line according to the correct indentation@> =
	int required_margin = scanner->D->closure_column;
	if (scanner->margin >= 0) required_margin = scanner->margin;
	if (scanner->margin == -1) scanner->margin = spaces;
	if (spaces == scanner->D->closure_column) {
		match_results mr = Regexp::create_mr();
		if (Regexp::match(&mr, tail, U"} *")) {
			scanner->D = scanner->D->scope;
			skip_line = TRUE;
			scanner->margin = spaces;
			required_margin = spaces;
		}
		Regexp::dispose_of(&mr);
	}
	if (spaces < required_margin) @<Throw an error for insufficient indentation@>;
	while (spaces > scanner->margin) {
		spaces--; PUT_TO(trimmed, ' ');
	}
	WRITE_TO(trimmed, "%S", tail);

@ Once a declaration has been established as having content indented by, say,
6 spaces, it will be an error for a subsequent line to be indented less than that.
(In practice, this may well mean that a close-brace is missing.)

@<Throw an error for insufficient indentation@> =
	TEMPORARY_TEXT(msg)
	WRITE_TO(msg, "line is indented %d char(s), but should be at least %d ",
		spaces, required_margin);
	WRITE_TO(msg, "to remain inside declaration which began at line %d and is still open",
		scanner->D->declaration_position.line_count);
	WCL::error(scanner->D, tfp, msg);
	DISCARD_TEXT(msg)

@<Throw a hierarchy error@> =
	TEMPORARY_TEXT(message)
	WRITE_TO(message, "a ");
	WCL::write_type(message, new_declaration_type);
	WRITE_TO(message, " cannot be put inside a ");
	WCL::write_type(message, outer_type);
	WCL::error(scanner->D, tfp, message);
	DISCARD_TEXT(message)

@<See if this line opens a new declaration@> =
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, trimmed, U"Colony { *"))
		new_declaration_type = COLONY_WCLTYPE;
	if (Regexp::match(&mr, trimmed, U"Colony \"(%c+)\" { *")) {
		new_declaration_type = COLONY_WCLTYPE; Str::copy(name, mr.exp[0]); }
	if (Regexp::match(&mr, trimmed, U"Web { *"))
		new_declaration_type = WEB_WCLTYPE;
	if (Regexp::match(&mr, trimmed, U"Web \"(%c+)\" { *")) {
		new_declaration_type = WEB_WCLTYPE; Str::copy(name, mr.exp[0]); }
	if (Regexp::match(&mr, trimmed, U"Language { *"))
		new_declaration_type = LANGUAGE_WCLTYPE;
	if (Regexp::match(&mr, trimmed, U"Language \"(%c+)\" { *")) {
		new_declaration_type = LANGUAGE_WCLTYPE; Str::copy(name, mr.exp[0]); }
	if (Regexp::match(&mr, trimmed, U"Notation { *"))
		new_declaration_type = NOTATION_WCLTYPE;
	if (Regexp::match(&mr, trimmed, U"Notation \"(%c+)\" { *")) {
		new_declaration_type = NOTATION_WCLTYPE; Str::copy(name, mr.exp[0]); }
	if (Regexp::match(&mr, trimmed, U"Navigation { *"))
		new_declaration_type = NAVIGATION_WCLTYPE;
	if (Regexp::match(&mr, trimmed, U"Navigation \"(%c+)\" { *")) {
		new_declaration_type = NAVIGATION_WCLTYPE; Str::copy(name, mr.exp[0]); }
	if (Regexp::match(&mr, trimmed, U"Pattern { *"))
		new_declaration_type = PATTERN_WCLTYPE;
	if (Regexp::match(&mr, trimmed, U"Pattern \"(%c+)\" { *")) {
		new_declaration_type = PATTERN_WCLTYPE; Str::copy(name, mr.exp[0]); }
	if (Regexp::match(&mr, trimmed, U"Conventions { *"))
		new_declaration_type = CONVENTIONS_WCLTYPE;
	if (Regexp::match(&mr, trimmed, U"Conventions \"(%c+)\" { *")) {
		new_declaration_type = CONVENTIONS_WCLTYPE; Str::copy(name, mr.exp[0]); }
	if (Regexp::match(&mr, trimmed, U"Page { *")) {
		new_declaration_type = WEB_WCLTYPE;
		new_declaration_modifier = PAGE_WCLMODIFIER;
	}
	if (Regexp::match(&mr, trimmed, U"Page \"(%c+)\" { *")) {
		new_declaration_type = WEB_WCLTYPE; Str::copy(name, mr.exp[0]);
		new_declaration_modifier = PAGE_WCLMODIFIER;
	}
	Regexp::dispose_of(&mr);

@<Create the new declaration object for this block@> =
	ND = WCL::new(new_declaration_type);
	ND->modifier = new_declaration_modifier;
	if (Str::len(name) > 0) ND->name = Str::duplicate(name);
	ND->closure_column = scanner->margin;
	ND->declaration_position = *tfp;
	ND->body_position = *tfp; ND->body_position.line_count++;
	if (ND->body_position.line_count < 1) ND->body_position.line_count = 1;

@<Add this line to the declaration body@> =
	linked_list *list = scanner->D->declaration_lines;
	if (LinkedLists::len(scanner->D->declarations) > 0) list = scanner->D->surplus_lines;
	if ((Str::is_whitespace(trimmed) == FALSE) || (LinkedLists::len(list) > 0))
		ADD_TO_LINKED_LIST(Str::duplicate(trimmed), text_stream, list);

@h Parsing and resolving declarations.
The first stage of parsing a chunk of WCL is now complete: we know what type
all the declarations are, we've formed them into a hierarchy, and that appears
to make reasonable sense. But the actual content of each declaration is just
a list of unparsed lines. How we should understand them depends on what is
being declared, inevitably, so we call in specialists.

With parsing done, the second stage is "resolution". This resolves references
from one resource to another, as for example when a web says that it is
written in a language called "C": the definition of that language is another
resource, and must be found.

=
void WCL::parse_declarations_throwing_errors(wcl_declaration *D) {
	WCL::parse_declarations(D);
	if (WCL::is_incorrect(D)) WCL::report_errors(D);
}

void WCL::parse_declarations(wcl_declaration *D) {
	WCL::parse_declarations_r(D, 1);
	WCL::parse_declarations_r(D, 2);
	WCL::resolve_r(D);
}

void WCL::parse_declarations_r(wcl_declaration *D, int pass) {
	if ((D) && (WCL::is_correct(D))) {
		wcl_declaration *X;
		LOOP_OVER_LINKED_LIST(X, wcl_declaration, D->declarations)
			WCL::parse_declarations_r(X, pass);
		switch (D->declaration_type) {
			case COLONY_WCLTYPE:     if (pass == 1) Colonies::parse_declaration(D); break;
			case LANGUAGE_WCLTYPE:   if (pass == 1) Languages::parse_declaration(D); break;
			case NAVIGATION_WCLTYPE: if (pass == 1) Colonies::parse_nav_declaration(D); break;
			case NOTATION_WCLTYPE:   if (pass == 1) WebNotation::parse_declaration(D); break;
			case PATTERN_WCLTYPE:    if (pass == 1) Patterns::parse_declaration(D); break;
			case WEB_WCLTYPE:        if (pass == 2) WebStructure::parse_declaration(D); break;
			case CONVENTIONS_WCLTYPE: if (pass == 2) Conventions::parse_declaration(D); break;
		}
	}
}

void WCL::resolve_r(wcl_declaration *D) {
	if ((D) && (WCL::is_correct(D))) {
		wcl_declaration *X;
		LOOP_OVER_LINKED_LIST(X, wcl_declaration, D->declarations)
			WCL::resolve_r(X);
		switch (D->declaration_type) {
			case COLONY_WCLTYPE:     Colonies::resolve_declaration(D); break;
			case LANGUAGE_WCLTYPE:   Languages::resolve_declaration(D); break;
			case NAVIGATION_WCLTYPE: Colonies::resolve_nav_declaration(D); break;
			case NOTATION_WCLTYPE:   WebNotation::resolve_declaration(D); break;
			case PATTERN_WCLTYPE:    Patterns::resolve_declaration(D); break;
			case WEB_WCLTYPE:        WebStructure::resolve_declaration(D); break;
			case CONVENTIONS_WCLTYPE: Conventions::resolve_declaration(D); break;
		}
	}
}

@h More on resolution.
So how are those specialist functions going to be able to find out what certain
names correspond to? By using the following API.

What resources can be seen by any given declaration will vary, but there will
pretty generally be a set of resources universally available. These are called
"global", and are accumulated as a miscellany in the following:

=
wcl_declaration *WCL::global_resources_declaration(void) {
	static wcl_declaration *global_WCL_resources = NULL;
	if (global_WCL_resources == NULL)
		global_WCL_resources = WCL::new(MISCELLANY_WCLTYPE);
	return global_WCL_resources;
}

void WCL::make_global(wcl_declaration *resources) {
	WCL::merge_within(resources, WCL::global_resources_declaration());
}

@ In general, these resources arrive by being loaded from a directory declared
by our owning app as the "path to LP (i.e., literate programming) resources":

=
wcl_declaration *WCL::global_resources(void) {
	static pathname *last_known_resources = NULL;
	pathname *resources = Pathnames::path_to_LP_resources();
	if ((resources) && (resources != last_known_resources)) {
		last_known_resources = resources;
		WCL::merge_resources_from_path(resources, WCL::global_resources_declaration(), TRUE);
	}
	return WCL::global_resources_declaration();
}

@ But we can also place everything in a nominated folder into the global domain:

=
void WCL::make_resources_at_path_global(pathname *P) {
	if (WCL::make_potential_pattern_global(P)) return;
	scan_directory *D = Directories::open(P);
	TEMPORARY_TEXT(leafname)
	while (Directories::next(D, leafname)) {
		if (Platform::is_folder_separator(Str::get_last_char(leafname)) == FALSE) {
			filename *F = Filenames::in(P, leafname);
			WCL::make_resources_at_file_global(F);
		} else {
			TEMPORARY_TEXT(subdir)
			Str::copy(subdir, leafname);
			Str::delete_last_character(subdir);
			pathname *Q = Pathnames::down(P, subdir);
			WCL::make_potential_pattern_global(Q);
		}
	}
	DISCARD_TEXT(leafname)
	Directories::close(D);
}

int WCL::make_potential_pattern_global(pathname *P) {
	text_stream *dirname = Pathnames::directory_name(P);
	if (Str::eq_insensitive(dirname, I"Patterns")) {
		int n = 0;
		scan_directory *D = Directories::open(P);
		TEMPORARY_TEXT(leafname)
		while (Directories::next(D, leafname)) {
			if (Platform::is_folder_separator(Str::get_last_char(leafname))) {
				TEMPORARY_TEXT(subdir)
				Str::copy(subdir, leafname);
				Str::delete_last_character(subdir);
				pathname *Q = Pathnames::down(P, subdir);
				if (WCL::make_potential_pattern_global(Q)) n++;
			}
		}
		DISCARD_TEXT(leafname)
		Directories::close(D);
		if (n > 0) return TRUE;
	}
	TEMPORARY_TEXT(name)
	WRITE_TO(name, "%S.inweb", dirname);
	filename *F = Filenames::in(P, name);
	DISCARD_TEXT(name)
	if (TextFiles::exists(F)) {
		wcl_declaration *M = WCL::make_resources_at_file_global(F);
		if (M->declaration_type == PATTERN_WCLTYPE) return TRUE;
	}
	return FALSE;
}

@ Or just a single file:

=
wcl_declaration *WCL::make_resources_at_file_global(filename *F) {
	wcl_declaration *D = WCL::read_anything(F);
	if (D) WCL::make_global(D);
	return D;
}

@ In general the |scope| pointer for a declaration points to the outer
declaration which contained it, but there's an exception: if a web is found
outside of a colony file (as is usually the case) but is in fact a member of
that colony (as is often the case) then the colony is the scope of the web.

=
wcl_declaration *WCL::search_scope(wcl_declaration *D) {
	if ((D->scope == NULL) && (D->declaration_type == WEB_WCLTYPE)) {
		ls_colony_member *CM = Colonies::find_ls_colony_member(RETRIEVE_POINTER_ls_web(D->object_declared));
		if (CM) D->scope = CM->owner->declaration;
	}
	return D->scope;
}

@ Okay, so it's time for the search algorithm. The following function finds a
resource of the given type and name (case insensitively), starting from |D|
and exploring outwards through everything which is in scope to |D|; we
return either |NULL| or the first result found.

If the type given is |-1|, all resource types are allowed; if the name given
is the empty text, all names are allowed.

=
wcl_declaration *WCL::resolve_resource(wcl_declaration *D, int type, text_stream *name) {
	wcl_declaration *result = NULL;
	WCL::resolve_resource_inner(D, type, name, &result, NULL);
	return result;
}

@ This variant performs the same search but returns a list, possibly empty,
of all results found.

=
linked_list *WCL::list_resources(wcl_declaration *D, int type, text_stream *name) {
	linked_list *results = NEW_LINKED_LIST(wcl_declaration);
	WCL::resolve_resource_inner(D, type, name, NULL, results);
	return results;
}

@ At each level we try to find a result without loading external files in, if
that's possible.

=
void WCL::resolve_resource_inner(wcl_declaration *D, int type, text_stream *name,
	wcl_declaration **result, linked_list *results) {
	wcl_declaration *S;
	for (S = D; S; S = WCL::search_scope(S)) {
		@<Search subdeclarations of S@>;
		if ((S) && (S->declaration_type == WEB_WCLTYPE) && (S->associated_path) &&
			(S->external_resources_loaded == FALSE)) {
			WCL::merge_resources_from_path(S->associated_path, S, FALSE);
			S->external_resources_loaded = TRUE;
			@<Search subdeclarations of S@>;
		}
	}	
	S = WCL::global_resources(); @<Search subdeclarations of S@>;
}

@<Search subdeclarations of S@> =
	wcl_declaration *X;
	LOOP_OVER_LINKED_LIST(X, wcl_declaration, S->declarations) {
		if ((Str::len(name) == 0) || (Str::eq_insensitive(name, X->name)))
			if ((type == -1) || (X->declaration_type == type)) {
				if (result) { *result = X; return; }
				if (results) { ADD_TO_LINKED_LIST(X, wcl_declaration, results); }
			}
	}

@ Applying the list version of the above algorithm, we can print out a roster,
with duplicates deleted:

=
void WCL::write_sorted_list_of_resources(OUTPUT_STREAM, ls_web *W, int type) {
	WCL::write_sorted_list_of_declaration_resources(OUT, W?(W->declaration):NULL, type);
}

void WCL::write_sorted_list_of_declaration_resources(OUTPUT_STREAM, wcl_declaration *OD, int type) {
	linked_list *L = WCL::list_resources(OD, type, NULL);
	int N = LinkedLists::len(L);
	wcl_declaration **sorted_table =
		Memory::calloc(N, (int) sizeof(wcl_declaration *), ARRAY_SORTING_MREASON);

	int i=0;
	wcl_declaration *D;
	LOOP_OVER_LINKED_LIST(D, wcl_declaration, L) sorted_table[i++] = D;

	qsort(sorted_table, (size_t) N, sizeof(wcl_declaration *), WCL::compare_names);

	textual_table *T = TextualTables::new_table();
	WRITE_TO(TextualTables::next_cell(T), "name");
	WRITE_TO(TextualTables::next_cell(T), "resource type");
	WRITE_TO(TextualTables::next_cell(T), "source");

	wcl_declaration *PD = NULL;
	for (int i=0; i<N; i++) {
		wcl_declaration *D = sorted_table[i];
		if (D != PD) {
			TextualTables::begin_row(T);
			if (Str::len(D->name) == 0) WRITE_TO(TextualTables::next_cell(T), "(nameless)");
			else WRITE_TO(TextualTables::next_cell(T), "%S", D->name);
			WCL::write_type(TextualTables::next_cell(T), D->declaration_type);
			if (D->inbuilt) {
				WRITE_TO(TextualTables::next_cell(T), "(built in)");
			} else if ((D->declaration_type == PATTERN_WCLTYPE) && (D->associated_file)) {
				WRITE_TO(TextualTables::next_cell(T), "%p", Pathnames::up(Filenames::up(D->associated_file)));
			} else if (D->associated_file) {
				WRITE_TO(TextualTables::next_cell(T), "%f", D->associated_file);
			} else {
				WRITE_TO(TextualTables::next_cell(T), "%f, line %d",
					D->declaration_position.text_file_filename,
					D->declaration_position.line_count);
			}
		}
		PD = D;
	}
	TextualTables::tabulate(OUT, T);
	Memory::I7_free(sorted_table, ARRAY_SORTING_MREASON, N*((int) sizeof(wcl_declaration *)));
}

@ =
int WCL::compare_names(const void *ent1, const void *ent2) {
	const wcl_declaration *D1 = *((const wcl_declaration **) ent1);
	const wcl_declaration *D2 = *((const wcl_declaration **) ent2);
	int delta = D1->declaration_type - D2->declaration_type;
	if (delta != 0) return delta;
	text_stream *tx1 = D1->name;
	text_stream *tx2 = D2->name;
	return Str::cmp_insensitive(tx1, tx2);
}

@h Merging declarations into a miscellany.
The exact rules here are still in a state of flux and represent something of
a tangled history of unsatisfactory solutions. But the idea is to load
in every WCL we can find, and merge it into |M|. The resource path |RP|
might be a web (in directory format), or might be a cache inside a tool
like Inform or Inweb.

=
void WCL::merge_resources_from_path(pathname *RP, wcl_declaration *M, int flag) {
	int presumption = MISCELLANY_WCLTYPE;
	filename *F = Filenames::in(RP, I"resources.inweb");
	if (TextFiles::exists(F)) @<Merge from F@>;
	pathname *P = Pathnames::down(RP, I"Inweb");
	@<Merge from P@>;
	presumption = LANGUAGE_WCLTYPE;
	P = Pathnames::down(RP, I"Dialects");
	@<Merge from P@>;
	P = Pathnames::down(RP, I"Languages");
	@<Merge from P@>;
	presumption = NOTATION_WCLTYPE;
	P = Pathnames::down(RP, I"Syntaxes");
	@<Merge from P@>;
	presumption = PATTERN_WCLTYPE;
	P = Pathnames::down(RP, I"Patterns");
	@<Merge from patterns P@>;
}

@<Merge from P@> =
	scan_directory *D = Directories::open(P);
	if (D) {
		TEMPORARY_TEXT(leafname)
		while (Directories::next(D, leafname)) {
			if (Platform::is_folder_separator(Str::get_last_char(leafname)) == FALSE) {
				filename *F = Filenames::in(P, leafname);
				@<Merge from F@>;
			}
		}
		DISCARD_TEXT(leafname)
		Directories::close(D);
	}

@<Merge from patterns P@> =
	wcl_declaration *PM = Patterns::parse_directory(P);
	if (PM) {
		if (flag) WCL::flag_as_inbuilt(PM);
		WCL::merge_within(PM, M);
	}

@<Merge from F@> =
	wcl_declaration *D = WCL::read_presumption(F, presumption);
	if (D) {
		if (flag) WCL::flag_as_inbuilt(D);
		WCL::merge_within(D, M);
	}

@h End-to-end readers.
As we've seen, parsing WCL from a file is a two-phase process, involving
first "reading for type only", then parsing in more detail, and it turns out
that we need a variety of minor variations on this theme. Here they are.

@ This reads |F|, assuming it will have type |presumed|, but then requiring
it to do so in the event: so, for example, if |WCL::read_inner| is called
presuming a |LANGUAGE_WCLTYPE| and finds a valid |NOTATION_WCLTYPE| instead,
or a miscellany, it will fail and throw errors. The function returns |NULL|
if errors of any kind arise, so a non-|NULL| reply means |F| is not only
what we expect but is syntactically correct too.

The pathname |P|, if not |NULL|, tells us to read in any side-resources from
that directory. (For example, this would read in dialect definitions in a
directory-format web.)

=
wcl_declaration *WCL::read_inner(pathname *P, filename *F, int presumed, int checking) {
	wcl_declaration *D = WCL::read_for_type_only(F, presumed);
	if (D == NULL) return NULL;
	D->associated_path = P;
	if (WCL::is_incorrect(D)) return NULL;
	if ((checking) && (D->declaration_type != presumed)) {
		text_file_position tfp = TextFiles::at(F, 1);
		TEMPORARY_TEXT(message)
		WRITE_TO(message, "file does not consist of a single ");
		WCL::write_type(message, presumed);
		WRITE_TO(message, " declaration");
		WCL::error(D, &tfp, message);
	}
	WCL::parse_declarations_throwing_errors(D);
	if (WCL::is_incorrect(D)) return NULL;
	return D;
}

@ Okay, so that was the implementation: here is the front end.

=
wcl_declaration *WCL::read_just_one(filename *F, int presumed) {
	return WCL::read_inner(NULL, F, presumed, TRUE);
}

@ At the opposite extreme, this reads |F| but allows any syntactically
correct contents to result.

=
wcl_declaration *WCL::read_anything(filename *F) {
	return WCL::read_presumption(F, MISCELLANY_WCLTYPE);
}

@ This similarly allows any outcome, but still expresses a preference:

=
wcl_declaration *WCL::read_presumption(filename *F, int presumed) {
	return WCL::read_inner(NULL, F, presumed, FALSE);
}

@ Reading what we know to be a web is a trickier business, because webs can
be either single files, or else whole directories. If the latter, then the
WCL matter is in its contents section; if the former, then the file itself is WCL.

So we provide a function which can handle either: the web should either be in
the file |F| or the directory |P|; however, if |F| is indeed a contents page,
then the web will be treated as the directory containing it.

Here, |D| can be a partly parsed declaration as returned by |WCL::read_for_type_only_forgivingly|,
or can be |NULL| to start from scratch.

=
wcl_declaration *WCL::read_web_or_halt(pathname *P, filename *F, wcl_declaration *D) {
	if (D) {
		WCL::parse_declarations_throwing_errors(D);
		if (WCL::is_incorrect(D)) D = NULL;
	} else {
		D = WCL::read_web(P, F);
	}
	if (D == NULL) {
		if (P) Errors::fatal_with_path("unable to read this web", P);
		else if (F) Errors::fatal_with_file("unable to read this web", F);
		else Errors::fatal("unable to read web");
	}
	return D;
}

int WCL::contents_page_file(filename *F) {
	int conts = FALSE;
	TEMPORARY_TEXT(extension)
	Filenames::write_extension(extension, F);
	if ((Str::eq_insensitive(extension, I".inwebc")) ||
		(Str::eq_insensitive(Filenames::get_leafname(F), I"Contents.inweb")) ||
		(Str::eq_insensitive(Filenames::get_leafname(F), I"Contents.w")))
		conts = TRUE;
	DISCARD_TEXT(extension)
	return conts;
}

wcl_declaration *WCL::read_web(pathname *P, filename *F) {
	filename *WCL_file = NULL;
	pathname *web_directory = NULL;
	if ((F) && (TextFiles::exists(F))) {
		if (WCL::contents_page_file(F)) {
			web_directory = Filenames::up(F);
			WCL_file = F;
		}
	} else if (P) {
		web_directory = P;
		WCL_file = Filenames::in(P, I"Contents.w");
		if (TextFiles::exists(WCL_file) == FALSE)
			WCL_file = Filenames::in(P, I"Contents.inweb");
		if (TextFiles::exists(WCL_file) == FALSE)
			WCL_file = Filenames::in(P, I"Contents.inwebc");
	} else internal_error("no location for web");

	wcl_declaration *D = NULL;
	if (web_directory) {
		D = WCL::read_inner(web_directory, WCL_file, WEB_WCLTYPE, TRUE);
		if (D) D->body_position = TextFiles::at(WCL_file, 1);
	} else {
		@<Read in a single-file web as WCL@>;
	}
	return D;
}

@<Read in a single-file web as WCL@> =
	D = WCL::new(WEB_WCLTYPE);
	D->modifier = PAGE_WCLMODIFIER;
	D->associated_file = F;
	D->body_position = TextFiles::at(WCL_file, 1);
	wcl_scanner scanner;
	scanner.D = D;
	scanner.margin = -1;
	TextFiles::read(F, FALSE, "can't open web file",
		TRUE, WCL::simple_read_line, NULL, (void *) (&scanner));
	WCL::parse_declarations_throwing_errors(D);
	if (WCL::is_incorrect(D)) D = NULL;

@ Note this very much simpler approach: the whole file is raw WCL, and we
do not allow recursive subdeclarations. (This is why the more sophisticated
//WCL::read_for_type_only// is not used.)

=
void WCL::simple_read_line(text_stream *line, text_file_position *tfp, void *v_state) {
	wcl_scanner *scanner = (wcl_scanner *) v_state;
	linked_list *list = scanner->D->declaration_lines;
	if ((Str::is_whitespace(line) == FALSE) || (LinkedLists::len(list) > 0))
		ADD_TO_LINKED_LIST(Str::duplicate(line), text_stream, list);
}

@h Writers.
A textual form of a WCL declaration is probably useful only for testing, but
here it is:

=
void WCL::write(OUTPUT_STREAM, wcl_declaration *D) {
	WCL::write_r(OUT, D, FALSE);
}

void WCL::write_briefly(OUTPUT_STREAM, wcl_declaration *D) {
	WCL::write_r(OUT, D, TRUE);
}

void WCL::write_r(OUTPUT_STREAM, wcl_declaration *D, int briefly) {
	if (D == NULL) { WRITE("Null declaration\n"); return; }
	WCL::write_type(OUT, D->declaration_type);
	if (Str::len(D->name) > 0) WRITE(" \"%S\"", D->name);
	WRITE(" at %f, line %d\n",
		D->declaration_position.text_file_filename, D->declaration_position.line_count);
	if (LinkedLists::len(D->errors) > 0) {
		WRITE("Error(s):\n");
		INDENT;
		wcl_error *E;
		LOOP_OVER_LINKED_LIST(E, wcl_error, D->errors)
			WRITE("%f, line %d: error: %S\n",
				E->tfp.text_file_filename, E->tfp.line_count, E->message);
		OUTDENT;
	}
	if (briefly == FALSE) {
		if (LinkedLists::len(D->declaration_lines) > 0) {
			WRITE("Declaration:\n");
			INDENT;
			text_stream *S;
			LOOP_OVER_LINKED_LIST(S, text_stream, D->declaration_lines)
				WRITE("%S\n", S);
			OUTDENT;
		}
		if (LinkedLists::len(D->surplus_lines) > 0) {
			WRITE("Surplus matter:\n");
			INDENT;
			text_stream *S;
			LOOP_OVER_LINKED_LIST(S, text_stream, D->surplus_lines)
				WRITE("%S\n", S);
			OUTDENT;
		}
	}
	INDENT;
	wcl_declaration *SD;
	LOOP_OVER_LINKED_LIST(SD, wcl_declaration, D->declarations)
		WCL::write_r(OUT, SD, briefly);
	OUTDENT;		
}

@ A mercifully briefer version is:

=
void WCL::summarise(OUTPUT_STREAM, wcl_declaration *D) {
	if (D == NULL) { WRITE("Null declaration\n"); return; }
	WCL::write_type(OUT, D->declaration_type);
	if (Str::len(D->name) > 0) WRITE(" \"%S\"", D->name);
	WRITE(", ");
	if (LinkedLists::len(D->declaration_lines) > 0) {
		WRITE("%d line(s)", LinkedLists::len(D->declaration_lines));
	}
	if (LinkedLists::len(D->surplus_lines) > 0) {
		if (LinkedLists::len(D->declaration_lines) > 0) WRITE(" + ");
		WRITE("%d surplus", LinkedLists::len(D->surplus_lines));
	}
	if (LinkedLists::len(D->declaration_lines) + LinkedLists::len(D->surplus_lines) == 0)
		WRITE("empty");
	WRITE("\n");
	if (LinkedLists::len(D->errors) > 0) {
		WRITE("Error(s):\n");
		INDENT;
		wcl_error *E;
		LOOP_OVER_LINKED_LIST(E, wcl_error, D->errors)
			WRITE("%f, line %d: error: %S\n",
				E->tfp.text_file_filename, E->tfp.line_count, E->message);
		OUTDENT;
	}
	INDENT;
	wcl_declaration *SD;
	LOOP_OVER_LINKED_LIST(SD, wcl_declaration, D->declarations)
		WCL::summarise(OUT, SD);
	OUTDENT;		
}
