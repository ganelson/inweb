[Wide::] Wide Strings.

A minimal library for handling wide C strings.

@ By "wide string", we mean an array of |wchar_t|. A pointer to this type
is what is returned by an L-literal in ANSI C, such as |L"look, I'm wide"|.
A wide string is essentially a C string but with characters stored in full
words instead of bytes. The character values should be Unicode code points.

We will do as little as possible with wide strings, and the following
wrappers simply abstract the standard C library's handling.

=
int Wide::len(wchar_t *p) {
	return (int) wcslen(p);
}

@ On the rare occasions when we need to sort alphabetically we'll also call:

=
int Wide::cmp(wchar_t *A, wchar_t *B) {
	return wcscmp(A, B);
}

@ =
int Wide::atoi(wchar_t *p) {
	return (int) wcstol(p, NULL, 10);
}
