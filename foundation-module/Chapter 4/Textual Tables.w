[TextualTables::] Textual Tables.

Simple plain-text tabulations, for reporting to the console.

@ =
typedef struct textual_table {
	struct linked_list *rows; /* of |textual_table_row| */
	CLASS_DEFINITION
} textual_table;

typedef struct textual_table_row {
	int positioning;
	int index;
	int sort_column;
	struct linked_list *columns; /* of |text_stream| */
	CLASS_DEFINITION
} textual_table_row;

textual_table *TextualTables::new_table(void) {
	textual_table *T = CREATE(textual_table);
	T->rows = NEW_LINKED_LIST(textual_table_row);
	textual_table_row *R = TextualTables::begin_row(T);
	R->positioning = -1;
	return T;
}

textual_table_row *TextualTables::begin_row(textual_table *T) {
	textual_table_row *R = CREATE(textual_table_row);
	R->positioning = 0;
	R->columns = NEW_LINKED_LIST(text_stream);
	R->index = LinkedLists::len(T->rows);
	ADD_TO_LINKED_LIST(R, textual_table_row, T->rows);
	return R;
}

textual_table_row *TextualTables::begin_footer_row(textual_table *T) {
	textual_table_row *R = TextualTables::begin_row(T);
	R->positioning = 1;
	return R;
}

text_stream *TextualTables::next_cell(textual_table *T) {
	textual_table_row *R = LAST_IN_LINKED_LIST(textual_table_row, T->rows);
	text_stream *C = Str::new();
	ADD_TO_LINKED_LIST(C, text_stream, R->columns);
	return C;
}

void TextualTables::tabulate(OUTPUT_STREAM, textual_table *T) {
	TextualTables::tabulate_sorted(OUT, T, -1);
}

void TextualTables::tabulate_sorted(OUTPUT_STREAM, textual_table *T, int on) {
	textual_table_row *R;
	int width[100], max_c = 0, N = 0, footer = -1;
	for (int c=0; c<100; c++) width[c] = 0;
	LOOP_OVER_LINKED_LIST(R, textual_table_row, T->rows) {
		text_stream *C;
		int c = 0;
		LOOP_OVER_LINKED_LIST(C, text_stream, R->columns) {
			if ((c<100) && (Str::len(C) > width[c])) width[c] = Str::len(C);
			c++;
			if (c > max_c) max_c = c;
		}
		N++;
		if (R->positioning == 1) footer = N;
	}

	textual_table_row **sorted_table =
		Memory::calloc(N, (int) sizeof(textual_table_row *), ARRAY_SORTING_MREASON);

	int r=0;
	LOOP_OVER_LINKED_LIST(R, textual_table_row, T->rows) {
		sorted_table[r++] = R;
		R->sort_column = on;
	}

	if ((on >= 0) && (on < max_c) && (N > 1))
		qsort(sorted_table, (size_t) N, sizeof(textual_table_row *), TextualTables::compare_rows);

	for (int r=0; r<N; r++) {
		textual_table_row *R = sorted_table[r];
		text_stream *C;
		int c = 0;
		LOOP_OVER_LINKED_LIST(C, text_stream, R->columns) {
			WRITE("%S", C);
			if (c<100) for (int j=Str::len(C); j<width[c]; j++) WRITE(" ");
			c++;
			if (c < max_c) WRITE(" | ");
		}
		WRITE("\n");
		if ((r == 0) || ((footer>0) && (r == N-2))) {
			for (int c=0; c<max_c; c++) {
				if (c<100) {
					for (int j=0; j<width[c]; j++) WRITE("-");
				} else {
					WRITE("-");
				}
				if (c < max_c-1) WRITE(" | ");
			}
			WRITE("\n");
		}
	}
	Memory::I7_free(sorted_table, ARRAY_SORTING_MREASON, N*((int) sizeof(textual_table_row *)));
}

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
