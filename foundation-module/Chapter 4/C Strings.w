[CStrings::] C Strings.

A minimal library for handling C-style strings.

@ Programs using Foundation store text in |text_stream| structures almost all
of the time, but old-style, null-terminated |char *| array strings are
still occasionally needed.

We need to handle C strings long enough to contain any plausible filename, and
any run of a dozen or so lines of code; but we have no real need to handle
strings of unlimited length, nor to be parsimonious with memory.

The following defines a type for a string long enough for our purposes.
It should be at least as long as the constant sometimes called |PATH_MAX|,
the maximum length of a pathname, which is 1024 on Mac OS X.

@d MAX_STRING_LENGTH 8*1024

=
typedef char string[MAX_STRING_LENGTH+1];

@ Occasionally we need access to the real, unbounded strlen:

=
int CStrings::strlen_unbounded(const char *p) {
	return (int) strlen(p);
}

@ Any out-of-range access immediately halts the program; this is drastic, but
an attempt to continue execution after a string overflow might conceivably
result in a malformatted shell command being passed to the operating system,
which we cannot risk.

=
int CStrings::check_len(int n) {
	if ((n > MAX_STRING_LENGTH) || (n < 0)) Errors::fatal("String overflow\n");
	return n;
}

@ The following is then protected from reading out of range if given a
non-terminated string, though this should never actually happen.

=
int CStrings::len(char *str) {
	for (int i=0; i<=MAX_STRING_LENGTH; i++)
		if (str[i] == 0) return i;
	str[MAX_STRING_LENGTH] = 0;
	return MAX_STRING_LENGTH;
}

@ We then have a replacement for |strcpy|, identical except that it's
bounds-checked:

=
void CStrings::copy(char *to, char *from) {
	CStrings::check_len(CStrings::len(from));
	int i;
	for (i=0; ((from[i]) && (i < MAX_STRING_LENGTH)); i++) to[i] = from[i];
	to[i] = 0;
}

@ String comparisons will be done with the following, not |strcmp| directly:

=
int CStrings::ne(char *A, char *B) {
	return (CStrings::cmp(A, B) == 0)?FALSE:TRUE;
}

@ On the rare occasions when we need to sort alphabetically we'll also call:

=
int CStrings::cmp(char *A, char *B) {
	if ((A == NULL) || (A[0] == 0)) {
		if ((B == NULL) || (B[0] == 0)) return 0;
		return -1;
	}
	if ((B == NULL) || (B[0] == 0)) return 1;
	return strcmp(A, B);
}

@ And the following is needed to deal with extension filenames on platforms
whose locale is encoded as UTF-8.

=
void CStrings::transcode_ISO_string_to_UTF8(char *p, char *dest) {
	int i, j;
	for (i=0, j=0; p[i]; i++) {
		int charcode = (int) (((unsigned char *)p)[i]);
		if (charcode >= 128) {
			dest[j++] = (char) (0xC0 + (charcode >> 6));
			dest[j++] = (char) (0x80 + (charcode & 0x3f));
		} else {
			dest[j++] = p[i];
		}
	}
	dest[j] = 0;
}

@ I dislike to use |strncpy| because, and for some reason this surprises
me every time, it truncates but fails to write a null termination character
if the string to be copied is larger than the buffer to write to: the
result is therefore not a well-formed string and we have to fix matters by
hand. This I think makes for opaque code. So:

=
void CStrings::truncated_strcpy(char *to, char *from, int max) {
	int i;
	for (i=0; ((from[i]) && (i<max-1)); i++) to[i] = from[i];
	to[i] = 0;
}
