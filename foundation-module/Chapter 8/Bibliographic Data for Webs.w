[Bibliographic::] Bibliographic Data for Webs.

To manage key-value pairs of bibliographic data, metadata if you like,
associated with a given web.

@h Storing data.
There are never more than a dozen or so key-value pairs, and it's more
convenient to store them directly here than to use a dictionary.

=
typedef struct web_bibliographic_datum {
	struct text_stream *key;
	struct text_stream *value;
	int declaration_permitted; /* is the contents page of the web allowed to set this? */
	int declaration_mandatory; /* is it positively required to? */
	int on_or_off; /* boolean: which we handle as the string "On" or "Off" */
	struct web_bibliographic_datum *alias;
	MEMORY_MANAGEMENT
} web_bibliographic_datum;

@ We keep these in linked lists, and here's a convenient way to scan them:

@d LOOP_OVER_BIBLIOGRAPHIC_DATA(bd, Wm)
	LOOP_OVER_LINKED_LIST(bd, web_bibliographic_datum, Wm->bibliographic_data)

@ The following check the rules:

=
int Bibliographic::datum_can_be_declared(web_md *Wm, text_stream *key) {
	web_bibliographic_datum *bd = Bibliographic::look_up_datum(Wm, key);
	if (bd == NULL) return FALSE;
	return bd->declaration_permitted;
}

int Bibliographic::datum_on_or_off(web_md *Wm, text_stream *key) {
	web_bibliographic_datum *bd = Bibliographic::look_up_datum(Wm, key);
	if (bd == NULL) return FALSE;
	return bd->on_or_off;
}

@h Initialising a web.
Each web has the following slate of data:

=
void Bibliographic::initialise_data(web_md *Wm) {
	web_bibliographic_datum *bd;

	bd = Bibliographic::set_datum(Wm, I"Author", NULL); bd->declaration_mandatory = TRUE;
	bd = Bibliographic::set_datum(Wm, I"Language", NULL); bd->declaration_mandatory = TRUE;
	bd = Bibliographic::set_datum(Wm, I"Purpose", NULL); bd->declaration_mandatory = TRUE;
	bd = Bibliographic::set_datum(Wm, I"Title", NULL); bd->declaration_mandatory = TRUE;

	bd = Bibliographic::set_datum(Wm, I"License", NULL);
	bd->alias = Bibliographic::set_datum(Wm, I"Licence", NULL); /* alias US to UK spelling */

	Bibliographic::set_datum(Wm, I"Short Title", NULL);
	Bibliographic::set_datum(Wm, I"Capitalized Title", NULL);
	Bibliographic::set_datum(Wm, I"Build Date", NULL);
	Bibliographic::set_datum(Wm, I"Build Number", NULL);
	Bibliographic::set_datum(Wm, I"Prerelease", NULL);
	Bibliographic::set_datum(Wm, I"Semantic Version Number", NULL);
	Bibliographic::set_datum(Wm, I"Version Number", I"1");
	Bibliographic::set_datum(Wm, I"Version Name", NULL);
	Bibliographic::set_datum(Wm, I"Index Template", NULL);
	Bibliographic::set_datum(Wm, I"Preform Language", NULL);

	bd = Bibliographic::set_datum(Wm, I"Declare Section Usage", I"Off"); bd->on_or_off = TRUE;
	bd = Bibliographic::set_datum(Wm, I"Namespaces", I"Off"); bd->on_or_off = TRUE;
	bd = Bibliographic::set_datum(Wm, I"Strict Usage Rules", I"Off"); bd->on_or_off = TRUE;
	bd = Bibliographic::set_datum(Wm, I"TeX Mathematics Notation", I"On"); bd->on_or_off = TRUE;
	bd = Bibliographic::set_datum(Wm, I"Code In Commentary Notation", I"|");
	bd = Bibliographic::set_datum(Wm, I"Code In Code Comments Notation", I"|");
	bd = Bibliographic::set_datum(Wm, I"Cross-References Notation", I"//");
	bd = Bibliographic::set_datum(Wm, I"Web Syntax Version", NULL);
}

@ Once the declarations for a web have been processed, the following is called
to check that all the mandatory declarations have indeed been made:

=
void Bibliographic::check_required_data(web_md *Wm) {
	web_bibliographic_datum *bd;
	LOOP_OVER_BIBLIOGRAPHIC_DATA(bd, Wm)
		if ((bd->declaration_mandatory) &&
			(Str::len(bd->value) == 0))
				Errors::fatal_with_text(
					"The web does not specify '%S: ...'", bd->key);
}

@h Reading bibliographic data.
Key names are case-sensitive.

=
text_stream *Bibliographic::get_datum(web_md *Wm, text_stream *key) {
	web_bibliographic_datum *bd = Bibliographic::look_up_datum(Wm, key);
	if (bd) return bd->value;
	return NULL;
}

int Bibliographic::data_exists(web_md *Wm, text_stream *key) {
	web_bibliographic_datum *bd = Bibliographic::look_up_datum(Wm, key);
	if ((bd) && (Str::len(bd->value) > 0)) return TRUE;
	return FALSE;
}

web_bibliographic_datum *Bibliographic::look_up_datum(web_md *Wm, text_stream *key) {
	web_bibliographic_datum *bd;
	LOOP_OVER_BIBLIOGRAPHIC_DATA(bd, Wm)
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
web_bibliographic_datum *Bibliographic::set_datum(web_md *Wm, text_stream *key, text_stream *val) {
	web_bibliographic_datum *bd = Bibliographic::look_up_datum(Wm, key);
	if (bd == NULL) @<Create a new datum, then@>
	else Str::copy(bd->value, val);
	if (Str::eq_wide_string(key, L"Title")) @<Also set a capitalized form@>;
	return bd;
}

@<Create a new datum, then@> =
	bd = CREATE(web_bibliographic_datum);
	bd->key = Str::duplicate(key);
	bd->value = Str::duplicate(val);
	bd->declaration_mandatory = FALSE;
	bd->declaration_permitted = TRUE;
	bd->on_or_off = FALSE;
	bd->alias = NULL;
	ADD_TO_LINKED_LIST(bd, web_bibliographic_datum, Wm->bibliographic_data);

@ A slightly foolish feature, this; if text like "Wuthering Heights" is
written to the "Title" key, then a full-caps "WUTHERING HEIGHTS" is
written to a "Capitalized Title" key. (This enables cover sheets which
want to typeset the title in full caps to do so.)

@<Also set a capitalized form@> =
	TEMPORARY_TEXT(recapped);
	Str::copy(recapped, val);
	LOOP_THROUGH_TEXT(P, recapped)
		Str::put(P, toupper(Str::get(P)));
	Bibliographic::set_datum(Wm, I"Capitalized Title", recapped);
	DISCARD_TEXT(recapped);
