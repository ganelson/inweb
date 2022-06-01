[JSON::] JSON.

To read and write JSON data interchange material.

@h Introduction.
JSON (Douglas Crockford, c. 2000) stands for "JavaScript Object Notation", but is
now a //standardised data interchange format -> https://www.ecma-international.org/wp-content/uploads/ECMA-404_2nd_edition_december_2017.pdf//
used in many contexts. It's especially suitable for passing small amounts of data
over the Internet, or between programs, or for making small data files human-readable.
It's not good for larger data sets: it is really designed for messages, metadata
or preference files.

This section provides encoding and decoding facilities. It is intended to comply
with //ECMA-404 -> https://www.ecma-international.org/wp-content/uploads/ECMA-404_2nd_edition_december_2017.pdf//,
except that (i) it disallows repetition the same key in the same object, and (ii)
text can only be used in the Basic Multilingual Plane of Unicode points |0x0000|
to |0xffff|.

There are no size maxima or limitations. Still, this code was written at typing speed,
and no effort has gone into reducing memory usage or running time in the face of
large (or malicious) JSON content. Error reporting is also limited in fulsomeness.

See the |foundation-test| test case |json| for many exercises of the code below;
do not change this section without checking that it continues to pass.

@h Data model.
JSON has a simple data model which we need to replicate in memory. Each value
will be a pointer to a (permanently held in memory) //JSON_value// object.
This is in effect a union, in that its type is always one of the following,
and then only certain elements are meaningful depending on type.

These are exactly the JSON types except that numbers are split between integer
and floating-point versions (the conflation of the two is where the Javascript
origins of JSON show through), and that the type |ERROR_JSONTYPE| represents
invalid data resulting from attempting to decode erroneous JSON.

@e NUMBER_JSONTYPE from 1
@e DOUBLE_JSONTYPE
@e STRING_JSONTYPE
@e BOOLEAN_JSONTYPE
@e ARRAY_JSONTYPE
@e OBJECT_JSONTYPE
@e NULL_JSONTYPE
@e ERROR_JSONTYPE

=
void JSON::write_type(OUTPUT_STREAM, int t) {
	switch (t) {
		case NUMBER_JSONTYPE:  WRITE("number"); break;
		case DOUBLE_JSONTYPE:  WRITE("double"); break;
		case STRING_JSONTYPE:  WRITE("string"); break;
		case BOOLEAN_JSONTYPE: WRITE("boolean"); break;
		case ARRAY_JSONTYPE:   WRITE("array"); break;
		case OBJECT_JSONTYPE:  WRITE("object"); break;
		case NULL_JSONTYPE:    WRITE("null"); break;
		case ERROR_JSONTYPE:   WRITE("<error>"); break;
		default:               WRITE("<invalid %d>", t); break;
	}
}

@

=
typedef struct JSON_value {
	int JSON_type;
	int if_integer;
	double if_double;
	struct text_stream *if_string;
	int if_boolean;
	struct linked_list *if_list; /* of |JSON_value| */
	struct dictionary *dictionary_if_object; /* to |JSON_value| */
	struct linked_list *list_if_object; /* of |text_stream| */
	struct text_stream *if_error;
	CLASS_DEFINITION
} JSON_value;

@ Now some constructor functions to create data of each JSON type:

=
JSON_value *JSON::new_null(void) {
	JSON_value *value = CREATE(JSON_value);
	value->JSON_type = NULL_JSONTYPE;
	value->if_integer = 0;
	value->if_double = 0;
	value->if_string = NULL;
	value->if_boolean = NOT_APPLICABLE;
	value->if_list = NULL;
	value->dictionary_if_object = NULL;
	value->list_if_object = NULL;
	value->if_error = NULL;
	return value;
}

JSON_value *JSON::new_boolean(int b) {
	JSON_value *value = JSON::new_null();
	value->JSON_type = BOOLEAN_JSONTYPE;
	value->if_boolean = b;
	if ((b != TRUE) && (b != FALSE)) internal_error("improper JSON boolean");
	return value;
}

JSON_value *JSON::new_number(int b) {
	JSON_value *value = JSON::new_null();
	value->JSON_type = NUMBER_JSONTYPE;
	value->if_integer = b;
	return value;
}

JSON_value *JSON::new_double(double d) {
	JSON_value *value = JSON::new_null();
	value->JSON_type = DOUBLE_JSONTYPE;
	value->if_double = d;
	return value;
}

JSON_value *JSON::new_string(text_stream *S) {
	JSON_value *value = JSON::new_null();
	value->JSON_type = STRING_JSONTYPE;
	value->if_string = Str::duplicate(S);
	return value;
}

@ JSON arrays -- lists, in effect -- should be created in an empty state, and
then have entries added sequentially:

=
JSON_value *JSON::new_array(void) {
	JSON_value *value = JSON::new_null();
	value->JSON_type = ARRAY_JSONTYPE;
	value->if_list = NEW_LINKED_LIST(JSON_value);
	return value;
}

JSON_value *JSON::add_to_array(JSON_value *array, JSON_value *new_entry) {
	if (array == NULL) internal_error("no array");
	if (array->JSON_type == ERROR_JSONTYPE) return array;
	if (array->JSON_type != ARRAY_JSONTYPE) internal_error("not an array");
	if (new_entry == NULL) internal_error("no new entry");
	if (new_entry->JSON_type == ERROR_JSONTYPE) return new_entry;
	ADD_TO_LINKED_LIST(new_entry, JSON_value, array->if_list);
	return array;
}

@ Similarly, JSON objects -- dictionaries of key-value pairs, in effect --
should be created in an empty state, and then have key-value pairs added as needed:

=
JSON_value *JSON::new_object(void) {
	JSON_value *value = JSON::new_null();
	value->JSON_type = OBJECT_JSONTYPE;
	value->dictionary_if_object = Dictionaries::new(16, FALSE);
	value->list_if_object = NEW_LINKED_LIST(text_stream);
	return value;
}

JSON_value *JSON::add_to_object(JSON_value *obj, text_stream *key, JSON_value *value) {
	if (obj == NULL) internal_error("no object");
	if (obj->JSON_type == ERROR_JSONTYPE) return obj;
	if (obj->JSON_type != OBJECT_JSONTYPE) internal_error("not an object");
	if (value == NULL) internal_error("no new entry");
	if (value->JSON_type == ERROR_JSONTYPE) return value;
	key = Str::duplicate(key);
	ADD_TO_LINKED_LIST(key, text_stream, obj->list_if_object);
	dict_entry *de = Dictionaries::create(obj->dictionary_if_object, key);
	if (de) de->value = value;
	return obj;
}

@ The following looks up a key in an object, returning |NULL| if and only if
it is not present:

=
JSON_value *JSON::look_up_object(JSON_value *obj, text_stream *key) {
	if (obj == NULL) internal_error("no object");
	if (obj->JSON_type == ERROR_JSONTYPE) return NULL;
	if (obj->JSON_type != OBJECT_JSONTYPE) internal_error("not an object");
	dict_entry *de = Dictionaries::find(obj->dictionary_if_object, key);
	if (de == NULL) return NULL;
	return de->value;
}

@ One last constructor creates an invalid JSON value resulting from incorrect
JSON input:

=
JSON_value *JSON::error(text_stream *msg) {
	JSON_value *value = JSON::new_null();
	value->JSON_type = ERROR_JSONTYPE;
	value->if_error = Str::duplicate(msg);
	return value;
}

@ This is a very limited form of comparison, since it cannot test equality
of arrays or objects.

=
int JSON::eq(JSON_value *val1, JSON_value *val2) {
	if ((val1 == NULL) && (val2)) return FALSE;
	if ((val1) && (val2 == NULL)) return FALSE;
	if (val1 == NULL) return TRUE;
	if (val1->JSON_type != val2->JSON_type) return FALSE;
	switch (val1->JSON_type) {
		case NUMBER_JSONTYPE:  if (val1->if_integer == val2->if_integer) return TRUE; break;
		case STRING_JSONTYPE:  if (Str::eq(val1->if_string, val2->if_string)) return TRUE; break;
		case BOOLEAN_JSONTYPE: if (val1->if_boolean == val2->if_boolean) return TRUE; break;
		case NULL_JSONTYPE:    return TRUE;
	}
	return FALSE;
}

@h Decoding JSON.
We do no actual file-handling in this section, but the following decoder can
be pointed to the contents of UTF-8 text file as needed.

The decoder returns a non-|NULL| pointer in all cases. If the text contains
any malformed JSON anywhere inside it, this pointer will be to a value of type
|ERROR_JSONTYPE|. Such a value should be thrown away as soon as the error
message is made use of.

=
JSON_value *JSON::decode(text_stream *T, text_file_position *tfp) {
	return JSON::decode_range(T, 0, Str::len(T), tfp);
}

JSON_value *JSON::decode_error(text_stream *err, text_file_position *tfp) {
	TEMPORARY_TEXT(msg)
	if (tfp) WRITE_TO(msg, "%f: ", tfp->text_file_filename);
	WRITE_TO(msg, "%S", err);
	JSON_value *value = JSON::error(msg);
	DISCARD_TEXT(msg)
	return value;
}

JSON_value *JSON::decode_error_q(text_stream *err, text_file_position *tfp,
	text_stream *T, int from, int to) {
	TEMPORARY_TEXT(msg)
	WRITE_TO(msg, "%S", err);
	if ((T) && (from < to)) {
		WRITE_TO(msg, ": '");
		for (int i=from; ((i<to) && (i-from < 40)); i++) {
			if (Str::get_at(T, i) == '\n') WRITE_TO(msg, " ");
			else WRITE_TO(msg, "%c", Str::get_at(T, i));
		}
		WRITE_TO(msg, "'");
	}
	JSON_value *value = JSON::decode_error(msg, tfp);
	DISCARD_TEXT(msg)
	return value;
}

@ This decodes the text in the character position range |[from, to)| as a
JSON value.

The possibilities here are |[ ... ]| for an array, |{ ... }| for an object,
|"..."| for a string, a token beginning with a digit or a minus sign for a
number (note that |+| and |.| are not allowed to open a number according to
the JSON standard), and the special cases |true|, |false| and |null|.

=
JSON_value *JSON::decode_range(text_stream *T, int from, int to, text_file_position *tfp) {
	int first_nws = -1, last_nws = -1, first_c = 0, last_c = 0;
	@<Find the first and last non-whitespace character@>;
	switch (first_c) {
		case '[':
			if (last_c != ']') return JSON::decode_error(I"mismatched '[' ... ']'", tfp);
			JSON_value *array = JSON::new_array();
			return JSON::decode_array(array, T, first_nws+1, last_nws, tfp);
		case '{':
			if (last_c != '}') return JSON::decode_error(I"mismatched '{' ... '}'", tfp);
			JSON_value *obj = JSON::new_object();
			return JSON::decode_object(obj, T, first_nws+1, last_nws, tfp);
		case '"':
			if (last_c != '"') return JSON::decode_error(I"mismatched quotation marks", tfp);
			return JSON::decode_string(T, first_nws+1, last_nws, tfp);
	}
	if ((Characters::isdigit(first_c)) || (first_c == '-'))
		return JSON::decode_number(T, first_nws, last_nws+1, tfp);
	if ((Str::includes_at(T, first_nws, I"true")) && (last_nws - first_nws == 3))
		return JSON::new_boolean(TRUE);
	if ((Str::includes_at(T, first_nws, I"false")) && (last_nws - first_nws == 4))
		return JSON::new_boolean(FALSE);
	if ((Str::includes_at(T, first_nws, I"null")) && (last_nws - first_nws == 3))
		return JSON::new_null();
	return JSON::decode_error(I"unknown JSON value", tfp);
}

@<Find the first and last non-whitespace character@> =
	for (int i=from; i<to; i++)
		if (Characters::is_whitespace(Str::get_at(T, i)) == FALSE) {
			first_nws = i; break;
		}
	for (int i=to-1; i>=from; i--)
		if (Characters::is_whitespace(Str::get_at(T, i)) == FALSE) {
			last_nws = i; break;
		}
	if (first_nws < 0) return JSON::decode_error(I"whitespace where JSON value expected", tfp);
	first_c = Str::get_at(T, first_nws);
	last_c = Str::get_at(T, last_nws);

@ So now we have individual decoder functions for each type. First, arrays, where
now the range |[from, to)| represents what is inside the square brackets: this
needs to be a comma-separated list. We follow ECMA strictly in disallowing a final
comma before the |]|, unlike some JSON-like parsers.

=
JSON_value *JSON::decode_array(JSON_value *array, text_stream *T, int from, int to,
	text_file_position *tfp) {
	int content = FALSE;
	for (int i=from; i<to; i++)
		if (Characters::is_whitespace(Str::get_at(T, i)) == FALSE)
			content = TRUE;
	if (content == FALSE) return array;
	NextEntry: ;
	int first_comma = -1, bl = 0;
	for (int i=from, quoted = FALSE; i<to; i++) {
		wchar_t c = Str::get_at(T, i);
		switch (c) {
			case '"': quoted = (quoted)?FALSE:TRUE; break;
			case '\\': if (quoted) i++; break;
			case ',': if ((first_comma < 0) && (bl == 0)) first_comma = i; break;
			case '[': case '{': if (quoted == FALSE) bl++; break;
			case ']': case '}': if (quoted == FALSE) bl--; break;
		}
	}
	if (first_comma >= 0) {
		array = JSON::decode_array_entry(array, T, from, first_comma, tfp);
		from = first_comma + 1;
		goto NextEntry;
	}
	return JSON::decode_array_entry(array, T, from, to, tfp);
}

JSON_value *JSON::decode_array_entry(JSON_value *array, text_stream *T, int from, int to,
	text_file_position *tfp) {
	JSON_value *value = JSON::decode_range(T, from, to, tfp);
	return JSON::add_to_array(array, value);
}

@ And similarly for objects.

=
JSON_value *JSON::decode_object(JSON_value *obj, text_stream *T, int from, int to,
	text_file_position *tfp) {
	int content = FALSE;
	for (int i=from; i<to; i++)
		if (Characters::is_whitespace(Str::get_at(T, i)) == FALSE)
			content = TRUE;
	if (content == FALSE) return obj;
	NextEntry: ;
	int first_comma = -1, bl = 0;
	for (int i=from, quoted = FALSE; i<to; i++) {
		wchar_t c = Str::get_at(T, i);
		switch (c) {
			case '"': quoted = (quoted)?FALSE:TRUE; break;
			case '\\': if (quoted) i++; break;
			case ',': if ((first_comma < 0) && (bl == 0)) first_comma = i; break;
			case '[': case '{': if (quoted == FALSE) bl++; break;
			case ']': case '}': if (quoted == FALSE) bl--; break;
		}
	}
	if (first_comma >= 0) {
		obj = JSON::decode_object_entry(obj, T, from, first_comma, tfp);
		from = first_comma + 1;
		goto NextEntry;
	}
	return JSON::decode_object_entry(obj, T, from, to, tfp);
}

@ Note that we allow key names to include all kinds of unconscionable garbage,
as ECMA requires. |\u0003\"\t\t\t| is a valid JSON key name; so is the empty string.

We are however slightly stricter than ECMA in that we disallow duplicate keys
in the same object. ECMA says this is a "semantic consideration that may be defined
by JSON processors". We are hereby defining it.

=
JSON_value *JSON::decode_object_entry(JSON_value *obj, text_stream *T, int from, int to,
	text_file_position *tfp) {
	while (Characters::is_whitespace(Str::get_at(T, from))) from++;
	int saved_from = from, saved_to = to;
	if (from >= to)
		return JSON::decode_error(I"object body ends with comma", tfp);
	if (Str::get_at(T, from) != '"')
		return JSON::decode_error_q(I"key does not begin with quotation mark", tfp, T, saved_from, saved_to);
	from++;
	int ended = FALSE;
	TEMPORARY_TEXT(key)
	while (from < to) {
		wchar_t c = Str::get_at(T, from++);
		if (c == '\"') { ended = TRUE; break; }
		PUT_TO(key, c);
		if ((c == '\\') && (from+1 < to)) {
			c = Str::get_at(T, from++);
			PUT_TO(key, c);
		}
	}
	if (ended == FALSE) return JSON::decode_error_q(I"key does not end with quotation mark", tfp, T, saved_from, saved_to);
	while (Characters::is_whitespace(Str::get_at(T, from))) from++;
	if ((from >= to) || (Str::get_at(T, from) != ':'))
		return JSON::decode_error_q(I"key is not followed by ':'", tfp, T, saved_from, saved_to);
	from++;
	if (JSON::look_up_object(obj, key)) return JSON::decode_error_q(I"duplicate key", tfp, T, saved_from, saved_to);
	JSON_value *value = JSON::decode_range(T, from, to, tfp);
	obj = JSON::add_to_object(obj, key, value);
	DISCARD_TEXT(key)
	return obj;
}

@ Numbers are annoying to decode since they can be given either in a restricted
floating-point syntax, or in decimal. ECMA is slippery on the question of exactly
what floating-point numbers can be represented, but it's common to consider
them as being |double|, so we'll follow suit.

=
JSON_value *JSON::decode_number(text_stream *T, int from, int to, text_file_position *tfp) {
	while (Characters::is_whitespace(Str::get_at(T, from))) from++;
	while ((to > from) && (Characters::is_whitespace(Str::get_at(T, to-1)))) to--;
	if (to <= from) return JSON::decode_error(I"whitespace where number expected", tfp);
	TEMPORARY_TEXT(integer)
	int at = from;
	if ((Str::get_at(T, at) == '-') && (to > at+1)) { PUT_TO(integer, '-'); at++; }
	int double_me = FALSE;
	for (int i=at; i<to; i++)
		if (Characters::isdigit(Str::get_at(T, i)))
			PUT_TO(integer, Str::get_at(T, i));
		else if ((Str::get_at(T, i) == 'E') || (Str::get_at(T, i) == 'e') ||
			(Str::get_at(T, i) == '.') || (Str::get_at(T, i) == '+'))
			double_me = TRUE;
		else
			return JSON::decode_error(I"number is not a decimal integer", tfp);
	JSON_value *value = NULL;
	if (double_me) {
		char double_buffer[32];
		for (int i=0; i<32; i++) double_buffer[i] = 0;
		for (int i=from; (i<to) && (i-from<31); i++)
			double_buffer[i-from] = (char) Str::get_at(T, i);
		double d = atof(double_buffer);
		if (isnan(d)) return JSON::decode_error(I"number is not allowed to be NaN", tfp);
		value = JSON::new_double(d);
	} else {
		int N = Str::atoi(integer, 0);
		value = JSON::new_number(N);
	}
	DISCARD_TEXT(integer)
	return value;
}

@ Strings are easy except for escape characters. I have no idea why JSON wants
to allow the escaping of forward slash, but the standard requires it.

=
JSON_value *JSON::decode_string(text_stream *T, int from, int to, text_file_position *tfp) {
	TEMPORARY_TEXT(string)
	for (int i=from; i<to; i++) {
		wchar_t c = Str::get_at(T, i);
		if (c == '\\') {
			i++;
			c = Str::get_at(T, i);
			if ((c >= 0) && (c < 32)) return JSON::decode_error(I"unescaped control character", tfp);
			switch (c) {
				case 'b': c = 8; break;
				case 't': c = 9; break;
				case 'n': c = 10; break;
				case 'f': c = 12; break;
				case 'r': c = 13; break;
				case '\\': break;
				case '/': break;
				case 'u': @<Decode a hexadecimal Unicode escape@>; break;
				default: return JSON::decode_error(I"bad '\\' escape in string", tfp);
			}
			PUT_TO(string, c);
		} else {
			PUT_TO(string, c);
		}
	}
	JSON_value *val = JSON::new_string(string);
	DISCARD_TEXT(string)
	return val;
}

@ We don't quite fully implement ECMA here: the following is fine for code points
in the Basic Multilingual Plane, but we don't handle the curious UTF-16 surrogate pair
rule for code points between |0x10000| and |0x10fff|.

@<Decode a hexadecimal Unicode escape@> =
	if (i+4 >= to) return JSON::decode_error(I"incomplete '\\u' escape", tfp);
	int hex = 0;
	for (int j=0; j<4; j++) {
		int v = 0;
		wchar_t digit = Str::get_at(T, i+1+j);
		if ((digit >= '0') && (digit <= '9')) v = (int) (digit-'0');
		else if ((digit >= 'a') && (digit <= 'f')) v = 10 + ((int) (digit-'a'));
		else if ((digit >= 'A') && (digit <= 'F')) v = 10 + ((int) (digit-'A'));
		else return JSON::decode_error(I"garbled '\\u' escape", tfp);
		hex = hex * 16 + v;
	}
	c = (wchar_t) hex;
	i += 4;

@h Encoding JSON.

=
void JSON::encode(OUTPUT_STREAM, JSON_value *J) {
	if (J == NULL) internal_error("no JSON value supplied");
	switch (J->JSON_type) {
		case ERROR_JSONTYPE:
			internal_error("tried to encode erroneous JSON");
		case NUMBER_JSONTYPE:
			WRITE("%d", J->if_integer);
			break;
		case DOUBLE_JSONTYPE:
			WRITE("%g", J->if_double);
			break;
		case STRING_JSONTYPE:
			WRITE("\""); JSON::encode_string(OUT, J->if_string); WRITE("\"");
			break;
		case BOOLEAN_JSONTYPE:
			if (J->if_boolean == TRUE) WRITE("true");
			else if (J->if_boolean == FALSE) WRITE("false");
			else internal_error("improper boolean JSON value");
			break;
		case ARRAY_JSONTYPE: {
			WRITE("[");
			int count = 0;
			JSON_value *E;
			LOOP_OVER_LINKED_LIST(E, JSON_value, J->if_list) {
				if (count++ > 0) WRITE(",");
				WRITE(" ");
				JSON::encode(OUT, E);
			}
			if (count > 0) WRITE(" ");
			WRITE("]");
			break;
		}
		case OBJECT_JSONTYPE: {
			WRITE("{\n"); INDENT;
			int count = 0;
			text_stream *key;
			LOOP_OVER_LINKED_LIST(key, text_stream, J->list_if_object) {
				if (count++ > 0) WRITE(",\n");
				JSON_value *E = Dictionaries::read_value(J->dictionary_if_object, key);
				if (E == NULL) internal_error("broken JSON object dictionary");
				WRITE("\"");
				JSON::encode_string(OUT, key);
				WRITE("\": ");
				JSON::encode(OUT, E);
			}
			if (count > 0) WRITE("\n");
			OUTDENT; WRITE("}");
			break;
		}
		case NULL_JSONTYPE:
			WRITE("null");
			break;
		default: internal_error("unsupported JSON value type");
	}
}

@ Note that we elect not to escape the slash character, or any Unicode code
points above 32.

=
void JSON::encode_string(OUTPUT_STREAM, text_stream *T) {
	LOOP_THROUGH_TEXT(pos, T) {
		wchar_t c = Str::get(pos);
		switch (c) {
			case '\\': WRITE("\\\\"); break;
			case 8: WRITE("\\b"); break;
			case 9: WRITE("\\t"); break;
			case 10: WRITE("\\n"); break;
			case 12: WRITE("\\f"); break;
			case 13: WRITE("\\r"); break;
			default:
				if ((c >= 0) && (c < 32)) WRITE("\\u%04x", c);
				else PUT(c);
				break;
		}
	}
}

@h Requirements.
Of course, the trouble with JSON is that it's a soup of undifferentiated data.
Just because you're expecting a pair of numbers, there's no reason to suppose
that's what you've been given, even if what you were given has parsed successfully.

The following is an intentionally similar tree structure to //JSON_value//,
but with requirements in place of values throughout, and with each member of
an object marked as optional or mandatory.

=
typedef struct JSON_requirement {
	struct linked_list *alternatives; /* of |JSON_single_requirement| */
	CLASS_DEFINITION
} JSON_requirement;

JSON_requirement *JSON::single_choice(JSON_single_requirement *sing) {
	JSON_requirement *req = CREATE(JSON_requirement);
	req->alternatives = NEW_LINKED_LIST(JSON_single_requirement);
	ADD_TO_LINKED_LIST(sing, JSON_single_requirement, req->alternatives);
	return req;
}	

JSON_requirement *JSON::add_alternative(JSON_requirement *so_far,
	JSON_single_requirement *sing) {
	if (so_far == NULL) return JSON::single_choice(sing);
	ADD_TO_LINKED_LIST(sing, JSON_single_requirement, so_far->alternatives);
	return so_far;
}	

typedef struct JSON_single_requirement {
	int JSON_type;
	struct JSON_requirement *this_requirement;
	struct JSON_value *this_value;
	struct JSON_requirement *all_if_list;
	struct linked_list *if_list; /* of |JSON_requirement| */
	struct dictionary *dictionary_if_object; /* to |JSON_pair_requirement| */
	struct linked_list *list_if_object; /* of |text_stream| */
	struct text_stream *if_error;
	int encoding_number;
	CLASS_DEFINITION
} JSON_single_requirement;

typedef struct JSON_pair_requirement {
	struct JSON_requirement *req;
	int optional;
	CLASS_DEFINITION
} JSON_pair_requirement;

@ The following constructors are used for everything...

=
JSON_single_requirement *JSON::require(int t) {
	JSON_single_requirement *req = CREATE(JSON_single_requirement);
	req->JSON_type = t;
	req->this_requirement = NULL;
	req->this_value = NULL;
	req->all_if_list = NULL;
	req->if_list = NULL;
	if (t == ARRAY_JSONTYPE) req->if_list = NEW_LINKED_LIST(JSON_requirement);
	req->dictionary_if_object = NULL;
	req->list_if_object = NULL;
	if (t == OBJECT_JSONTYPE) {
		req->dictionary_if_object = Dictionaries::new(16, FALSE);
		req->list_if_object = NEW_LINKED_LIST(text_stream);
	}
	req->if_error = NULL;
	req->encoding_number = 0;
	return req;
}

JSON_single_requirement *JSON::require_known(JSON_requirement *req) {
	JSON_single_requirement *sing = JSON::require(-1);
	sing->this_requirement = req;
	return sing;
}

JSON_single_requirement *JSON::require_value(JSON_value *value) {
	JSON_single_requirement *sing = JSON::require(-1);
	sing->this_value = value;
	return sing;
}

@ ...except for "array of any number of entries each matching this":

=
JSON_single_requirement *JSON::require_array_of(JSON_requirement *E_req) {
	JSON_single_requirement *req = JSON::require(ARRAY_JSONTYPE);
	req->all_if_list = E_req;
	return req;
}

@ If an array wants to be a tuple with a fixed number of entries, each with
its own requirement, then instead call |JSON::require(ARRAY_JSONTYPE)| and
then make a number of calls to the following in sequence:

=
void JSON::require_entry(JSON_single_requirement *req_array, JSON_requirement *req_entry) {
	if (req_array == NULL) internal_error("no array");
	if (req_array->JSON_type != ARRAY_JSONTYPE) internal_error("not an array requirement");
	if (req_entry == NULL) internal_error("no new entry");
	ADD_TO_LINKED_LIST(req_entry, JSON_requirement, req_array->if_list);
}

@ Similarly, create an object requirement with |JSON::require(OBJECT_JSONTYPE)|
and then either require or allow key-value pairs with:

=
void JSON::require_pair(JSON_single_requirement *req_obj, text_stream *key, JSON_requirement *req) {
	JSON::require_pair_inner(req_obj, key, req, FALSE);
}

void JSON::allow_pair(JSON_single_requirement *req_obj, text_stream *key, JSON_requirement *req) {
	JSON::require_pair_inner(req_obj, key, req, TRUE);
}

void JSON::require_pair_inner(JSON_single_requirement *req_obj, text_stream *key,
	JSON_requirement *req, int opt) {
	if (req_obj == NULL) internal_error("no object");
	if (req_obj->JSON_type != OBJECT_JSONTYPE) internal_error("not an object requirement");
	if (req == NULL) internal_error("no val req");
	key = Str::duplicate(key);
	ADD_TO_LINKED_LIST(key, text_stream, req_obj->list_if_object);
	JSON_pair_requirement *pr = CREATE(JSON_pair_requirement);
	pr->req = req;
	pr->optional = opt;
	dict_entry *de = Dictionaries::create(req_obj->dictionary_if_object, key);
	if (de) de->value = pr;
}

@ This then extracts the requirement on a given key, or returns |NULL| is if
is not permitted:

=
JSON_pair_requirement *JSON::look_up_pair(JSON_single_requirement *req_obj, text_stream *key) {
	if (req_obj == NULL) internal_error("no object");
	if (req_obj->JSON_type != OBJECT_JSONTYPE) internal_error("not an object");
	dict_entry *de = Dictionaries::find(req_obj->dictionary_if_object, key);
	if (de == NULL) return NULL;
	return de->value;
}

@ This is used when parsing textual requirements, to indicate a syntax error:

=
JSON_single_requirement *JSON::error_req(text_stream *msg) {
	JSON_single_requirement *req = JSON::require(ERROR_JSONTYPE);
	req->if_error = Str::duplicate(msg);
	return req;
}

@ The following returns |TRUE| if the value meets the requirement in full;
if not, |FALSE|, and then if |errs| is not null, a list of error messages is
appended to the linked list |errs|.

The stack here is used to give better error messages by locating where the
problem was: e.g. |"object.coordinates[1]"| is the result of the stack
holding |"object" > ".cooordinates" > "[1]"|.

=
int JSON::verify(JSON_value *val, JSON_requirement *req, linked_list *errs) {
	lifo_stack *location = NEW_LIFO_STACK(text_stream);
	if ((val) && (val->JSON_type == ARRAY_JSONTYPE)) {
		PUSH_TO_LIFO_STACK(I"array", text_stream, location);
	}
	if ((val) && (val->JSON_type == OBJECT_JSONTYPE)) {
		PUSH_TO_LIFO_STACK(I"object", text_stream, location);
	}
	return JSON::verify_r(val, req, errs, location);
}

void JSON::verify_error(linked_list *errs, text_stream *err, lifo_stack *location) {
	if (errs) {
		text_stream *msg = Str::new();
		int S = LinkedLists::len(location);
		for (int i=S-1; i>=0; i--) {
			int c = 0;
			text_stream *seg;
			LOOP_OVER_LINKED_LIST(seg, text_stream, location)
				if (c++ == i)
					WRITE_TO(msg, "%S", seg);
		}
		if (Str::len(msg) > 0) WRITE_TO(msg, ": ");
		WRITE_TO(msg, "%S", err);
		ADD_TO_LINKED_LIST(msg, text_stream, errs);
	}
}

@ So this is the recursive verification function:

=
int JSON::verify_r(JSON_value *val, JSON_requirement *req, linked_list *errs,
	lifo_stack *location) {
	if (val == NULL) internal_error("no value");
	if (req == NULL) internal_error("no req");
	JSON_single_requirement *sing;
	LOOP_OVER_LINKED_LIST(sing, JSON_single_requirement, req->alternatives) {
		int rv = JSON::verify_sr(val, sing, NULL, location);
		if (rv) return TRUE;
	}
	LOOP_OVER_LINKED_LIST(sing, JSON_single_requirement, req->alternatives) {
		JSON::verify_sr(val, sing, errs, location);
		break;
	}
	return FALSE;
}

int JSON::verify_sr(JSON_value *val, JSON_single_requirement *req, linked_list *errs,
	lifo_stack *location) {
	if (req->this_requirement)
		return JSON::verify_r(val, req->this_requirement, errs, location);
	if (req->this_value) {
		if (JSON::eq(val, req->this_value) == FALSE) {
			TEMPORARY_TEXT(msg)
			WRITE_TO(msg, "value ");
			JSON::encode(msg, val);
			WRITE_TO(msg, " not one of those allowed");
			JSON::verify_error(errs, msg, location);
			DISCARD_TEXT(msg)
			return FALSE;
		}
		return TRUE;
	}
	if (val->JSON_type == ERROR_JSONTYPE) {
		JSON::verify_error(errs, I"erroneous JSON value from parsing bad text", location);
		return FALSE;
	}
	@<Verify that the JSON type is correct@>;
	int outcome = TRUE;
	if (val->JSON_type == ARRAY_JSONTYPE)
		@<Verify that the array entries meet requirements@>;
	if (val->JSON_type == OBJECT_JSONTYPE)
		@<Verify that the object members meet requirements@>;
	return outcome;
}

@<Verify that the JSON type is correct@> =
	if (val->JSON_type != req->JSON_type) {
		if (errs) {
			TEMPORARY_TEXT(msg)
			WRITE_TO(msg, "expected ");
			JSON::write_type(msg, req->JSON_type);
			WRITE_TO(msg, " but found ");
			JSON::write_type(msg, val->JSON_type);
			JSON::verify_error(errs, msg, location);
			DISCARD_TEXT(msg)
		}
		return FALSE;
	}

@<Verify that the array entries meet requirements@> =
	int count = 0;
	JSON_value *E;
	LOOP_OVER_LINKED_LIST(E, JSON_value, val->if_list) {
		JSON_requirement *E_req = req->all_if_list;
		if (E_req == NULL) {
			JSON_requirement *A_req;
			int rcount = 0;
			LOOP_OVER_LINKED_LIST(A_req, JSON_requirement, req->if_list)
				if (rcount++ == count)
					E_req = A_req;
		}
		TEMPORARY_TEXT(at)
		WRITE_TO(at, "[%d]", count);
		PUSH_TO_LIFO_STACK(at, text_stream, location);
		if (E_req == NULL) {
			JSON::verify_error(errs, I"unexpected array entry", location);
			outcome = FALSE;
		} else {
			if (JSON::verify_r(E, E_req, errs, location) == FALSE) outcome = FALSE;
		}
		POP_LIFO_STACK(text_stream, location);
		DISCARD_TEXT(at)
		count++;
	}

@<Verify that the object members meet requirements@> =
	text_stream *key;
	LOOP_OVER_LINKED_LIST(key, text_stream, val->list_if_object) {
		JSON_value *E = Dictionaries::read_value(val->dictionary_if_object, key);
		if (E == NULL) internal_error("broken JSON object dictionary");
		JSON_pair_requirement *pr = JSON::look_up_pair(req, key);
		TEMPORARY_TEXT(at)
		WRITE_TO(at, ".%S", key);
		PUSH_TO_LIFO_STACK(at, text_stream, location);
		if (pr == NULL) {
			TEMPORARY_TEXT(msg)
			WRITE_TO(msg, "unexpected member '%S'", key);
			JSON::verify_error(errs, msg, location);
			DISCARD_TEXT(msg)
			outcome = FALSE;
		} else {
			if (JSON::verify_r(E, pr->req, errs, location) == FALSE) outcome = FALSE;
		}
		POP_LIFO_STACK(text_stream, location);
		DISCARD_TEXT(at)
	}
	LOOP_OVER_LINKED_LIST(key, text_stream, req->list_if_object) {
		JSON_pair_requirement *pr = Dictionaries::read_value(req->dictionary_if_object, key);
		if (pr == NULL) internal_error("broken JSON object requirement");
		if (pr->optional == FALSE) {
			JSON_value *E = JSON::look_up_object(val, key);
			if (E == NULL) {
				TEMPORARY_TEXT(msg)
				WRITE_TO(msg, "member '%S' missing", key);
				JSON::verify_error(errs, msg, location);
				DISCARD_TEXT(msg)
				outcome = FALSE;
			}
		}
	}

@h Decoding JSON requirements.
It's convenient to be able to read and write these requirements to textual
form, exactly as we do with JSON itself, and here goes.

This is an example of the syntax we parse. It's JSON except that
(a) the type names |number|, |double|, |string|, |boolean| and |null| are
used in place of their respective values;
(b) a question mark |?| before the name of a key means that it is optional;
(c) if an array has one entry followed by an asterisk |*|, it means
"any number of entries, each of which must match this";
(d) |<name>| refers to a requirement recorded in the |known_names| dictionary.

For example:

= (text)
{
	"coordinates": [ double, double, string ],
	?"jurisdiction": string,
	"journal": [ {
		"date": number,
		"entry": string
	}* ]
}
=

This function is essentially the same as //JSON::decode//, but returning a
requirement rather than a value, and therefore a little simpler. Note that
|known_names| can be |NULL| to have it not recognise any such names; there's
no need to create an empty dictionary in this case.

=
JSON_requirement *JSON::decode_req(text_stream *T, dictionary *known_names) {
	return JSON::decode_req_range(T, 0, Str::len(T), known_names);
}

@ This decodes the text in the character position range |[from, to)| as a
JSON requirement.

=
JSON_requirement *JSON::decode_req_range(text_stream *T, int from, int to,
	dictionary *known_names) {
	int first_nws = -1, last_nws = -1, first_c = 0, last_c = 0;
	@<Find the first and last non-whitespace character in requirement@>;
	if (first_c == '(') {
		if (last_c != ')') return JSON::single_choice(JSON::error_req(I"mismatched '(' ... ')'"));
		from = first_nws + 1;
		to = last_nws;
		JSON_requirement *req = NULL;
		NextEntry: ;
		int first_pipe = -1, bl = 0;
		for (int i=from, quoted = FALSE; i<to; i++) {
			wchar_t c = Str::get_at(T, i);
			switch (c) {
				case '"': quoted = (quoted)?FALSE:TRUE; break;
				case '\\': if (quoted) i++; break;
				case '|': if ((first_pipe < 0) && (bl == 0)) first_pipe = i; break;
				case '[': case '{': case '(': if (quoted == FALSE) bl++; break;
				case ']': case '}': case ')': if (quoted == FALSE) bl--; break;
			}
		}
		if (first_pipe >= 0) {
			req = JSON::decode_req_alternative(req, T, from, first_pipe, known_names);
			from = first_pipe + 1;
			goto NextEntry;
		}
		return JSON::decode_req_alternative(req, T, from, to, known_names);
	}
	return JSON::single_choice(JSON::decode_sreq_range(T, from, to, known_names));
}

JSON_requirement *JSON::decode_req_alternative(JSON_requirement *req, text_stream *T,
	int from, int to, dictionary *known_names) {
	JSON_single_requirement *sing = JSON::decode_sreq_range(T, from, to, known_names);
	return JSON::add_alternative(req, sing);
}

JSON_single_requirement *JSON::decode_sreq_range(text_stream *T, int from, int to,
	dictionary *known_names) {
	int first_nws = -1, last_nws = -1, first_c = 0, last_c = 0;
	@<Find the first and last non-whitespace character in requirement@>;
	if (first_nws < 0) return JSON::error_req(I"whitespace where requirement expected");
	switch (first_c) {
		case '[':
			if (last_c != ']') return JSON::error_req(I"mismatched '[' ... ']'");
			JSON_single_requirement *array = JSON::require(ARRAY_JSONTYPE);
			return JSON::decode_req_array(array, T, first_nws+1, last_nws, known_names);
		case '{':
			if (last_c != '}') return JSON::error_req(I"mismatched '{' ... '}'");
			JSON_single_requirement *obj = JSON::require(OBJECT_JSONTYPE);
			return JSON::decode_req_object(obj, T, first_nws+1, last_nws, known_names);
		case '<':
			if (last_c != '>') return JSON::error_req(I"mismatched '<' ... '>'");
			JSON_requirement *known = NULL;
			TEMPORARY_TEXT(name)
			for (int i = first_nws+1; i<last_nws; i++)
				PUT_TO(name, Str::get_at(T, i));
			if (known_names) {
				dict_entry *de = Dictionaries::find(known_names, name);
				if (de == NULL) return JSON::error_req(I"unknown '<name>'");
				known = de->value;
			} else {
				return JSON::error_req(I"'<' ... '>' not allowed");
			}
			DISCARD_TEXT(name)
			if (known) return JSON::require_known(known);
			return NULL;
	}

	int require_value = FALSE;
	
	if ((first_c == '"') || (first_c == '-') || (Characters::isdigit(first_c)))
		require_value = TRUE;
	if ((Str::includes_at(T, first_nws, I"true")) && (last_nws - first_nws == 3))
		require_value = TRUE;
	if ((Str::includes_at(T, first_nws, I"false")) && (last_nws - first_nws == 4))
		require_value = TRUE;
	if ((Str::includes_at(T, first_nws, I"null")) && (last_nws - first_nws == 3))
		require_value = TRUE;

	if (require_value) {
		JSON_value *value = JSON::decode_range(T, from, to, NULL);
		if (value->JSON_type == ERROR_JSONTYPE) {
			TEMPORARY_TEXT(err)
			WRITE_TO(err, "JSON value error: %S", value->if_error);
			JSON_single_requirement *sing = JSON::error_req(err);
			DISCARD_TEXT(err)
			return sing;
		}
		return JSON::require_value(value);
	}

	if ((Str::includes_at(T, first_nws, I"number")) && (last_nws - first_nws == 5))
		return JSON::require(NUMBER_JSONTYPE);
	if ((Str::includes_at(T, first_nws, I"double")) && (last_nws - first_nws == 5))
		return JSON::require(DOUBLE_JSONTYPE);
	if ((Str::includes_at(T, first_nws, I"string")) && (last_nws - first_nws == 5))
		return JSON::require(STRING_JSONTYPE);
	if ((Str::includes_at(T, first_nws, I"boolean")) && (last_nws - first_nws == 6))
		return JSON::require(BOOLEAN_JSONTYPE);
	if ((Str::includes_at(T, first_nws, I"null")) && (last_nws - first_nws == 3))
		return JSON::require(NULL_JSONTYPE);

	text_stream *msg = Str::new();
	WRITE_TO(msg, "unknown JSON type '");
	for (int i=first_nws; i<last_nws; i++) PUT_TO(msg, Str::get_at(T, i));
	WRITE_TO(msg, "'");
	return JSON::error_req(msg);
}

@<Find the first and last non-whitespace character in requirement@> =
	for (int i=from; i<to; i++)
		if (Characters::is_whitespace(Str::get_at(T, i)) == FALSE) {
			first_nws = i; break;
		}
	for (int i=to-1; i>=from; i--)
		if (Characters::is_whitespace(Str::get_at(T, i)) == FALSE) {
			last_nws = i; break;
		}
	first_c = Str::get_at(T, first_nws);
	last_c = Str::get_at(T, last_nws);

@ Array requirements:

=
JSON_single_requirement *JSON::decode_req_array(JSON_single_requirement *array, text_stream *T, 
	int from, int to, dictionary *known_names) {
	int content = FALSE;
	for (int i=from; i<to; i++)
		if (Characters::is_whitespace(Str::get_at(T, i)) == FALSE)
			content = TRUE;
	if (content == FALSE) return array;
	while ((to > from) && (Characters::is_whitespace(Str::get_at(T, to-1)))) to--;
	if (Str::get_at(T, to-1) == '*') {
		to--;
		return JSON::require_array_of(JSON::decode_req_range(T, from, to, known_names));
	}
	NextEntry: ;
	int first_comma = -1, bl = 0;
	for (int i=from, quoted = FALSE; i<to; i++) {
		wchar_t c = Str::get_at(T, i);
		switch (c) {
			case '"': quoted = (quoted)?FALSE:TRUE; break;
			case '\\': if (quoted) i++; break;
			case ',': if ((first_comma < 0) && (bl == 0)) first_comma = i; break;
			case '[': case '{': case '(': if (quoted == FALSE) bl++; break;
			case ']': case '}': case ')': if (quoted == FALSE) bl--; break;
		}
	}
	if (first_comma >= 0) {
		array = JSON::decode_req_array_entry(array, T, from, first_comma, known_names);
		from = first_comma + 1;
		goto NextEntry;
	}
	return JSON::decode_req_array_entry(array, T, from, to, known_names);
}

JSON_single_requirement *JSON::decode_req_array_entry(JSON_single_requirement *array, text_stream *T,
	int from, int to, dictionary *known_names) {
	JSON_requirement *req = JSON::decode_req_range(T, from, to, known_names);
	JSON::require_entry(array, req);
	return array;
}

@ And similarly for objects.

=
JSON_single_requirement *JSON::decode_req_object(JSON_single_requirement *obj, text_stream *T, 
	int from, int to, dictionary *known_names) {
	int content = FALSE;
	for (int i=from; i<to; i++)
		if (Characters::is_whitespace(Str::get_at(T, i)) == FALSE)
			content = TRUE;
	if (content == FALSE) return obj;
	NextEntry: ;
	int first_comma = -1, bl = 0;
	for (int i=from, quoted = FALSE; i<to; i++) {
		wchar_t c = Str::get_at(T, i);
		switch (c) {
			case '"': quoted = (quoted)?FALSE:TRUE; break;
			case '\\': if (quoted) i++; break;
			case ',': if ((first_comma < 0) && (bl == 0)) first_comma = i; break;
			case '[': case '{': case '(': if (quoted == FALSE) bl++; break;
			case ']': case '}': case ')': if (quoted == FALSE) bl--; break;
		}
	}
	if (first_comma >= 0) {
		obj = JSON::decode_req_object_entry(obj, T, from, first_comma, known_names);
		from = first_comma + 1;
		goto NextEntry;
	}
	return JSON::decode_req_object_entry(obj, T, from, to, known_names);
}

JSON_single_requirement *JSON::decode_req_object_entry(JSON_single_requirement *obj, text_stream *T, 
	int from, int to, dictionary *known_names) {
	int optional = FALSE;
	while (Characters::is_whitespace(Str::get_at(T, from))) from++;
	if (Str::get_at(T, from) == '?') { optional = TRUE; from++; }
	while (Characters::is_whitespace(Str::get_at(T, from))) from++;
	if (Str::get_at(T, from) != '"')
		return JSON::error_req(I"key does not begin with quotation mark");
	from++;
	int ended = FALSE;
	TEMPORARY_TEXT(key)
	while (from < to) {
		wchar_t c = Str::get_at(T, from++);
		if (c == '\"') { ended = TRUE; break; }
		PUT_TO(key, c);
		if ((c == '\\') && (from+1 < to)) {
			c = Str::get_at(T, from++);
			PUT_TO(key, c);
		}
	}
	if (ended == FALSE) return JSON::error_req(I"key does not end with quotation mark");
	while (Characters::is_whitespace(Str::get_at(T, from))) from++;
	if ((from >= to) || (Str::get_at(T, from) != ':'))
		return JSON::error_req(I"key is not followed by ':'");
	from++;
	if (JSON::look_up_pair(obj, key)) return JSON::error_req(I"duplicate key");
	JSON_requirement *req = JSON::decode_req_range(T, from, to, known_names);
	if (optional) JSON::allow_pair(obj, key, req);
	else JSON::require_pair(obj, key, req);
	DISCARD_TEXT(key)
	return obj;
}

@h Encoding JSON requirements.
This is now simple, with one caveat. It's possible to set up requirement trees
so that they are not well-founded. For example:

= (text as InC)
	JSON_single_requirement *set = JSON::require(ARRAY_JSONTYPE);
	set->all_if_list = JSON::single_choice(set);
=

This is not useless: it matches, say, |[]|, |[ [] ]| and |[ [], [ [] ] ]|
and other constructions giving amusement to set theorists. But it would cause
the following to hang without the check on "encoding numbers", which in effect
detect whether a requirement has already been printed in this round.

=
int unique_JSON_encoding = 1;
void JSON::encode_req(OUTPUT_STREAM, JSON_requirement *req) {
	JSON::encode_req_r(OUT, req, ++unique_JSON_encoding);
}

void JSON::encode_req_r(OUTPUT_STREAM, JSON_requirement *req, int uniq) {
	if (req == NULL) internal_error("no JSON value supplied");
	int L = LinkedLists::len(req->alternatives);
	if (L > 1) WRITE("( ");
	int c = 0;
	JSON_single_requirement *sing;
	LOOP_OVER_LINKED_LIST(sing, JSON_single_requirement, req->alternatives) {
		if (c++ > 0) WRITE(" | ");
		JSON::encode_sreq_r(OUT, sing, uniq);
	}
	if (L > 1) WRITE(" )");
}

void JSON::encode_sreq_r(OUTPUT_STREAM, JSON_single_requirement *req, int uniq) {
	if (req->encoding_number == uniq) {
		WRITE("<req %d>", req->allocation_id);
	} else {
		req->encoding_number = uniq;
		if (req->this_requirement) {
			JSON::encode_req_r(OUT, req->this_requirement, uniq);
			return;
		}
		if (req->this_value) {
			JSON::encode(OUT, req->this_value);
			return;
		}
		switch (req->JSON_type) {
			case ARRAY_JSONTYPE: {
				WRITE("[");
				if (req->all_if_list) {
					WRITE(" ");
					JSON::encode_req_r(OUT, req->all_if_list, uniq);
					WRITE("* ");
				} else {
					int count = 0;
					JSON_requirement *E_req;
					LOOP_OVER_LINKED_LIST(E_req, JSON_requirement, req->if_list) {
						if (count++ > 0) WRITE(",");
						WRITE(" ");
						JSON::encode_req_r(OUT, E_req, uniq);
					}
					if (count > 0) WRITE(" ");
				}
				WRITE("]");
				break;
			}
			case OBJECT_JSONTYPE: {
				WRITE("{\n"); INDENT;
				int count = 0;
				text_stream *key;
				LOOP_OVER_LINKED_LIST(key, text_stream, req->list_if_object) {
					if (count++ > 0) WRITE(",\n");
					JSON_pair_requirement *pr =
						Dictionaries::read_value(req->dictionary_if_object, key);
					if (pr == NULL) internal_error("broken JSON req dictionary");
					if (pr->optional) WRITE("?");
					WRITE("\"");
					JSON::encode_string(OUT, key);
					WRITE("\": ");
					JSON::encode_req_r(OUT, pr->req, uniq);
				}
				if (count > 0) WRITE("\n");
				OUTDENT; WRITE("}");
				break;
			}
			default: JSON::write_type(OUT, req->JSON_type);
		}
	}
}

@h Reading requirements files.

=
typedef struct JSON_rrf_state {
	struct text_stream *name;
	struct text_stream *defn;
	struct dictionary *dict;
	struct text_file_position at;
} JSON_rrf_state;

dictionary *JSON::read_requirements_file(dictionary *known, filename *F) {
	if (known == NULL) known = Dictionaries::new(32, FALSE);
	JSON_rrf_state state;
	state.name = Str::new();
	state.defn = Str::new();
	state.dict = known;
	TextFiles::read(F, FALSE, "unable to read file of JSON requirements", TRUE,
		&JSON::read_requirements_file_helper, NULL, (void *) &state);
	JSON::process_req_defn(&state);
	return known;	
}

void JSON::read_requirements_file_helper(text_stream *text, text_file_position *tfp,
	void *v_state) {
	JSON_rrf_state *state = (JSON_rrf_state *) v_state;
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, text, L" *<(%C+)> *::= *(%c*)")) {
		JSON::process_req_defn(state);
		WRITE_TO(state->name, "%S", mr.exp[0]);
		WRITE_TO(state->defn, "%S", mr.exp[1]);
		state->at = *tfp;
	} else if (Regexp::match(&mr, text, L" *!%c*")) {
		/* do nothing: this line is a comment */
	} else if (Regexp::match(&mr, text, L" *")) {
		/* do nothing: this line is blank */
	} else if (Str::len(state->name) > 0) {
		WRITE_TO(state->defn, "%S\n", text);
	} else {
		Errors::in_text_file_S(I"spurious text before first requirement", tfp);
	}
}

void JSON::process_req_defn(JSON_rrf_state *state) {
	if (Str::len(state->name) > 0) {
		JSON_requirement *req = JSON::decode_printing_errors(state->defn, state->dict, &(state->at));
		if (req) {
			dict_entry *de = Dictionaries::create(state->dict, state->name);
			if (de) de->value = req;
		}
	}
	Str::clear(state->name);
	Str::clear(state->defn);
}

JSON_requirement *JSON::decode_printing_errors(text_stream *defn, dictionary *dict,
	text_file_position *tfp) {
	JSON_requirement *req = JSON::decode_req(defn, dict);
	if (req == NULL) internal_error("decode_req returned NULL");
	int errors_found = FALSE;
	JSON_single_requirement *sing;
	LOOP_OVER_LINKED_LIST(sing, JSON_single_requirement, req->alternatives) {
		if (sing->JSON_type == ERROR_JSONTYPE) {
			TEMPORARY_TEXT(err)
			WRITE_TO(err, "JSON requirement error: %S", sing->if_error);
			Errors::in_text_file_S(err, tfp);
			errors_found = TRUE;
			DISCARD_TEXT(err)
		}
	}
	if (errors_found == FALSE) return req;
	return NULL;
}

JSON_requirement *JSON::look_up_requirements(dictionary *known, text_stream *name) {
	dict_entry *de = Dictionaries::find(known, name);
	if (de == NULL) return NULL;
	return de->value;
}
