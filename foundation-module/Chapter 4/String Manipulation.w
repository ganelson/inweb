[Str::] String Manipulation.

Convenient routines for manipulating strings of text.

@h Strings are streams.
Although Foundation provides limited facilities for handling standard or
wide C-style strings -- that is, null-terminated arrays of |char| or
|inchar32_t| -- these are not encouraged.

Instead, a standard string for a program using Foundation is nothing more than
a text stream (see Chapter 2). These are unbounded in size, with memory
allocation being automatic; they are encoded as an array of Unicode code
points (not as UTF-8, -16 or -32); and they do not use a null or indeed any
terminator. This has the advantage that finding the length of a string, and
appending characters to it, run in constant time regardless of the string's
length. It is is entirely feasible to write hundreds of megabytes of
output into a string, if that's useful, and no substantial slowing down
will occur in handling the result (except, of course, that printing it
out on screen would take a while). Strings are also very well protected
against buffer overruns.

The present section of code provides convenient routines for creating,
duplicating, modifying and examining such strings.

@h New strings.
Sometimes we want to make a new string in the sense of allocating more
memory to hold it. These objects won't automatically be destroyed, so we
shouldn't call these routines too casually. If we need a string just for
some space to play with for a short while, it's better to create one
with |TEMPORARY_TEXT| and then get rid of it with |DISCARD_TEXT|, macros
defined in Chapter 2.

The capacity of these strings is unlimited in principle, and the number
here is just the size of the initial memory block, which is fastest to
access.

=
text_stream *Str::new(void) {
	return Str::new_with_capacity(32);
}

text_stream *Str::new_with_capacity(int c) {
	text_stream *S = CREATE(text_stream);
	if (Streams::open_to_memory(S, c)) return S;
	return NULL;
}

void Str::dispose_of(text_stream *text) {
	if (text) STREAM_CLOSE(text);
}

@ Duplication of an existing string is complicated only by the issue that
we want the duplicate always to be writeable, so that |NULL| can't be
duplicated as |NULL|.

=
text_stream *Str::duplicate(text_stream *E) {
	if (E == NULL) return Str::new();
	text_stream *S = CREATE(text_stream);
	if (Streams::open_to_memory(S, Str::len(E)+4)) {
		Streams::copy(S, E);
		return S;
	}
	return NULL;
}

@h Converting from C strings.
Here we open text streams initially equal to the given C strings, and
with the capacity of the initial block large enough to hold the whole
thing plus a little extra, for efficiency's sake.

=
text_stream *Str::new_from_wide_string(const inchar32_t *C_string) {
	text_stream *S = CREATE(text_stream);
	int C_len = (C_string)?Wide::len(C_string):0;
	if (Streams::open_from_wide_string(S, C_string, C_len)) return S;
	return NULL;
}

text_stream *Str::new_from_ISO_string(const char *C_string) {
	text_stream *S = CREATE(text_stream);
	if (Streams::open_from_ISO_string(S, C_string)) return S;
	return NULL;
}

text_stream *Str::new_from_UTF8_string(const char *C_string) {
	text_stream *S = CREATE(text_stream);
	if (Streams::open_from_UTF8_string(S, C_string)) return S;
	return NULL;
}

text_stream *Str::new_from_locale_string(const char *C_string) {
	text_stream *S = CREATE(text_stream);
	if (Streams::open_from_locale_string(S, C_string)) return S;
	return NULL;
}

@ And sometimes we want to use an existing stream object:

=
text_stream *Str::from_wide_string(text_stream *S, inchar32_t *c_string) {
	int c_len = (c_string)?Wide::len(c_string):0;
	if (Streams::open_from_wide_string(S, c_string, c_len) == FALSE) return NULL;
	return S;
}

text_stream *Str::from_locale_string(text_stream *S, char *c_string) {
	if (Streams::open_from_locale_string(S, c_string) == FALSE) return NULL;
	return S;
}

@h Converting to C strings.

=
void Str::copy_to_ISO_string(char *C_string, text_stream *S, int buffer_size) {
	Streams::write_as_ISO_string(C_string, S, buffer_size);
}

void Str::copy_to_UTF8_string(char *C_string, text_stream *S, int buffer_size) {
	Streams::write_as_UTF8_string(C_string, S, buffer_size);
}

void Str::copy_to_wide_string(inchar32_t *C_string, text_stream *S, int buffer_size) {
	Streams::write_as_wide_string(C_string, S, buffer_size);
}

void Str::copy_to_locale_string(char *C_string, text_stream *S, int buffer_size) {
	Streams::write_as_locale_string(C_string, S, buffer_size);
}

@h Converting to integers.

=
int Str::atoi(text_stream *S, int index) {
	char buffer[32];
	int i = 0;
	for (string_position P = Str::at(S, index);
		((i < 31) && (P.index < Str::len(S))); P = Str::forward(P))
		buffer[i++] = (char) Str::get(P);
	buffer[i] = 0;
	return atoi(buffer);
}

@h Length.
A puritan would return a |size_t| here, but I am not a puritan.

=
int Str::len(text_stream *S) {
	return Streams::get_position(S);
}

@h Position markers.
A position marker is a lightweight way to refer to a particular position
in a given string. Position 0 is before the first character; if, for
example, the string contains the word "gazpacho", then position 8 represents
the end of the string, after the "o". Negative positions are not allowed,
but positive ones well past the end of the string are legal. (Doing things
at those positions may well not be, of course.)

=
typedef struct string_position {
	struct text_stream *S;
	int index;
} string_position;

@ You can then find a position in a given string thus:

=
string_position Str::start(text_stream *S) {
	string_position P; P.S = S; P.index = 0; return P;
}

string_position Str::at(text_stream *S, int i) {
	if (i < 0) i = 0;
	if (i > Str::len(S)) i = Str::len(S);
	string_position P; P.S = S; P.index = i; return P;
}

string_position Str::end(text_stream *S) {
	string_position P; P.S = S; P.index = Str::len(S); return P;
}

@ And you can step forwards or backwards:

=
string_position Str::back(string_position P) {
	if (P.index > 0) P.index--; return P;
}

string_position Str::forward(string_position P) {
	P.index++; return P;
}

string_position Str::plus(string_position P, int increment) {
	P.index += increment; return P;
}

int Str::width_between(string_position P1, string_position P2) {
	if (P1.S != P2.S) internal_error("positions are in different strings");
	return P2.index - P1.index;
}

int Str::in_range(string_position P) {
	if (P.index < Str::len(P.S)) return TRUE;
	return FALSE;
}

int Str::index(string_position P) {
	return P.index;
}

@ This leads to the following convenient loop macros:

@d LOOP_THROUGH_TEXT(P, ST)
	for (string_position P = Str::start(ST); P.index < Str::len(P.S); P.index++)

@d LOOP_BACKWARDS_THROUGH_TEXT(P, ST)
	for (string_position P = Str::back(Str::end(ST)); P.index >= 0; P.index--)

@h Character operations.
How to get at individual characters, then, now that we can refer to positions:

=
inchar32_t Str::get(string_position P) {
	if ((P.S == NULL) || (P.index < 0)) return 0;
	return Streams::get_char_at_index(P.S, P.index);
}

inchar32_t Str::get_at(text_stream *S, int index) {
	if ((S == NULL) || (index < 0)) return 0;
	return Streams::get_char_at_index(S, index);
}

inchar32_t Str::get_first_char(text_stream *S) {
	return Str::get(Str::at(S, 0));
}

inchar32_t Str::get_last_char(text_stream *S) {
	int L = Str::len(S);
	if (L == 0) return 0;
	return Str::get(Str::at(S, L-1));
}

@ =
void Str::put(string_position P, inchar32_t C) {
	if (P.index < 0) internal_error("wrote before start of string");
	if (P.S == NULL) internal_error("wrote to null stream");
	int ext = Str::len(P.S);
	if (P.index > ext) internal_error("wrote beyond end of string");
	if (P.index == ext) {
		if (C) PUT_TO(P.S, C);
		return;
	}
	Streams::put_char_at_index(P.S, P.index, C);
}

void Str::put_at(text_stream *S, int index, inchar32_t C) {
	Str::put(Str::at(S, index), C);
}

@h Truncation.

=
void Str::clear(text_stream *S) {
	Str::truncate(S, 0);
}

void Str::truncate(text_stream *S, int len) {
	if (len < 0) len = 0;
	if (len < Str::len(S)) Str::put(Str::at(S, len), 0);
}

@h Indentation.

=
int Str::remove_indentation(text_stream *S, int spaces_per_tab) {
	int spaces_in = 0, tab_stops_of_indentation = 0;
	while (Characters::is_space_or_tab(Str::get_first_char(S))) {
		if (Str::get_first_char(S) == '\t') {
			spaces_in = 0;
			tab_stops_of_indentation++;
		} else {
			spaces_in++;
			if (spaces_in == spaces_per_tab) {
				tab_stops_of_indentation++;
				spaces_in = 0;
			}
		}
		Str::delete_first_character(S);
	}
	if (spaces_in > 0) {
		TEMPORARY_TEXT(respaced)
		while (spaces_in > 0) { PUT_TO(respaced, ' '); spaces_in--; }
		WRITE_TO(respaced, "%S", S);
		Str::clear(S);
		Str::copy(S, respaced);
		DISCARD_TEXT(respaced)
	}
	return tab_stops_of_indentation;
}

void Str::rectify_indentation(text_stream *S, int spaces_per_tab) {
	TEMPORARY_TEXT(tail)
	WRITE_TO(tail, "%S", S);
	int N = Str::remove_indentation(tail, spaces_per_tab);
	Str::clear(S);
	for (int i=0; i<N; i++) for (int j=0; j<spaces_per_tab; j++) PUT_TO(S, ' ');
	WRITE_TO(S, "%S", tail);
	DISCARD_TEXT(tail)
}

@h Copying.

=
void Str::concatenate(text_stream *S1, text_stream *S2) {
	Streams::copy(S1, S2);
}

void Str::copy(text_stream *S1, text_stream *S2) {
	if (S1 == S2) return;
	Str::clear(S1);
	Streams::copy(S1, S2);
}

void Str::copy_tail(text_stream *S1, text_stream *S2, int from) {
	Str::clear(S1);
	int L = Str::len(S2);
	if (from < L)
		for (string_position P = Str::at(S2, from); P.index < L; P = Str::forward(P))
			PUT_TO(S1, Str::get(P));
}

@ A subtly different operation is to set a string equal to a given C string:

=
void Str::copy_ISO_string(text_stream *S, char *C_string) {
	Str::clear(S);
	Streams::write_ISO_string(S, C_string);
}

void Str::copy_UTF8_string(text_stream *S, char *C_string) {
	Str::clear(S);
	Streams::write_UTF8_string(S, C_string);
}

void Str::copy_wide_string(text_stream *S, inchar32_t *C_string) {
	Str::clear(S);
	Streams::write_wide_string(S, C_string);
}

@h Comparisons.
We provide both case sensitive and insensitive versions.

=
int Str::eq(text_stream *S1, text_stream *S2) {
	if (Str::cmp(S1, S2) == 0) return TRUE;
	return FALSE;
}

int Str::eq_insensitive(text_stream *S1, text_stream *S2) {
	if ((Str::len(S1) == Str::len(S2)) && (Str::cmp_insensitive(S1, S2) == 0)) return TRUE;
	return FALSE;
}

int Str::ne(text_stream *S1, text_stream *S2) {
	if (Str::cmp(S1, S2) != 0) return TRUE;
	return FALSE;
}

int Str::ne_insensitive(text_stream *S1, text_stream *S2) {
	if ((Str::len(S1) != Str::len(S2)) || (Str::cmp_insensitive(S1, S2) != 0)) return TRUE;
	return FALSE;
}

@ These two routines produce a numerical string difference suitable for
alphabetic sorting, like |strlen| in the C standard library.

This would be a more elegant implementation:
= (text as InC)
	for (string_position P = Str::start(S1), Q = Str::start(S2);
		(P.index < Str::len(S1)) && (Q.index < Str::len(S2));
		P = Str::forward(P), Q = Str::forward(Q)) {
		int d = (int) Str::get(P) - (int) Str::get(Q);
		if (d != 0) return d;
	}
	return Str::len(S1) - Str::len(S2);
=
But profiling shows that the following speeds up the Inform 7 compiler by
around 1%.

=
int Str::cmp(text_stream *S1, text_stream *S2) {
	int L1 = Str::len(S1), L2 = Str::len(S2), M = L1;
	if (L2 < M) M = L2;
	for (int i=0; i<M; i++) {
		int d = (int) Str::get_at(S1, i) - (int) Str::get_at(S2, i);
		if (d != 0) return d;
	}
	return L1 - L2;
}

int Str::cmp_insensitive(text_stream *S1, text_stream *S2) {
	for (string_position P = Str::start(S1), Q = Str::start(S2);
		(P.index < Str::len(S1)) && (Q.index < Str::len(S2));
		P = Str::forward(P), Q = Str::forward(Q)) {
		int d = tolower((int) Str::get(P)) - tolower((int) Str::get(Q));
		if (d != 0) return d;
	}
	return Str::len(S1) - Str::len(S2);
}

@ It's sometimes useful to see whether two strings agree on their last
|N| characters, or their first |N|. For example,
= (text as code)
	Str::suffix_eq(I"wayzgoose", I"snow goose", N)
=
will return |TRUE| for |N| equal to 0 to 5, and |FALSE| thereafter.

(The Oxford English Dictionary defines a "wayzgoose" as a holiday outing
for the staff of a publishing house.)

=
int Str::prefix_eq(text_stream *S1, text_stream *S2, int N) {
	int L1 = Str::len(S1), L2 = Str::len(S2);
	if ((N > L1) || (N > L2)) return FALSE;
	for (int i=0; i<N; i++)
		if (Str::get_at(S1, i) != Str::get_at(S2, i))
			return FALSE;
	return TRUE;
}

int Str::suffix_eq(text_stream *S1, text_stream *S2, int N) {
	int L1 = Str::len(S1), L2 = Str::len(S2);
	if ((N > L1) || (N > L2)) return FALSE;
	for (int i=1; i<=N; i++)
		if (Str::get_at(S1, L1-i) != Str::get_at(S2, L2-i))
			return FALSE;
	return TRUE;
}

int Str::begins_with(text_stream *S1, text_stream *S2) {
	return Str::prefix_eq(S1, S2, Str::len(S2));
}

int Str::ends_with(text_stream *S1, text_stream *S2) {
	return Str::suffix_eq(S1, S2, Str::len(S2));
}

@ And the obvious analogues:

=
int Str::prefix_eq_insensitive(text_stream *S1, text_stream *S2, int N) {
	int L1 = Str::len(S1), L2 = Str::len(S2);
	if ((N > L1) || (N > L2)) return FALSE;
	for (int i=0; i<N; i++)
		if (tolower((int) Str::get_at(S1, i)) != tolower((int) (Str::get_at(S2, i))))
			return FALSE;
	return TRUE;
}

int Str::suffix_eq_insensitive(text_stream *S1, text_stream *S2, int N) {
	int L1 = Str::len(S1), L2 = Str::len(S2);
	if ((N > L1) || (N > L2)) return FALSE;
	for (int i=1; i<=N; i++)
		if (tolower((int) Str::get_at(S1, L1-i)) != tolower((int) Str::get_at(S2, L2-i)))
			return FALSE;
	return TRUE;
}

int Str::begins_with_insensitive(text_stream *S1, text_stream *S2) {
	return Str::prefix_eq_insensitive(S1, S2, Str::len(S2));
}

int Str::ends_with_insensitive(text_stream *S1, text_stream *S2) {
	return Str::suffix_eq_insensitive(S1, S2, Str::len(S2));
}

@ An occasional convenience:

=
int Str::begins_with_wide_string(text_stream *S, inchar32_t *prefix) {
	if ((prefix == NULL) || (*prefix == 0)) return TRUE;
	if (S == NULL) return FALSE;
	for (int i = 0; prefix[i]; i++)
		if (Str::get_at(S, i) != prefix[i])
			return FALSE;
	return TRUE;
}

int Str::ends_with_wide_string(text_stream *S, inchar32_t *suffix) {
	if ((suffix == NULL) || (*suffix == 0)) return TRUE;
	if (S == NULL) return FALSE;
	for (int i = 0, at = Str::len(S) - Wide::len(suffix); suffix[i]; i++)
		if (Str::get_at(S, at+i) != suffix[i])
			return FALSE;
	return TRUE;
}

@ =
int Str::eq_wide_string(text_stream *S1, inchar32_t *S2) {
	if (S2 == NULL) return (Str::len(S1) == 0)?TRUE:FALSE;
	if (Str::len(S1) == Wide::len(S2)) {
		int i=0;
		LOOP_THROUGH_TEXT(P, S1)
			if (Str::get(P) != S2[i++])
				return FALSE;
		return TRUE;
	}
	return FALSE;
}
int Str::eq_narrow_string(text_stream *S1, char *S2) {
	if (S2 == NULL) return (Str::len(S1) == 0)?TRUE:FALSE;
	if (Str::len(S1) == (int) strlen(S2)) {
		int i=0;
		LOOP_THROUGH_TEXT(P, S1)
			if (Str::get(P) != (inchar32_t) S2[i++])
				return FALSE;
		return TRUE;
	}
	return FALSE;
}
int Str::ne_wide_string(text_stream *S1, inchar32_t *S2) {
	return (Str::eq_wide_string(S1, S2)?FALSE:TRUE);
}

@h White space.

=
int Str::is_whitespace(text_stream *S) {
	LOOP_THROUGH_TEXT(pos, S)
		if (Characters::is_space_or_tab(Str::get(pos)) == FALSE)
			return FALSE;
	return TRUE;
}

@ This removes spaces and tabs from both ends:

=
void Str::trim_white_space(text_stream *S) {
	int len = Str::len(S), i = 0, j = 0;
	string_position F = Str::start(S);
	LOOP_THROUGH_TEXT(P, S) {
		if (!(Characters::is_space_or_tab(Str::get(P)))) { F = P; break; }
		i++;
	}
	LOOP_BACKWARDS_THROUGH_TEXT(Q, S) {
		if (!(Characters::is_space_or_tab(Str::get(Q)))) break;
		j++;
	}
	if (i+j > Str::len(S)) Str::truncate(S, 0);
	else {
		len = len - j;
		Str::truncate(S, len);
		if (i > 0) {
			string_position P = Str::start(S);
			inchar32_t c = 0;
			do {
				c = Str::get(F);
				Str::put(P, c);
				P = Str::forward(P); F = Str::forward(F);
			} while (c != 0);
			len = len - i;
			Str::truncate(S, len);
		}
	}
}

int Str::trim_white_space_at_end(text_stream *S) {
	int shortened = FALSE;
	for (int j = Str::len(S)-1; j >= 0; j--) {
		if (Characters::is_space_or_tab(Str::get_at(S, j))) {
			Str::truncate(S, j);
			shortened = TRUE;
		} else break;
	}
	return shortened;
}

int Str::trim_all_white_space_at_end(text_stream *S) {
	int shortened = FALSE;
	for (int j = Str::len(S)-1; j >= 0; j--) {
		if (Characters::is_babel_whitespace(Str::get_at(S, j))) {
			Str::truncate(S, j);
			shortened = TRUE;
		} else break;
	}
	return shortened;
}

@h Deleting characters.

=
void Str::delete_first_character(text_stream *S) {
	Str::delete_nth_character(S, 0);
}

void Str::delete_last_character(text_stream *S) {
	if (Str::len(S) > 0)
		Str::truncate(S, Str::len(S) - 1);
}

void Str::delete_nth_character(text_stream *S, int n) {
	for (string_position P = Str::at(S, n); P.index < Str::len(P.S); P = Str::forward(P))
		Str::put(P, Str::get(Str::forward(P)));
}

void Str::delete_n_characters(text_stream *S, int n) {
	int L = Str::len(S) - n;
	if (L <= 0) Str::clear(S);
	else {
		for (int i=0; i<L; i++)
			Str::put(Str::at(S, i), Str::get(Str::at(S, i+n)));
		Str::truncate(S, L);
	}
}

@h Substrings.

=
void Str::substr(OUTPUT_STREAM, string_position from, string_position to) {
	if (from.S != to.S) internal_error("substr on two different strings");
	for (int i = from.index; i < to.index; i++)
		PUT(Str::get_at(from.S, i));
}

int Str::includes_character(text_stream *S, inchar32_t c) {
	if (S)
		LOOP_THROUGH_TEXT(pos, S)
			if (Str::get(pos) == c)
				return TRUE;
	return FALSE;
}

int Str::includes_wide_string_at(text_stream *S, inchar32_t *prefix, int j) {
	if ((prefix == NULL) || (*prefix == 0)) return TRUE;
	if (S == NULL) return FALSE;
	for (int i = 0; prefix[i]; i++)
		if (Str::get_at(S, i+j) != prefix[i])
			return FALSE;
	return TRUE;
}

int Str::includes_wide_string_at_insensitive(text_stream *S, inchar32_t *prefix, int j) {
	if ((prefix == NULL) || (*prefix == 0)) return TRUE;
	if (S == NULL) return FALSE;
	for (int i = 0; prefix[i]; i++)
		if (Characters::tolower(Str::get_at(S, i+j)) != Characters::tolower(prefix[i]))
			return FALSE;
	return TRUE;
}

int Str::includes(text_stream *S, text_stream *T) {
	int LS = Str::len(S);
	int LT = Str::len(T);
	for (int i=0; i<=LS-LT; i++) {
		int failed = FALSE;
		for (int j=0; j<LT; j++)
			if (Str::get_at(S, i+j) != Str::get_at(T, j)) {
				failed = TRUE;
				break;
			}
		if (failed == FALSE) return TRUE;
	}
	return FALSE;
}

int Str::includes_insensitive(text_stream *S, text_stream *T) {
	int LS = Str::len(S);
	int LT = Str::len(T);
	for (int i=0; i<=LS-LT; i++) {
		int failed = FALSE;
		for (int j=0; j<LT; j++)
			if (Characters::tolower(Str::get_at(S, i+j)) !=
				Characters::tolower(Str::get_at(T, j))) {
				failed = TRUE;
				break;
			}
		if (failed == FALSE) return TRUE;
	}
	return FALSE;
}

int Str::includes_at(text_stream *line, int i, text_stream *pattern) {
	if (Str::len(pattern) == 0) return FALSE;
	if (i < 0) return FALSE;
	if (i + Str::len(pattern) > Str::len(line)) return FALSE;
	LOOP_THROUGH_TEXT(pos, pattern)
		if (Str::get(pos) != Str::get_at(line, i++))
			return FALSE;
	return TRUE;
}

@h Shim for literal storage.
This is where all of those I-literals created in tangling are stored at run-time.
Note that every instance of, say, |I"fish"| would return the same string,
that is, the same |text_stream *| value. To prevent nasty accidents, this
is marked so that the stream value, "fish", cannot be modified at run-time.

The dictionary look-up here would not be thread-safe, so it's protected by
a mutex. There's no real performance concern because the following routine
is run just once per I-literal in the source code, when the program starts up.

=
dictionary *string_literals_dictionary = NULL;

text_stream *Str::literal(inchar32_t *wide_C_string) {
	text_stream *answer = NULL;
	CREATE_MUTEX(mutex);
	LOCK_MUTEX(mutex);
	@<Look in dictionary of string literals@>;
	UNLOCK_MUTEX(mutex);
	return answer;
}

@<Look in dictionary of string literals@> =
	if (string_literals_dictionary == NULL)
		string_literals_dictionary = Dictionaries::new(100, TRUE);
	answer = Dictionaries::get_text_literal(string_literals_dictionary, wide_C_string);
	if (answer == NULL) {
		Dictionaries::create_literal(string_literals_dictionary, wide_C_string);
		answer = Dictionaries::get_text_literal(string_literals_dictionary, wide_C_string);
		WRITE_TO(answer, "%w", wide_C_string);
		Streams::mark_as_read_only(answer);
	}
