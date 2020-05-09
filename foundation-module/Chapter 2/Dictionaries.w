[Dictionaries::] Dictionaries.

A simple implementation for a flexible-sized dictionary of key-value
pairs.

@h Storage.
There's nothing fancy here. A "dictionary" is a hash table allowing reasonably
efficient lookup: it's a correspondence between "keys", which are texts, and
pointers to some external structure. Often these will also be texts, but
not necessarily.

=
typedef struct dictionary {
	int textual; /* values are texts? */
	int no_entries; /* total number of key-value pairs currently stored here */
	int hash_table_size; /* size of array... */
	struct dict_entry *hash_table; /* ...of linked lists of dictionary entries */
	CLASS_DEFINITION
} dictionary;

typedef struct dict_entry {
	int vacant; /* a "vacant" entry is not currently used to store a k-v pair */
	struct text_stream *key; /* for non-vacant entries only: the key text */
	void *value; /* for non-vacant entries only: the value, some kind of pointer */
	struct dict_entry *next_in_entry;
} dict_entry;

@h Creation.
Dictionaries can have arbitrary size, in that they expand as needed, but for
efficiency's sake the caller can set them up with an initial size of her choice.

=
dictionary *Dictionaries::new(int S, int textual) {
	if (S < 2) internal_error("dictionary too small");
	dictionary *D = CREATE(dictionary);
	D->textual = textual;
	D->hash_table_size = S;
	D->no_entries = 0;
	D->hash_table = Memory::calloc(S, sizeof(dict_entry), DICTIONARY_MREASON);
	for (int i=0; i<S; i++) {
		D->hash_table[i].vacant = TRUE;
		D->hash_table[i].value = NULL;
		D->hash_table[i].next_in_entry = NULL;
	}
	return D;
}

@h Logging.

=
void Dictionaries::log(OUTPUT_STREAM, dictionary *D) {
	WRITE("Dictionary:\n", (unsigned int) D); INDENT;
	for (int i=0; i<D->hash_table_size; i++) {
		WRITE("Slot %02d:", i);
		for (dict_entry *E = &(D->hash_table[i]); E; E = E->next_in_entry)
			if (E->vacant) WRITE(" vacant");
			else if (D->textual) WRITE(" %S='%S'", E->key, E->value);
			else WRITE(" %S=%08x", E->key, (unsigned int) E->value);
		WRITE("\n");
	}
	OUTDENT;
}

@h Hashing.
The whole point of a hash table is that it crudely sorts the contents by a rough
indication of the key values. This crude indication is the hash value, calculated
here. If there are |N| slots in the dictionary table, this tells us which slot
(from 0 to |N-1|) a given key value belongs in.

=
int Dictionaries::hash(text_stream *K, int N) {
	unsigned int hash = 0;
	LOOP_THROUGH_TEXT(P, K)
		hash = 16339*hash + ((unsigned int) Str::get(P));
	return (int) (hash % ((unsigned int) N));
}

@h Create, find, destroy.
These three fundamental operations locate the dictionary entry structure for
a given key value, and then do something to/with it. Note that these pointers
remain valid only until somebody writes a new value into the dictionary;
so be careful if thread safety's an issue.

=
dict_entry *Dictionaries::find(dictionary *D, text_stream *K) {
	return Dictionaries::find_p(D, K, 0);
}
dict_entry *Dictionaries::create(dictionary *D, text_stream *K) {
	return Dictionaries::find_p(D, K, 1);
}
void Dictionaries::destroy(dictionary *D, text_stream *K) {
	Dictionaries::find_p(D, K, -1);
}

@ A nuisance we have to live with is that we often want to express the key
as wide text (so that we can use literals like |L"my-key"|) instead of text
streams. So we also offer versions suffixed |_literal|:

=
dict_entry *Dictionaries::find_literal(dictionary *D, wchar_t *lit) {
	TEMPORARY_TEXT(K);
	WRITE_TO(K, "%w", lit);
	dict_entry *E = Dictionaries::find(D, K);
	DISCARD_TEXT(K);
	return E;
}
dict_entry *Dictionaries::create_literal(dictionary *D, wchar_t *lit) {
	TEMPORARY_TEXT(K);
	WRITE_TO(K, "%w", lit);
	dict_entry *E = Dictionaries::create(D, K);
	DISCARD_TEXT(K);
	return E;
}
void Dictionaries::destroy_literal(dictionary *D, wchar_t *lit) {
	TEMPORARY_TEXT(K);
	WRITE_TO(K, "%w", lit);
	Dictionaries::destroy(D, K);
	DISCARD_TEXT(K);
}

@ So, then, find an entry (if |change| is |0|), create it (if |+1|) or delete
it (if |-1|).

=
dict_entry *Dictionaries::find_p(dictionary *D, text_stream *K, int change) {
	if (D == NULL) @<Handle the null dictionary@>;
	if (change == 1) @<Expand the dictionary if necessary@>;
	@<Work within the existing dictionary@>;
}

@ It's legal to perform a find on the null dictionary: the answer's always "no".

@<Handle the null dictionary@> =
	if (change == 0) return NULL;
	internal_error("tried to create or destroy in a null dictionary");

@ For speed, our policy is that the hash table should have roughly the
same number of slots as there are entries in the dictionary; that way, each
slot will have an average of one or fewer entries. When we exceed this
ideal population, we double the dictionary's capacity.

@<Expand the dictionary if necessary@> =
	if (D->no_entries > D->hash_table_size) {
		dictionary *D2 = Dictionaries::new(2*D->hash_table_size, D->textual);
		for (int i=0; i<D->hash_table_size; i++)
			for (dict_entry *E = &(D->hash_table[i]); E; E = E->next_in_entry)
				if (E->vacant == FALSE) {
					dict_entry *E2 = Dictionaries::find_p(D2, E->key, 1);
					E2->value = E->value;
				}
		Memory::I7_free(D->hash_table, DICTIONARY_MREASON,
			D->hash_table_size*((int) sizeof(dict_entry)));
		D->hash_table_size = D2->hash_table_size;
		D->hash_table = D2->hash_table;
	}

@<Work within the existing dictionary@> =
	dict_entry *last_E = NULL;
	for (dict_entry *E = &(D->hash_table[Dictionaries::hash(K, D->hash_table_size)]);
		E; E = E->next_in_entry) {
		last_E = E;
		if (E->vacant) {
			if (change == 1) { @<Make E the new entry@>; return E; }
		} else {
			if (Str::eq(K, E->key)) {
				if (change == -1) @<Destroy the E entry@>;
				return E;
			}
		}
	}
	if (change == 1) {
		dict_entry *E = CREATE(dict_entry);
		@<Make E the new entry@>;
		last_E->next_in_entry = E;
		return E;
	}
	return NULL;

@ When creating text values, we want them to be empty strings rather than null
strings, so that printing to them will work.

@<Make E the new entry@> =
	E->vacant = FALSE;
	if (D->textual) E->value = Str::new(); else E->value = NULL;
	E->key = Str::duplicate(K);
	D->no_entries++;

@ When deleting text values, we close them first, to give back the memory.
Careful: it would not be thread-safe to allow different threads to use the
same dictionary if deletions are a possibility.

@<Destroy the E entry@> =
	E->vacant = TRUE; D->no_entries--;
	if ((D->textual) && (E->value)) Str::dispose_of(E->value);
	E->value = NULL;

@h Accessing entries.
Eventually we're going to want the value. In principle we could be storing
values which are arbitrary pointers, so we have to use void pointers:

=
void *Dictionaries::read_value(dictionary *D, text_stream *key) {
	if (D == NULL) return NULL;
	if (D->textual) internal_error("textual dictionary accessed as pointy");
	dict_entry *E = Dictionaries::find(D, key);
	if (E == NULL) internal_error("read null dictionary entry");
	if (E->vacant) internal_error("read vacant dictionary entry");
	return E->value;
}
void *Dictionaries::read_value_literal(dictionary *D, wchar_t *key) {
	if (D == NULL) return NULL;
	if (D->textual) internal_error("textual dictionary accessed as pointy");
	dict_entry *E = Dictionaries::find_literal(D, key);
	if (E == NULL) internal_error("read null dictionary entry");
	if (E->vacant) internal_error("read vacant dictionary entry");
	return E->value;
}

void Dictionaries::write_value(dictionary *D, text_stream *key, void *val) {
	if (D == NULL) internal_error("wrote to null dictionary");
	if (D->textual) internal_error("textual dictionary accessed as pointy");
	dict_entry *E = Dictionaries::find(D, key);
	if (E == NULL) internal_error("wrote null dictionary entry");
	if (E->vacant) internal_error("wrote vacant dictionary entry");
	E->value = val;
}
void Dictionaries::write_value_literal(dictionary *D, wchar_t *key, void *val) {
	if (D == NULL) internal_error("wrote to null dictionary");
	if (D->textual) internal_error("textual dictionary accessed as pointy");
	dict_entry *E = Dictionaries::find_literal(D, key);
	if (E == NULL) internal_error("wrote null dictionary entry");
	if (E->vacant) internal_error("wrote vacant dictionary entry");
	E->value = val;
}

@ But the commonest use case is that the dictionary stores texts as values,
so we provide convenient wrappers with the correct C types.

=
text_stream *Dictionaries::create_text(dictionary *D, text_stream *key) {
	if (D == NULL) internal_error("wrote to null dictionary");
	if (D->textual == FALSE) internal_error("pointy dictionary accessed as textual");
	dict_entry *E = Dictionaries::create(D, key);
	return (text_stream *) E->value;
}
text_stream *Dictionaries::create_text_literal(dictionary *D, wchar_t *lit) {
	if (D == NULL) internal_error("wrote to null dictionary");
	if (D->textual == FALSE) internal_error("pointy dictionary accessed as textual");
	dict_entry *E = Dictionaries::create_literal(D, lit);
	return (text_stream *) E->value;
}

@ We only need a read operation, because the caller can write to the dictionary
entry by reading the text pointer and then using |WRITE_TO|.

=
text_stream *Dictionaries::get_text(dictionary *D, text_stream *key) {
	if (D == NULL) return NULL;
	if (D->textual == FALSE) internal_error("pointy dictionary accessed as textual");
	dict_entry *E = Dictionaries::find(D, key);
	if (E == NULL) return NULL;
	return (text_stream *) E->value;
}

text_stream *Dictionaries::get_text_literal(dictionary *D, wchar_t *lit) {
	if (D == NULL) return NULL;
	if (D->textual == FALSE) internal_error("pointy dictionary accessed as textual");
	dict_entry *E = Dictionaries::find_literal(D, lit);
	if (E == NULL) return NULL;
	return (text_stream *) E->value;
}

@h Disposal.
If a dictionary was only needed temporarily then we should dispose of it
and free the memory when done:

=
void Dictionaries::dispose_of(dictionary *D) {
	if (D->textual)
		for (int i=0; i<D->hash_table_size; i++)
			for (dict_entry *E = &(D->hash_table[i]); E; E = E->next_in_entry)
				if (E->vacant == FALSE)
					Str::dispose_of(E->value);
	Memory::I7_free(D->hash_table, DICTIONARY_MREASON, D->hash_table_size*((int) sizeof(dict_entry)));
	D->hash_table = NULL;
}
