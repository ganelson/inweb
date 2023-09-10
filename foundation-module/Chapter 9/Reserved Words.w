[ReservedWords::] Reserved Words.

Managing reserved words, that is, significant identifiers, for programming
languages.

@h The identifier hash table.
We clearly need rapid access to a large symbols table, and we store this as
a hash. Identifiers are hash-coded with the following simple code, which is
simplified from one used by Inform; it's the algorithm called "X 30011"
in Aho, Sethi and Ullman, "Compilers: Principles, Techniques and Tools"
(1986), adapted slightly to separate out literal numbers.

@d HASH_TAB_SIZE 1000 /* the possible hash codes are 0 up to this minus 1 */
@d NUMBER_HASH 0 /* literal decimal integers, and no other words, have this hash code */

=
int ReservedWords::hash_code_from_word(text_stream *text) {
    unsigned int hash_code = 0;
    string_position p = Str::start(text);
    switch(Str::get(p)) {
    	case '-': if (Str::len(text) == 1) break; /* an isolated minus sign is an ordinary word */
    		/* and otherwise fall through to... */
    	case '0': case '1': case '2': case '3': case '4':
    	case '5': case '6': case '7': case '8': case '9': {
    		int numeric = TRUE;
    		/* the first character may prove to be the start of a number: is this true? */
			for (p = Str::forward(p); Str::in_range(p); p = Str::forward(p))
				if (Characters::isdigit(Str::get(p)) == FALSE) numeric = FALSE;
			if (numeric) return NUMBER_HASH;
		}
    }
    for (p=Str::start(text); Str::in_range(p); p = Str::forward(p))
       hash_code = (hash_code*30011) + Str::get(p);
    return (int) (1+(hash_code % (HASH_TAB_SIZE-1))); /* result of X 30011, plus 1 */
}

@ The actual table is stored here:

@d HASH_SAFETY_CODE 0x31415927

=
typedef struct hash_table {
	struct linked_list *analysis_hash[HASH_TAB_SIZE]; /* of |hash_table_entry| */
	int safety_code; /* when we start up, array's contents are undefined, so... */
} hash_table;

void ReservedWords::initialise_hash_table(hash_table *HT) {
	HT->safety_code = HASH_SAFETY_CODE;
	for (int i=0; i<HASH_TAB_SIZE; i++) HT->analysis_hash[i] = NULL;
}

@ Where we define:

=
typedef struct hash_table_entry {
	text_stream *hash_key;
	int language_reserved_word; /* in the language currently being woven, that is */
	struct linked_list *usages; /* of |hash_table_entry_usage| */
	struct source_line *definition_line; /* or null, if it's not a constant, function or type name */
	struct language_function *as_function; /* for function names only */
	CLASS_DEFINITION
} hash_table_entry;

@ A single routine is used both to interrogate the hash and to lodge values
in it, as usual with symbols tables. For example, the code to handle C-like
languages prepares for code analysis by calling this routine on the name
of each C function.

=
hash_table_entry *ReservedWords::find_hash_entry(hash_table *HT, text_stream *text, int create) {
	int h = ReservedWords::hash_code_from_word(text);
	if (h == NUMBER_HASH) return NULL;
	if (HT == NULL) return NULL;
	if ((h<0) || (h>=HASH_TAB_SIZE)) internal_error("hash code out of range");
	if (HT->safety_code != HASH_SAFETY_CODE) internal_error("uninitialised HT");
	if (HT->analysis_hash[h] != NULL) {
		hash_table_entry *hte = NULL;
		LOOP_OVER_LINKED_LIST(hte, hash_table_entry, HT->analysis_hash[h]) {
			if (Str::eq(hte->hash_key, text))
				return hte;
		}
	}
	if (create) {
		hash_table_entry *hte = CREATE(hash_table_entry);
		hte->language_reserved_word = 0;
		hte->hash_key = Str::duplicate(text);
		hte->usages = NEW_LINKED_LIST(hash_table_entry_usage);
		hte->definition_line = NULL;
		hte->as_function = NULL;
		if (HT->analysis_hash[h] == NULL)
			HT->analysis_hash[h] = NEW_LINKED_LIST(hash_table_entry);
		ADD_TO_LINKED_LIST(hte, hash_table_entry, HT->analysis_hash[h]);
		return hte;
	}
	return NULL;
}

@ Marking and testing these bits:

=
hash_table_entry *ReservedWords::mark_reserved_word(hash_table *HT, text_stream *p, int e) {
	hash_table_entry *hte = ReservedWords::find_hash_entry(HT, p, TRUE);
	hte->language_reserved_word |= (1 << (e % 32));
	hte->definition_line = NULL;
	hte->as_function = NULL;
	return hte;
}

int ReservedWords::is_reserved_word(hash_table *HT, text_stream *p, int e) {
	hash_table_entry *hte = ReservedWords::find_hash_entry(HT, p, FALSE);
	if ((hte) && (hte->language_reserved_word & (1 << (e % 32)))) return TRUE;
	return FALSE;
}
