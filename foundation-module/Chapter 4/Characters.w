[Characters::] Characters.

Individual characters.

@h Character classes.

=
wchar_t Characters::tolower(wchar_t c) {
	return (wchar_t) tolower((int) c);
}
wchar_t Characters::toupper(wchar_t c) {
	return (wchar_t) toupper((int) c);
}
int Characters::isalpha(wchar_t c) {
	return isalpha((int) c);
}
int Characters::isdigit(wchar_t c) {
	return isdigit((int) c);
}
int Characters::isupper(wchar_t c) {
	return isupper((int) c);
}
int Characters::islower(wchar_t c) {
	return islower((int) c);
}
int Characters::isalnum(wchar_t c) {
	return isalnum((int) c);
}
int Characters::vowel(wchar_t c) {
	if ((c == 'a') || (c == 'e') || (c == 'i') || (c == 'o') || (c == 'u')) return TRUE;
	return FALSE;
}

@ White space classes:

=
int Characters::is_space_or_tab(int c) {
	if ((c == ' ') || (c == '\t')) return TRUE;
	return FALSE;
}
int Characters::is_whitespace(int c) {
	if ((c == ' ') || (c == '\t') || (c == '\n')) return TRUE;
	return FALSE;
}

@ These are all the characters which would come out as whitespace in the
sense of the Treaty of Babel rules on leading and trailing spaces in
iFiction records.

=
int Characters::is_babel_whitespace(int c) {
	if ((c == ' ') || (c == '\t') || (c == '\x0a')
		|| (c == '\x0d') || (c == NEWLINE_IN_STRING)) return TRUE;
	return FALSE;
}

@h Unicode composition.
A routine which converts the Unicode combining accents with letters,
sufficient correctly to handle all characters in the ZSCII set.

=
int Characters::combine_accent(int accent, int letter) {
	switch(accent) {
		case 0x0300: /* Unicode combining grave */
			switch(letter) {
				case 'a': return 0xE0; case 'e': return 0xE8; case 'i': return 0xEC;
				case 'o': return 0xF2; case 'u': return 0xF9;
				case 'A': return 0xC0; case 'E': return 0xC8; case 'I': return 0xCC;
				case 'O': return 0xD2; case 'U': return 0xD9;
			}
			break;
		case 0x0301: /* Unicode combining acute */
			switch(letter) {
				case 'a': return 0xE1; case 'e': return 0xE9; case 'i': return 0xED;
				case 'o': return 0xF3; case 'u': return 0xFA; case 'y': return 0xFF;
				case 'A': return 0xC1; case 'E': return 0xC9; case 'I': return 0xCD;
				case 'O': return 0xD3; case 'U': return 0xDA;
			}
			break;
		case 0x0302: /* Unicode combining circumflex */
			switch(letter) {
				case 'a': return 0xE2; case 'e': return 0xEA; case 'i': return 0xEE;
				case 'o': return 0xF4; case 'u': return 0xFB;
				case 'A': return 0xC2; case 'E': return 0xCA; case 'I': return 0xCE;
				case 'O': return 0xD4; case 'U': return 0xDB;
			}
			break;
		case 0x0303: /* Unicode combining tilde */
			switch(letter) {
				case 'a': return 0xE3; case 'n': return 0xF1; case 'o': return 0xF5;
				case 'A': return 0xC3; case 'N': return 0xD1; case 'O': return 0xD5;
			}
			break;
		case 0x0308: /* Unicode combining diaeresis */
			switch(letter) {
				case 'a': return 0xE4; case 'e': return 0xEB; case 'u': return 0xFC;
				case 'o': return 0xF6; case 'i': return 0xEF;
				case 'A': return 0xC4; case 'E': return 0xCB; case 'U': return 0xDC;
				case 'O': return 0xD6; case 'I': return 0xCF;
			}
			break;
		case 0x0327: /* Unicode combining cedilla */
			switch(letter) {
				case 'c': return 0xE7; case 'C': return 0xC7;
			}
			break;
	}
	return '?';
}

@h Accent stripping.
It's occasionally useful to simplify text used as a filename by removing
the more obvious accents from it.

=
int Characters::make_filename_safe(int charcode) {
	charcode = Characters::remove_accent(charcode);
	if (charcode >= 128) charcode = '-';
	return charcode;
}

@ The following strips the accent, if present, from an ISO Latin-1 character:

=
int Characters::remove_accent(int charcode) {
	switch (charcode) {
		case 0xC0: case 0xC1: case 0xC2: case 0xC3:
		case 0xC4: case 0xC5: charcode = 'A'; break;
		case 0xE0: case 0xE1: case 0xE2: case 0xE3:
		case 0xE4: case 0xE5: charcode = 'a'; break;
		case 0xC8: case 0xC9: case 0xCA: case 0xCB: charcode = 'E'; break;
		case 0xE8: case 0xE9: case 0xEA: case 0xEB: charcode = 'e'; break;
		case 0xCC: case 0xCD: case 0xCE: case 0xCF: charcode = 'I'; break;
		case 0xEC: case 0xED: case 0xEE: case 0xEF: charcode = 'i'; break;
		case 0xD2: case 0xD3: case 0xD4: case 0xD5:
		case 0xD6: case 0xD8: charcode = 'O'; break;
		case 0xF2: case 0xF3: case 0xF4: case 0xF5:
		case 0xF6: case 0xF8: charcode = 'o'; break;
		case 0xD9: case 0xDA: case 0xDB: case 0xDC: charcode = 'U'; break;
		case 0xF9: case 0xFA: case 0xFB: case 0xFC: charcode = 'u'; break;
		case 0xDD: charcode = 'Y'; break;
		case 0xFD: charcode = 'y'; break;
		case 0xD1: charcode = 'N'; break;
		case 0xF1: charcode = 'n'; break;
		case 0xC7: charcode = 'C'; break;
		case 0xE7: charcode = 'c'; break;
		case 0xDF: charcode = 's'; break;
	}
	return charcode;
}
