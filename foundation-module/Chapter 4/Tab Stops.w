[TabbedStr::] Tab Stops.

Reading strings where tab characters need to be interpreted as if spaces had
been used for the same visual effect.

@ Suppose we want to read through a line in which tab characters mean "this
material occurs on the next tab stop position", with stops every 8 characters.
We want to treat the sequence A, space, B, tab, C, D exactly as |"A B     CD"|,
that is, as if had been typed with spaces to reach the same visual outcome.

Writing code to handle such lines, without modifying them, is tricky, and the
following gadget can help. Be a little wary, though: if the text in |line|
is freed in memory, this will leave a dangling pointer, so it's best not to
keep these iterators alive for longer than necessary.

=
typedef struct tabbed_string_iterator {
	struct text_stream *line;
	int read_index;
	int line_position;
	int tab_spacing;
} tabbed_string_iterator;

tabbed_string_iterator TabbedStr::new(text_stream *line, int tab_spacing) {
	tabbed_string_iterator mdw;
	mdw.line = line;
	mdw.read_index = 0;
	mdw.line_position = 0;
	mdw.tab_spacing = tab_spacing;
	return mdw;
}

@ The sequence A, space, B, tab, C, D has 6 code points, but is visually
10 characters wide. D appears in "position" 9 but at "index" 5.

=
int TabbedStr::get_index(tabbed_string_iterator *mdw) {
	return mdw->read_index;
}

int TabbedStr::get_position(tabbed_string_iterator *mdw) {
	return mdw->line_position;
}

@ We want to treat tabs as runs of 1 or more spaces, so if the character
stored at the read index is a tab then it represents a space for parsing
purposes.

=
inchar32_t TabbedStr::get_character(tabbed_string_iterator *mdw) {
	inchar32_t c = Str::get_at(mdw->line, mdw->read_index);
	if (c == '\t') return ' ';
	return c;
}

@ It's possible for the index point to be at a tab which is incompletely
being expanded into spaces: then the following returns |FALSE|.

=
int TabbedStr::at_whole_character(tabbed_string_iterator *mdw) {
	inchar32_t c = Str::get_at(mdw->line, mdw->read_index);
	if (c != '\t') return TRUE;
	if (mdw->line_position % mdw->tab_spacing == 0) return TRUE;
	return FALSE;
}

@ Here we advance the position, which may or may not advance the index as well.

=
void TabbedStr::advance(tabbed_string_iterator *mdw) {
	mdw->line_position++;
	if (TabbedStr::at_whole_character(mdw)) mdw->read_index++;
}

void TabbedStr::advance_by(tabbed_string_iterator *mdw, int N) {
	if (N < 0) internal_error("There's no going back");
	for (int i=0; i<N; i++) TabbedStr::advance(mdw);
}

@ This is much slower, and seeks a given position the hard way, by rewinding
to the start of the string and counting it out.

=
int TabbedStr::seek(tabbed_string_iterator *mdw, int pos) {
	mdw->read_index = 0;
	mdw->line_position = 0;
	while (mdw->read_index < Str::len(mdw->line)) {
		if (mdw->line_position == pos) return TRUE;
		TabbedStr::advance(mdw);
	}
	return FALSE;
}

@ To "eat" a space is to advance the position past a (conceptual) space.

=
int TabbedStr::eat_space(tabbed_string_iterator *mdw) {
	if (mdw == NULL) internal_error("no mdw");
	if (TabbedStr::get_character(mdw) == ' ') {
		TabbedStr::advance(mdw);
		return TRUE;
	}
	return FALSE;
}

int TabbedStr::eat_spaces(int N, tabbed_string_iterator *mdw) {
	tabbed_string_iterator copy = *mdw;
	for (int i=1; i<=N; i++)
		if (TabbedStr::eat_space(mdw) == FALSE) {
			*mdw = copy;
			return FALSE;
		}
	return TRUE;
}

@ The number of spaces available to be eaten can be read off in advance,
that is, without moving the position or index:

=
int TabbedStr::spaces_available(tabbed_string_iterator *mdw) {
	tabbed_string_iterator copy = *mdw;
	int total = 0;
	while (TabbedStr::eat_space(&copy)) total++;
	return total;
}

@ And this is a quick way to see if there are any non-spaces left to find:

=
int TabbedStr::blank_from_here(tabbed_string_iterator *mdw) {
	for (int i=mdw->read_index; i<Str::len(mdw->line); i++) {
		inchar32_t c = Str::get_at(mdw->line, i);
		if ((c != ' ') && (c != '\t')) return FALSE;
	}
	return TRUE;
}
