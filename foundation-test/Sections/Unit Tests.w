[Unit::] Unit Tests.

A selection of tests for, or demonstrations of, foundation features.

@h Strings.

=
void Unit::test_strings(void) {
	text_stream *S = Str::new_from_wide_string(L"Jack and Jill");
	PRINT("Setup: %S\n", S);

	text_stream *T = Str::new_from_wide_string(L" had a great fall");
	PRINT("Plus: %S\n", T);
	Str::concatenate(S, T);
	PRINT("Concatenation: %S\n", S);

	text_stream *BB = Str::new_from_wide_string(L"   banana bread  is fun   ");
	PRINT("Setup statically: <%S>\n", BB);
	Str::trim_white_space(BB);
	PRINT("Trimmed: <%S>\n", BB);

	Str::copy(BB, S);
	PRINT("Copied: <%S>\n", BB);

	PRINT("Length: %d\n", Str::len(BB));

	Str::put(Str::at(BB, 3), L'Q');
	PRINT("Modified: <%S>\n", BB);

	text_stream *A = Str::new_from_wide_string(L"fish");
	text_stream *B = Str::new_from_wide_string(L"Fish");

	PRINT("%S eq %S? %d\n", A, B, Str::eq(A, B));
	PRINT("%S ci-eq %S? %d\n", A, B, Str::eq_insensitive(A, B));
	PRINT("%S ne %S? %d\n", A, B, Str::ne(A, B));
	PRINT("%S ci-ne %S? %d\n", A, B, Str::ne_insensitive(A, B));
}

@h Literals.

=
void Unit::test_literals(void) {
	LOG("This is \"tricky"); LOG("%S", I"bananas");
	int z = '"'; LOG("%S%d", I"peaches", z);
	text_stream *A = I"Jackdaws love my big sphinx of quartz";
	PRINT("So A is <%S>\n", A);
	text_stream *B = I"Jackdaws love my big sphinx of quartz";
	PRINT("So B is <%S>\n", B);
	text_stream *C = I"Jinxed wizards pluck ivy from my quilt";
	PRINT("So C is <%S>\n", C);
	if (A != B) PRINT("FAIL: A != B\n");
	else PRINT("and A == B as pointers, too\n");
}

@h Dictionaries.

=
void Unit::test_dictionaries(text_stream *arg) {
	dictionary *D = Dictionaries::new(2, TRUE);
	Dictionaries::log(STDOUT, D);
	filename *F = Filenames::from_text(arg);
	TextFiles::read(F, FALSE, "unable to read file of test cases", TRUE,
		&Unit::test_dictionaries_helper1, NULL, D);
	Dictionaries::log(STDOUT, D);
	TextFiles::read(F, FALSE, "unable to reread file of test cases", TRUE,
		&Unit::test_dictionaries_helper2, NULL, D);
	Dictionaries::log(STDOUT, D);
}

void Unit::test_dictionaries_helper1(text_stream *text, text_file_position *tfp, void *vD) {
	dictionary *D = (dictionary *) vD;
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, text, L" *")) return;
	if (Regexp::match(&mr, text, L"%'(%c*?)%' %'(%c*)%'")) {
		if (Dictionaries::find(D, mr.exp[0]) == NULL) {
			PRINT("Creating new entry <%S>\n", mr.exp[0]);
			Dictionaries::create_text(D, mr.exp[0]);
			if (Dictionaries::find(D, mr.exp[0]) == NULL) PRINT("Didn't create\n");
		}
		Str::copy(Dictionaries::get_text(D, mr.exp[0]), mr.exp[1]);
		if (!Str::eq(mr.exp[1], Dictionaries::get_text(D, mr.exp[0])))
			PRINT("FAIL: can't read back entry once written\n");
		Regexp::dispose_of(&mr);
		return;
	}
	Errors::in_text_file("test case won't parse", tfp);
}

void Unit::test_dictionaries_helper2(text_stream *text, text_file_position *tfp, void *vD) {
	dictionary *D = (dictionary *) vD;
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, text, L" *")) return;
	if (Regexp::match(&mr, text, L"%'(%c*?)%' %'(%c*)%'")) {
		if (Dictionaries::find(D, mr.exp[0]) == NULL) {
			PRINT("Missing %S\n", mr.exp[0]);
		} else {
			Dictionaries::destroy(D, mr.exp[0]);
			if (Dictionaries::find(D, mr.exp[0])) PRINT("Didn't destroy\n");
		}
		Regexp::dispose_of(&mr);
		return;
	}
	Errors::in_text_file("test case won't parse", tfp);
}

@h Regexp.

=
void Unit::test_regexp(text_stream *arg) {
	filename *F = Filenames::from_text(arg);
	TextFiles::read(F, FALSE, "unable to read file of test cases", TRUE,
		&Unit::test_regexp_helper, NULL, NULL);
}

void Unit::test_regexp_helper(text_stream *text, text_file_position *tfp, void *state) {
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, text, L" *")) return;
	if (Regexp::match(&mr, text, L"%'(%c*?)%' %'(%c*)%'")) {
		wchar_t pattern[1024];
		Str::copy_to_wide_string(pattern, mr.exp[1], 1024);
		match_results mr2 = Regexp::create_mr();
		PRINT("Text <%S> pattern <%w>: ", mr.exp[0], pattern);
		if (Regexp::match(&mr2, mr.exp[0], pattern)) {
			PRINT("Match");
			for (int i=0; i<mr2.no_matched_texts; i++)
				PRINT(" %d=<%S>", i, mr2.exp[i]);
			PRINT("\n");
			Regexp::dispose_of(&mr2);
		} else {
			PRINT("No match\n");
		}
		Regexp::dispose_of(&mr);
		return;
	}
	Errors::in_text_file("test case won't parse", tfp);
}

@h Replacements.

=
void Unit::test_replacement(text_stream *arg) {
	filename *F = Filenames::from_text(arg);
	TextFiles::read(F, FALSE, "unable to read file of test cases", TRUE,
		&Unit::test_replacement_helper, NULL, NULL);
}

void Unit::test_replacement_helper(text_stream *text, text_file_position *tfp, void *state) {
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, text, L" *")) return;
	if (Regexp::match(&mr, text, L"%'(%c*?)%' %'(%c*?)%' %'(%c*)%'")) {
		wchar_t pattern[1024];
		wchar_t replacement[1024];
		Str::copy_to_wide_string(pattern, mr.exp[1], 1024);
		Str::copy_to_wide_string(replacement, mr.exp[2], 1024);
		PRINT("Text <%S> pattern <%w> replacement <%w>: ", mr.exp[0], pattern, replacement);
		int rc = Regexp::replace(mr.exp[0], pattern, replacement, REP_REPEATING);
		PRINT("%S (%d replacement%s)\n", mr.exp[0], rc, (rc == 1)?"":"s");
		Regexp::dispose_of(&mr);
		return;
	}
	Errors::in_text_file("test case won't parse", tfp);
}

@h Linked lists.

=
void Unit::test_linked_lists(void) {
	linked_list *test_list = NEW_LINKED_LIST(text_stream);
	PRINT("List (which should be empty) contains:\n");
	text_stream *text;
	LOOP_OVER_LINKED_LIST(text, text_stream, test_list) {
		PRINT("%S\n", text);
	}
	for (int i = 1; i<17; i++) {
		TEMPORARY_TEXT(T)
		WRITE_TO(T, "S%d", i);
		ADD_TO_LINKED_LIST(Str::duplicate(T), text_stream, test_list);
		DISCARD_TEXT(T)
	}
	PRINT("List contains:\n");
	LOOP_OVER_LINKED_LIST(text, text_stream, test_list) {
		PRINT("%S\n", text);
	}
	PRINT("And has length %d\n", LinkedLists::len(test_list));
	PRINT("First is: %S\n", FIRST_IN_LINKED_LIST(text_stream, test_list));
	PRINT("Last is: %S\n", LAST_IN_LINKED_LIST(text_stream, test_list));
}

@h Stacks.

=
void Unit::test_stacks(void) {
	lifo_stack *test_stack = NEW_LIFO_STACK(text_stream);
	PRINT("Top of stack is: %S\n", TOP_OF_LIFO_STACK(text_stream, test_stack));
	if (LIFO_STACK_EMPTY(text_stream, test_stack)) PRINT("Stack is empty\n");
	PUSH_TO_LIFO_STACK(I"Mercury", text_stream, test_stack);
	PRINT("Top of stack is: %S\n", TOP_OF_LIFO_STACK(text_stream, test_stack));
	if (LIFO_STACK_EMPTY(text_stream, test_stack)) PRINT("Stack is empty\n");
	PUSH_TO_LIFO_STACK(I"Venus", text_stream, test_stack);
	PRINT("Top of stack is: %S\n", TOP_OF_LIFO_STACK(text_stream, test_stack));
	if (LIFO_STACK_EMPTY(text_stream, test_stack)) PRINT("Stack is empty\n");
	POP_LIFO_STACK(text_stream, test_stack);
	PRINT("Top of stack is: %S\n", TOP_OF_LIFO_STACK(text_stream, test_stack));
	if (LIFO_STACK_EMPTY(text_stream, test_stack)) PRINT("Stack is empty\n");
	PUSH_TO_LIFO_STACK(I"Earth", text_stream, test_stack);
	PRINT("Top of stack is: %S\n", TOP_OF_LIFO_STACK(text_stream, test_stack));
	if (LIFO_STACK_EMPTY(text_stream, test_stack)) PRINT("Stack is empty\n");
	POP_LIFO_STACK(text_stream, test_stack);
	PRINT("Top of stack is: %S\n", TOP_OF_LIFO_STACK(text_stream, test_stack));
	if (LIFO_STACK_EMPTY(text_stream, test_stack)) PRINT("Stack is empty\n");
	POP_LIFO_STACK(text_stream, test_stack);
	PRINT("Top of stack is: %S\n", TOP_OF_LIFO_STACK(text_stream, test_stack));
	if (LIFO_STACK_EMPTY(text_stream, test_stack)) PRINT("Stack is empty\n");
}

@h Semantic versions.

=
void Unit::test_range(OUTPUT_STREAM, text_stream *text) {
	semantic_version_number V = VersionNumbers::from_text(text);
	semver_range *R = VersionNumberRanges::compatibility_range(V);
	WRITE("Compatibility range of %v  =  ", &V);
	VersionNumberRanges::write_range(OUT, R);
	WRITE("\n");
	R = VersionNumberRanges::at_least_range(V);
	WRITE("At-least range of %v  =  ", &V);
	VersionNumberRanges::write_range(OUT, R);
	WRITE("\n");
	R = VersionNumberRanges::at_most_range(V);
	WRITE("At-most range of %v  =  ", &V);
	VersionNumberRanges::write_range(OUT, R);
	WRITE("\n");
}

void Unit::test_intersect(OUTPUT_STREAM,
	text_stream *text1, int r1, text_stream *text2, int r2) {
	semantic_version_number V1 = VersionNumbers::from_text(text1);
	semver_range *R1 = NULL;
	if (r1 == 0) R1 = VersionNumberRanges::compatibility_range(V1);
	else if (r1 > 0) R1 = VersionNumberRanges::at_least_range(V1);
	else if (r1 < 0) R1 = VersionNumberRanges::at_most_range(V1);
	semantic_version_number V2 = VersionNumbers::from_text(text2);
	semver_range *R2 = NULL;
	if (r2 == 0) R2 = VersionNumberRanges::compatibility_range(V2);
	else if (r2 > 0) R2 = VersionNumberRanges::at_least_range(V2);
	else if (r2 < 0) R2 = VersionNumberRanges::at_most_range(V2);
	VersionNumberRanges::write_range(OUT, R1);
	WRITE(" intersect ");
	VersionNumberRanges::write_range(OUT, R2);
	WRITE(" = ");
	int changed = VersionNumberRanges::intersect_range(R1, R2);
	VersionNumberRanges::write_range(OUT, R1);
	if (changed) WRITE (" -- changed");
	WRITE("\n");
}

void Unit::test_read_write(OUTPUT_STREAM, text_stream *text) {
	semantic_version_number V = VersionNumbers::from_text(text);
	WRITE("'%S'   -->   %v\n", text, &V);
}

void Unit::test_precedence(OUTPUT_STREAM, text_stream *text1, text_stream *text2) {
	semantic_version_number V1 = VersionNumbers::from_text(text1);
	semantic_version_number V2 = VersionNumbers::from_text(text2);
	int gt = VersionNumbers::gt(V1, V2);
	int eq = VersionNumbers::eq(V1, V2);
	int lt = VersionNumbers::lt(V1, V2);
	if (lt) WRITE("%v  <  %v", &V1, &V2);
	if (eq) WRITE("%v  =  %v", &V1, &V2);
	if (gt) WRITE("%v  >  %v", &V1, &V2);
	WRITE("\n");
}

void Unit::test_semver(void) {
	Unit::test_read_write(STDOUT, I"1");
	Unit::test_read_write(STDOUT, I"1.2");
	Unit::test_read_write(STDOUT, I"1.2.3");
	Unit::test_read_write(STDOUT, I"71.0.45672");
	Unit::test_read_write(STDOUT, I"1.2.3.4");
	Unit::test_read_write(STDOUT, I"9/861022");
	Unit::test_read_write(STDOUT, I"9/86102");
	Unit::test_read_write(STDOUT, I"9/8610223");
	Unit::test_read_write(STDOUT, I"9/861022.2");
	Unit::test_read_write(STDOUT, I"9/861022/2");
	Unit::test_read_write(STDOUT, I"1.2.3-alpha.0.x45.1789");
	Unit::test_read_write(STDOUT, I"1+lobster");
	Unit::test_read_write(STDOUT, I"1.2+lobster");
	Unit::test_read_write(STDOUT, I"1.2.3+lobster");
	Unit::test_read_write(STDOUT, I"1.2.3-beta.2+shellfish");
	
	PRINT("\n");
	Unit::test_precedence(STDOUT, I"3", I"5");
	Unit::test_precedence(STDOUT, I"3", I"3");
	Unit::test_precedence(STDOUT, I"3", I"3.0");
	Unit::test_precedence(STDOUT, I"3", I"3.0.0");
	Unit::test_precedence(STDOUT, I"3.1.41", I"3.1.5");
	Unit::test_precedence(STDOUT, I"3.1.41", I"3.2.5");
	Unit::test_precedence(STDOUT, I"3.1.41", I"3.1.41+arm64");
	Unit::test_precedence(STDOUT, I"3.1.41", I"3.1.41-pre.0.1");
	Unit::test_precedence(STDOUT, I"3.1.41-alpha.72", I"3.1.41-alpha.8");
	Unit::test_precedence(STDOUT, I"3.1.41-alpha.72a", I"3.1.41-alpha.8a");
	Unit::test_precedence(STDOUT, I"3.1.41-alpha.72", I"3.1.41-beta.72");
	Unit::test_precedence(STDOUT, I"3.1.41-alpha.72", I"3.1.41-alpha.72.zeta");
	Unit::test_precedence(STDOUT, I"1.2.3+lobster.54", I"1.2.3+lobster.100");
	
	PRINT("\n");
	Unit::test_range(STDOUT, I"6.4.2-kappa.17");

	PRINT("\n");
	Unit::test_intersect(STDOUT, I"6.4.2-kappa.17", 0, I"3.5.5", 0);
	Unit::test_intersect(STDOUT, I"6.4.2-kappa.17", 0, I"6.9.1", 0);
	Unit::test_intersect(STDOUT, I"6.9.1", 0, I"6.4.2-kappa.17", 0);
	Unit::test_intersect(STDOUT, I"6.4.2", 1, I"3.5.5", 1);
	Unit::test_intersect(STDOUT, I"6.4.2", 1, I"3.5.5", -1);
	Unit::test_intersect(STDOUT, I"6.4.2", -1, I"3.5.5", 1);
	Unit::test_intersect(STDOUT, I"6.4.2", -1, I"3.5.5", -1);
}

@h Trees.

@e prince_CLASS
@e princess_CLASS

=
DECLARE_CLASS(prince)
DECLARE_CLASS(princess)

@ =
typedef struct prince {
	struct text_stream *boys_name;
	CLASS_DEFINITION
} prince;

typedef struct princess {
	int meaningless;
	struct text_stream *girls_name;
	CLASS_DEFINITION
} princess;

tree_node_type *M = NULL, *F = NULL;

@ =
void Unit::test_trees(void) {
	tree_type *TT = Trees::new_type(I"royal family", &Unit::verifier);
	heterogeneous_tree *royalty = Trees::new(TT);
	M = Trees::new_node_type(I"male", prince_CLASS, &Unit::prince_verifier);
	F = Trees::new_node_type(I"female", princess_CLASS, &Unit::princess_verifier);

	prince *charles_I = CREATE(prince);
	charles_I->boys_name = I"Charles I of England";
	princess *mary = CREATE(princess);
	mary->girls_name = I"Mary, Princess Royal";
	prince *charles_II = CREATE(prince);
	charles_II->boys_name = I"Charles II of England";
	prince *james_II = CREATE(prince);
	james_II->boys_name = I"James II of England";
					
	tree_node *charles_I_n = Trees::new_node(royalty, M, STORE_POINTER_prince(charles_I));
	tree_node *charles_II_n = Trees::new_node(royalty, M, STORE_POINTER_prince(charles_II));
	tree_node *james_II_n = Trees::new_node(royalty, M, STORE_POINTER_prince(james_II));
	tree_node *mary_n = Trees::new_node(royalty, F, STORE_POINTER_princess(mary));

	Unit::show_tree(STDOUT, royalty);
	Trees::make_root(royalty, charles_I_n);
	Unit::show_tree(STDOUT, royalty);
	Trees::make_child(charles_II_n, charles_I_n);
	Unit::show_tree(STDOUT, royalty);
	Trees::make_eldest_child(mary_n, charles_I_n);
	Trees::make_child(james_II_n, charles_I_n);
	Unit::show_tree(STDOUT, royalty);
}

int Unit::verifier(tree_node *N) {
	if (N->type == M) PRINT("(Root is M)\n");
	if (N->type == F) PRINT("(Root is F)\n");
	if (N->type == M) return TRUE;
	return FALSE;
}

int Unit::prince_verifier(tree_node *N) {
	for (tree_node *C = N->child; C; C = C->next)
		if (C->type == M) PRINT("(Prince's child is M)\n");
		else PRINT("(Prince's child is F)\n");
	PRINT("(verified)\n");
	return TRUE;
}

int Unit::princess_verifier(tree_node *N) {
	for (tree_node *C = N->child; C; C = C->next)
		if (C->type == M) PRINT("(Princess's child is M)\n");
		else PRINT("(Princess's child is F)\n");
	PRINT("(verified)\n");
	return TRUE;
}

@ =
void Unit::show_tree(text_stream *OUT, heterogeneous_tree *T) {
	WRITE("%S\n", T->type->name);
	INDENT;
	Trees::traverse_from(T->root, &Unit::visit, (void *) STDOUT, 0);
	OUTDENT;
	WRITE("Done\n");
}

int Unit::visit(tree_node *N, void *state, int L) {
	text_stream *OUT = (text_stream *) state;
	for (int i=0; i<L; i++) WRITE("  ");
	if (N->type == M) {
		prince *P = RETRIEVE_POINTER_prince(N->content);
		WRITE("Male: %S\n", P->boys_name);
	} else if (N->type == F) {
		princess *P = RETRIEVE_POINTER_princess(N->content);
		WRITE("Female: %S\n", P->girls_name);
	} else WRITE("Unknown node\n");
	return TRUE;
}

@h JSON.

=
dictionary *known_JSON_reqs = NULL;

void Unit::test_JSON(text_stream *arg) {
	known_JSON_reqs = Dictionaries::new(32, FALSE);
	filename *F = Filenames::from_text(arg);
	TEMPORARY_TEXT(JSON)
	TextFiles::read(F, FALSE, "unable to read file of JSON", TRUE,
		&Unit::test_JSON_helper, NULL, JSON);
	DISCARD_TEXT(JSON)
}

void Unit::test_JSON_helper(text_stream *text, text_file_position *tfp, void *state) {
	text_stream *JSON = (text_stream *) state;
	if (Str::eq(text, I"----")) {
		match_results mr = Regexp::create_mr();
		if (Regexp::match(&mr, JSON, L" *<(%C+)> *= *(%c+)")) {
			text_stream *rname = mr.exp[0];
			text_stream *rtext = mr.exp[1];
			WRITE_TO(STDOUT, "JSON requirement <%S> set to:\n%S----\n", rname, rtext);
			JSON_requirement *req = JSON::decode_printing_errors(rtext, known_JSON_reqs, tfp);
			if (req) {
				dict_entry *de = Dictionaries::create(known_JSON_reqs, rname);
				if (de) de->value = req;
				JSON::encode_req(STDOUT, req);
			}
		} else if (Regexp::match(&mr, JSON, L" *(%c+?) against *(%c+)")) {
			text_stream *rtext = mr.exp[0];
			text_stream *material = mr.exp[1];
			WRITE_TO(STDOUT, "JSON verification test on:\n%S-- to match --\n%S\n----\n",
				material, rtext);
			JSON_requirement *req = JSON::decode_printing_errors(rtext, known_JSON_reqs, tfp);
			if (req) {
				JSON_value *value = JSON::decode(material, tfp);
				if ((value) && (value->JSON_type == ERROR_JSONTYPE))
					WRITE_TO(STDOUT, "JSON error: %S", value->if_error);
				else {
					linked_list *errs = NEW_LINKED_LIST(text_stream);
					int v = JSON::verify(value, req, errs);
					if (v) {
						WRITE_TO(STDOUT, "Verifies");
					} else {
						int c = 0;
						text_stream *err;
						LOOP_OVER_LINKED_LIST(err, text_stream, errs) {
							if (c++ > 0) WRITE_TO(STDOUT, "\n");
							WRITE_TO(STDOUT, "%S", err);
						}
					}
				}
			}
		} else {
			WRITE_TO(STDOUT, "JSON test on:\n%S----\n", JSON);
			JSON_value *value = JSON::decode(JSON, tfp);
			if ((value) && (value->JSON_type == ERROR_JSONTYPE))
				WRITE_TO(STDOUT, "JSON error: %S", value->if_error);
			else
				JSON::encode(STDOUT, value);
		}	
		Regexp::dispose_of(&mr);
		WRITE_TO(STDOUT, "\n--------\n");
		Str::clear(JSON);
	} else {
		WRITE_TO(JSON, "%S\n", text);
	}
}
