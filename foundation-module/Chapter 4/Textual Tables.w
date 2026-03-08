[TextualTables::] Textual Tables.

Simple plain-text tabulations, for reporting to the console.

@h Creation.
The following is for at most modest-sized textual tables of information,
for printing out to the console. (Inweb makes use of this for commands such
as `inweb inspect`.)

=
classdef textual_table {
	struct linked_list *rows; /* of `textual_table_row` */
}

classdef textual_table_row {
	int positioning;             /* `-1` for header, `0` for most rows, `1` for footer */
	int index;                   /* position in the list, counting 0, 1, 2, ... from the top */
	int sort_column;             /* which column we are sorting on */
	struct linked_list *columns; /* of `text_stream` */
}

@ The model here is that we first create an empty table object by calling the
following. A header row is automatically created, ready for us to fill its
cells with column headings; note that it is compulsory to have a header row.

=
textual_table *TextualTables::new_table(void) {
	textual_table *T = CREATE(textual_table);
	T->rows = NEW_LINKED_LIST(textual_table_row);
	textual_table_row *R = TextualTables::begin_row(T);
	R->positioning = -1;
	return T;
}

@ And cells are then filled by calling this repeatedly to produce the
string to write the contents to:

=
text_stream *TextualTables::next_cell(textual_table *T) {
	textual_table_row *R = LAST_IN_LINKED_LIST(textual_table_row, T->rows);
	text_stream *C = Str::new();
	ADD_TO_LINKED_LIST(C, text_stream, R->columns);
	return C;
}

@ When ready for a fresh row, we call this, which creates a middle-positioned
row:

=
textual_table_row *TextualTables::begin_row(textual_table *T) {
	textual_table_row *R = CREATE(textual_table_row);
	R->positioning = 0;
	R->columns = NEW_LINKED_LIST(text_stream);
	R->index = LinkedLists::len(T->rows);
	ADD_TO_LINKED_LIST(R, textual_table_row, T->rows);
	return R;
}

@ ...except for a footer (which is optional), thus:

=
textual_table_row *TextualTables::begin_footer_row(textual_table *T) {
	textual_table_row *R = TextualTables::begin_row(T);
	R->positioning = 1;
	return R;
}

@h Tabulation.
Tables are always sorted before printing, though sorting them on column `-1`
means "leave the table with its rows in creation order", as here:

=
void TextualTables::tabulate(OUTPUT_STREAM, textual_table *T) {
	TextualTables::tabulate_sorted(OUT, T, -1);
}

@ More generally, then:

=
void TextualTables::tabulate_sorted(OUTPUT_STREAM, textual_table *T, int on) {
	textual_table_row **rows;
	int width[MAX_TEXTUAL_TABLE_COL_WIDTHS], max_c = 0, N = 0, footer = -1;
	@<Compute widths and such@>;
	@<Make a qsortable array of table row pointers@>;
	@<And qsort it@>;
	@<Print the now-sorted table@>;
	@<Free the memory for the pointer array@>;
}

@ We compute the widths of only the first 100 columns; any subsequent columns
will just have to be ragged. (But nobody will print a 101-column table on
a terminal window.) The "width" of column 3, say, is the maximum textual length
of the contents of column 3 in any row.

`max_c` is then the largest column number in any row. (Tables do not have to
have an equal number of columns in each row.) `N` is the number of rows,
and `footer` is the row number of the footer row, if there is one.

@d MAX_TEXTUAL_TABLE_COL_WIDTHS 100

@<Compute widths and such@> =
	for (int c=0; c<MAX_TEXTUAL_TABLE_COL_WIDTHS; c++) width[c] = 0;
	textual_table_row *R;
	LOOP_OVER_LINKED_LIST(R, textual_table_row, T->rows) {
		text_stream *C;
		int c = 0;
		LOOP_OVER_LINKED_LIST(C, text_stream, R->columns) {
			if ((c<MAX_TEXTUAL_TABLE_COL_WIDTHS) && (Str::len(C) > width[c]))
				width[c] = Str::len(C);
			c++;
			if (c > max_c) max_c = c;
		}
		N++;
		if (R->positioning == 1) footer = N;
	}

@<Make a qsortable array of table row pointers@> =	
	rows = Memory::calloc(N, (int) sizeof(textual_table_row *), ARRAY_SORTING_MREASON);
	int r=0;
	textual_table_row *R;
	LOOP_OVER_LINKED_LIST(R, textual_table_row, T->rows) {
		rows[r++] = R;
		R->sort_column = on;
	}

@<And qsort it@> =
	if ((on >= 0) && (on < max_c) && (N > 1))
		qsort(rows, (size_t) N, sizeof(textual_table_row *), TextualTables::compare_rows);

@ Which uses the following pairwise comparison function. Note that the indexes
are used to ensure that the sorting is stable, i.e., preserves the original row
order when the contents of the sort column are equal.

=
int TextualTables::compare_rows(const void *ent1, const void *ent2) {
	const textual_table_row *R1 = *((const textual_table_row **) ent1);
	const textual_table_row *R2 = *((const textual_table_row **) ent2);
	int delta = R1->positioning - R2->positioning;
	if (delta != 0) return delta;
	int c = 0;
	text_stream *C, *C1 = NULL, *C2 = NULL;
	LOOP_OVER_LINKED_LIST(C, text_stream, R1->columns)
		if (c++ == R1->sort_column)
			C1 = C;
	c = 0;
	LOOP_OVER_LINKED_LIST(C, text_stream, R2->columns)
		if (c++ == R2->sort_column)
			C2 = C;
	delta = Str::cmp_insensitive(C1, C2);
	if (delta != 0) return delta;
	return R1->index - R2->index;
}

@<Free the memory for the pointer array@> =
	Memory::I7_free(rows, ARRAY_SORTING_MREASON, N*((int) sizeof(textual_table_row *)));

@<Print the now-sorted table@> =
	for (int r=0; r<N; r++) {
		textual_table_row *R = rows[r];
		text_stream *C;
		int c = 0;
		LOOP_OVER_LINKED_LIST(C, text_stream, R->columns) {
			WRITE("%S", C);
			if (c<MAX_TEXTUAL_TABLE_COL_WIDTHS)
				for (int j=Str::len(C); j<width[c]; j++) WRITE(" ");
			c++;
			if (c < max_c) WRITE(" | ");
		}
		WRITE("\n");
		if ((r == 0) || ((footer>0) && (r == N-2))) @<Print a divider row@>;
	}

@ Rows of dashes appear below the header and above the footer (if one exists):

@<Print a divider row@> =
	for (int c=0; c<max_c; c++) {
		if (c<MAX_TEXTUAL_TABLE_COL_WIDTHS) {
			for (int j=0; j<width[c]; j++) WRITE("-");
		} else {
			WRITE("-");
		}
		if (c < max_c-1) WRITE(" | ");
	}
	WRITE("\n");
