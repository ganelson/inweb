[Bibliographic::] Bibliographic Data.

To manage key-value pairs of bibliographic data, metadata if you like,
associated with a given web.

@h Storing data.
There are never more than a dozen or so key-value pairs, and it's more
convenient to store them directly here than to use a dictionary.

=
typedef struct bibliographic_datum {
	struct text_stream *key;
	struct text_stream *value;
	int declaration_permitted; /* is the contents page of the web allowed to set this? */
	int declaration_mandatory; /* is it positively required to? */
	int on_or_off; /* boolean: which we handle as the string "On" or "Off" */
	struct bibliographic_datum *alias;
	MEMORY_MANAGEMENT
} bibliographic_datum;

@ We keep these in linked lists, and here's a convenient way to scan them:

@d LOOP_OVER_BIBLIOGRAPHIC_DATA(bd, W)
	LOOP_OVER_LINKED_LIST(bd, bibliographic_datum, W->bibliographic_data)

@ The following check the rules:

=
int Bibliographic::datum_can_be_declared(web *W, text_stream *key) {
	bibliographic_datum *bd = Bibliographic::look_up_datum(W, key);
	if (bd == NULL) return FALSE;
	return bd->declaration_permitted;
}

int Bibliographic::datum_on_or_off(web *W, text_stream *key) {
	bibliographic_datum *bd = Bibliographic::look_up_datum(W, key);
	if (bd == NULL) return FALSE;
	return bd->on_or_off;
}

@h Initialising a web.
Each web has the following slate of data:

=
void Bibliographic::initialise_data(web *W) {
	bibliographic_datum *bd;
	TEMPORARY_TEXT(IB);
	WRITE_TO(IB, "%s", INWEB_BUILD);
	bd = Bibliographic::set_datum(W, I"Inweb Version", IB); bd->declaration_permitted = FALSE;
	DISCARD_TEXT(IB);

	bd = Bibliographic::set_datum(W, I"Author", NULL); bd->declaration_mandatory = TRUE;
	bd = Bibliographic::set_datum(W, I"Language", NULL); bd->declaration_mandatory = TRUE;
	bd = Bibliographic::set_datum(W, I"Purpose", NULL); bd->declaration_mandatory = TRUE;
	bd = Bibliographic::set_datum(W, I"Title", NULL); bd->declaration_mandatory = TRUE;

	bd = Bibliographic::set_datum(W, I"License", NULL);
	bd->alias = Bibliographic::set_datum(W, I"Licence", NULL); /* alias US to UK spelling */

	Bibliographic::set_datum(W, I"Short Title", NULL);
	Bibliographic::set_datum(W, I"Capitalized Title", NULL);
	Bibliographic::set_datum(W, I"Build Date", NULL);
	Bibliographic::set_datum(W, I"Build Number", NULL);
	Bibliographic::set_datum(W, I"Prerelease", NULL);
	Bibliographic::set_datum(W, I"Semantic Version Number", NULL);
	Bibliographic::set_datum(W, I"Version Number", I"1");
	Bibliographic::set_datum(W, I"Version Name", NULL);
	Bibliographic::set_datum(W, I"Index Template", NULL);
	Bibliographic::set_datum(W, I"Preform Language", NULL);

	bd = Bibliographic::set_datum(W, I"Declare Section Usage", I"Off"); bd->on_or_off = TRUE;
	bd = Bibliographic::set_datum(W, I"Namespaces", I"Off"); bd->on_or_off = TRUE;
	bd = Bibliographic::set_datum(W, I"Strict Usage Rules", I"Off"); bd->on_or_off = TRUE;
	bd = Bibliographic::set_datum(W, I"Web Syntax Version", NULL);
	
	BuildFiles::set_bibliographic_data_for(W);
}

@ Once the declarations for a web have been processed, the following is called
to check that all the mandatory declarations have indeed been made:

=
void Bibliographic::check_required_data(web *W) {
	bibliographic_datum *bd;
	LOOP_OVER_BIBLIOGRAPHIC_DATA(bd, W)
		if ((bd->declaration_mandatory) &&
			(Str::len(bd->value) == 0))
				Errors::fatal_with_text(
					"The Contents.w section does not specify '%S: ...'", bd->key);
}

@h Reading bibliographic data.
Key names are case-sensitive.

=
text_stream *Bibliographic::get_datum(web *W, text_stream *key) {
	bibliographic_datum *bd = Bibliographic::look_up_datum(W, key);
	if (bd) return bd->value;
	return NULL;
}

int Bibliographic::data_exists(web *W, text_stream *key) {
	bibliographic_datum *bd = Bibliographic::look_up_datum(W, key);
	if ((bd) && (Str::len(bd->value) > 0)) return TRUE;
	return FALSE;
}

bibliographic_datum *Bibliographic::look_up_datum(web *W, text_stream *key) {
	bibliographic_datum *bd;
	LOOP_OVER_BIBLIOGRAPHIC_DATA(bd, W)
		if (Str::eq(key, bd->key)) {
			if (bd->alias) return bd->alias;
			return bd;
		}
	return NULL;
}

@h Writing bibliographic data.
Note that a key-value pair is created if the key doesn't exist at present,
so this routine never fails.

=
bibliographic_datum *Bibliographic::set_datum(web *W, text_stream *key, text_stream *val) {
	bibliographic_datum *bd = Bibliographic::look_up_datum(W, key);
	if (bd == NULL) @<Create a new datum, then@>
	else Str::copy(bd->value, val);
	if (Str::eq_wide_string(key, L"Title")) @<Also set a capitalized form@>;
	return bd;
}

@<Create a new datum, then@> =
	bd = CREATE(bibliographic_datum);
	bd->key = Str::duplicate(key);
	bd->value = Str::duplicate(val);
	bd->declaration_mandatory = FALSE;
	bd->declaration_permitted = TRUE;
	bd->on_or_off = FALSE;
	bd->alias = NULL;
	ADD_TO_LINKED_LIST(bd, bibliographic_datum, W->bibliographic_data);

@ A slightly foolish feature, this; if text like "Wuthering Heights" is
written to the "Title" key, then a full-caps "WUTHERING HEIGHTS" is
written to a "Capitalized Title" key. (This enables cover sheets which
want to typeset the title in full caps to do so.)

@<Also set a capitalized form@> =
	TEMPORARY_TEXT(recapped);
	Str::copy(recapped, val);
	LOOP_THROUGH_TEXT(P, recapped)
		Str::put(P, toupper(Str::get(P)));
	Bibliographic::set_datum(W, I"Capitalized Title", recapped);
	DISCARD_TEXT(recapped);
