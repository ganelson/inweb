[TextWeaver::] The Weaver of Text.

To write rendering instructions for commentary or source code text.

@h Commentary text.
This section deals with commentary which is not written in Markdown format,
but in Inweb's older format.

The following takes text, divides it up at stroke-mark boundaries --
that is, |this is inside|, this is outside -- and sends contiguous pieces
of it either to |TextWeaver::inline_code_fragment| or |TextWeaver::commentary_fragment|
as appropriate.

=
void TextWeaver::commentary_text(heterogeneous_tree *tree, tree_node *ap, text_stream *matter) {
	TextWeaver::commentary_r(tree, ap, matter, FALSE, FALSE);
}
void TextWeaver::comment_text_in_code(heterogeneous_tree *tree, tree_node *ap, text_stream *matter) {
	TextWeaver::commentary_r(tree, ap, matter, FALSE, TRUE);
}

void TextWeaver::commentary_r(heterogeneous_tree *tree, tree_node *ap, text_stream *matter,
	int within, int in_code) {
	weave_document_node *C = RETRIEVE_POINTER_weave_document_node(tree->root->content);
	weave_order *wv = C->wv;
	text_stream *code_in_comments_notation =
		Bibliographic::get_datum(wv->weave_web,
		(in_code)?(I"Code In Code Comments Notation"):(I"Code In Commentary Notation"));
	if (Str::ne(code_in_comments_notation, I"Off")) @<Split text and code extracts@>;

	int display_flag = TRUE;
	text_stream *tex_notation = Bibliographic::get_datum(wv->weave_web,
		I"TeX Mathematics Displayed Notation");
	if (Str::ne(tex_notation, I"Off")) @<Recognise mathematics@>;
	display_flag = FALSE;
	tex_notation = Bibliographic::get_datum(wv->weave_web,
		I"TeX Mathematics Notation");
	if (Str::ne(tex_notation, I"Off")) @<Recognise mathematics@>;

	text_stream *xref_notation = Bibliographic::get_datum(wv->weave_web,
		I"Cross-References Notation");
	if (Str::ne(xref_notation, I"Off")) @<Recognise cross-references@>;

	if (within) {
		TextWeaver::inline_code_fragment(tree, ap, matter);
	} else {
		@<Recognise hyperlinks@>;
		@<Detect use of footnotes@>;
		TextWeaver::commentary_fragment(tree, ap, matter, in_code);
	}
}

@<Split text and code extracts@> =
	for (int i=0; i < Str::len(matter); i++) {
		if (Str::get_at(matter, i) == '\\') i += Str::len(code_in_comments_notation) - 1;
		else if (Str::includes_at(matter, i, code_in_comments_notation)) {
			TEMPORARY_TEXT(before)
			Str::copy(before, matter); Str::truncate(before, i);
			TEMPORARY_TEXT(after)
			Str::substr(after, Str::at(matter,
				i + Str::len(code_in_comments_notation)), Str::end(matter));
			TextWeaver::commentary_r(tree, ap, before, within, in_code);
			TextWeaver::commentary_r(tree, ap, after, (within)?FALSE:TRUE, in_code);
			DISCARD_TEXT(before)
			DISCARD_TEXT(after)
			return;
		}
	}

@<Recognise hyperlinks@> =
	for (int i=0; i < Str::len(matter); i++) {
		if ((Str::includes_at(matter, i, I"http://")) ||
				(Str::includes_at(matter, i, I"https://"))) {
			TEMPORARY_TEXT(before)
			Str::copy(before, matter); Str::truncate(before, i);
			TEMPORARY_TEXT(after)
			Str::substr(after, Str::at(matter, i), Str::end(matter));
			match_results mr = Regexp::create_mr();
			if (Regexp::match(&mr, after, U"(https*://%C+)(%c*)")) {
				while (TextWeaver::boundary_character(FALSE, Str::get_last_char(mr.exp[0]))) {
					inchar32_t c = Str::get_last_char(mr.exp[0]);
					Str::delete_last_character(mr.exp[0]);
					TEMPORARY_TEXT(longer)
					WRITE_TO(longer, "%c%S", c, mr.exp[1]);
					Str::clear(mr.exp[1]);
					Str::copy(mr.exp[1], longer);
					DISCARD_TEXT(longer)
				}
				TextWeaver::commentary_r(tree, ap, before, within, in_code);
				Trees::make_child(WeaveTree::url(tree, mr.exp[0], mr.exp[0], TRUE), ap);
				TextWeaver::commentary_r(tree, ap, mr.exp[1], within, in_code);
				Regexp::dispose_of(&mr);
				return;
			}
			Regexp::dispose_of(&mr);
			DISCARD_TEXT(before)
			DISCARD_TEXT(after)
		}
	}

@<Recognise mathematics@> =
	int N = Str::len(tex_notation);
	for (int i=0; i < Str::len(matter); i++) {
		if ((within == FALSE) && (Str::includes_at(matter, i, tex_notation))) {
			int j = i + N;
			while (j < Str::len(matter)) {
				if (Str::includes_at(matter, j, tex_notation)) {
					int allow = FALSE;
					TEMPORARY_TEXT(before)
					TEMPORARY_TEXT(maths)
					TEMPORARY_TEXT(after)
					Str::substr(before, Str::start(matter), Str::at(matter, i));
					Str::substr(maths, Str::at(matter, i + N), Str::at(matter, j));
					Str::substr(after, Str::at(matter, j + N), Str::end(matter));
					TextWeaver::commentary_r(tree, ap, before, within, in_code);
					Trees::make_child(WeaveTree::mathematics(tree, maths, display_flag), ap);
					TextWeaver::commentary_r(tree, ap, after, within, in_code);
					allow = TRUE;					
					DISCARD_TEXT(before)
					DISCARD_TEXT(maths)
					DISCARD_TEXT(after)
					if (allow) return;
				}
				j++;
			}
		}
	}

@<Detect use of footnotes@> =
	TEMPORARY_TEXT(before)
	TEMPORARY_TEXT(cue)
	TEMPORARY_TEXT(after)
	int allow = FALSE;
	if (LiterateSource::detect_footnote(wv->weave_web->web_syntax,
			matter, before, cue, after)) {
		ls_footnote *F = LiterateSource::find_footnote_in_para(
			LiterateSource::par_of_line(wv->current_weave_line), cue);
		if (F) {
			F->cued_already = TRUE;
			allow = TRUE;
			TextWeaver::commentary_r(tree, ap, before, within, in_code);
			Trees::make_child(WeaveTree::footnote_cue(tree, F->cue_text), ap);
			TextWeaver::commentary_r(tree, ap, after, within, in_code);
		} else {
			WebErrors::issue_at(I"this is a cue for a missing note", wv->current_weave_line);
		}
	}
	DISCARD_TEXT(before)
	DISCARD_TEXT(cue)
	DISCARD_TEXT(after)
	if (allow) return;

@<Recognise cross-references@> =
	int N = Str::len(xref_notation);
	for (int i=0; i < Str::len(matter); i++) {
		if ((within == FALSE) && (Str::includes_at(matter, i, xref_notation)) &&
			((i == 0) || (TextWeaver::boundary_character(TRUE,
				Str::get_at(matter, i-1))))) {
			int j = i + N+1;
			while (j < Str::len(matter)) {
				if ((Str::includes_at(matter, j, xref_notation)) && 
					(TextWeaver::boundary_character(FALSE,
						Str::get_at(matter, j+Str::len(xref_notation))))) {
					int allow = FALSE;
					TEMPORARY_TEXT(before)
					TEMPORARY_TEXT(reference)
					TEMPORARY_TEXT(after)
					Str::substr(before, Str::start(matter), Str::at(matter, i));
					Str::substr(reference, Str::at(matter, i + N), Str::at(matter, j));
					Str::substr(after, Str::at(matter, j + N), Str::end(matter));
					@<Attempt to resolve the cross-reference@>;
					DISCARD_TEXT(before)
					DISCARD_TEXT(reference)
					DISCARD_TEXT(after)
					if (allow) return;
				}
				j++;
			}
		}
	}

@<Attempt to resolve the cross-reference@> =
	TEMPORARY_TEXT(url)
	TEMPORARY_TEXT(title)
	int ext = FALSE;
	if (Colonies::resolve_reference_in_weave(wv->weave_colony,
		url, title, wv->weave_to, reference,
		wv->weave_web, wv->current_weave_line, &ext)) {
		TextWeaver::commentary_r(tree, ap, before, within, in_code);
		Trees::make_child(WeaveTree::url(tree, url, title, ext), ap);
		TextWeaver::commentary_r(tree, ap, after, within, in_code);
		allow = TRUE;
	}
	DISCARD_TEXT(url)
	DISCARD_TEXT(title)

@ This tests whether a cross-reference is allowed to begin or end: it must
begin after and finish before a "boundary character".

Note the one-sided treatment of |:|, which is a boundary after but not before,
so that |http://| won't trigger a cross-reference with the standard |//|
xref notation.

=
int TextWeaver::boundary_character(int before, inchar32_t c) {
	if (c == 0) return TRUE;
	if (Characters::is_whitespace(c)) return TRUE;
	if ((c == '.') || (c == ',') || (c == '!') || (c == '?') || (c == ';') ||
		(c == '(')|| (c == ')')) return TRUE;
	if ((before == FALSE) && (c == ':')) return TRUE;
	return FALSE;
}

@ =
void TextWeaver::commentary_fragment(heterogeneous_tree *tree, tree_node *ap,
	text_stream *fragment, int in_code) {
	if (Str::len(fragment) > 0)
		Trees::make_child(WeaveTree::commentary(tree, fragment, in_code), ap);
}

void TextWeaver::inline_code_fragment(heterogeneous_tree *tree, tree_node *ap, text_stream *fragment) {
	tree_node *I = WeaveTree::inline(tree);
	Trees::make_child(I, ap);
	TEMPORARY_TEXT(colouring)
	for (int i=0; i< Str::len(fragment); i++) PUT_TO(colouring, EXTRACT_COLOUR);
	tree_node *SC = WeaveTree::source_code(tree, fragment, colouring);
	DISCARD_TEXT(colouring)
	Trees::make_child(SC, I);
}

@h Code text.

=
void TextWeaver::source_code(heterogeneous_tree *tree, tree_node *ap,
	text_stream *matter, text_stream *colouring, int linked) {
	weave_document_node *C = RETRIEVE_POINTER_weave_document_node(tree->root->content);
	weave_order *wv = C->wv;
	Str::truncate(colouring, Str::len(matter));
	int from = 0;
	for (int i=0; i < Str::len(matter); i++) {
		if (linked) {
			@<Pick up hyperlinking at the eleventh hour@>;
			text_stream *xref_notation = Bibliographic::get_datum(wv->weave_web,
				I"Cross-References Notation");
			if (Str::ne(xref_notation, I"Off"))
				@<Pick up cross-references at the eleventh hour@>;
		}
		if ((Str::get_at(colouring, i) == FUNCTION_COLOUR) &&
			(LiterateSource::is_text_extract_chunk(wv->current_weave_line->owning_chunk) == FALSE)) {
			TEMPORARY_TEXT(fname)
			int j = i;
			while (Str::get_at(colouring, j) == FUNCTION_COLOUR)
				PUT_TO(fname, Str::get_at(matter, j++));
			if (CodeAnalysis::is_reserved_word_for_section(
				LiterateSource::section_of_line(wv->current_weave_line), fname, FUNCTION_COLOUR))
				@<Spot the function@>;
			DISCARD_TEXT(fname)
		}

	}
	if (from < Str::len(matter))
		TextWeaver::source_code_piece(tree, ap, matter, colouring, from, Str::len(matter));
}

@<Pick up hyperlinking at the eleventh hour@> =
	if ((Str::includes_at(matter, i, I"http://")) ||
		(Str::includes_at(matter, i, I"https://"))) {
		TEMPORARY_TEXT(after)
		Str::substr(after, Str::at(matter, i), Str::end(matter));
		match_results mr = Regexp::create_mr();
		if (Regexp::match(&mr, after, U"(https*://%C+)(%c*)")) {
			tree_node *U = WeaveTree::url(tree, mr.exp[0], mr.exp[0], TRUE);
			TextWeaver::source_code_piece(tree, ap, matter, colouring, from, i);
			Trees::make_child(U, ap);
			i += Str::len(mr.exp[0]);
			from = i;
		}
		DISCARD_TEXT(after)
	}

@<Pick up cross-references at the eleventh hour@> =
	int N = Str::len(xref_notation);
	if ((Str::includes_at(matter, i, xref_notation))) {
		int j = i + N+1;
		while (j < Str::len(matter)) {
			if (Str::includes_at(matter, j, xref_notation)) {
				TEMPORARY_TEXT(reference)
				Str::substr(reference, Str::at(matter, i + N), Str::at(matter, j));
				@<Attempt to resolve the cross-reference at the eleventh hour@>;
				DISCARD_TEXT(reference)
				break;
			}
			j++;
		}
	}

@<Attempt to resolve the cross-reference at the eleventh hour@> =
	TEMPORARY_TEXT(url)
	TEMPORARY_TEXT(title)
	int ext = FALSE;
	if (Colonies::resolve_reference_in_weave(wv->weave_colony,
		url, title, wv->weave_to, reference,
		wv->weave_web, wv->current_weave_line, &ext)) {
		tree_node *U = WeaveTree::url(tree, url, title, ext);
		TextWeaver::source_code_piece(tree, ap, matter, colouring, from, i);
		Trees::make_child(U, ap);
		i = j + N;
		from = i;
	}
	DISCARD_TEXT(url)
	DISCARD_TEXT(title)

@<Spot the function@> =
	language_function *fn = CodeAnalysis::get_function(
		LiterateSource::section_of_line(wv->current_weave_line), fname, FUNCTION_COLOUR);
	if (fn) {
		ls_paragraph *par = Functions::declaration_lsparagraph(fn);
		if (wv->current_weave_line == fn->function_header_at) {
			if (fn->usage_described == FALSE) {
				TextWeaver::source_code_piece(tree, ap, matter, colouring, from, i);
				tree_node *FD = WeaveTree::function_defn(tree, fn);
				Trees::make_child(FD, ap);
				Weaver::show_function_usage(tree, wv, FD, par, fn, TRUE);
				i += Str::len(fname) - 1;
				from = i+1;
			}
		} else {
			TextWeaver::source_code_piece(tree, ap, matter, colouring, from, i);
			TEMPORARY_TEXT(url)
			Colonies::paragraph_URL(url, par, wv->weave_to, wv->weave_colony);
			tree_node *U = WeaveTree::function_usage(tree, url, fn);
			Trees::make_child(U, ap);
			i += Str::len(fname) - 1;
			from = i+1;
		}
	}

@ =
void TextWeaver::source_code_piece(heterogeneous_tree *tree, tree_node *ap,
	text_stream *matter, text_stream *colouring, int from, int to) {
	if (to > from) {
		TEMPORARY_TEXT(m)
		TEMPORARY_TEXT(c)
		Str::substr(m, Str::at(matter, from), Str::at(matter, to));
		Str::substr(c, Str::at(colouring, from), Str::at(colouring, to));
		tree_node *SC = WeaveTree::source_code(tree, m, c);
		Trees::make_child(SC, ap);
		DISCARD_TEXT(m)
		DISCARD_TEXT(c)
	}
}
