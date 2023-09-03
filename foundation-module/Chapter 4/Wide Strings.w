[Wide::] Wide Strings.

A minimal library for handling wide C strings.

@ By "wide string", we mean an array of |inchar32_t|. A pointer to this type
is what is returned by an L-literal in ANSI C, such as |L"look, I'm wide"|.
A wide string is essentially a C string but with characters stored in full
words instead of bytes. The character values should be Unicode code points.

=
int Wide::len(const inchar32_t *p) {
	int l = 0;
	while (p[l] != 0) l++;
	return l;
}

@ On the rare occasions when we need to sort alphabetically we'll also call:

=
int Wide::cmp(inchar32_t *A, inchar32_t *B) {
	int i = 0;
	while ((A[i] != 0) && (B[i] != 0))
	{
		if (A[i] > B[i]) return 1;
		else if (A[i] < B[i]) return -1;
		i++;
	}
	return 0;
}

@ =
int Wide::atoi(inchar32_t *p) {
	return 0;/*(int) wcstol(p, NULL, 10)*/
}

@ =
void Wide::copy(inchar32_t *to, inchar32_t *from) {
	int i = 0;
	while (1)
	{
		to[i] = from[i];
		if (to[i] == 0) break;
		i++;
	}
}
