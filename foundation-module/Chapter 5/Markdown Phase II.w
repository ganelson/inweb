[MDInlineParser::] Markdown Phase II.

Phase II of the Markdown parser: fragmenting inline material into emphasis,
links, backticked code and so forth.

@h Disclaimer.
Do not call functions in this section directly: use the API in //Markdown//.

@h Inline code.
Phase II of the parser consists entirely of walking the tree built in Phase I,
with the following function.

=
void MDInlineParser::inline_recursion(markdown_variation *variation,
	md_links_dictionary *link_refs, markdown_item *at) {
	if (at == NULL) return;
	if ((at->type == PARAGRAPH_MIT) ||
		(at->type == HEADING_MIT) ||
		((at->type == TABLE_COLUMN_MIT) && (Str::len(at->stashed) > 0))) {
		markdown_item *matter = MDInlineParser::inline(variation, link_refs, at->stashed);
		Markdown::add_to(matter, at);
	}
	for (markdown_item *c = at->down; c; c = c->next)
		MDInlineParser::inline_recursion(variation, link_refs, c);
}

@ What it does, then, is to look at the text of paragraphs and headings to
process them as "inline matter", which may contain emphasis, code excerpts
and raw HTML, or images, or links. Since all these constructions can be
nested, the result is a further tree, using a whole lot of new items never
generated in Phase I.

To recap the syntaxes we're looking for:
= (text)
	This is a line of plain copy.
	This one has `a backtick string`.
	This one an autolink, <stanley.gibbons@heaven.org>, in email form.
	This one an autolink, <https://www.stanleygibbons.com>, in web form.
	This one [uses a link](https://www.stanleygibbons.com).
	This one depicts ![the Blue Mauritius](https://upload.wikimedia.org/wikipedia/commons/8/8e/1847_BothPost_Office_Jakubek.jpg).
	This one uses **strong** and *weak* emphasis.
	This one also uses __strong__ and _weak_ emphasis.
=

Every inline string becomes a subtree under a |MATERIAL_MIT| item. We then
proceed in three stages: make the "chain", which involves finding backtick
strings, raw HTML and autolinks, all constructions of equal precedence.
Then we look for links and images, images being essentially a form of link
for most purposes. Finally, but with some difficulty, we look for emphasis
notation. 

=
markdown_item *MDInlineParser::inline(markdown_variation *variation,
	md_links_dictionary *link_refs, text_stream *text) {
	markdown_item *owner = Markdown::new_item(MATERIAL_MIT);
	MDInlineParser::make_inline_chain(variation, owner, text);
	MDInlineParser::links_and_images(variation, link_refs, owner, FALSE);
	int mask = 0;
	if (MarkdownVariations::supports(variation, ASTERISK_EMPHASIS_MARKDOWNFEATURE))
		mask += ASTERISK_EMPHASIS_BIT;
	if (MarkdownVariations::supports(variation, UNDERSCORE_EMPHASIS_MARKDOWNFEATURE))
		mask += UNDERSCORE_EMPHASIS_BIT;
	if (MarkdownVariations::supports(variation, STRIKETHROUGH_MARKDOWNFEATURE))
		mask += TILDE_STRIKETHROUGH_BIT;
	if (mask) MDInlineParser::emphasis(variation, owner, mask);
	return owner;
}

markdown_item *MDInlineParser::make_inline_chain(markdown_variation *variation,
	markdown_item *owner, text_stream *text) {
	int i = 0;
	while (Str::get_at(text, i) == ' ') i++;
	int from = i, escaped = FALSE;
	for (; i<Str::len(text); i++) {
		if ((escaped == FALSE) && (Str::get_at(text, i) == '\\') &&
			(Characters::is_ASCII_punctuation(Str::get_at(text, i+1)))) {
			escaped = TRUE;
		} else {
			if (escaped == FALSE) {
				@<Does a backtick begin here?@>;
				@<Does an index mark begin here?@>;
				@<Does an autolink begin here?@>;
				@<Does a raw HTML tag begin here?@>;
			}
			@<Does a hard or soft line break occur here?@>;
			ContinueOuter: ;
			escaped = FALSE;
		}
	}
	if (from <= Str::len(text)-1) {
		int to = Str::len(text)-1;
		while (Str::get_at(text, to) == ' ') to--;
		if (to >= from) {
			markdown_item *md = Markdown::new_slice(PLAIN_MIT, text, from, to);
			Markdown::add_to(md, owner);
		}
	}
	return owner;
}

@ See CommonMark 6.1: "A backtick string is a string of one or more backtick
characters that is neither preceded nor followed by a backtick." This returns
the length of a backtick string beginning at |at|, if one does, or 0 if it
does not.

=
int MDInlineParser::backtick_string(text_stream *text, int at) {
	int count = 0;
	while (Str::get_at(text, at + count) == '`') count++;
	if (count == 0) return 0;
	if ((at > 0) && (Str::get_at(text, at - 1) == '`')) return 0;
	return count;
}

@<Does a backtick begin here?@> =
	if (MarkdownVariations::supports(variation, BACKTICKED_CODE_MARKDOWNFEATURE)) {
		int count = MDInlineParser::backtick_string(text, i);
		if (count > 0) {
			for (int j=i+count+1; j<Str::len(text); j++) {
				if (MDInlineParser::backtick_string(text, j) == count) {
					if (i-1 >= from) {
						markdown_item *md = Markdown::new_slice(PLAIN_MIT, text, from, i-1);
						Markdown::add_to(md, owner);
					}
					@<Insert an inline code item@>;
					i = j+count; from = j+count;
					goto ContinueOuter;
				}
			}
		}
	}

@ "The contents of the code span are the characters between these two backtick strings".
Inside it, "line endings are converted to spaces", and "If the resulting string
both begins and ends with a space character, but does not consist entirely of
space characters, a single space character is removed from the front and back."

@<Insert an inline code item@> =
	int start = i+count, end = j-1;
	text_stream *codespan = Str::new();
	int all_spaces = TRUE;
	for (int k=start; k<=end; k++) {
		inchar32_t c = Str::get_at(text, k);
		if (c == '\n') c = ' ';
		if (c != ' ') all_spaces = FALSE;
		PUT_TO(codespan, c);
	}
	if ((all_spaces == FALSE) && (Str::get_first_char(codespan) == ' ')
		 && (Str::get_last_char(codespan) == ' ')) {
		markdown_item *md = Markdown::new_slice(CODE_MIT, codespan, 1, Str::len(codespan)-2);
		Markdown::set_backtick_count(md, count);
		Markdown::add_to(md, owner);		 
	} else {
		markdown_item *md = Markdown::new_slice(CODE_MIT, codespan, 0, Str::len(codespan)-1);
		Markdown::set_backtick_count(md, count);
		Markdown::add_to(md, owner);
	}

@ This provides an extension borrowed from traditional TeX manual-indexing
notation, also used by indoc.

@<Does an index mark begin here?@> =
	if (MarkdownVariations::supports(variation, INDEXING_MARKS_MARKDOWNFEATURE)) {
		if (Str::get_at(text, i) == '^') {
			int j = i+1, count = 1;
			if (Str::get_at(text, j) == '^') j++, count++;
			if (Str::get_at(text, j) == '^') j++, count++;
			if (Str::get_at(text, j) == '{') {
				TEMPORARY_TEXT(lemma)
				j++;
				int escaped = FALSE, end_found = FALSE;
				while (Str::get_at(text, j)) {
					if ((escaped == FALSE) && (Str::get_at(text, j) == '\\'))
						escaped = TRUE;
					else {
						if ((escaped == FALSE) && (Str::get_at(text, j) == '}')) {
							end_found = TRUE; break;
						}
						PUT_TO(lemma, Str::get_at(text, j));
						escaped = FALSE;
					}
					j++;
				}
				if (end_found) {
					if (i-1 >= from) {
						markdown_item *md = Markdown::new_slice(PLAIN_MIT, text, from, i-1);
						Markdown::add_to(md, owner);
					}
					@<Insert an index item@>;
					i = j; from = j+1;
				}
				DISCARD_TEXT(lemma)
				if (end_found) goto ContinueOuter;
			}
		}
	}

@<Insert an index item@> =
	markdown_item *md = Markdown::new_item(INDEX_MARKER_MIT);
	md->stashed = Str::duplicate(lemma);
	md->details = count;
	Markdown::add_to(md, owner);
	if (count == 1) {
		markdown_item *md = Markdown::new_slice(PLAIN_MIT, Str::duplicate(lemma), 0, Str::len(lemma)-1);
		Markdown::add_to(md, owner);
	}
	
@<Does an autolink begin here?@> =
	if (Str::get_at(text, i) == '<') {
		for (int j=i+1; j<Str::len(text); j++) {
			inchar32_t c = Str::get_at(text, j);
			if (c == '>') {
				int link_from = i+1, link_to = j-1, count = j-i+1;
				if (tracing_Markdown_parser) {
					text_stream *OUT = STDOUT;
					WRITE("Investigating potential autolink: ");
					for (int k=i; k<=j; k++) PUT(Str::get_at(text, k));
					WRITE("\n");
				}
				if (MarkdownVariations::supports(variation, WEB_AUTOLINKS_MARKDOWNFEATURE))
					@<Test for URI autolink@>;
				if (MarkdownVariations::supports(variation, EMAIL_AUTOLINKS_MARKDOWNFEATURE))
					@<Test for email autolink@>;
				break;
			}
			if ((c == '<') ||
				(Characters::is_Unicode_whitespace(c)) ||
				(Characters::is_control_character(c)))
				break;
		}
	}
	if (MarkdownVariations::supports(variation, EXTENDED_AUTOLINKS_MARKDOWNFEATURE)) {
		if ((MDInlineParser::extended_autolink_domain_char(Str::get_at(text, i))) &&
			((i == 0) ||
				(Str::get_at(text, i-1) == '\n') ||
				(Str::get_at(text, i-1) == '*') ||
				(Str::get_at(text, i-1) == '_') ||
				(Str::get_at(text, i-1) == '~') ||
				((Str::get_at(text, i-1) == '(') && (Str::get_at(text, i-2) != ']')) ||
				(Characters::is_Unicode_whitespace(Str::get_at(text, i-1)))))
					@<Test for extended autolink@>;
	}

@ "A URI autolink consists of... a scheme followed by a colon followed by zero
or more characters other than ASCII control characters, space, <, and >... a
scheme is any sequence of 2–32 characters beginning with an ASCII letter and
followed by any combination of ASCII letters, digits, or the symbols plus,
period, or hyphen."

@<Test for URI autolink@> =
	int colon_at = -1;
	for (int k=link_from; k<=link_to; k++) if (Str::get_at(text, k) == ':') { colon_at = k; break; }
	if (colon_at >= 0) {
		int scheme_valid = TRUE;
		@<Vet the scheme@>;
		int link_valid = TRUE;
		@<Vet the link@>;
		if ((scheme_valid) && (link_valid)) {
			if (i-1 >= from) {
				markdown_item *md = Markdown::new_slice(PLAIN_MIT, text, from, i-1);
				Markdown::add_to(md, owner);
			}
			markdown_item *md = Markdown::new_slice(URI_AUTOLINK_MIT,
				text, link_from, link_to);
			Markdown::add_to(md, owner);
			i = link_to+1; from = link_to+2;
			if (tracing_Markdown_parser) PRINT("Found URI from = %c\n", Markdown::get_at(md, from));
			goto ContinueOuter;			
		} else if (tracing_Markdown_parser) {
			if (scheme_valid == FALSE) PRINT("Colon suggested URI but scheme invalid\n");
			if (link_valid == FALSE) PRINT("Colon suggested URI but link invalid\n");
		}
	} else {
		if (tracing_Markdown_parser) PRINT("Not a URI: no colon\n");
	}

@<Vet the scheme@> =
	int scheme_length = colon_at - link_from;
	if ((scheme_length < 2) || (scheme_length > 32)) scheme_valid = FALSE;
	for (int i=link_from; i<colon_at; i++) {
		inchar32_t c = Str::get_at(text, i);
		if (!((Characters::is_ASCII_letter(c)) ||
			((i > link_from) &&
				((Characters::is_ASCII_digit(c)) || (c == '+') || (c == '-') || (c == '.')))))
			scheme_valid = FALSE;
	}

@<Vet the link@> =
	for (int i=colon_at+1; i<=link_to; i++) {
		inchar32_t c = Str::get_at(text, i);
		if ((c == '<') || (c == '>') || (c == ' ') ||
			(Characters::is_control_character(c)))
			link_valid = FALSE;
	}

@<Test for email autolink@> =
	int atsign_at = -1;
	for (int k=link_from; k<=link_to; k++) if (Str::get_at(text, k) == '@') { atsign_at = k; break; }
	if (atsign_at >= 0) {
		int username_valid = TRUE;
		@<Vet the username@>;
		int domain_valid = TRUE;
		@<Vet the domain name@>;
		if ((username_valid) && (domain_valid)) {
			if (i-1 >= from) {
				markdown_item *md = Markdown::new_slice(PLAIN_MIT, text, from, i-1);
				Markdown::add_to(md, owner);
			}
			markdown_item *md = Markdown::new_slice(EMAIL_AUTOLINK_MIT,
				text, link_from, link_to);
			Markdown::set_add_protocol_state(md, TRUE);
			Markdown::add_to(md, owner);
			i = j+count; from = j+count;
			if (tracing_Markdown_parser) PRINT("Found email\n");
			goto ContinueOuter;			
		} else if (tracing_Markdown_parser) {
			if (username_valid == FALSE) PRINT("At suggested email but username invalid\n");
			if (domain_valid == FALSE) PRINT("At suggested email but domain invalid\n");
		}
	} else {
		if (tracing_Markdown_parser) PRINT("Not an email: no at-sign\n");
	}

@ What constitutes a legal email address follows the HTML 5 regular expression,
according to CommonMark. Good luck using |{{@1-x.2.z.w| as your email address,
but you absolutely can.

@<Vet the username@> =
	int username_length = atsign_at - link_from;
	if (username_length < 1) username_valid = FALSE;
	for (int i=link_from; i<atsign_at; i++) {
		inchar32_t c = Str::get_at(text, i);
		if (!((Characters::is_ASCII_letter(c)) ||
				(Characters::is_ASCII_digit(c)) ||
				(c == '.') ||
				(c == '!') ||
				(c == '#') ||
				(c == '$') ||
				(c == '%') ||
				(c == '&') ||
				(c == '\'') ||
				(c == '*') ||
				(c == '+') ||
				(c == '/') ||
				(c == '=') ||
				(c == '?') ||
				(c == '^') ||
				(c == '_') ||
				(c == '`') ||
				(c == '{') ||
				(c == '|') ||
				(c == '}') ||
				(c == '~') ||
				(c == '-')))
			username_valid = FALSE;
	}

@<Vet the domain name@> =
	int segment_length = 0;
	for (int i=atsign_at+1; i<=link_to; i++) {
		inchar32_t c = Str::get_at(text, i);
		if (segment_length == 0) {
			if (!((Characters::is_ASCII_letter(c)) || (Characters::is_ASCII_digit(c))))
				domain_valid = FALSE;
		} else {
			if (c == '.') { segment_length = 0; continue; }
			if (c == '-') {
				if ((Str::get_at(text, i+1) == 0) || (Str::get_at(text, i+1) == '.'))
					domain_valid = FALSE;
			} else if (!((Characters::is_ASCII_letter(c)) || (Characters::is_ASCII_digit(c))))
				domain_valid = FALSE;
		}
		segment_length++;
		if (segment_length >= 64) domain_valid = FALSE;
	}
	if (segment_length >= 64) domain_valid = FALSE;

@ Extended autolinks are a GitHub-flavored Markdown extension, and allow (some)
websites and email addresses to be turned into links without needing angle
brackets around them. This part of GitHub's specification uses sloppily
different criteria for what is a legal domain or email address, but I follow
it as written.

@<Test for extended autolink@> =
	int domain_from = i, to = i;
	int add_protocol = FALSE, email_address = FALSE, email_required = FALSE, xmpp = FALSE;
	@<Look for a domain prefix@>;
	if ((email_required) || (to == domain_from)) @<Look for an email address opening@>;
	if (((email_required == FALSE) || (email_address)) && (to > domain_from)) {
		if (tracing_Markdown_parser) {
			PRINT("Found valid extended autolink prefix: ");
			for (int j=domain_from; j<=to; j++) PUT_TO(STDOUT, Str::get_at(text, j));
			PRINT("\n");
		}
		@<Look for the rest of the domain@>;
		int domain_name_invalid = FALSE;
		@<Test the domain name for validity@>;
		if (domain_name_invalid == FALSE) {
			@<Push the link forwards through URL or resource@>;
			@<Insert as an extended autolink@>;
		}
	}

@<Look for a domain prefix@> =
	if ((Str::get_at(text, domain_from) == 'w') &&
		(Str::get_at(text, domain_from+1) == 'w') &&
		(Str::get_at(text, domain_from+2) == 'w') &&
		(Str::get_at(text, domain_from+3) == '.') &&
		(MDInlineParser::extended_autolink_domain_char(Str::get_at(text, domain_from+4)))) {
		add_protocol = TRUE;
		to = domain_from+4;
	} else if ((Str::get_at(text, domain_from) == 'm') &&
		(Str::get_at(text, domain_from+1) == 'a') &&
		(Str::get_at(text, domain_from+2) == 'i') &&
		(Str::get_at(text, domain_from+3) == 'l') &&
		(Str::get_at(text, domain_from+4) == 't') &&
		(Str::get_at(text, domain_from+5) == 'o') &&
		(Str::get_at(text, domain_from+6) == ':') &&
		(MDInlineParser::extended_autolink_domain_char(Str::get_at(text, domain_from+7)))) {
		to = domain_from+7; email_required = TRUE;
	} else if ((Str::get_at(text, domain_from) == 'x') &&
		(Str::get_at(text, domain_from+1) == 'm') &&
		(Str::get_at(text, domain_from+2) == 'p') &&
		(Str::get_at(text, domain_from+3) == 'p') &&
		(Str::get_at(text, domain_from+4) == ':') &&
		(MDInlineParser::extended_autolink_domain_char(Str::get_at(text, domain_from+5)))) {
		to = domain_from+5; email_required = TRUE; xmpp = TRUE;
	} else if ((Str::get_at(text, domain_from) == 'h') &&
		(Str::get_at(text, domain_from+1) == 't') &&
		(Str::get_at(text, domain_from+2) == 't') &&
		(Str::get_at(text, domain_from+3) == 'p') &&
		(Str::get_at(text, domain_from+4) == ':') &&
		(Str::get_at(text, domain_from+5) == '/') &&
		(Str::get_at(text, domain_from+6) == '/') &&
		(MDInlineParser::extended_autolink_domain_char(Str::get_at(text, domain_from+7)))) {
		to = domain_from+7;
	} else if ((Str::get_at(text, domain_from) == 'h') &&
		(Str::get_at(text, domain_from+1) == 't') &&
		(Str::get_at(text, domain_from+2) == 't') &&
		(Str::get_at(text, domain_from+3) == 'p') &&
		(Str::get_at(text, domain_from+4) == 's') &&
		(Str::get_at(text, domain_from+5) == ':') &&
		(Str::get_at(text, domain_from+6) == '/') &&
		(Str::get_at(text, domain_from+7) == '/') &&
		(MDInlineParser::extended_autolink_domain_char(Str::get_at(text, domain_from+8)))) {
		to = domain_from+8;
	}

@<Look for an email address opening@> =
	int j = to;
	while ((MDInlineParser::extended_autolink_email_char(Str::get_at(text, j))) ||
		(Str::get_at(text, j) == '+') ||
		(Str::get_at(text, j) == '.')) j++;
	if ((j > to) && (Str::get_at(text, j) == '@')) {
		to = j+1; email_address = TRUE;
		if (email_required == FALSE) add_protocol = TRUE;
	}

@<Look for the rest of the domain@> =
	if (email_address) {
		while (TRUE) {
			if (MDInlineParser::extended_autolink_email_char(Str::get_at(text, to+1))) to++;
			else if ((Str::get_at(text, to+1) == '.') && (Str::get_at(text, to) != '.')) to++;
			else break;
		}
	} else {
		while (TRUE) {
			if (MDInlineParser::extended_autolink_domain_char(Str::get_at(text, to+1))) to++;
			else if ((Str::get_at(text, to+1) == '.') && (Str::get_at(text, to) != '.')) to++;
			else break;
		}
	}
	if (Str::get_at(text, to) == '.') to--;

@<Test the domain name for validity@> =
	int dot_count = 0;
	for (int j=domain_from; j<=to; j++) if (Str::get_at(text, j) == '.') dot_count++;
	if (dot_count == 0) domain_name_invalid = TRUE;
	if (email_address) {
		if ((Str::get_at(text, to) == '_') || (Str::get_at(text, to) == '-'))
			domain_name_invalid = TRUE;
	} else {
		for (int j=domain_from, dots_passed=0; j<=to; j++) {
			inchar32_t c = Str::get_at(text, j);
			if (c == '.') dots_passed++;
			if ((c == '_') && (dots_passed >= dot_count - 2)) domain_name_invalid = TRUE;
		}
	}

@<Push the link forwards through URL or resource@> =
	int domain_to = to;
	if (email_address == FALSE) {
		while ((Str::get_at(text, to+1) != 0) && (Str::get_at(text, to+1) != '<') &&
			(Characters::is_Unicode_whitespace(Str::get_at(text, to+1)) == FALSE)) to++;
		while (MDInlineParser::extended_autolink_trailing_punctuation_char(Str::get_at(text, to))) to--;
	} else if (xmpp) {
		if (Str::get_at(text, to+1) == '/') {
			to++;
			while (MDInlineParser::extended_autolink_xmpp_resource_char(Str::get_at(text, to+1))) to++;
		}
	}
	while (TRUE) {
		int initial_to = to;
		if (Str::get_at(text, to) == ')') {
			int bl = 0;
			for (int j=domain_to+1; j<=to; j++) {
				if (Str::get_at(text, j) == '(') bl++;
				if (Str::get_at(text, j) == ')') bl--;
				if (bl < 0) { to = j-1; break; }
			}
		} else if (Str::get_at(text, to) == ';') {
			int b = to-1;
			while (Characters::isalnum(Str::get_at(text, b))) b--;
			if (Str::get_at(text, b) == '#') b--;
			if (Str::get_at(text, b) == '&') to = b-1;
		}
		if (to == initial_to) break;
	}

@<Insert as an extended autolink@> =
	if (i-1 >= from) {
		markdown_item *md = Markdown::new_slice(PLAIN_MIT, text, from, i-1);
		Markdown::add_to(md, owner);
	}
	int link_from = domain_from, link_to = to;
	i = link_to; from = link_to+1;
	int type = URI_AUTOLINK_MIT;
	if (email_address) type = EMAIL_AUTOLINK_MIT;
	if (xmpp) type = XMPP_AUTOLINK_MIT;
	markdown_item *md = Markdown::new_slice(type,
		text, link_from, link_to);
	Markdown::set_add_protocol_state(md, add_protocol);
	Markdown::add_to(md, owner);
	if (tracing_Markdown_parser) {
		PRINT("Found extended autolink ");
		for (int j=domain_from; j<=to; j++) PUT_TO(STDOUT, Str::get_at(text, j));
		PRINT("\n");
	}
	goto ContinueOuter;

@ "Alphanumeric characters, underscores and hyphens." It's not entirely clear
what the GitHub-flavored Markdown specification means by "alphanumeric" here:
are arbitrary Unicode letters and numerals allowed? I'm going to say not.

=
int MDInlineParser::extended_autolink_domain_char(inchar32_t c) {
	if ((Characters::isalnum(c)) || (c == '_') || (c == '-')) return TRUE;
	return FALSE;
}

@ "One ore [sic] more characters which are alphanumeric, or ., -, _, or +."
But we take care of |+| and |.| above.

=
int MDInlineParser::extended_autolink_email_char(inchar32_t c) {
	if ((Characters::isalnum(c)) || (c == '_') || (c == '-')) return TRUE;
	return FALSE;
}

@ "The resource can contain all alphanumeric characters, as well as @ and .."

=
int MDInlineParser::extended_autolink_xmpp_resource_char(inchar32_t c) {
	if ((Characters::isalnum(c)) || (c == '@') || (c == '.')) return TRUE;
	return FALSE;
}

@ "Trailing punctuation (specifically, ?, !, ., ,, :, *, _, and ~) will not be
considered part of the autolink."

=
int MDInlineParser::extended_autolink_trailing_punctuation_char(inchar32_t c) {
	if ((c == '?') || (c == '!') || (c == ',') || (c == '.') ||
		(c == ':') || (c == '*') || (c == '_') || (c == '~')) return TRUE;
	return FALSE;
}

@<Does a raw HTML tag begin here?@> =
	if (MarkdownVariations::supports(variation, INLINE_HTML_MARKDOWNFEATURE)) {
		int filter = NOT_APPLICABLE;
		if (Str::get_at(text, i) == '<') {
			switch (Str::get_at(text, i+1)) {
				case '?': @<Does a processing instruction begin here?@>; break;
				case '!':
					if ((Str::get_at(text, i+2) == '-') && (Str::get_at(text, i+3) == '-'))
						@<Does an HTML comment begin here?@>;
					if ((Str::get_at(text, i+2) == '[') && (Str::get_at(text, i+3) == 'C') &&
						(Str::get_at(text, i+4) == 'D') && (Str::get_at(text, i+5) == 'A') &&
						(Str::get_at(text, i+6) == 'T') && (Str::get_at(text, i+7) == 'A') &&
						(Str::get_at(text, i+8) == '['))
						@<Does a CDATA section begin here?@>;
					if (Characters::is_ASCII_letter(Str::get_at(text, i+2)))
						@<Does an HTML declaration begin here?@>;
					break;
				case '/': @<Does a close tag begin here?@>; break;
				default: @<Does an open tag begin here?@>; break;
			}
			NotATag: ;
		}
	}

@ The content of a PI must be non-empty.

@<Does a processing instruction begin here?@> =
	for (int j = i+3; j<Str::len(text); j++)
		if ((Str::get_at(text, j) == '?') && (Str::get_at(text, j+1) == '>')) {
			int tag_from = i, tag_to = j+1;
			@<Allow it as a raw HTML tag@>;
		}

@ A comment can be empty, but cannot end in a dash or contain a double-dash:

@<Does an HTML comment begin here?@> =
	int bad_start = FALSE;
	if (Str::get_at(text, i+4) == '>') bad_start = TRUE;
	if ((Str::get_at(text, i+4) == '-') && (Str::get_at(text, i+5) == '>')) bad_start = TRUE;
	if (bad_start == FALSE)
		for (int j = i+4; j<Str::len(text); j++)
			if ((Str::get_at(text, j) == '-') && (Str::get_at(text, j+1) == '-')) {
				if (Str::get_at(text, j+2) == '>') {
					int tag_from = i, tag_to = j+2;
					@<Allow it as a raw HTML tag@>;
				}
				break;
			} 

@ The content of a declaration can be empty.

@<Does an HTML declaration begin here?@> =
	for (int j = i+2; j<Str::len(text); j++)
		if (Str::get_at(text, j) == '>') {
			int tag_from = i, tag_to = j;
			@<Allow it as a raw HTML tag@>;
		}

@ The content of a CDATA must be non-empty.

@<Does a CDATA section begin here?@> =
	for (int j = i+10; j<Str::len(text); j++)
		if ((Str::get_at(text, j) == ']') && (Str::get_at(text, j+1) == ']') &&
			(Str::get_at(text, j+2) == '>')) {
			int tag_from = i, tag_to = j+2;
			@<Allow it as a raw HTML tag@>;
		}

@<Does an open tag begin here?@> =
	int at = i+1;
	filter = FALSE;
	@<Advance past tag name@>;
	@<Advance past attributes@>;
	@<Advance past optional tag-whitespace@>;
	if (Str::get_at(text, at) == '/') at++;
	if (Str::get_at(text, at) == '>') {
		int tag_from = i, tag_to = at;
		@<Allow it as a raw HTML tag@>;
	}

@<Does a close tag begin here?@> =
	int at = i+2;
	@<Advance past tag name@>;
	@<Advance past optional tag-whitespace@>;
	if (Str::get_at(text, at) == '>') {
		int tag_from = i, tag_to = at;
		@<Allow it as a raw HTML tag@>;
	}

@<Advance past tag name@> =
	inchar32_t c = Str::get_at(text, at);
	if (Characters::is_ASCII_letter(c) == FALSE) goto NotATag;
	TEMPORARY_TEXT(tag)
	while ((c == '-') || (Characters::is_ASCII_letter(c)) || (Characters::is_ASCII_digit(c))) {
		PUT_TO(tag, c);
		c = Str::get_at(text, ++at);
	}
	if ((filter == FALSE) &&
		(MarkdownVariations::supports(variation, DISALLOWED_RAW_HTML_MARKDOWNFEATURE)) &&
		(Markdown::tag_should_be_filtered(tag))) filter = TRUE;
	DISCARD_TEXT(tag)

@<Advance past attributes@> =
	while (TRUE) {
		int start_at = at;
		@<Advance past optional tag-whitespace@>;
		if (at == start_at) break;
		inchar32_t c = Str::get_at(text, at);
		if ((c == '_') || (c == ':') || (Characters::is_ASCII_letter(c))) {
			while ((c == '_') || (c == ':') || (c == '.') || (c == '-') ||
				(Characters::is_ASCII_letter(c)) || (Characters::is_ASCII_digit(c)))
				c = Str::get_at(text, ++at);
			int start_value_at = at;
			@<Advance past optional tag-whitespace@>;
			if (Str::get_at(text, at) != '=') {
				at = start_value_at; goto DoneValueSpecification;
			}
			at++;
			@<Advance past optional tag-whitespace@>;
			@<Try for a single-quoted attribute value@>;
			@<Try for a double-quoted attribute value@>;
			@<Try for an unquoted attribute value@>;
			DoneValueSpecification: ;
		} else { at = start_at; break; }
	}

@<Try for an unquoted attribute value@> =
	int k = at;
	while (TRUE) {
		inchar32_t c = Str::get_at(text, k);
		if ((c == ' ') || (c == '\t') || (c == '\n') || (c == '"') || (c == '\'') ||
			(c == '=') || (c == '<') || (c == '>') || (c == '`') || (c == 0))
			break;
		k++;
	}
	if (k == at) { at = start_value_at; goto DoneValueSpecification; }
	at = k; goto DoneValueSpecification;

@<Try for a single-quoted attribute value@> =
	if (Str::get_at(text, at) == '\'') {
		int k = at + 1;
		while ((Str::get_at(text, k) != '\'') && (Str::get_at(text, k) != 0))
			k++;
		if (Str::get_at(text, k) == '\'') { at = k+1; goto DoneValueSpecification; }
		at = start_value_at; goto DoneValueSpecification;
	}

@<Try for a double-quoted attribute value@> =
	if (Str::get_at(text, at) == '"') {
		int k = at + 1;
		while ((Str::get_at(text, k) != '"') && (Str::get_at(text, k) != 0))
			k++;
		if (Str::get_at(text, k) == '"') { at = k+1; goto DoneValueSpecification; }
		at = start_value_at; goto DoneValueSpecification;
	}

@<Advance past compulsory tag-whitespace@> =
	inchar32_t c = Str::get_at(text, at);
	if ((c != ' ') && (c != '\t') && (c != '\n')) goto NotATag;
	@<Advance past optional tag-whitespace@>;

@<Advance past optional tag-whitespace@> =
	int line_ending_count = 0;
	while (TRUE) {
		inchar32_t c = Str::get_at(text, at++);
		if (c == '\n') {
			line_ending_count++;
			if (line_ending_count == 2) break;
		}
		if ((c != ' ') && (c != '\t') && (c != '\n')) break;
	}
	at--;

@<Allow it as a raw HTML tag@> =
	if (i-1 >= from) {
		markdown_item *md = Markdown::new_slice(PLAIN_MIT, text, from, i-1);
		Markdown::add_to(md, owner);
	}
	markdown_item *md = Markdown::new_slice(INLINE_HTML_MIT, text, tag_from, tag_to);
	if (filter == TRUE) Markdown::set_filtered_state(md, TRUE);
	Markdown::add_to(md, owner);
	i = tag_to; from = tag_to + 1;
	if (tracing_Markdown_parser) PRINT("Found raw HTML\n");
	goto ContinueOuter;

@<Does a hard or soft line break occur here?@> =
	if (Str::get_at(text, i) == '\n') {
		int soak = 0;
		if (Str::get_at(text, i-1) == '\\') soak = 2;
		int preceding_spaces = 0;
		while (Str::get_at(text, i-1-preceding_spaces) == ' ') preceding_spaces++;
		if (preceding_spaces >= 2) soak = preceding_spaces+1;
		if (soak > 0) {
			if (i-soak >= from) {
				markdown_item *md = Markdown::new_slice(PLAIN_MIT, text, from, i-soak);
				Markdown::add_to(md, owner);
			}
			markdown_item *md = Markdown::new_slice(LINE_BREAK_MIT, I"\n\n", 0, 1);
			Markdown::add_to(md, owner);
		} else {
			if (i-preceding_spaces-1 >= from) {
				markdown_item *md = Markdown::new_slice(PLAIN_MIT, text, from, i-preceding_spaces-1);
				Markdown::add_to(md, owner);
			}
			markdown_item *md = Markdown::new_slice(SOFT_BREAK_MIT, I"\n", 0, 0);
			Markdown::add_to(md, owner);
		}
		i++;
		while (Str::get_at(text, i) == ' ') i++;
		from = i;
		i--;
		if (tracing_Markdown_parser) PRINT("Found line break\n");
		goto ContinueOuter;
	}

@h Links and images.
Well, so now we come to the middle-precedence items: links and images. These
have equal precedence, so they ought to be read from left to right, but there's
a twist: a link is not valid if its linked material contains another link.
= (text)
	This [looks like [a link within a link](somewhere.html)](nowhere.html).
=
results in only the inner link being processed as such. That restriction
does not hold for images, so this is all legal:
= (text)
	This ![picture of [an unperforated Malaya strip](malaya.html)](strip.jpg).
=
Indeed, image notations can contain other image notations. Of course, that
does no good, because rendering uses the textual part of an image as its |"alt"|
text, which is not allowed to contain tags, only plain text. But syntactically
it is legal Markdown.

=
void MDInlineParser::links_and_images(markdown_variation *variation,
	md_links_dictionary *link_refs, markdown_item *owner, int images_only) {
	if (owner == NULL) return;
	if ((MarkdownVariations::supports(variation, LINKS_MARKDOWNFEATURE) == FALSE) &&
		(MarkdownVariations::supports(variation, IMAGES_MARKDOWNFEATURE) == FALSE))
		return;
	if (tracing_Markdown_parser) {
		PRINT("Beginning link/image pass:\n");
		Markdown::debug_subtree(STDOUT, owner);
	}
	md_charpos leftmost_pos = Markdown::left_edge_of(owner->down);
	while (TRUE) {
		if (tracing_Markdown_parser) {
			if (Markdown::somewhere(leftmost_pos)) {
				PRINT("Link/image notation scan from %c\n",
					Markdown::get(leftmost_pos));
				Markdown::debug_subtree(STDOUT, leftmost_pos.md);
			} else {
				PRINT("Link/image notation scan from start\n");
			}
		}
		md_link_parse found = MDInlineParser::first_valid_link(variation,
			link_refs, leftmost_pos, Markdown::nowhere(), images_only, FALSE);
		if (found.is_link == NOT_APPLICABLE) break;
		md_link_dictionary_entry *ref = found.link_reference;
		if (tracing_Markdown_parser) {
			PRINT("Link matter: ");
			if (found.link_text_empty) PRINT("EMPTY\n");
			else Markdown::debug_interval(STDOUT, found.link_text_from, found.link_text_to);
			if (ref) {
				PRINT("Link destination (reference): %S\n", ref->destination);
				PRINT("Link title (reference): %S\n", ref->title);
			} else {
				PRINT("Link destination: ");
				if (found.link_destination_empty) PRINT("EMPTY\n");
				else Markdown::debug_interval(STDOUT, found.link_destination_from, found.link_destination_to);
				PRINT("Link title: ");
				if (found.link_title_empty) PRINT("EMPTY\n");
				else Markdown::debug_interval(STDOUT, found.link_title_from, found.link_title_to);
			}
		}
		@<Deal with a valid link or image@>;
	}
}

@ The following structure holds the findings of |MDInlineParser::first_valid_link|
if it succeeds. Note that a link/image which makes a reference is only syntactically
valid if the reference matches something in the dictionary.

It might seem redundant to have the |*_empty| fields below, but there are some
awkward cases where, as a result of earlier splicing, it's difficult to represent
nonexistent text with |md_charpos| structs.

=
typedef struct md_link_parse {
	int is_link; /* |TRUE| for link, |FALSE| for image, |NOT_APPLICABLE| for fail */
	struct md_charpos first;                  /* leftmost character of the whole construct */
	struct md_charpos link_text_from;         /* leftmost character inside the squares */
	struct md_charpos link_text_to;           /* ...and so on */
	int link_text_empty;                      /* |TRUE| or |FALSE| */
	struct md_charpos link_destination_from;
	struct md_charpos link_destination_to;
	int link_destination_empty;
	struct md_charpos link_title_from;
	struct md_charpos link_title_to;
	int link_title_empty;
	struct md_link_dictionary_entry *link_reference; /* or |NULL| if it's not by reference */
	struct md_charpos last; /* rightmost character of the whole construct */
} md_link_parse;

@ See //Markdown// for how all this splicing is done.

@<Deal with a valid link or image@> =
	markdown_item *chain = owner->down, *found_text = NULL, *remainder = NULL;
	Markdown::cut_interval(chain, found.first, found.last, &chain, &found_text, &remainder);

	markdown_item *link_text = NULL;
	markdown_item *link_destination = NULL;
	markdown_item *link_title = NULL;
	if (found.link_text_empty == FALSE)
		Markdown::cut_interval(found_text, found.link_text_from, found.link_text_to,
			NULL, &link_text, &found_text);
	if ((Markdown::somewhere(found.link_destination_from)) &&
		(found.link_destination_empty == FALSE))
		Markdown::cut_interval(found_text, found.link_destination_from, found.link_destination_to,
			NULL, &link_destination, &found_text);
	if ((Markdown::somewhere(found.link_title_from)) && (found.link_title_empty == FALSE))
		Markdown::cut_interval(found_text, found.link_title_from, found.link_title_to,
			NULL, &link_title, &found_text);
	markdown_item *link_item = Markdown::new_item((found.is_link == TRUE)?LINK_MIT:IMAGE_MIT);
	markdown_item *matter = Markdown::new_item(MATERIAL_MIT);
	if (found.link_text_empty == FALSE) matter->down = link_text;
	Markdown::add_to(matter, link_item);
	if (found.is_link == TRUE) MDInlineParser::links_and_images(variation, link_refs, matter, TRUE);
	else MDInlineParser::links_and_images(variation, link_refs, matter, FALSE);
	if (ref) {
		if (Str::len(ref->destination) > 0) {
			markdown_item *dest_item = Markdown::new_item(LINK_DEST_MIT);
			dest_item->down = Markdown::new_slice(PLAIN_MIT, ref->destination, 0, Str::len(ref->destination)-1);
			Markdown::add_to(dest_item, link_item);
		}
		if (Str::len(ref->title) > 0) {
			markdown_item *title_item = Markdown::new_item(LINK_TITLE_MIT);
			title_item->down = Markdown::new_slice(PLAIN_MIT, ref->title, 0, Str::len(ref->title)-1);
			Markdown::add_to(title_item, link_item);
		}
	} else {
		if (link_destination) {
			markdown_item *dest_item = Markdown::new_item(LINK_DEST_MIT);
			if (found.link_destination_empty == FALSE) dest_item->down = link_destination;
			Markdown::add_to(dest_item, link_item);
		}
		if (link_title) {
			markdown_item *title_item = Markdown::new_item(LINK_TITLE_MIT);
			if (found.link_title_empty == FALSE) title_item->down = link_title;
			Markdown::add_to(title_item, link_item);
		}
	}
	if (chain) {
		owner->down = chain;
		while (chain->next) chain = chain->next; chain->next = link_item;
	} else {
		owner->down = link_item;
	}
	link_item->next = remainder;
	if (tracing_Markdown_parser) {
		PRINT("After link surgery:\n");
		Markdown::debug_subtree(STDOUT, owner);
	}
	leftmost_pos = Markdown::left_edge_of(remainder);

@ Okay, so it's time to go looking for the leftmost valid link or image in
the given part of a chain of nodes. Links begin with an unescaped |[|
and images with an unescaped |![|.

=
md_link_parse MDInlineParser::first_valid_link(markdown_variation *variation,
	md_links_dictionary *link_refs, md_charpos from, md_charpos to,
	int images_only, int links_only) {
	md_link_parse result;
	@<Initialise the parse result to a no@>;
	inchar32_t prev_c = 0;
	md_charpos prev_pos = Markdown::nowhere();
	int escaped = FALSE;
	while ((Markdown::somewhere(from)) && (Markdown::plainish(from.md) == FALSE))
		from = Markdown::advance_up_to(from, to);
	for (md_charpos pos = from; Markdown::somewhere(pos); pos = Markdown::advance_up_to(pos, to)) {
		inchar32_t c = Markdown::get(pos);
		if ((c == '\\') && (escaped == FALSE)) escaped = TRUE;
		else {
			if ((c == '[') && (escaped == FALSE)) {
				md_charpos pass_pos = pos;
				for (int pass=1; pass<=2; pass++) {
					if (tracing_Markdown_parser) {
						PRINT("Pass %d: at ", pass);
						Markdown::debug_pos(STDOUT, pos);
						PRINT("\n");
					}
					if (pass == 2) pos = pass_pos;
					@<See if a link begins here@>;
					AbandonHope: ;
				}
			}
			if (escaped == FALSE) {
				prev_c = c;
				prev_pos = pos;	
			}
			escaped = FALSE;
		}
	}
	return result;
}

@<Initialise the parse result to a no@> =
	result.is_link = NOT_APPLICABLE;
	result.first = Markdown::nowhere();
	result.link_text_from = Markdown::nowhere();
	result.link_text_to = Markdown::nowhere();
	result.link_text_empty = NOT_APPLICABLE;
	result.link_destination_from = Markdown::nowhere();
	result.link_destination_to = Markdown::nowhere();
	result.link_destination_empty = NOT_APPLICABLE;
	result.link_title_from = Markdown::nowhere();
	result.link_title_to = Markdown::nowhere();
	result.link_title_empty = NOT_APPLICABLE;
	result.link_reference = FALSE;
	result.last = Markdown::nowhere();

@

@d ABANDON_LINK(reason)
	{ if (tracing_Markdown_parser) { PRINT("Link abandoned: %s\n", reason); }
	pos = abandon_at; goto AbandonHope; }

@<See if a link begins here@> =
	if (((links_only == FALSE) || (prev_c != '!')) &&
		((images_only == FALSE) || (prev_c == '!'))) {
		int link_rather_than_image = TRUE, uses = LINKS_MARKDOWNFEATURE;
		result.first = pos;
		if ((prev_c == '!') && (links_only == FALSE)) {
			link_rather_than_image = FALSE;
			uses = IMAGES_MARKDOWNFEATURE;
			result.first = prev_pos;
		}
		if (MarkdownVariations::supports(variation, uses)) {
			if (link_rather_than_image) {
				if (tracing_Markdown_parser) PRINT("Potential link found\n");
			} else {
				if (tracing_Markdown_parser) PRINT("Potential image found\n");
			}
			md_charpos abandon_at = pos;
			@<Work out the link text@>;
			if (Markdown::get(pos) == '[') {
				@<Work out the reference@>;
			} else {
				if ((Markdown::get(pos) != '(') || (pass == 2)) {
					TEMPORARY_TEXT(label)
					for (md_charpos pos = result.link_text_from; Markdown::somewhere(pos);
						pos = Markdown::advance(pos)) {
						PUT_TO(label, Markdown::get(pos));
						if (Markdown::pos_eq(pos, result.link_text_to)) break;
					}
					@<Deal with escape characters in the label@>;
					md_link_dictionary_entry *ref = Markdown::look_up(link_refs, label);
					if (ref == NULL) ABANDON_LINK("no '(' and not a valid reference");
					result.link_reference = ref;
					pos = result.link_text_to;
					pos = Markdown::advance_up_to(pos, to);
					DISCARD_TEXT(label)
				} else {
					pos = Markdown::advance_up_to_quasi_plainish_only(pos, to);
					@<Advance pos by optional small amount of white space@>;
					if (Markdown::get(pos) != ')') @<Work out the link destination@>;
					@<Advance pos by optional small amount of white space@>;
					if (Markdown::get(pos) != ')') @<Work out the link title@>;
					@<Advance pos by optional small amount of white space@>;
					if (Markdown::get(pos) != ')') ABANDON_LINK("no ')'");
				}
			}
			result.last = pos;
			result.is_link = link_rather_than_image;
			if (tracing_Markdown_parser) PRINT("Confirmed\n");
			return result;
		}
	}

@<Work out the link text@> =
	inchar32_t c = Markdown::get(pos);
	md_charpos prev_pos = pos;
	result.link_text_from = Markdown::advance_up_to(pos, to);
	inchar32_t prev_c = 0;
	int bl = 0, count = 0, escaped = FALSE;
	while (c != 0) {
		if ((c == '\\') && (escaped == FALSE)) {
			escaped = TRUE;
		} else {
			count++;
			if ((c == '[') && (escaped == FALSE)) bl++;
			if ((c == ']') && (escaped == FALSE)) { bl--; if (bl == 0) break; }
			escaped = FALSE;
		}
			prev_pos = pos;
			prev_c = c;
			pos = Markdown::advance_up_to(pos, to);
			c = Markdown::get(pos);
	}
	if (c == 0) { pos = abandon_at; ABANDON_LINK("no end to linked matter"); }
	result.link_text_empty = (count<=2)?TRUE:FALSE;
	result.link_text_to = prev_pos;
	if (link_rather_than_image) {
		md_link_parse nested =
			MDInlineParser::first_valid_link(variation, link_refs,
				result.link_text_from, result.link_text_to, FALSE, TRUE);
		if (nested.is_link != NOT_APPLICABLE) return nested;
	}
	pos = Markdown::advance_up_to_plainish_only(pos, to);

@<Work out the reference@> =
	md_charpos prev_pos = pos;
	pos = Markdown::advance_up_to_plainish_only(pos, to);
	result.link_destination_from = pos;
	inchar32_t prev_c = 0;
	int bl = 1, escaping = FALSE;
	TEMPORARY_TEXT(label)
	inchar32_t c = Markdown::get(pos);
	while (c != 0) {
		if ((c == '\\') && (escaping == FALSE)) {
			escaping = TRUE;
		} else {
			if (escaping) {
				if ((c != '[') && (c != ']') && (c != '\\')) PUT_TO(label, '\\');
			} else {
				if (c == '[') bl++;
				if (c == ']') { bl--; if (bl == 0) break; }
			}
			PUT_TO(label, c);
			escaping = FALSE;
		}
		prev_pos = pos;
		prev_c = c;
		pos = Markdown::advance_up_to_plainish_only(pos, to);
		c = Markdown::get(pos);
	}
	if (c == 0) { pos = abandon_at; ABANDON_LINK("no end to reference"); }
	if (Str::len(label) == 0) {
		for (md_charpos pos = result.link_text_from; Markdown::somewhere(pos);
			pos = Markdown::advance(pos)) {
			PUT_TO(label, Markdown::get(pos));
			if (Markdown::pos_eq(pos, result.link_text_to)) break;
		}
	}
	md_link_dictionary_entry *ref = Markdown::look_up(link_refs, label);
	if (ref == NULL) ABANDON_LINK("unknown reference");
	result.link_reference = ref;

@ Note that only square brackets and backslashes can be escaped in a link
or image reference label, not other ASCII punctuation.

@<Deal with escape characters in the label@> =
	TEMPORARY_TEXT(to)
	for (int i=0; i<Str::len(label); i++) {
		if ((Str::get_at(label, i) == '\\') &&
			((Str::get_at(label, i+1) == '[') ||
				(Str::get_at(label, i+1) == '\\') ||
				(Str::get_at(label, i+1) == ']')))
			i++;
		PUT_TO(to, Str::get_at(label, i));
	}
	Str::clear(label); WRITE_TO(label, "%S", to);
	DISCARD_TEXT(to)

@<Work out the link destination@> =
	if (Markdown::get(pos) == '<') {
		pos = Markdown::advance_up_to_quasi_plainish_only(pos, to);
		result.link_destination_from = pos;
		int empty = TRUE;
		inchar32_t prev_c = 0;
		while ((Markdown::get(pos) != '>') || (prev_c == '\\')) {
			if (Markdown::get(pos) == 0) ABANDON_LINK("no end to destination in angles");
			if (Markdown::get(pos) == '<') ABANDON_LINK("'<' in destination in angles");
			if (Markdown::get(pos) == '\n') ABANDON_LINK("reference includes line end");
			prev_pos = pos; prev_c = Markdown::get(pos);
			pos = Markdown::advance_up_to_quasi_plainish_only(pos, to); empty = FALSE;
		}
		result.link_destination_empty = empty;
		result.link_destination_to = prev_pos;
		pos = Markdown::advance_up_to_quasi_plainish_only(pos, to);
		if ((Markdown::get(pos) == '"') || (Markdown::get(pos) == '\'') ||
			(Markdown::get(pos) == '(')) ABANDON_LINK("no gap between destination and title");
	} else {
		result.link_destination_from = pos;
		int bl = 1;
		inchar32_t prev_c = 0;
		md_charpos prev_pos = pos;
		int empty = TRUE;
		while ((Markdown::get(pos) != ' ') && (Markdown::get(pos) != '\n') &&
			(Markdown::get(pos) != '\t')) {
			inchar32_t c = Markdown::get(pos);
			if ((c == '(') && (prev_c != '\\')) bl++;
			if ((c == ')') && (prev_c != '\\')) { bl--; if (bl == 0) break; }
			if (c == 0) ABANDON_LINK("no end to destination");
			if (Characters::is_control_character(c)) ABANDON_LINK("control character in destination");
			prev_pos = pos;
			prev_c = c;
			pos = Markdown::advance_up_to_quasi_plainish_only(pos, to); empty = FALSE;
		}
		result.link_destination_empty = empty;
		result.link_destination_to = prev_pos;
		if ((Markdown::get(pos) == '"') || (Markdown::get(pos) == '\'') ||
			(Markdown::get(pos) == '(')) ABANDON_LINK("no gap between destination and title");
	}

@<Work out the link title@> =
	if (Markdown::get(pos) == '"') {
		pos = Markdown::advance_up_to_plainish_only(pos, to);
		result.link_title_from = pos;
		inchar32_t prev_c = 0;
		md_charpos prev_pos = pos;
		int empty = TRUE;
		inchar32_t c = Markdown::get(pos);
		while (c != 0) {
			inchar32_t c = Markdown::get(pos);
			if ((c == '"') && (prev_c != '\\')) break;
			prev_pos = pos;
			prev_c = c;
			pos = Markdown::advance_up_to_plainish_only(pos, to); empty = FALSE;
		}
		if (c == 0) ABANDON_LINK("no end to title");
		result.link_title_empty = empty;
		result.link_title_to = prev_pos;
		pos = Markdown::advance_up_to_plainish_only(pos, to);
	}
	else if (Markdown::get(pos) == '\'') {
		pos = Markdown::advance_up_to_plainish_only(pos, to);
		result.link_title_from = pos;
		inchar32_t prev_c = 0;
		md_charpos prev_pos = pos;
		int empty = TRUE;
		inchar32_t c = Markdown::get(pos);
		while (c != 0) {
			inchar32_t c = Markdown::get(pos);
			if ((c == '\'') && (prev_c != '\\')) break;
			prev_pos = pos;
			prev_c = c;
			pos = Markdown::advance_up_to_plainish_only(pos, to); empty = FALSE;
		}
		if (c == 0) ABANDON_LINK("no end to title");
		result.link_title_empty = empty;
		result.link_title_to = prev_pos;
		pos = Markdown::advance_up_to_plainish_only(pos, to);
	}
	else if (Markdown::get(pos) == '(') {
		pos = Markdown::advance_up_to(pos, to);
		result.link_title_from = pos;
		inchar32_t prev_c = 0;
		md_charpos prev_pos = pos;
		int empty = TRUE;
		inchar32_t c = Markdown::get(pos);
		while (c != 0) {
			inchar32_t c = Markdown::get(pos);
			if ((c == '(') && (prev_c != '\\')) ABANDON_LINK("unescaped '(' in title");
			if ((c == ')') && (prev_c != '\\')) break;
			prev_pos = pos;
			prev_c = c;
			pos = Markdown::advance_up_to(pos, to); empty = FALSE;
		}
		if (c == 0) ABANDON_LINK("no end to title");
		result.link_title_empty = empty;
		result.link_title_to = prev_pos;
		pos = Markdown::advance_up_to_plainish_only(pos, to);
	}

@<Advance pos by optional small amount of white space@> =
	int line_endings = 0;
	inchar32_t c = Markdown::get(pos);
	while ((c == ' ') || (c == '\t') || (c == '\n')) {
		if (c == '\n') { line_endings++; if (line_endings >= 2) break; }
		pos = Markdown::advance_up_to_quasi_plainish_only(pos, to);
		c = Markdown::get(pos);
	}

@h Emphasis.
Well, that was easy. Now for the hardest pass, in which we look for the use
of asterisks and underscores for emphasis. This notation is deeply ambiguous
on its face, and CommonMark's precise specification is a bit of an ordeal,
but here goes.

@d ASTERISK_EMPHASIS_BIT 1
@d UNDERSCORE_EMPHASIS_BIT 2
@d TILDE_STRIKETHROUGH_BIT 4

=
void MDInlineParser::emphasis(markdown_variation *variation, markdown_item *owner,
	int mask) {
	for (markdown_item *md = owner->down; md; md = md->next)
		if ((md->type == LINK_MIT) || (md->type == IMAGE_MIT))
			MDInlineParser::emphasis(variation, md->down, mask);
	text_stream *OUT = STDOUT;
	if (tracing_Markdown_parser) {
		WRITE("Seeking emphasis (%d) in:\n", mask);
		INDENT;
		Markdown::debug_subtree(STDOUT, owner);
	}
	@<Seek emphasis@>;
	if (tracing_Markdown_parser) {
		OUTDENT;
		WRITE("Emphasis search complete\n");
	}
}

@ "A delimiter run is either a sequence of one or more * characters that is not
preceded or followed by a non-backslash-escaped * character, or a sequence of
one or more _ characters that is not preceded or followed by a
non-backslash-escaped _ character."

This function returns 0 unless a delimiter run begins at |at|, and then returns
its length if this was asterisked, and minus its length if underscored.

The GitHub extension to CommonMark for tildes meaning strikethrough is restricted
to runs of length 1 or 2, and we return those as 10000001 and 10000002.

=
int MDInlineParser::delimiter_run(md_charpos pos, int mask) {
	int count = 0;
	if (mask & ASTERISK_EMPHASIS_BIT) {
		count = Markdown::unescaped_run(pos, '*');
		if ((count > 0) && (Markdown::get_unescaped(pos, -1) != '*')) return count;
	}
	if (mask & UNDERSCORE_EMPHASIS_BIT) {
		count = Markdown::unescaped_run(pos, '_');
		if ((count > 0) && (Markdown::get_unescaped(pos, -1) != '_')) return -count;
	}
	if (mask & TILDE_STRIKETHROUGH_BIT) {
		count = Markdown::unescaped_run(pos, '~');
		if ((count >= 1) && (count <= 2) && (Markdown::get_unescaped(pos, -1) != '~'))
			return 10000000 + count;
	}
	return 0;
}

@ "A left-flanking delimiter run is a delimiter run that is (1) not followed by
Unicode whitespace, and either (2a) not followed by a Unicode punctuation
character, or (2b) followed by a Unicode punctuation character and preceded by
Unicode whitespace or a Unicode punctuation character. For purposes of this
definition, the beginning and the end of the line count as Unicode whitespace."

"A right-flanking delimiter run is a delimiter run that is (1) not preceded by
Unicode whitespace, and either (2a) not preceded by a Unicode punctuation
character, or (2b) preceded by a Unicode punctuation character and followed by
Unicode whitespace or a Unicode punctuation character. For purposes of this
definition, the beginning and the end of the line count as Unicode whitespace."

=
int MDInlineParser::left_flanking(md_charpos pos, int count) {
	if (count == 0) return FALSE;
	if (count < 0) count = -count;
	inchar32_t followed_by = Markdown::get_unescaped(pos, count);
	if ((followed_by == 0) || (Characters::is_Unicode_whitespace(followed_by))) return FALSE;
	if (Characters::is_Unicode_punctuation(followed_by) == FALSE) return TRUE;
	inchar32_t preceded_by = Markdown::get_unescaped(pos, -1);
	if ((preceded_by == 0) || (Characters::is_Unicode_whitespace(preceded_by)) ||
		(Characters::is_Unicode_punctuation(preceded_by))) return TRUE;
	return FALSE;
}

int MDInlineParser::right_flanking(md_charpos pos, int count) {
	if (count == 0) return FALSE;
	if (count < 0) count = -count;
	inchar32_t preceded_by = Markdown::get_unescaped(pos, -1);
	if ((preceded_by == 0) || (Characters::is_Unicode_whitespace(preceded_by))) return FALSE;
	if (Characters::is_Unicode_punctuation(preceded_by) == FALSE) return TRUE;
	inchar32_t followed_by = Markdown::get_unescaped(pos, count);
	if ((followed_by == 0) || (Characters::is_Unicode_whitespace(followed_by)) ||
		(Characters::is_Unicode_punctuation(followed_by))) return TRUE;
	return FALSE;
}

@ The following expresses rules (1) to (8) in the CM specification, section 6.2.

=
int MDInlineParser::can_open_emphasis(md_charpos pos, int count) {
	if (MDInlineParser::left_flanking(pos, count) == FALSE) return FALSE;
	if (count > 0) return TRUE;
	if (MDInlineParser::right_flanking(pos, count) == FALSE) return TRUE;
	inchar32_t preceded_by = Markdown::get_unescaped(pos, -1);
	if (Characters::is_Unicode_punctuation(preceded_by)) return TRUE;
	return FALSE;
}

int MDInlineParser::can_close_emphasis(md_charpos pos, int count) {
	if (MDInlineParser::right_flanking(pos, count) == FALSE) return FALSE;
	if (count > 0) return TRUE;
	if (MDInlineParser::left_flanking(pos, count) == FALSE) return TRUE;
	inchar32_t followed_by = Markdown::get_unescaped(pos, -count); /* count < 0 here */
	if (Characters::is_Unicode_punctuation(followed_by)) return TRUE;
	return FALSE;
}

@ This naive algorithm has every possibility of becoming computationally
explosive if a really knotty tangle of nested emphasis delimiters comes along,
though of course that is a rare occurrence. We're going to find every possible
way to pair opening and closing delimiters, and then score the results with a
system of penalties. Whichever solution has the least penalty is the winner.

In almost every example of normal Markdown written by actual human beings,
there will be just one open/close option at a time.

@d MAX_MD_EMPHASIS_PAIRS (MAX_MD_EMPHASIS_DELIMITERS*MAX_MD_EMPHASIS_DELIMITERS)

@<Seek emphasis@> =
	int no_delimiters = 0;
	md_emphasis_delimiter delimiters[MAX_MD_EMPHASIS_DELIMITERS];
	@<Find the possible emphasis delimiters@>;

	markdown_item *options[MAX_MD_EMPHASIS_DELIMITERS];
	int no_options = 0;
	for (int open_i = 0; open_i < no_delimiters; open_i++) {
		md_emphasis_delimiter *OD = &(delimiters[open_i]);
		if (OD->can_open == FALSE) continue;
		for (int close_i = open_i+1; close_i < no_delimiters; close_i++) {
			md_emphasis_delimiter *CD = &(delimiters[close_i]);
			if (CD->can_close == FALSE) continue;
			@<Reject this as a possible closer if it cannot match the opener@>;
			if (tracing_Markdown_parser) {
				WRITE("Option %d is to pair D%d with D%d\n", no_options, open_i, close_i);
			}
			@<Create the subtree which would result from this option being chosen@>;
		}
	}
	if (no_options > 0) @<Select the option with the lowest penalty@>;

@ We don't want to find every possible delimiter, in case the source text is
absolutely huge: indeed, we never exceed |MAX_MD_EMPHASIS_DELIMITERS|.

A further optimisation is that (a) we needn't even record delimiters which
can't open or close, (b) or delimiters which can only close and which occur
before any openers, (c) or anything after a point where we can clearly complete
at least one pair correctly.

For example, consider |This is *emphatic* and **so is this**.| Rule (c) makes
it unnecessary to look past the end of the word "emphatic", because by that
point we have seen an opener which cannot close and a closer which cannot open,
of equal widths. These can only pair with each other; so we can stop.

As a result, in almost all human-written Markdown, the algorithm below returns
exactly two delimiters, one open, one close.

In other situations, it's harder to predict what will happen. We will contain
the possible explosion by restricting to cases where at least one pair can be
made within the first |MAX_MD_EMPHASIS_DELIMITERS| potential delimiters, and
we can pretty safely keep that number small.

@d MAX_MD_EMPHASIS_DELIMITERS 10

=
typedef struct md_emphasis_delimiter {
	struct md_charpos pos; /* first character in the run */
	int width;             /* for example, 7 for a run of seven asterisks */
	int type;              /* 1 for asterisks, -1 for underscores, 0 for tildes */
	int can_open;          /* result of |MDInlineParser::can_open_emphasis| on it */
	int can_close;         /* result of |MDInlineParser::can_close_emphasis| on it */
	CLASS_DEFINITION
} md_emphasis_delimiter;

@<Find the possible emphasis delimiters@> =
	int open_count[3] = { 0, 0, 0 }, close_count[3] = { 0, 0, 0 }, both_count[3] = { 0, 0, 0 };
	md_charpos from = Markdown::left_edge_of(owner->down);
	while ((Markdown::somewhere(from)) && (Markdown::plainish(from.md) == FALSE))
		from = Markdown::advance(from);
	for (md_charpos pos = from; Markdown::somewhere(pos); pos = Markdown::advance(pos)) {
		int run = MDInlineParser::delimiter_run(pos, mask);
		if (run != 0) {
			if (no_delimiters >= MAX_MD_EMPHASIS_DELIMITERS) break;
			int run_combined = run;
			if (run > 10000000) run_combined = run - 10000000;
			int can_open = MDInlineParser::can_open_emphasis(pos, run_combined);
			int can_close = MDInlineParser::can_close_emphasis(pos, run_combined);
			if ((no_delimiters == 0) && (can_open == FALSE)) continue;
			if ((can_open == FALSE) && (can_close == FALSE)) continue;
			md_emphasis_delimiter *P = &(delimiters[no_delimiters++]);
			P->pos = pos;
			P->width = (run_combined>0)?run_combined:(-run_combined);
			P->type = (run_combined>0)?1:-1;
			if (run > 10000000) P->type = 0;
			P->can_open = can_open;
			P->can_close = can_close;
			if (tracing_Markdown_parser) {
				WRITE("DR%d at ", no_delimiters);
				Markdown::debug_pos(OUT, pos);
				WRITE(" width %d type %d", P->width, P->type);
				if (MDInlineParser::left_flanking(pos, run_combined)) WRITE(", left-flanking");
				if (MDInlineParser::right_flanking(pos, run_combined)) WRITE(", right-flanking");
				if (P->can_open) WRITE(", can-open");
				if (P->can_close) WRITE(", can-close");
				WRITE(", preceded by ");
				Markdown::debug_char(OUT, Markdown::get_unescaped(P->pos, -1));
				WRITE(", followed by ");
				Markdown::debug_char(OUT, Markdown::get_unescaped(P->pos, P->width));
				WRITE("\n");
			}
			int x = (P->type>0)?0:1;
			if (P->type == 0) x = 2;
			if ((can_open) && (can_close == FALSE)) open_count[x] += P->width;
			if ((can_open == FALSE) && (can_close)) close_count[x] += P->width;
			if ((can_open) && (can_close)) both_count[x] += P->width;
			if ((both_count[0] == 0) && (open_count[0] == close_count[0]) &&
				(both_count[1] == 0) && (open_count[1] == close_count[1]) &&
				(both_count[2] == 0) && (open_count[2] == close_count[2])) break;
		}
	}

@ We vet |OD| and |CD| to see if it's possible to pair them together. We
already know that |OD| can open and |CD| can close, and that |OD| precedes
|CD| ("The opening and closing delimiters must belong to separate delimiter
runs."). They must have the same type: asterisk pair with asterisks, underscores
with underscores.

That's when the CommonMark specification becomes kind of hilarious: "If one of
the delimiters can both open and close emphasis, then the sum of the lengths of
the delimiter runs containing the opening and closing delimiters must not be a
multiple of 3 unless both lengths are multiples of 3."

@<Reject this as a possible closer if it cannot match the opener@> =
	if (CD->type != OD->type) continue;
	if ((CD->can_open) || (OD->can_close)) {
		int sum = OD->width + CD->width;
		if (sum % 3 == 0) {
			if (OD->width % 3 != 0) continue;
			if (CD->width % 3 != 0) continue;
		}
	}

@ Okay, so now |OD| and |CD| are conceivable pairs to each other, and we
investigate the consequences. We need to copy the existing situation so
that we can alter it without destroying the original.

Note the two recursive uses of |MDInlineParser::emphasis| to continue
the process of pairing: this is where the computational fuse is lit, with
the explosion to follow. But since each subtree contains fewer delimiter runs
than the original, it does at least terminate.

@<Create the subtree which would result from this option being chosen@> =
	markdown_item *option = Markdown::deep_copy(owner);
	options[no_options++] = option;
	markdown_item *OI = NULL, *CI = NULL;
	for (markdown_item *md = option->down; md; md = md->next) {
		if (md->copied_from == OD->pos.md) OI = md;
		if (md->copied_from == CD->pos.md) CI = md;
	}
	if ((OI == NULL) || (CI == NULL)) internal_error("copy accident");

	int width; /* number of delimiter characters we will trim */
	md_charpos first_trimmed_char_left;
	md_charpos last_trimmed_char_left;
	md_charpos first_trimmed_char_right;
	md_charpos last_trimmed_char_right;
	@<Draw the dotted lines where we will cut@>;

	@<Deactivate the active characters being acted on@>;

	markdown_item *em_top, *em_bottom;
	@<Make the chain of emphasis items from top to bottom@>;
	@<Perform the tree surgery to insert the emphasis item@>;

	MDInlineParser::emphasis(variation, em_bottom, mask);
	MDInlineParser::emphasis(variation, option, mask);

	if (tracing_Markdown_parser) {
		WRITE("Option %d is to fragment thus:\n", no_options);
		Markdown::debug_subtree(STDOUT, option);
		WRITE("Resulting in: ");
		Markdown::render_extended(STDOUT, option, variation);
		WRITE("\nWhich scores %d penalty points\n", MDInlineParser::penalty(option));
	}

@ This innocent-looking code is very tricky. The issue is that the two delimiters
may be of unequal width. We want to take as many asterisks/underscores away
as we can, so we set |width| to the minimum of the two lengths. But a complication
is that they need to be cropped to fit inside the slice of the node they belong
to first.

We then mark to remove |width| characters from the inside edges of each
delimiter, not the outside edges.

@<Draw the dotted lines where we will cut@> =
	int O_start = OD->pos.at, O_width = OD->width;
	if (O_start < OI->from) { O_width -= (OI->from - O_start); O_start = OI->from; }

	int C_start = CD->pos.at, C_width = CD->width;
	if (C_start + C_width - 1 > CI->to) { C_width = CI->to - C_start + 1; }

	width = O_width; if (width > C_width) width = C_width;

	first_trimmed_char_left = Markdown::pos(OI, O_start + O_width - width);
	last_trimmed_char_left = Markdown::pos(OI, O_start + O_width - 1);
	first_trimmed_char_right = Markdown::pos(CI, C_start);
	last_trimmed_char_right = Markdown::pos(CI, C_start + width - 1);

	if (tracing_Markdown_parser) {
		WRITE(" first left = "); Markdown::debug_pos(OUT, first_trimmed_char_left);
		WRITE("\n  last left = "); Markdown::debug_pos(OUT, last_trimmed_char_left);
		WRITE("\nfirst right = "); Markdown::debug_pos(OUT, first_trimmed_char_right);
		WRITE("\n last right = "); Markdown::debug_pos(OUT, last_trimmed_char_right);
		WRITE("\n");
	}

@<Deactivate the active characters being acted on@> =
	for (int w=0; w<width; w++) {
		Markdown::put_offset(first_trimmed_char_left, w, ':');
		Markdown::put_offset(first_trimmed_char_right, w, ':');
	}

@ Suppose we are peeling away 5 asterisks from the inside edges of each delimiter,
so that |width| is 5. There are only two strengths of emphasis in Markdown, so
this must be read as one of the various ways to add 1s and 2s to make 5.
CommonMark rule 13 reads "The number of nestings should be minimized.", so we
must use all 2s except for the 1 left over. Rule 14 says that left-over 1 must
be outermost. So this would give us:
= (text)
	EMPHASIS_MIT  <--- this is em_top
		STRONG_MIT
			STRONG_MIT  <--- this is em_bottom
				...the actual content being emphasised
=

@<Make the chain of emphasis items from top to bottom@> =
	if (OD->type == 0) {
		em_top = Markdown::new_item(STRIKETHROUGH_MIT);
		em_bottom = em_top;
	} else {
		em_top = Markdown::new_item(((width%2) == 1)?EMPHASIS_MIT:STRONG_MIT);
		if ((width%2) == 1) width -= 1; else width -= 2;
		em_bottom = em_top;
		while (width > 0) {
			markdown_item *g = Markdown::new_item(STRONG_MIT); width -= 2;
			em_bottom->down = g; em_bottom = g;
		}
	}

@<Perform the tree surgery to insert the emphasis item@> =
	markdown_item *chain = option->down;
	if (tracing_Markdown_parser) {
		Markdown::debug_chain_label(OUT, chain, I"Before surgery");
	}
	markdown_item *before_emphasis = NULL, *emphasis = NULL, *after_emphasis = NULL;
	Markdown::cut_to_just_before(chain, first_trimmed_char_left,
		&before_emphasis, &emphasis);
	Markdown::cut_to_just_at(emphasis, last_trimmed_char_left,
		NULL, &emphasis);
	Markdown::cut_to_just_before(emphasis, first_trimmed_char_right,
		&emphasis, &after_emphasis);
	Markdown::cut_to_just_at(after_emphasis, last_trimmed_char_right,
		NULL, &after_emphasis);

	if (tracing_Markdown_parser) {
		Markdown::debug_chain_label(OUT, before_emphasis, I"Before emphasis");
		Markdown::debug_chain_label(OUT, emphasis, I"Emphasis");
		Markdown::debug_chain_label(OUT, after_emphasis, I"After emphasis");
	}

	option->down = before_emphasis;
	if (option->down) {
		chain = option->down;
		while ((chain) && (chain->next)) chain = chain->next;
		chain->next = em_top;
	} else {
		option->down = em_top;
	}
	em_top->next = after_emphasis;
	em_bottom->down = emphasis;

@<Select the option with the lowest penalty@> =
	int best_is = 1, best_score = 100000000;
	for (int pair_i = 0; pair_i < no_options; pair_i++) {
		int score = MDInlineParser::penalty(options[pair_i]);
		if (score < best_score) { best_score = score; best_is = pair_i; }
	}
	if (tracing_Markdown_parser) {
		WRITE("Selected option %d with penalty %d\n", best_is, best_score);
	}
	owner->down = options[best_is]->down;

@ That just leaves the penalty scoring system: how unfortunate is a possible
reading of the Markdown syntax?

We score a whopping penalty for any unescaped asterisks and underscores left
over, because above all we want to pair as many delimiters as possible together.
(Some choices of pairings preclude others: it's a messy dynamic programming
problem to work this out in detail.)

We then impose a modest penalty on the width of a piece of emphasis, in
order to achieve CommonMark's rule 16: "When there are two potential emphasis
or strong emphasis spans with the same closing delimiter, the shorter one
(the one that opens later) takes precedence."

=
int MDInlineParser::penalty(markdown_item *md) {
	if (md) {
		int penalty = 0;
		if (md->type == PLAIN_MIT) {
			for (int i=md->from; i<=md->to; i++) {
				md_charpos pos = Markdown::pos(md, i);
				inchar32_t c = Markdown::get_unescaped(pos, 0);
				if ((c == '*') || (c == '_')) penalty += 100000;
			}
		}
		if ((md->type == EMPHASIS_MIT) || (md->type == STRONG_MIT))
			penalty += Markdown::width(md->down);
		for (markdown_item *c = md->down; c; c = c->next)
			penalty += MDInlineParser::penalty(c);
		return penalty;
	}
	return 0;
}
