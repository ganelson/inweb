[WebSyntax::] Web Syntax.

To manage possible syntaxes for webs.

@h Introduction.
Inweb syntax has gradually shifted over the years, but there are two main
versions: the second was cleaned up and simplified from the first in 2019.
A third version for a simplified Markdown-based approach was added
experimentally in 2024.

@e V1_SYNTAX from 1
@e V2_SYNTAX
@e MD_SYNTAX

=
typedef struct web_syntax {
	int actual_number;
	CLASS_DEFINITION
} web_syntax;

@

=
web_syntax *old_Inweb_syntax = NULL;
web_syntax *new_Inweb_syntax = NULL;

void WebSyntax::create(void) {
	old_Inweb_syntax = CREATE(web_syntax);
	old_Inweb_syntax->actual_number = 1;
	new_Inweb_syntax = CREATE(web_syntax);
	new_Inweb_syntax->actual_number = 2;
}

int WebSyntax::default(void) {
	return V2_SYNTAX;
}

int WebSyntax::parse_internal_declaration(text_stream *line, text_file_position *tfp, text_stream *title, text_stream *author) {
	if (Str::eq(line, I"Web Syntax Version: 1"))
		return V1_SYNTAX;
	else if (Str::eq(line, I"Web Syntax Version: 2"))
		return V2_SYNTAX;
	else if (Str::eq(line, I"Web Syntax Version: Markdown"))
		return MD_SYNTAX;
	else if ((tfp->line_count == 1) && (Str::get_at(line, 0) == '#')) {
		match_results mr = Regexp::create_mr();
		if (Regexp::match(&mr, line, U"# (%C%c*?) by (%C%c*?) *")) {
			Str::copy(title, mr.exp[0]);
			Str::copy(author, mr.exp[1]);
		} else if (Regexp::match(&mr, line, U"# (%C%c*) *")) {
			Str::copy(title, mr.exp[0]);
		}
		Regexp::dispose_of(&mr);
		return MD_SYNTAX;
	}
	return -1;
}

int WebSyntax::line_can_mark_end_of_metadata(int syntax, text_stream *line, text_file_position *tfp) {
	if (syntax == MD_SYNTAX) {
		if (tfp->line_count == 2) return TRUE;
	} else {
		if (Str::get_at(line, 0) == '@') return TRUE;
	}
	return FALSE;
}
