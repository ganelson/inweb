[Wide::] Wide Strings.

A minimal library for handling wide C strings.

@ By "wide string", we mean an array of |inchar32_t|. A pointer to this type
is what is returned by an L-literal in ANSI C, such as |L"look, I'm wide"|.
A wide string is essentially a C string but with characters stored in full
words instead of bytes. The character values should be Unicode code points.

=
int Wide::len(const inchar32_t *p) {
	int l = 0;
	while (*(p++) != 0) l++;
	return l;
}

@ On the rare occasions when we need to sort alphabetically we'll also call:

=
int Wide::cmp(inchar32_t *A, inchar32_t *B) {
	while ((*A != 0) && (*B != 0))
	{
		if (*A > *B) return 1;
		if (*A < *B) return -1;
	}
	return 0;
}

@ =
int Wide::atoi(inchar32_t *p) {
	return 0;/*(int) wcstol(p, NULL, 10)*/
}

@ =
void Wide::copy(inchar32_t *to, inchar32_t *from) {
	while (*from != 0) *(to++) = *(from++);
}
