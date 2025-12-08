[Bibliographic::] Bibliographic Data for Webs.

To manage key-value pairs of bibliographic data, metadata if you like,
associated with a given web.

@h Storing data.
There are never more than a dozen or so key-value pairs, and it's more
convenient to store them in a linked list than to use a dictionary.

=
typedef struct web_bibliographic_datum {
	struct text_stream *key;
	struct text_stream *value;
	int declaration_permitted; /* is the contents page of the web allowed to set this? */
	int declaration_mandatory; /* is it positively required to? */
	int on_or_off; /* boolean: which we handle as the string "On" or "Off" */
	int default_setting_only; /* made by Inweb to ensure the key's existence */
	struct web_bibliographic_datum *alias;
	CLASS_DEFINITION
} web_bibliographic_datum;

@ We keep these in linked lists, and here's a convenient way to scan them:

@d LOOP_OVER_BIBLIOGRAPHIC_DATA(bd, W)
	LOOP_OVER_LINKED_LIST(bd, web_bibliographic_datum, W->bibliographic_data)

@ The following check the rules:

=
int Bibliographic::datum_can_be_declared(ls_web *W, text_stream *key) {
	web_bibliographic_datum *bd = Bibliographic::look_up_datum(W, key);
	if (bd == NULL) return FALSE;
	while ((bd) && (bd->alias)) bd = bd->alias;
	return bd->declaration_permitted;
}

int Bibliographic::datum_on_or_off(ls_web *W, text_stream *key) {
	web_bibliographic_datum *bd = Bibliographic::look_up_datum(W, key);
	if (bd == NULL) return FALSE;
	while ((bd) && (bd->alias)) bd = bd->alias;
	return bd->on_or_off;
}

@h Initialising a web.
Each web has the following slate of data:

=
void Bibliographic::initialise_data(ls_web *W) {
	web_bibliographic_datum *bd;

	bd = Bibliographic::set_datum(W, I"Title", I"Untitled");
	bd = Bibliographic::set_datum(W, I"Author", I"Anonymous");
	bd = Bibliographic::preset_datum(W, I"Purpose", I"");
	bd = Bibliographic::set_datum(W, I"Language", I"None");
	bd = Bibliographic::set_datum(W, I"Notation", I"");

	bd = Bibliographic::set_datum(W, I"License", NULL);
	bd->alias = Bibliographic::preset_datum(W, I"Licence", NULL); /* alias US to UK spelling */

	Bibliographic::preset_datum(W, I"Short Title", NULL);
	Bibliographic::preset_datum(W, I"Build Date", NULL);
	Bibliographic::preset_datum(W, I"Build Number", NULL);
	Bibliographic::preset_datum(W, I"Prerelease", NULL);
	Bibliographic::preset_datum(W, I"Semantic Version Number", NULL);
	Bibliographic::preset_datum(W, I"Version Number", I"1");
	Bibliographic::preset_datum(W, I"Version Name", NULL);
	Bibliographic::preset_datum(W, I"Preform Language", NULL);
}

@ Once the declarations for a web have been processed, the following is called
to check that all the mandatory declarations have indeed been made:

=
void Bibliographic::check_required_data(ls_web *W) {
	web_bibliographic_datum *bd;
	LOOP_OVER_BIBLIOGRAPHIC_DATA(bd, W)
		if ((bd->declaration_mandatory) &&
			(Str::len(bd->value) == 0))
				Errors::fatal_with_text(
					"The web does not specify '%S: ...'", bd->key);
}

@h Reading bibliographic data.
Key names are case-sensitive.

A slightly foolish feature, this; if text like "Wuthering Heights" is written to
the "Title" key, then a full-caps "WUTHERING HEIGHTS" is returned by the query
for "Capitalized Title". (This enables cover sheets which want to typeset the
title in full caps to do so.) But strictly speaking the key "Capitalized Title"
does not exist.

=
text_stream *Bibliographic::get_datum(ls_web *W, text_stream *key) {
	if ((Str::begins_with(key, I"Capitalized ")) ||
		(Str::begins_with(key, I"Capitalised "))) {
		TEMPORARY_TEXT(key2)
		Str::substr(key2, Str::at(key, 12), Str::end(key));
		text_stream *value2 = Str::duplicate(Bibliographic::get_datum(W, key2));
		DISCARD_TEXT(key2)
		LOOP_THROUGH_TEXT(P, value2)
			Str::put(P, Characters::toupper(Str::get(P)));
		return value2;
	}
	web_bibliographic_datum *bd = Bibliographic::look_up_datum(W, key);
	if (bd) return bd->value;
	return NULL;
}

int Bibliographic::data_exists(ls_web *W, text_stream *key) {
	web_bibliographic_datum *bd = Bibliographic::look_up_datum(W, key);
	if ((bd) && (Str::len(bd->value) > 0)) return TRUE;
	return FALSE;
}

int Bibliographic::datum_has_been_set(ls_web *W, text_stream *key) {
	web_bibliographic_datum *bd = Bibliographic::look_up_datum(W, key);
	if ((bd) && (bd->default_setting_only == FALSE)) return TRUE;
	return FALSE;
}

web_bibliographic_datum *Bibliographic::look_up_datum(ls_web *W, text_stream *key) {
	web_bibliographic_datum *bd;
	LOOP_OVER_BIBLIOGRAPHIC_DATA(bd, W)
		if (Str::eq(key, bd->key)) {
			while ((bd) && (bd->alias)) bd = bd->alias;
			return bd;
		}
	return NULL;
}

@h Writing bibliographic data.
Note that a key-value pair is created if the key doesn't exist at present,
so this routine never fails.

=
web_bibliographic_datum *Bibliographic::set_datum(ls_web *W, text_stream *key, text_stream *val) {
	web_bibliographic_datum *bd = Bibliographic::look_up_datum(W, key);
	if (bd == NULL) @<Create a new datum, then@>
	else {
		while ((bd) && (bd->alias)) bd = bd->alias;
		Str::copy(bd->value, val);
		bd->default_setting_only = FALSE;
	}
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
	bd->default_setting_only = FALSE;
	ADD_TO_LINKED_LIST(bd, web_bibliographic_datum, W->bibliographic_data);

@ Almost the same, but distinguishing between default settings made here, and
explicit settings from the user:

=
web_bibliographic_datum *Bibliographic::preset_datum(ls_web *W, text_stream *key,
	text_stream *val) {
	web_bibliographic_datum *bd = Bibliographic::set_datum(W, key, val);
	bd->default_setting_only = TRUE;
	return bd;
}

@h Parsing bibliographic data.
The following attempts to parse |line| as a key-value pair, i.e., as text
reading |Key: Value|, and returns |TRUE| or |FALSE| according to whether the
text syntactically looks that way. 

If |set| is |TRUE| then the setting is made in the web |W|: or, it that's not
possible, an error is issued (but the function still returns |TRUE|).

=
int Bibliographic::parse_kvp(ls_web *W, text_stream *line, int set,
	text_file_position *tfp, text_stream *k, int throw_error) {
	int rv = FALSE;
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, line, U"([A-Z]%c+?): (%c+?) *")) {
		TEMPORARY_TEXT(key)
		Str::copy(key, mr.exp[0]);
		TEMPORARY_TEXT(value)
		Str::copy(value, mr.exp[1]);
		if (set) @<Set bibliographic key-value pair@>;
		if (k) {
			Str::clear(k);
			Str::copy(k, key);
		}
		DISCARD_TEXT(key)
		DISCARD_TEXT(value)
		rv = TRUE;
	}
	Regexp::dispose_of(&mr);
	return rv;
}

@<Set bibliographic key-value pair@> =
	if (Bibliographic::datum_can_be_declared(W, key)) {
		if (Bibliographic::datum_on_or_off(W, key)) {
			if ((Str::ne_wide_string(value, U"On")) && (Str::ne_wide_string(value, U"Off"))) {
				TEMPORARY_TEXT(err)
				WRITE_TO(err, "this setting must be 'On' or 'Off': %S", key);
				Errors::in_text_file_S(err, tfp);
				DISCARD_TEXT(err)
				Str::clear(value);
				WRITE_TO(value, "Off");
			}
		}
		Bibliographic::set_datum(W, key, value);
	} else {
		if (throw_error) {
			TEMPORARY_TEXT(err)
			WRITE_TO(err, "no such bibliographic datum: %S", key);
			Errors::in_text_file_S(err, tfp);
			DISCARD_TEXT(err)
		} else {
			return FALSE;
		}
	}
