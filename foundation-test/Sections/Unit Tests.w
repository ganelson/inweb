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
		TEMPORARY_TEXT(T);
		WRITE_TO(T, "S%d", i);
		ADD_TO_LINKED_LIST(Str::duplicate(T), text_stream, test_list);
		DISCARD_TEXT(T);
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
