[Wide::] Wide Strings.

A minimal library for handling wide C strings.

@ By "wide string", we mean an array of |inchar32_t|. A pointer to this type
is what is returned by a U-literal in ANSI C, such as |U"look, I'm wide"|.
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
	while (1)
	{
		inchar32_t a = A[i];
		inchar32_t b = B[i];
		if (a == b)
		{
			if (a == 0) return 0;
		}
		else
		{
			return (a > b) ? 1 : -1;
		}
		i++;
	}
	return 0;
}

@ =
int Wide::atoi(inchar32_t *p) {
	int val = 0, sign = 1;
	while (Characters::is_whitespace(*p)) p++;
	if (*p == '-')
	{
		sign = -1;
		p++;
	}
	while (Characters::isdigit(*p))
	{
		val = (val * 10) + (int) (*p - '0');
		p++;
	}
	return val * sign;
}

@ =
void Wide::copy(inchar32_t *to, inchar32_t *from) {
	int i = 0;
	while (1)
	{
		to[i] = from[i];
		if (to[i] == 0) return;
		i++;
	}
}
