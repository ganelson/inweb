[Characters::] Characters.

Individual characters.

@h Character classes.

=
inchar32_t Characters::tolower(inchar32_t c) {
	return (inchar32_t) tolower((int) c);
}
inchar32_t Characters::toupper(inchar32_t c) {
	return (inchar32_t) toupper((int) c);
}
int Characters::isalpha(inchar32_t c) {
	return isalpha((int) c);
}
int Characters::isdigit(inchar32_t c) {
	return isdigit((int) c);
}
int Characters::isupper(inchar32_t c) {
	return isupper((int) c);
}
int Characters::islower(inchar32_t c) {
	return islower((int) c);
}
int Characters::isalnum(inchar32_t c) {
	return isalnum((int) c);
}
int Characters::iscntrl(inchar32_t c) {
	return (c < 32);
}
int Characters::vowel(inchar32_t c) {
	if ((c == 'a') || (c == 'e') || (c == 'i') || (c == 'o') || (c == 'u')) return TRUE;
	return FALSE;
}

@ White space classes:

=
int Characters::is_space_or_tab(inchar32_t c) {
	if ((c == ' ') || (c == '\t')) return TRUE;
	return FALSE;
}
int Characters::is_whitespace(inchar32_t c) {
	if ((c == ' ') || (c == '\t') || (c == '\n')) return TRUE;
	return FALSE;
}

@ These are all the characters which would come out as whitespace in the
sense of the Treaty of Babel rules on leading and trailing spaces in
iFiction records.

=
int Characters::is_babel_whitespace(inchar32_t c) {
	if ((c == ' ') || (c == '\t') || (c == '\x0a')
		|| (c == '\x0d') || (c == NEWLINE_IN_STRING)) return TRUE;
	return FALSE;
}

@ The following covers ASCII white-space characters, and beyond those all
non-ASCII Unicode characters of category Zs.

=
int Characters::is_Unicode_whitespace(inchar32_t c) {
	if (c == 0x0009) return TRUE;
	if (c == 0x000A) return TRUE;
	if (c == 0x000C) return TRUE;
	if (c == 0x000D) return TRUE;
	if (c == 0x0020) return TRUE;
	if (c == 0x00A0) return TRUE; // NO-BREAK SPACE
	if (c == 0x1680) return TRUE; // OGHAM SPACE MARK
	if (c == 0x2000) return TRUE; // EN QUAD
	if (c == 0x2001) return TRUE; // EM QUAD
	if (c == 0x2002) return TRUE; // EN SPACE
	if (c == 0x2003) return TRUE; // EM SPACE
	if (c == 0x2004) return TRUE; // THREE-PER-EM SPACE
	if (c == 0x2005) return TRUE; // FOUR-PER-EM SPACE
	if (c == 0x2006) return TRUE; // SIX-PER-EM SPACE
	if (c == 0x2007) return TRUE; // FIGURE SPACE
	if (c == 0x2008) return TRUE; // PUNCTUATION SPACE
	if (c == 0x2009) return TRUE; // THIN SPACE
	if (c == 0x200A) return TRUE; // HAIR SPACE
	if (c == 0x202F) return TRUE; // NARROW NO-BREAK SPACE
	if (c == 0x205F) return TRUE; // MEDIUM MATHEMATICAL SPACE
	if (c == 0x3000) return TRUE; // IDEOGRAPHIC SPACE
	return FALSE;
}

@ ASCII-only punctuation characters, using the convenient definition of
"ASCII punctuation" from the CommonMark standard:

=
int Characters::is_ASCII_punctuation(inchar32_t c) {
	if ((c >= 0x0021) && (c <= 0x002F)) return TRUE;
	if ((c >= 0x003A) && (c <= 0x0040)) return TRUE;
	if ((c >= 0x005B) && (c <= 0x0060)) return TRUE;
	if ((c >= 0x007B) && (c <= 0x007E)) return TRUE;
	return FALSE;
}

@ This extends ASCII punctuation by adding all Unicode characters of category
Pc, Pd, Pe, Pf, Pi, Po, or Ps. After all, we wouldn't want to get old Assyrian
cuneiform spacing indicators wrong, would we? Or the Imperial Aramaic section sign?

=
int Characters::is_Unicode_punctuation(inchar32_t c) {
	if (c < 0x80) return Characters::is_ASCII_punctuation(c);
	if (c == 0x00A1) return TRUE; // INVERTED EXCLAMATION MARK
	if (c == 0x00A7) return TRUE; // SECTION SIGN
	if (c == 0x00AB) return TRUE; // LEFT-POINTING DOUBLE ANGLE QUOTATION MARK
	if (c == 0x00B6) return TRUE; // PILCROW SIGN
	if (c == 0x00B7) return TRUE; // MIDDLE DOT
	if (c == 0x00BB) return TRUE; // RIGHT-POINTING DOUBLE ANGLE QUOTATION MARK
	if (c == 0x00BF) return TRUE; // INVERTED QUESTION MARK
	if (c < 0x0100) return FALSE;
	if (c == 0x037E) return TRUE; // GREEK QUESTION MARK
	if (c == 0x0387) return TRUE; // GREEK ANO TELEIA
	if (c == 0x055A) return TRUE; // ARMENIAN APOSTROPHE
	if (c == 0x055B) return TRUE; // ARMENIAN EMPHASIS MARK
	if (c == 0x055C) return TRUE; // ARMENIAN EXCLAMATION MARK
	if (c == 0x055D) return TRUE; // ARMENIAN COMMA
	if (c == 0x055E) return TRUE; // ARMENIAN QUESTION MARK
	if (c == 0x055F) return TRUE; // ARMENIAN ABBREVIATION MARK
	if (c == 0x0589) return TRUE; // ARMENIAN FULL STOP
	if (c == 0x058A) return TRUE; // ARMENIAN HYPHEN
	if (c == 0x05BE) return TRUE; // HEBREW PUNCTUATION MAQAF
	if (c == 0x05C0) return TRUE; // HEBREW PUNCTUATION PASEQ
	if (c == 0x05C3) return TRUE; // HEBREW PUNCTUATION SOF PASUQ
	if (c == 0x05C6) return TRUE; // HEBREW PUNCTUATION NUN HAFUKHA
	if (c == 0x05F3) return TRUE; // HEBREW PUNCTUATION GERESH
	if (c == 0x05F4) return TRUE; // HEBREW PUNCTUATION GERSHAYIM
	if (c == 0x0609) return TRUE; // ARABIC-INDIC PER MILLE SIGN
	if (c == 0x060A) return TRUE; // ARABIC-INDIC PER TEN THOUSAND SIGN
	if (c == 0x060C) return TRUE; // ARABIC COMMA
	if (c == 0x060D) return TRUE; // ARABIC DATE SEPARATOR
	if (c == 0x061B) return TRUE; // ARABIC SEMICOLON
	if (c == 0x061D) return TRUE; // ARABIC END OF TEXT MARK
	if (c == 0x061E) return TRUE; // ARABIC TRIPLE DOT PUNCTUATION MARK
	if (c == 0x061F) return TRUE; // ARABIC QUESTION MARK
	if (c == 0x066A) return TRUE; // ARABIC PERCENT SIGN
	if (c == 0x066B) return TRUE; // ARABIC DECIMAL SEPARATOR
	if (c == 0x066C) return TRUE; // ARABIC THOUSANDS SEPARATOR
	if (c == 0x066D) return TRUE; // ARABIC FIVE POINTED STAR
	if (c == 0x06D4) return TRUE; // ARABIC FULL STOP
	if (c == 0x0700) return TRUE; // SYRIAC END OF PARAGRAPH
	if (c == 0x0701) return TRUE; // SYRIAC SUPRALINEAR FULL STOP
	if (c == 0x0702) return TRUE; // SYRIAC SUBLINEAR FULL STOP
	if (c == 0x0703) return TRUE; // SYRIAC SUPRALINEAR COLON
	if (c == 0x0704) return TRUE; // SYRIAC SUBLINEAR COLON
	if (c == 0x0705) return TRUE; // SYRIAC HORIZONTAL COLON
	if (c == 0x0706) return TRUE; // SYRIAC COLON SKEWED LEFT
	if (c == 0x0707) return TRUE; // SYRIAC COLON SKEWED RIGHT
	if (c == 0x0708) return TRUE; // SYRIAC SUPRALINEAR COLON SKEWED LEFT
	if (c == 0x0709) return TRUE; // SYRIAC SUBLINEAR COLON SKEWED RIGHT
	if (c == 0x070A) return TRUE; // SYRIAC CONTRACTION
	if (c == 0x070B) return TRUE; // SYRIAC HARKLEAN OBELUS
	if (c == 0x070C) return TRUE; // SYRIAC HARKLEAN METOBELUS
	if (c == 0x070D) return TRUE; // SYRIAC HARKLEAN ASTERISCUS
	if (c == 0x07F7) return TRUE; // NKO SYMBOL GBAKURUNEN
	if (c == 0x07F8) return TRUE; // NKO COMMA
	if (c == 0x07F9) return TRUE; // NKO EXCLAMATION MARK
	if (c == 0x0830) return TRUE; // SAMARITAN PUNCTUATION NEQUDAA
	if (c == 0x0831) return TRUE; // SAMARITAN PUNCTUATION AFSAAQ
	if (c == 0x0832) return TRUE; // SAMARITAN PUNCTUATION ANGED
	if (c == 0x0833) return TRUE; // SAMARITAN PUNCTUATION BAU
	if (c == 0x0834) return TRUE; // SAMARITAN PUNCTUATION ATMAAU
	if (c == 0x0835) return TRUE; // SAMARITAN PUNCTUATION SHIYYAALAA
	if (c == 0x0836) return TRUE; // SAMARITAN ABBREVIATION MARK
	if (c == 0x0837) return TRUE; // SAMARITAN PUNCTUATION MELODIC QITSA
	if (c == 0x0838) return TRUE; // SAMARITAN PUNCTUATION ZIQAA
	if (c == 0x0839) return TRUE; // SAMARITAN PUNCTUATION QITSA
	if (c == 0x083A) return TRUE; // SAMARITAN PUNCTUATION ZAEF
	if (c == 0x083B) return TRUE; // SAMARITAN PUNCTUATION TURU
	if (c == 0x083C) return TRUE; // SAMARITAN PUNCTUATION ARKAANU
	if (c == 0x083D) return TRUE; // SAMARITAN PUNCTUATION SOF MASHFAAT
	if (c == 0x083E) return TRUE; // SAMARITAN PUNCTUATION ANNAAU
	if (c == 0x085E) return TRUE; // MANDAIC PUNCTUATION
	if (c == 0x0964) return TRUE; // DEVANAGARI DANDA
	if (c == 0x0965) return TRUE; // DEVANAGARI DOUBLE DANDA
	if (c == 0x0970) return TRUE; // DEVANAGARI ABBREVIATION SIGN
	if (c == 0x09FD) return TRUE; // BENGALI ABBREVIATION SIGN
	if (c == 0x0A76) return TRUE; // GURMUKHI ABBREVIATION SIGN
	if (c == 0x0AF0) return TRUE; // GUJARATI ABBREVIATION SIGN
	if (c == 0x0C77) return TRUE; // TELUGU SIGN SIDDHAM
	if (c == 0x0C84) return TRUE; // KANNADA SIGN SIDDHAM
	if (c == 0x0DF4) return TRUE; // SINHALA PUNCTUATION KUNDDALIYA
	if (c == 0x0E4F) return TRUE; // THAI CHARACTER FONGMAN
	if (c == 0x0E5A) return TRUE; // THAI CHARACTER ANGKHANKHU
	if (c == 0x0E5B) return TRUE; // THAI CHARACTER KHOMUT
	if (c == 0x0F04) return TRUE; // TIBETAN MARK INITIAL YIG MGO MDUN MA
	if (c == 0x0F05) return TRUE; // TIBETAN MARK CLOSING YIG MGO SGAB MA
	if (c == 0x0F06) return TRUE; // TIBETAN MARK CARET YIG MGO PHUR SHAD MA
	if (c == 0x0F07) return TRUE; // TIBETAN MARK YIG MGO TSHEG SHAD MA
	if (c == 0x0F08) return TRUE; // TIBETAN MARK SBRUL SHAD
	if (c == 0x0F09) return TRUE; // TIBETAN MARK BSKUR YIG MGO
	if (c == 0x0F0A) return TRUE; // TIBETAN MARK BKA- SHOG YIG MGO
	if (c == 0x0F0B) return TRUE; // TIBETAN MARK INTERSYLLABIC TSHEG
	if (c == 0x0F0C) return TRUE; // TIBETAN MARK DELIMITER TSHEG BSTAR
	if (c == 0x0F0D) return TRUE; // TIBETAN MARK SHAD
	if (c == 0x0F0E) return TRUE; // TIBETAN MARK NYIS SHAD
	if (c == 0x0F0F) return TRUE; // TIBETAN MARK TSHEG SHAD
	if (c == 0x0F10) return TRUE; // TIBETAN MARK NYIS TSHEG SHAD
	if (c == 0x0F11) return TRUE; // TIBETAN MARK RIN CHEN SPUNGS SHAD
	if (c == 0x0F12) return TRUE; // TIBETAN MARK RGYA GRAM SHAD
	if (c == 0x0F14) return TRUE; // TIBETAN MARK GTER TSHEG
	if (c == 0x0F3A) return TRUE; // TIBETAN MARK GUG RTAGS GYON
	if (c == 0x0F3B) return TRUE; // TIBETAN MARK GUG RTAGS GYAS
	if (c == 0x0F3C) return TRUE; // TIBETAN MARK ANG KHANG GYON
	if (c == 0x0F3D) return TRUE; // TIBETAN MARK ANG KHANG GYAS
	if (c == 0x0F85) return TRUE; // TIBETAN MARK PALUTA
	if (c == 0x0FD0) return TRUE; // TIBETAN MARK BSKA- SHOG GI MGO RGYAN
	if (c == 0x0FD1) return TRUE; // TIBETAN MARK MNYAM YIG GI MGO RGYAN
	if (c == 0x0FD2) return TRUE; // TIBETAN MARK NYIS TSHEG
	if (c == 0x0FD3) return TRUE; // TIBETAN MARK INITIAL BRDA RNYING YIG MGO MDUN MA
	if (c == 0x0FD4) return TRUE; // TIBETAN MARK CLOSING BRDA RNYING YIG MGO SGAB MA
	if (c == 0x0FD9) return TRUE; // TIBETAN MARK LEADING MCHAN RTAGS
	if (c == 0x0FDA) return TRUE; // TIBETAN MARK TRAILING MCHAN RTAGS
	if (c < 0x01000) return FALSE;
	if (c == 0x104A) return TRUE; // MYANMAR SIGN LITTLE SECTION
	if (c == 0x104B) return TRUE; // MYANMAR SIGN SECTION
	if (c == 0x104C) return TRUE; // MYANMAR SYMBOL LOCATIVE
	if (c == 0x104D) return TRUE; // MYANMAR SYMBOL COMPLETED
	if (c == 0x104E) return TRUE; // MYANMAR SYMBOL AFOREMENTIONED
	if (c == 0x104F) return TRUE; // MYANMAR SYMBOL GENITIVE
	if (c == 0x10FB) return TRUE; // GEORGIAN PARAGRAPH SEPARATOR
	if (c == 0x1360) return TRUE; // ETHIOPIC SECTION MARK
	if (c == 0x1361) return TRUE; // ETHIOPIC WORDSPACE
	if (c == 0x1362) return TRUE; // ETHIOPIC FULL STOP
	if (c == 0x1363) return TRUE; // ETHIOPIC COMMA
	if (c == 0x1364) return TRUE; // ETHIOPIC SEMICOLON
	if (c == 0x1365) return TRUE; // ETHIOPIC COLON
	if (c == 0x1366) return TRUE; // ETHIOPIC PREFACE COLON
	if (c == 0x1367) return TRUE; // ETHIOPIC QUESTION MARK
	if (c == 0x1368) return TRUE; // ETHIOPIC PARAGRAPH SEPARATOR
	if (c == 0x1400) return TRUE; // CANADIAN SYLLABICS HYPHEN
	if (c == 0x166E) return TRUE; // CANADIAN SYLLABICS FULL STOP
	if (c == 0x169B) return TRUE; // OGHAM FEATHER MARK
	if (c == 0x169C) return TRUE; // OGHAM REVERSED FEATHER MARK
	if (c == 0x16EB) return TRUE; // RUNIC SINGLE PUNCTUATION
	if (c == 0x16EC) return TRUE; // RUNIC MULTIPLE PUNCTUATION
	if (c == 0x16ED) return TRUE; // RUNIC CROSS PUNCTUATION
	if (c == 0x1735) return TRUE; // PHILIPPINE SINGLE PUNCTUATION
	if (c == 0x1736) return TRUE; // PHILIPPINE DOUBLE PUNCTUATION
	if (c == 0x17D4) return TRUE; // KHMER SIGN KHAN
	if (c == 0x17D5) return TRUE; // KHMER SIGN BARIYOOSAN
	if (c == 0x17D6) return TRUE; // KHMER SIGN CAMNUC PII KUUH
	if (c == 0x17D8) return TRUE; // KHMER SIGN BEYYAL
	if (c == 0x17D9) return TRUE; // KHMER SIGN PHNAEK MUAN
	if (c == 0x17DA) return TRUE; // KHMER SIGN KOOMUUT
	if (c == 0x1800) return TRUE; // MONGOLIAN BIRGA
	if (c == 0x1801) return TRUE; // MONGOLIAN ELLIPSIS
	if (c == 0x1802) return TRUE; // MONGOLIAN COMMA
	if (c == 0x1803) return TRUE; // MONGOLIAN FULL STOP
	if (c == 0x1804) return TRUE; // MONGOLIAN COLON
	if (c == 0x1805) return TRUE; // MONGOLIAN FOUR DOTS
	if (c == 0x1806) return TRUE; // MONGOLIAN TODO SOFT HYPHEN
	if (c == 0x1807) return TRUE; // MONGOLIAN SIBE SYLLABLE BOUNDARY MARKER
	if (c == 0x1808) return TRUE; // MONGOLIAN MANCHU COMMA
	if (c == 0x1809) return TRUE; // MONGOLIAN MANCHU FULL STOP
	if (c == 0x180A) return TRUE; // MONGOLIAN NIRUGU
	if (c == 0x1944) return TRUE; // LIMBU EXCLAMATION MARK
	if (c == 0x1945) return TRUE; // LIMBU QUESTION MARK
	if (c == 0x1A1E) return TRUE; // BUGINESE PALLAWA
	if (c == 0x1A1F) return TRUE; // BUGINESE END OF SECTION
	if (c == 0x1AA0) return TRUE; // TAI THAM SIGN WIANG
	if (c == 0x1AA1) return TRUE; // TAI THAM SIGN WIANGWAAK
	if (c == 0x1AA2) return TRUE; // TAI THAM SIGN SAWAN
	if (c == 0x1AA3) return TRUE; // TAI THAM SIGN KEOW
	if (c == 0x1AA4) return TRUE; // TAI THAM SIGN HOY
	if (c == 0x1AA5) return TRUE; // TAI THAM SIGN DOKMAI
	if (c == 0x1AA6) return TRUE; // TAI THAM SIGN REVERSED ROTATED RANA
	if (c == 0x1AA8) return TRUE; // TAI THAM SIGN KAAN
	if (c == 0x1AA9) return TRUE; // TAI THAM SIGN KAANKUU
	if (c == 0x1AAA) return TRUE; // TAI THAM SIGN SATKAAN
	if (c == 0x1AAB) return TRUE; // TAI THAM SIGN SATKAANKUU
	if (c == 0x1AAC) return TRUE; // TAI THAM SIGN HANG
	if (c == 0x1AAD) return TRUE; // TAI THAM SIGN CAANG
	if (c == 0x1B5A) return TRUE; // BALINESE PANTI
	if (c == 0x1B5B) return TRUE; // BALINESE PAMADA
	if (c == 0x1B5C) return TRUE; // BALINESE WINDU
	if (c == 0x1B5D) return TRUE; // BALINESE CARIK PAMUNGKAH
	if (c == 0x1B5E) return TRUE; // BALINESE CARIK SIKI
	if (c == 0x1B5F) return TRUE; // BALINESE CARIK PAREREN
	if (c == 0x1B60) return TRUE; // BALINESE PAMENENG
	if (c == 0x1B7D) return TRUE; // BALINESE PANTI LANTANG
	if (c == 0x1B7E) return TRUE; // BALINESE PAMADA LANTANG
	if (c == 0x1BFC) return TRUE; // BATAK SYMBOL BINDU NA METEK
	if (c == 0x1BFD) return TRUE; // BATAK SYMBOL BINDU PINARBORAS
	if (c == 0x1BFE) return TRUE; // BATAK SYMBOL BINDU JUDUL
	if (c == 0x1BFF) return TRUE; // BATAK SYMBOL BINDU PANGOLAT
	if (c == 0x1C3B) return TRUE; // LEPCHA PUNCTUATION TA-ROL
	if (c == 0x1C3C) return TRUE; // LEPCHA PUNCTUATION NYET THYOOM TA-ROL
	if (c == 0x1C3D) return TRUE; // LEPCHA PUNCTUATION CER-WA
	if (c == 0x1C3E) return TRUE; // LEPCHA PUNCTUATION TSHOOK CER-WA
	if (c == 0x1C3F) return TRUE; // LEPCHA PUNCTUATION TSHOOK
	if (c == 0x1C7E) return TRUE; // OL CHIKI PUNCTUATION MUCAAD
	if (c == 0x1C7F) return TRUE; // OL CHIKI PUNCTUATION DOUBLE MUCAAD
	if (c == 0x1CC0) return TRUE; // SUNDANESE PUNCTUATION BINDU SURYA
	if (c == 0x1CC1) return TRUE; // SUNDANESE PUNCTUATION BINDU PANGLONG
	if (c == 0x1CC2) return TRUE; // SUNDANESE PUNCTUATION BINDU PURNAMA
	if (c == 0x1CC3) return TRUE; // SUNDANESE PUNCTUATION BINDU CAKRA
	if (c == 0x1CC4) return TRUE; // SUNDANESE PUNCTUATION BINDU LEU SATANGA
	if (c == 0x1CC5) return TRUE; // SUNDANESE PUNCTUATION BINDU KA SATANGA
	if (c == 0x1CC6) return TRUE; // SUNDANESE PUNCTUATION BINDU DA SATANGA
	if (c == 0x1CC7) return TRUE; // SUNDANESE PUNCTUATION BINDU BA SATANGA
	if (c == 0x1CD3) return TRUE; // VEDIC SIGN NIHSHVASA
	if (c == 0x2010) return TRUE; // HYPHEN
	if (c == 0x2011) return TRUE; // NON-BREAKING HYPHEN
	if (c == 0x2012) return TRUE; // FIGURE DASH
	if (c == 0x2013) return TRUE; // EN DASH
	if (c == 0x2014) return TRUE; // EM DASH
	if (c == 0x2015) return TRUE; // HORIZONTAL BAR
	if (c == 0x2016) return TRUE; // DOUBLE VERTICAL LINE
	if (c == 0x2017) return TRUE; // DOUBLE LOW LINE
	if (c == 0x2018) return TRUE; // LEFT SINGLE QUOTATION MARK
	if (c == 0x2019) return TRUE; // RIGHT SINGLE QUOTATION MARK
	if (c == 0x201A) return TRUE; // SINGLE LOW-9 QUOTATION MARK
	if (c == 0x201B) return TRUE; // SINGLE HIGH-REVERSED-9 QUOTATION MARK
	if (c == 0x201C) return TRUE; // LEFT DOUBLE QUOTATION MARK
	if (c == 0x201D) return TRUE; // RIGHT DOUBLE QUOTATION MARK
	if (c == 0x201E) return TRUE; // DOUBLE LOW-9 QUOTATION MARK
	if (c == 0x201F) return TRUE; // DOUBLE HIGH-REVERSED-9 QUOTATION MARK
	if (c == 0x2020) return TRUE; // DAGGER
	if (c == 0x2021) return TRUE; // DOUBLE DAGGER
	if (c == 0x2022) return TRUE; // BULLET
	if (c == 0x2023) return TRUE; // TRIANGULAR BULLET
	if (c == 0x2024) return TRUE; // ONE DOT LEADER
	if (c == 0x2025) return TRUE; // TWO DOT LEADER
	if (c == 0x2026) return TRUE; // HORIZONTAL ELLIPSIS
	if (c == 0x2027) return TRUE; // HYPHENATION POINT
	if (c == 0x2030) return TRUE; // PER MILLE SIGN
	if (c == 0x2031) return TRUE; // PER TEN THOUSAND SIGN
	if (c == 0x2032) return TRUE; // PRIME
	if (c == 0x2033) return TRUE; // DOUBLE PRIME
	if (c == 0x2034) return TRUE; // TRIPLE PRIME
	if (c == 0x2035) return TRUE; // REVERSED PRIME
	if (c == 0x2036) return TRUE; // REVERSED DOUBLE PRIME
	if (c == 0x2037) return TRUE; // REVERSED TRIPLE PRIME
	if (c == 0x2038) return TRUE; // CARET
	if (c == 0x2039) return TRUE; // SINGLE LEFT-POINTING ANGLE QUOTATION MARK
	if (c == 0x203A) return TRUE; // SINGLE RIGHT-POINTING ANGLE QUOTATION MARK
	if (c == 0x203B) return TRUE; // REFERENCE MARK
	if (c == 0x203C) return TRUE; // DOUBLE EXCLAMATION MARK
	if (c == 0x203D) return TRUE; // INTERROBANG
	if (c == 0x203E) return TRUE; // OVERLINE
	if (c == 0x203F) return TRUE; // UNDERTIE
	if (c == 0x2040) return TRUE; // CHARACTER TIE
	if (c == 0x2041) return TRUE; // CARET INSERTION POINT
	if (c == 0x2042) return TRUE; // ASTERISM
	if (c == 0x2043) return TRUE; // HYPHEN BULLET
	if (c == 0x2045) return TRUE; // LEFT SQUARE BRACKET WITH QUILL
	if (c == 0x2046) return TRUE; // RIGHT SQUARE BRACKET WITH QUILL
	if (c == 0x2047) return TRUE; // DOUBLE QUESTION MARK
	if (c == 0x2048) return TRUE; // QUESTION EXCLAMATION MARK
	if (c == 0x2049) return TRUE; // EXCLAMATION QUESTION MARK
	if (c == 0x204A) return TRUE; // TIRONIAN SIGN ET
	if (c == 0x204B) return TRUE; // REVERSED PILCROW SIGN
	if (c == 0x204C) return TRUE; // BLACK LEFTWARDS BULLET
	if (c == 0x204D) return TRUE; // BLACK RIGHTWARDS BULLET
	if (c == 0x204E) return TRUE; // LOW ASTERISK
	if (c == 0x204F) return TRUE; // REVERSED SEMICOLON
	if (c == 0x2050) return TRUE; // CLOSE UP
	if (c == 0x2051) return TRUE; // TWO ASTERISKS ALIGNED VERTICALLY
	if (c == 0x2053) return TRUE; // SWUNG DASH
	if (c == 0x2054) return TRUE; // INVERTED UNDERTIE
	if (c == 0x2055) return TRUE; // FLOWER PUNCTUATION MARK
	if (c == 0x2056) return TRUE; // THREE DOT PUNCTUATION
	if (c == 0x2057) return TRUE; // QUADRUPLE PRIME
	if (c == 0x2058) return TRUE; // FOUR DOT PUNCTUATION
	if (c == 0x2059) return TRUE; // FIVE DOT PUNCTUATION
	if (c == 0x205A) return TRUE; // TWO DOT PUNCTUATION
	if (c == 0x205B) return TRUE; // FOUR DOT MARK
	if (c == 0x205C) return TRUE; // DOTTED CROSS
	if (c == 0x205D) return TRUE; // TRICOLON
	if (c == 0x205E) return TRUE; // VERTICAL FOUR DOTS
	if (c == 0x207D) return TRUE; // SUPERSCRIPT LEFT PARENTHESIS
	if (c == 0x207E) return TRUE; // SUPERSCRIPT RIGHT PARENTHESIS
	if (c == 0x208D) return TRUE; // SUBSCRIPT LEFT PARENTHESIS
	if (c == 0x208E) return TRUE; // SUBSCRIPT RIGHT PARENTHESIS
	if (c == 0x2308) return TRUE; // LEFT CEILING
	if (c == 0x2309) return TRUE; // RIGHT CEILING
	if (c == 0x230A) return TRUE; // LEFT FLOOR
	if (c == 0x230B) return TRUE; // RIGHT FLOOR
	if (c == 0x2329) return TRUE; // LEFT-POINTING ANGLE BRACKET
	if (c == 0x232A) return TRUE; // RIGHT-POINTING ANGLE BRACKET
	if (c == 0x2768) return TRUE; // MEDIUM LEFT PARENTHESIS ORNAMENT
	if (c == 0x2769) return TRUE; // MEDIUM RIGHT PARENTHESIS ORNAMENT
	if (c == 0x276A) return TRUE; // MEDIUM FLATTENED LEFT PARENTHESIS ORNAMENT
	if (c == 0x276B) return TRUE; // MEDIUM FLATTENED RIGHT PARENTHESIS ORNAMENT
	if (c == 0x276C) return TRUE; // MEDIUM LEFT-POINTING ANGLE BRACKET ORNAMENT
	if (c == 0x276D) return TRUE; // MEDIUM RIGHT-POINTING ANGLE BRACKET ORNAMENT
	if (c == 0x276E) return TRUE; // HEAVY LEFT-POINTING ANGLE QUOTATION MARK ORNAMENT
	if (c == 0x276F) return TRUE; // HEAVY RIGHT-POINTING ANGLE QUOTATION MARK ORNAMENT
	if (c == 0x2770) return TRUE; // HEAVY LEFT-POINTING ANGLE BRACKET ORNAMENT
	if (c == 0x2771) return TRUE; // HEAVY RIGHT-POINTING ANGLE BRACKET ORNAMENT
	if (c == 0x2772) return TRUE; // LIGHT LEFT TORTOISE SHELL BRACKET ORNAMENT
	if (c == 0x2773) return TRUE; // LIGHT RIGHT TORTOISE SHELL BRACKET ORNAMENT
	if (c == 0x2774) return TRUE; // MEDIUM LEFT CURLY BRACKET ORNAMENT
	if (c == 0x2775) return TRUE; // MEDIUM RIGHT CURLY BRACKET ORNAMENT
	if (c == 0x27C5) return TRUE; // LEFT S-SHAPED BAG DELIMITER
	if (c == 0x27C6) return TRUE; // RIGHT S-SHAPED BAG DELIMITER
	if (c == 0x27E6) return TRUE; // MATHEMATICAL LEFT WHITE SQUARE BRACKET
	if (c == 0x27E7) return TRUE; // MATHEMATICAL RIGHT WHITE SQUARE BRACKET
	if (c == 0x27E8) return TRUE; // MATHEMATICAL LEFT ANGLE BRACKET
	if (c == 0x27E9) return TRUE; // MATHEMATICAL RIGHT ANGLE BRACKET
	if (c == 0x27EA) return TRUE; // MATHEMATICAL LEFT DOUBLE ANGLE BRACKET
	if (c == 0x27EB) return TRUE; // MATHEMATICAL RIGHT DOUBLE ANGLE BRACKET
	if (c == 0x27EC) return TRUE; // MATHEMATICAL LEFT WHITE TORTOISE SHELL BRACKET
	if (c == 0x27ED) return TRUE; // MATHEMATICAL RIGHT WHITE TORTOISE SHELL BRACKET
	if (c == 0x27EE) return TRUE; // MATHEMATICAL LEFT FLATTENED PARENTHESIS
	if (c == 0x27EF) return TRUE; // MATHEMATICAL RIGHT FLATTENED PARENTHESIS
	if (c == 0x2983) return TRUE; // LEFT WHITE CURLY BRACKET
	if (c == 0x2984) return TRUE; // RIGHT WHITE CURLY BRACKET
	if (c == 0x2985) return TRUE; // LEFT WHITE PARENTHESIS
	if (c == 0x2986) return TRUE; // RIGHT WHITE PARENTHESIS
	if (c == 0x2987) return TRUE; // Z NOTATION LEFT IMAGE BRACKET
	if (c == 0x2988) return TRUE; // Z NOTATION RIGHT IMAGE BRACKET
	if (c == 0x2989) return TRUE; // Z NOTATION LEFT BINDING BRACKET
	if (c == 0x298A) return TRUE; // Z NOTATION RIGHT BINDING BRACKET
	if (c == 0x298B) return TRUE; // LEFT SQUARE BRACKET WITH UNDERBAR
	if (c == 0x298C) return TRUE; // RIGHT SQUARE BRACKET WITH UNDERBAR
	if (c == 0x298D) return TRUE; // LEFT SQUARE BRACKET WITH TICK IN TOP CORNER
	if (c == 0x298E) return TRUE; // RIGHT SQUARE BRACKET WITH TICK IN BOTTOM CORNER
	if (c == 0x298F) return TRUE; // LEFT SQUARE BRACKET WITH TICK IN BOTTOM CORNER
	if (c == 0x2990) return TRUE; // RIGHT SQUARE BRACKET WITH TICK IN TOP CORNER
	if (c == 0x2991) return TRUE; // LEFT ANGLE BRACKET WITH DOT
	if (c == 0x2992) return TRUE; // RIGHT ANGLE BRACKET WITH DOT
	if (c == 0x2993) return TRUE; // LEFT ARC LESS-THAN BRACKET
	if (c == 0x2994) return TRUE; // RIGHT ARC GREATER-THAN BRACKET
	if (c == 0x2995) return TRUE; // DOUBLE LEFT ARC GREATER-THAN BRACKET
	if (c == 0x2996) return TRUE; // DOUBLE RIGHT ARC LESS-THAN BRACKET
	if (c == 0x2997) return TRUE; // LEFT BLACK TORTOISE SHELL BRACKET
	if (c == 0x2998) return TRUE; // RIGHT BLACK TORTOISE SHELL BRACKET
	if (c == 0x29D8) return TRUE; // LEFT WIGGLY FENCE
	if (c == 0x29D9) return TRUE; // RIGHT WIGGLY FENCE
	if (c == 0x29DA) return TRUE; // LEFT DOUBLE WIGGLY FENCE
	if (c == 0x29DB) return TRUE; // RIGHT DOUBLE WIGGLY FENCE
	if (c == 0x29FC) return TRUE; // LEFT-POINTING CURVED ANGLE BRACKET
	if (c == 0x29FD) return TRUE; // RIGHT-POINTING CURVED ANGLE BRACKET
	if (c == 0x2CF9) return TRUE; // COPTIC OLD NUBIAN FULL STOP
	if (c == 0x2CFA) return TRUE; // COPTIC OLD NUBIAN DIRECT QUESTION MARK
	if (c == 0x2CFB) return TRUE; // COPTIC OLD NUBIAN INDIRECT QUESTION MARK
	if (c == 0x2CFC) return TRUE; // COPTIC OLD NUBIAN VERSE DIVIDER
	if (c == 0x2CFE) return TRUE; // COPTIC FULL STOP
	if (c == 0x2CFF) return TRUE; // COPTIC MORPHOLOGICAL DIVIDER
	if (c == 0x2D70) return TRUE; // TIFINAGH SEPARATOR MARK
	if (c == 0x2E00) return TRUE; // RIGHT ANGLE SUBSTITUTION MARKER
	if (c == 0x2E01) return TRUE; // RIGHT ANGLE DOTTED SUBSTITUTION MARKER
	if (c == 0x2E02) return TRUE; // LEFT SUBSTITUTION BRACKET
	if (c == 0x2E03) return TRUE; // RIGHT SUBSTITUTION BRACKET
	if (c == 0x2E04) return TRUE; // LEFT DOTTED SUBSTITUTION BRACKET
	if (c == 0x2E05) return TRUE; // RIGHT DOTTED SUBSTITUTION BRACKET
	if (c == 0x2E06) return TRUE; // RAISED INTERPOLATION MARKER
	if (c == 0x2E07) return TRUE; // RAISED DOTTED INTERPOLATION MARKER
	if (c == 0x2E08) return TRUE; // DOTTED TRANSPOSITION MARKER
	if (c == 0x2E09) return TRUE; // LEFT TRANSPOSITION BRACKET
	if (c == 0x2E0A) return TRUE; // RIGHT TRANSPOSITION BRACKET
	if (c == 0x2E0B) return TRUE; // RAISED SQUARE
	if (c == 0x2E0C) return TRUE; // LEFT RAISED OMISSION BRACKET
	if (c == 0x2E0D) return TRUE; // RIGHT RAISED OMISSION BRACKET
	if (c == 0x2E0E) return TRUE; // EDITORIAL CORONIS
	if (c == 0x2E0F) return TRUE; // PARAGRAPHOS
	if (c == 0x2E10) return TRUE; // FORKED PARAGRAPHOS
	if (c == 0x2E11) return TRUE; // REVERSED FORKED PARAGRAPHOS
	if (c == 0x2E12) return TRUE; // HYPODIASTOLE
	if (c == 0x2E13) return TRUE; // DOTTED OBELOS
	if (c == 0x2E14) return TRUE; // DOWNWARDS ANCORA
	if (c == 0x2E15) return TRUE; // UPWARDS ANCORA
	if (c == 0x2E16) return TRUE; // DOTTED RIGHT-POINTING ANGLE
	if (c == 0x2E17) return TRUE; // DOUBLE OBLIQUE HYPHEN
	if (c == 0x2E18) return TRUE; // INVERTED INTERROBANG
	if (c == 0x2E19) return TRUE; // PALM BRANCH
	if (c == 0x2E1A) return TRUE; // HYPHEN WITH DIAERESIS
	if (c == 0x2E1B) return TRUE; // TILDE WITH RING ABOVE
	if (c == 0x2E1C) return TRUE; // LEFT LOW PARAPHRASE BRACKET
	if (c == 0x2E1D) return TRUE; // RIGHT LOW PARAPHRASE BRACKET
	if (c == 0x2E1E) return TRUE; // TILDE WITH DOT ABOVE
	if (c == 0x2E1F) return TRUE; // TILDE WITH DOT BELOW
	if (c == 0x2E20) return TRUE; // LEFT VERTICAL BAR WITH QUILL
	if (c == 0x2E21) return TRUE; // RIGHT VERTICAL BAR WITH QUILL
	if (c == 0x2E22) return TRUE; // TOP LEFT HALF BRACKET
	if (c == 0x2E23) return TRUE; // TOP RIGHT HALF BRACKET
	if (c == 0x2E24) return TRUE; // BOTTOM LEFT HALF BRACKET
	if (c == 0x2E25) return TRUE; // BOTTOM RIGHT HALF BRACKET
	if (c == 0x2E26) return TRUE; // LEFT SIDEWAYS U BRACKET
	if (c == 0x2E27) return TRUE; // RIGHT SIDEWAYS U BRACKET
	if (c == 0x2E28) return TRUE; // LEFT DOUBLE PARENTHESIS
	if (c == 0x2E29) return TRUE; // RIGHT DOUBLE PARENTHESIS
	if (c == 0x2E2A) return TRUE; // TWO DOTS OVER ONE DOT PUNCTUATION
	if (c == 0x2E2B) return TRUE; // ONE DOT OVER TWO DOTS PUNCTUATION
	if (c == 0x2E2C) return TRUE; // SQUARED FOUR DOT PUNCTUATION
	if (c == 0x2E2D) return TRUE; // FIVE DOT MARK
	if (c == 0x2E2E) return TRUE; // REVERSED QUESTION MARK
	if (c == 0x2E30) return TRUE; // RING POINT
	if (c == 0x2E31) return TRUE; // WORD SEPARATOR MIDDLE DOT
	if (c == 0x2E32) return TRUE; // TURNED COMMA
	if (c == 0x2E33) return TRUE; // RAISED DOT
	if (c == 0x2E34) return TRUE; // RAISED COMMA
	if (c == 0x2E35) return TRUE; // TURNED SEMICOLON
	if (c == 0x2E36) return TRUE; // DAGGER WITH LEFT GUARD
	if (c == 0x2E37) return TRUE; // DAGGER WITH RIGHT GUARD
	if (c == 0x2E38) return TRUE; // TURNED DAGGER
	if (c == 0x2E39) return TRUE; // TOP HALF SECTION SIGN
	if (c == 0x2E3A) return TRUE; // TWO-EM DASH
	if (c == 0x2E3B) return TRUE; // THREE-EM DASH
	if (c == 0x2E3C) return TRUE; // STENOGRAPHIC FULL STOP
	if (c == 0x2E3D) return TRUE; // VERTICAL SIX DOTS
	if (c == 0x2E3E) return TRUE; // WIGGLY VERTICAL LINE
	if (c == 0x2E3F) return TRUE; // CAPITULUM
	if (c == 0x2E40) return TRUE; // DOUBLE HYPHEN
	if (c == 0x2E41) return TRUE; // REVERSED COMMA
	if (c == 0x2E42) return TRUE; // DOUBLE LOW-REVERSED-9 QUOTATION MARK
	if (c == 0x2E43) return TRUE; // DASH WITH LEFT UPTURN
	if (c == 0x2E44) return TRUE; // DOUBLE SUSPENSION MARK
	if (c == 0x2E45) return TRUE; // INVERTED LOW KAVYKA
	if (c == 0x2E46) return TRUE; // INVERTED LOW KAVYKA WITH KAVYKA ABOVE
	if (c == 0x2E47) return TRUE; // LOW KAVYKA
	if (c == 0x2E48) return TRUE; // LOW KAVYKA WITH DOT
	if (c == 0x2E49) return TRUE; // DOUBLE STACKED COMMA
	if (c == 0x2E4A) return TRUE; // DOTTED SOLIDUS
	if (c == 0x2E4B) return TRUE; // TRIPLE DAGGER
	if (c == 0x2E4C) return TRUE; // MEDIEVAL COMMA
	if (c == 0x2E4D) return TRUE; // PARAGRAPHUS MARK
	if (c == 0x2E4E) return TRUE; // PUNCTUS ELEVATUS MARK
	if (c == 0x2E4F) return TRUE; // CORNISH VERSE DIVIDER
	if (c == 0x2E52) return TRUE; // TIRONIAN SIGN CAPITAL ET
	if (c == 0x2E53) return TRUE; // MEDIEVAL EXCLAMATION MARK
	if (c == 0x2E54) return TRUE; // MEDIEVAL QUESTION MARK
	if (c == 0x2E55) return TRUE; // LEFT SQUARE BRACKET WITH STROKE
	if (c == 0x2E56) return TRUE; // RIGHT SQUARE BRACKET WITH STROKE
	if (c == 0x2E57) return TRUE; // LEFT SQUARE BRACKET WITH DOUBLE STROKE
	if (c == 0x2E58) return TRUE; // RIGHT SQUARE BRACKET WITH DOUBLE STROKE
	if (c == 0x2E59) return TRUE; // TOP HALF LEFT PARENTHESIS
	if (c == 0x2E5A) return TRUE; // TOP HALF RIGHT PARENTHESIS
	if (c == 0x2E5B) return TRUE; // BOTTOM HALF LEFT PARENTHESIS
	if (c == 0x2E5C) return TRUE; // BOTTOM HALF RIGHT PARENTHESIS
	if (c == 0x2E5D) return TRUE; // OBLIQUE HYPHEN
	if (c == 0x3001) return TRUE; // IDEOGRAPHIC COMMA
	if (c == 0x3002) return TRUE; // IDEOGRAPHIC FULL STOP
	if (c == 0x3003) return TRUE; // DITTO MARK
	if (c == 0x3008) return TRUE; // LEFT ANGLE BRACKET
	if (c == 0x3009) return TRUE; // RIGHT ANGLE BRACKET
	if (c == 0x300A) return TRUE; // LEFT DOUBLE ANGLE BRACKET
	if (c == 0x300B) return TRUE; // RIGHT DOUBLE ANGLE BRACKET
	if (c == 0x300C) return TRUE; // LEFT CORNER BRACKET
	if (c == 0x300D) return TRUE; // RIGHT CORNER BRACKET
	if (c == 0x300E) return TRUE; // LEFT WHITE CORNER BRACKET
	if (c == 0x300F) return TRUE; // RIGHT WHITE CORNER BRACKET
	if (c == 0x3010) return TRUE; // LEFT BLACK LENTICULAR BRACKET
	if (c == 0x3011) return TRUE; // RIGHT BLACK LENTICULAR BRACKET
	if (c == 0x3014) return TRUE; // LEFT TORTOISE SHELL BRACKET
	if (c == 0x3015) return TRUE; // RIGHT TORTOISE SHELL BRACKET
	if (c == 0x3016) return TRUE; // LEFT WHITE LENTICULAR BRACKET
	if (c == 0x3017) return TRUE; // RIGHT WHITE LENTICULAR BRACKET
	if (c == 0x3018) return TRUE; // LEFT WHITE TORTOISE SHELL BRACKET
	if (c == 0x3019) return TRUE; // RIGHT WHITE TORTOISE SHELL BRACKET
	if (c == 0x301A) return TRUE; // LEFT WHITE SQUARE BRACKET
	if (c == 0x301B) return TRUE; // RIGHT WHITE SQUARE BRACKET
	if (c == 0x301C) return TRUE; // WAVE DASH
	if (c == 0x301D) return TRUE; // REVERSED DOUBLE PRIME QUOTATION MARK
	if (c == 0x301E) return TRUE; // DOUBLE PRIME QUOTATION MARK
	if (c == 0x301F) return TRUE; // LOW DOUBLE PRIME QUOTATION MARK
	if (c == 0x3030) return TRUE; // WAVY DASH
	if (c == 0x303D) return TRUE; // PART ALTERNATION MARK
	if (c == 0x30A0) return TRUE; // KATAKANA-HIRAGANA DOUBLE HYPHEN
	if (c == 0x30FB) return TRUE; // KATAKANA MIDDLE DOT
	if (c == 0xA4FE) return TRUE; // LISU PUNCTUATION COMMA
	if (c == 0xA4FF) return TRUE; // LISU PUNCTUATION FULL STOP
	if (c == 0xA60D) return TRUE; // VAI COMMA
	if (c == 0xA60E) return TRUE; // VAI FULL STOP
	if (c == 0xA60F) return TRUE; // VAI QUESTION MARK
	if (c == 0xA673) return TRUE; // SLAVONIC ASTERISK
	if (c == 0xA67E) return TRUE; // CYRILLIC KAVYKA
	if (c == 0xA6F2) return TRUE; // BAMUM NJAEMLI
	if (c == 0xA6F3) return TRUE; // BAMUM FULL STOP
	if (c == 0xA6F4) return TRUE; // BAMUM COLON
	if (c == 0xA6F5) return TRUE; // BAMUM COMMA
	if (c == 0xA6F6) return TRUE; // BAMUM SEMICOLON
	if (c == 0xA6F7) return TRUE; // BAMUM QUESTION MARK
	if (c == 0xA874) return TRUE; // PHAGS-PA SINGLE HEAD MARK
	if (c == 0xA875) return TRUE; // PHAGS-PA DOUBLE HEAD MARK
	if (c == 0xA876) return TRUE; // PHAGS-PA MARK SHAD
	if (c == 0xA877) return TRUE; // PHAGS-PA MARK DOUBLE SHAD
	if (c == 0xA8CE) return TRUE; // SAURASHTRA DANDA
	if (c == 0xA8CF) return TRUE; // SAURASHTRA DOUBLE DANDA
	if (c == 0xA8F8) return TRUE; // DEVANAGARI SIGN PUSHPIKA
	if (c == 0xA8F9) return TRUE; // DEVANAGARI GAP FILLER
	if (c == 0xA8FA) return TRUE; // DEVANAGARI CARET
	if (c == 0xA8FC) return TRUE; // DEVANAGARI SIGN SIDDHAM
	if (c == 0xA92E) return TRUE; // KAYAH LI SIGN CWI
	if (c == 0xA92F) return TRUE; // KAYAH LI SIGN SHYA
	if (c == 0xA95F) return TRUE; // REJANG SECTION MARK
	if (c == 0xA9C1) return TRUE; // JAVANESE LEFT RERENGGAN
	if (c == 0xA9C2) return TRUE; // JAVANESE RIGHT RERENGGAN
	if (c == 0xA9C3) return TRUE; // JAVANESE PADA ANDAP
	if (c == 0xA9C4) return TRUE; // JAVANESE PADA MADYA
	if (c == 0xA9C5) return TRUE; // JAVANESE PADA LUHUR
	if (c == 0xA9C6) return TRUE; // JAVANESE PADA WINDU
	if (c == 0xA9C7) return TRUE; // JAVANESE PADA PANGKAT
	if (c == 0xA9C8) return TRUE; // JAVANESE PADA LINGSA
	if (c == 0xA9C9) return TRUE; // JAVANESE PADA LUNGSI
	if (c == 0xA9CA) return TRUE; // JAVANESE PADA ADEG
	if (c == 0xA9CB) return TRUE; // JAVANESE PADA ADEG ADEG
	if (c == 0xA9CC) return TRUE; // JAVANESE PADA PISELEH
	if (c == 0xA9CD) return TRUE; // JAVANESE TURNED PADA PISELEH
	if (c == 0xA9DE) return TRUE; // JAVANESE PADA TIRTA TUMETES
	if (c == 0xA9DF) return TRUE; // JAVANESE PADA ISEN-ISEN
	if (c == 0xAA5C) return TRUE; // CHAM PUNCTUATION SPIRAL
	if (c == 0xAA5D) return TRUE; // CHAM PUNCTUATION DANDA
	if (c == 0xAA5E) return TRUE; // CHAM PUNCTUATION DOUBLE DANDA
	if (c == 0xAA5F) return TRUE; // CHAM PUNCTUATION TRIPLE DANDA
	if (c == 0xAADE) return TRUE; // TAI VIET SYMBOL HO HOI
	if (c == 0xAADF) return TRUE; // TAI VIET SYMBOL KOI KOI
	if (c == 0xAAF0) return TRUE; // MEETEI MAYEK CHEIKHAN
	if (c == 0xAAF1) return TRUE; // MEETEI MAYEK AHANG KHUDAM
	if (c == 0xABEB) return TRUE; // MEETEI MAYEK CHEIKHEI
	if (c == 0xFD3E) return TRUE; // ORNATE LEFT PARENTHESIS
	if (c == 0xFD3F) return TRUE; // ORNATE RIGHT PARENTHESIS
	if (c == 0xFE10) return TRUE; // PRESENTATION FORM FOR VERTICAL COMMA
	if (c == 0xFE11) return TRUE; // PRESENTATION FORM FOR VERTICAL IDEOGRAPHIC COMMA
	if (c == 0xFE12) return TRUE; // PRESENTATION FORM FOR VERTICAL IDEOGRAPHIC FULL STOP
	if (c == 0xFE13) return TRUE; // PRESENTATION FORM FOR VERTICAL COLON
	if (c == 0xFE14) return TRUE; // PRESENTATION FORM FOR VERTICAL SEMICOLON
	if (c == 0xFE15) return TRUE; // PRESENTATION FORM FOR VERTICAL EXCLAMATION MARK
	if (c == 0xFE16) return TRUE; // PRESENTATION FORM FOR VERTICAL QUESTION MARK
	if (c == 0xFE17) return TRUE; // PRESENTATION FORM FOR VERTICAL LEFT WHITE LENTICULAR BRACKET
	if (c == 0xFE18) return TRUE; // PRESENTATION FORM FOR VERTICAL RIGHT WHITE LENTICULAR BRAKCET
	if (c == 0xFE19) return TRUE; // PRESENTATION FORM FOR VERTICAL HORIZONTAL ELLIPSIS
	if (c == 0xFE30) return TRUE; // PRESENTATION FORM FOR VERTICAL TWO DOT LEADER
	if (c == 0xFE31) return TRUE; // PRESENTATION FORM FOR VERTICAL EM DASH
	if (c == 0xFE32) return TRUE; // PRESENTATION FORM FOR VERTICAL EN DASH
	if (c == 0xFE33) return TRUE; // PRESENTATION FORM FOR VERTICAL LOW LINE
	if (c == 0xFE34) return TRUE; // PRESENTATION FORM FOR VERTICAL WAVY LOW LINE
	if (c == 0xFE35) return TRUE; // PRESENTATION FORM FOR VERTICAL LEFT PARENTHESIS
	if (c == 0xFE36) return TRUE; // PRESENTATION FORM FOR VERTICAL RIGHT PARENTHESIS
	if (c == 0xFE37) return TRUE; // PRESENTATION FORM FOR VERTICAL LEFT CURLY BRACKET
	if (c == 0xFE38) return TRUE; // PRESENTATION FORM FOR VERTICAL RIGHT CURLY BRACKET
	if (c == 0xFE39) return TRUE; // PRESENTATION FORM FOR VERTICAL LEFT TORTOISE SHELL BRACKET
	if (c == 0xFE3A) return TRUE; // PRESENTATION FORM FOR VERTICAL RIGHT TORTOISE SHELL BRACKET
	if (c == 0xFE3B) return TRUE; // PRESENTATION FORM FOR VERTICAL LEFT BLACK LENTICULAR BRACKET
	if (c == 0xFE3C) return TRUE; // PRESENTATION FORM FOR VERTICAL RIGHT BLACK LENTICULAR BRACKET
	if (c == 0xFE3D) return TRUE; // PRESENTATION FORM FOR VERTICAL LEFT DOUBLE ANGLE BRACKET
	if (c == 0xFE3E) return TRUE; // PRESENTATION FORM FOR VERTICAL RIGHT DOUBLE ANGLE BRACKET
	if (c == 0xFE3F) return TRUE; // PRESENTATION FORM FOR VERTICAL LEFT ANGLE BRACKET
	if (c == 0xFE40) return TRUE; // PRESENTATION FORM FOR VERTICAL RIGHT ANGLE BRACKET
	if (c == 0xFE41) return TRUE; // PRESENTATION FORM FOR VERTICAL LEFT CORNER BRACKET
	if (c == 0xFE42) return TRUE; // PRESENTATION FORM FOR VERTICAL RIGHT CORNER BRACKET
	if (c == 0xFE43) return TRUE; // PRESENTATION FORM FOR VERTICAL LEFT WHITE CORNER BRACKET
	if (c == 0xFE44) return TRUE; // PRESENTATION FORM FOR VERTICAL RIGHT WHITE CORNER BRACKET
	if (c == 0xFE45) return TRUE; // SESAME DOT
	if (c == 0xFE46) return TRUE; // WHITE SESAME DOT
	if (c == 0xFE47) return TRUE; // PRESENTATION FORM FOR VERTICAL LEFT SQUARE BRACKET
	if (c == 0xFE48) return TRUE; // PRESENTATION FORM FOR VERTICAL RIGHT SQUARE BRACKET
	if (c == 0xFE49) return TRUE; // DASHED OVERLINE
	if (c == 0xFE4A) return TRUE; // CENTRELINE OVERLINE
	if (c == 0xFE4B) return TRUE; // WAVY OVERLINE
	if (c == 0xFE4C) return TRUE; // DOUBLE WAVY OVERLINE
	if (c == 0xFE4D) return TRUE; // DASHED LOW LINE
	if (c == 0xFE4E) return TRUE; // CENTRELINE LOW LINE
	if (c == 0xFE4F) return TRUE; // WAVY LOW LINE
	if (c == 0xFE50) return TRUE; // SMALL COMMA
	if (c == 0xFE51) return TRUE; // SMALL IDEOGRAPHIC COMMA
	if (c == 0xFE52) return TRUE; // SMALL FULL STOP
	if (c == 0xFE54) return TRUE; // SMALL SEMICOLON
	if (c == 0xFE55) return TRUE; // SMALL COLON
	if (c == 0xFE56) return TRUE; // SMALL QUESTION MARK
	if (c == 0xFE57) return TRUE; // SMALL EXCLAMATION MARK
	if (c == 0xFE58) return TRUE; // SMALL EM DASH
	if (c == 0xFE59) return TRUE; // SMALL LEFT PARENTHESIS
	if (c == 0xFE5A) return TRUE; // SMALL RIGHT PARENTHESIS
	if (c == 0xFE5B) return TRUE; // SMALL LEFT CURLY BRACKET
	if (c == 0xFE5C) return TRUE; // SMALL RIGHT CURLY BRACKET
	if (c == 0xFE5D) return TRUE; // SMALL LEFT TORTOISE SHELL BRACKET
	if (c == 0xFE5E) return TRUE; // SMALL RIGHT TORTOISE SHELL BRACKET
	if (c == 0xFE5F) return TRUE; // SMALL NUMBER SIGN
	if (c == 0xFE60) return TRUE; // SMALL AMPERSAND
	if (c == 0xFE61) return TRUE; // SMALL ASTERISK
	if (c == 0xFE63) return TRUE; // SMALL HYPHEN-MINUS
	if (c == 0xFE68) return TRUE; // SMALL REVERSE SOLIDUS
	if (c == 0xFE6A) return TRUE; // SMALL PERCENT SIGN
	if (c == 0xFE6B) return TRUE; // SMALL COMMERCIAL AT
	if (c == 0xFF01) return TRUE; // FULLWIDTH EXCLAMATION MARK
	if (c == 0xFF02) return TRUE; // FULLWIDTH QUOTATION MARK
	if (c == 0xFF03) return TRUE; // FULLWIDTH NUMBER SIGN
	if (c == 0xFF05) return TRUE; // FULLWIDTH PERCENT SIGN
	if (c == 0xFF06) return TRUE; // FULLWIDTH AMPERSAND
	if (c == 0xFF07) return TRUE; // FULLWIDTH APOSTROPHE
	if (c == 0xFF08) return TRUE; // FULLWIDTH LEFT PARENTHESIS
	if (c == 0xFF09) return TRUE; // FULLWIDTH RIGHT PARENTHESIS
	if (c == 0xFF0A) return TRUE; // FULLWIDTH ASTERISK
	if (c == 0xFF0C) return TRUE; // FULLWIDTH COMMA
	if (c == 0xFF0D) return TRUE; // FULLWIDTH HYPHEN-MINUS
	if (c == 0xFF0E) return TRUE; // FULLWIDTH FULL STOP
	if (c == 0xFF0F) return TRUE; // FULLWIDTH SOLIDUS
	if (c == 0xFF1A) return TRUE; // FULLWIDTH COLON
	if (c == 0xFF1B) return TRUE; // FULLWIDTH SEMICOLON
	if (c == 0xFF1F) return TRUE; // FULLWIDTH QUESTION MARK
	if (c == 0xFF20) return TRUE; // FULLWIDTH COMMERCIAL AT
	if (c == 0xFF3B) return TRUE; // FULLWIDTH LEFT SQUARE BRACKET
	if (c == 0xFF3C) return TRUE; // FULLWIDTH REVERSE SOLIDUS
	if (c == 0xFF3D) return TRUE; // FULLWIDTH RIGHT SQUARE BRACKET
	if (c == 0xFF3F) return TRUE; // FULLWIDTH LOW LINE
	if (c == 0xFF5B) return TRUE; // FULLWIDTH LEFT CURLY BRACKET
	if (c == 0xFF5D) return TRUE; // FULLWIDTH RIGHT CURLY BRACKET
	if (c == 0xFF5F) return TRUE; // FULLWIDTH LEFT WHITE PARENTHESIS
	if (c == 0xFF60) return TRUE; // FULLWIDTH RIGHT WHITE PARENTHESIS
	if (c == 0xFF61) return TRUE; // HALFWIDTH IDEOGRAPHIC FULL STOP
	if (c == 0xFF62) return TRUE; // HALFWIDTH LEFT CORNER BRACKET
	if (c == 0xFF63) return TRUE; // HALFWIDTH RIGHT CORNER BRACKET
	if (c == 0xFF64) return TRUE; // HALFWIDTH IDEOGRAPHIC COMMA
	if (c == 0xFF65) return TRUE; // HALFWIDTH KATAKANA MIDDLE DOT
	if (c == 0x10100) return TRUE; // AEGEAN WORD SEPARATOR LINE
	if (c == 0x10101) return TRUE; // AEGEAN WORD SEPARATOR DOT
	if (c == 0x10102) return TRUE; // AEGEAN CHECK MARK
	if (c == 0x1039F) return TRUE; // UGARITIC WORD DIVIDER
	if (c == 0x103D0) return TRUE; // OLD PERSIAN WORD DIVIDER
	if (c == 0x1056F) return TRUE; // CAUCASIAN ALBANIAN CITATION MARK
	if (c == 0x10857) return TRUE; // IMPERIAL ARAMAIC SECTION SIGN
	if (c == 0x1091F) return TRUE; // PHOENICIAN WORD SEPARATOR
	if (c == 0x1093F) return TRUE; // LYDIAN TRIANGULAR MARK
	if (c == 0x10A50) return TRUE; // KHAROSHTHI PUNCTUATION DOT
	if (c == 0x10A51) return TRUE; // KHAROSHTHI PUNCTUATION SMALL CIRCLE
	if (c == 0x10A52) return TRUE; // KHAROSHTHI PUNCTUATION CIRCLE
	if (c == 0x10A53) return TRUE; // KHAROSHTHI PUNCTUATION CRESCENT BAR
	if (c == 0x10A54) return TRUE; // KHAROSHTHI PUNCTUATION MANGALAM
	if (c == 0x10A55) return TRUE; // KHAROSHTHI PUNCTUATION LOTUS
	if (c == 0x10A56) return TRUE; // KHAROSHTHI PUNCTUATION DANDA
	if (c == 0x10A57) return TRUE; // KHAROSHTHI PUNCTUATION DOUBLE DANDA
	if (c == 0x10A58) return TRUE; // KHAROSHTHI PUNCTUATION LINES
	if (c == 0x10A7F) return TRUE; // OLD SOUTH ARABIAN NUMERIC INDICATOR
	if (c == 0x10AF0) return TRUE; // MANICHAEAN PUNCTUATION STAR
	if (c == 0x10AF1) return TRUE; // MANICHAEAN PUNCTUATION FLEURON
	if (c == 0x10AF2) return TRUE; // MANICHAEAN PUNCTUATION DOUBLE DOT WITHIN DOT
	if (c == 0x10AF3) return TRUE; // MANICHAEAN PUNCTUATION DOT WITHIN DOT
	if (c == 0x10AF4) return TRUE; // MANICHAEAN PUNCTUATION DOT
	if (c == 0x10AF5) return TRUE; // MANICHAEAN PUNCTUATION TWO DOTS
	if (c == 0x10AF6) return TRUE; // MANICHAEAN PUNCTUATION LINE FILLER
	if (c == 0x10B39) return TRUE; // AVESTAN ABBREVIATION MARK
	if (c == 0x10B3A) return TRUE; // TINY TWO DOTS OVER ONE DOT PUNCTUATION
	if (c == 0x10B3B) return TRUE; // SMALL TWO DOTS OVER ONE DOT PUNCTUATION
	if (c == 0x10B3C) return TRUE; // LARGE TWO DOTS OVER ONE DOT PUNCTUATION
	if (c == 0x10B3D) return TRUE; // LARGE ONE DOT OVER TWO DOTS PUNCTUATION
	if (c == 0x10B3E) return TRUE; // LARGE TWO RINGS OVER ONE RING PUNCTUATION
	if (c == 0x10B3F) return TRUE; // LARGE ONE RING OVER TWO RINGS PUNCTUATION
	if (c == 0x10B99) return TRUE; // PSALTER PAHLAVI SECTION MARK
	if (c == 0x10B9A) return TRUE; // PSALTER PAHLAVI TURNED SECTION MARK
	if (c == 0x10B9B) return TRUE; // PSALTER PAHLAVI FOUR DOTS WITH CROSS
	if (c == 0x10B9C) return TRUE; // PSALTER PAHLAVI FOUR DOTS WITH DOT
	if (c == 0x10EAD) return TRUE; // YEZIDI HYPHENATION MARK
	if (c == 0x10F55) return TRUE; // SOGDIAN PUNCTUATION TWO VERTICAL BARS
	if (c == 0x10F56) return TRUE; // SOGDIAN PUNCTUATION TWO VERTICAL BARS WITH DOTS
	if (c == 0x10F57) return TRUE; // SOGDIAN PUNCTUATION CIRCLE WITH DOT
	if (c == 0x10F58) return TRUE; // SOGDIAN PUNCTUATION TWO CIRCLES WITH DOTS
	if (c == 0x10F59) return TRUE; // SOGDIAN PUNCTUATION HALF CIRCLE WITH DOT
	if (c == 0x10F86) return TRUE; // OLD UYGHUR PUNCTUATION BAR
	if (c == 0x10F87) return TRUE; // OLD UYGHUR PUNCTUATION TWO BARS
	if (c == 0x10F88) return TRUE; // OLD UYGHUR PUNCTUATION TWO DOTS
	if (c == 0x10F89) return TRUE; // OLD UYGHUR PUNCTUATION FOUR DOTS
	if (c == 0x11047) return TRUE; // BRAHMI DANDA
	if (c == 0x11048) return TRUE; // BRAHMI DOUBLE DANDA
	if (c == 0x11049) return TRUE; // BRAHMI PUNCTUATION DOT
	if (c == 0x1104A) return TRUE; // BRAHMI PUNCTUATION DOUBLE DOT
	if (c == 0x1104B) return TRUE; // BRAHMI PUNCTUATION LINE
	if (c == 0x1104C) return TRUE; // BRAHMI PUNCTUATION CRESCENT BAR
	if (c == 0x1104D) return TRUE; // BRAHMI PUNCTUATION LOTUS
	if (c == 0x110BB) return TRUE; // KAITHI ABBREVIATION SIGN
	if (c == 0x110BC) return TRUE; // KAITHI ENUMERATION SIGN
	if (c == 0x110BE) return TRUE; // KAITHI SECTION MARK
	if (c == 0x110BF) return TRUE; // KAITHI DOUBLE SECTION MARK
	if (c == 0x110C0) return TRUE; // KAITHI DANDA
	if (c == 0x110C1) return TRUE; // KAITHI DOUBLE DANDA
	if (c == 0x11140) return TRUE; // CHAKMA SECTION MARK
	if (c == 0x11141) return TRUE; // CHAKMA DANDA
	if (c == 0x11142) return TRUE; // CHAKMA DOUBLE DANDA
	if (c == 0x11143) return TRUE; // CHAKMA QUESTION MARK
	if (c == 0x11174) return TRUE; // MAHAJANI ABBREVIATION SIGN
	if (c == 0x11175) return TRUE; // MAHAJANI SECTION MARK
	if (c == 0x111C5) return TRUE; // SHARADA DANDA
	if (c == 0x111C6) return TRUE; // SHARADA DOUBLE DANDA
	if (c == 0x111C7) return TRUE; // SHARADA ABBREVIATION SIGN
	if (c == 0x111C8) return TRUE; // SHARADA SEPARATOR
	if (c == 0x111CD) return TRUE; // SHARADA SUTRA MARK
	if (c == 0x111DB) return TRUE; // SHARADA SIGN SIDDHAM
	if (c == 0x111DD) return TRUE; // SHARADA CONTINUATION SIGN
	if (c == 0x111DE) return TRUE; // SHARADA SECTION MARK-1
	if (c == 0x111DF) return TRUE; // SHARADA SECTION MARK-2
	if (c == 0x11238) return TRUE; // KHOJKI DANDA
	if (c == 0x11239) return TRUE; // KHOJKI DOUBLE DANDA
	if (c == 0x1123A) return TRUE; // KHOJKI WORD SEPARATOR
	if (c == 0x1123B) return TRUE; // KHOJKI SECTION MARK
	if (c == 0x1123C) return TRUE; // KHOJKI DOUBLE SECTION MARK
	if (c == 0x1123D) return TRUE; // KHOJKI ABBREVIATION SIGN
	if (c == 0x112A9) return TRUE; // MULTANI SECTION MARK
	if (c == 0x1144B) return TRUE; // NEWA DANDA
	if (c == 0x1144C) return TRUE; // NEWA DOUBLE DANDA
	if (c == 0x1144D) return TRUE; // NEWA COMMA
	if (c == 0x1144E) return TRUE; // NEWA GAP FILLER
	if (c == 0x1144F) return TRUE; // NEWA ABBREVIATION SIGN
	if (c == 0x1145A) return TRUE; // NEWA DOUBLE COMMA
	if (c == 0x1145B) return TRUE; // NEWA PLACEHOLDER MARK
	if (c == 0x1145D) return TRUE; // NEWA INSERTION SIGN
	if (c == 0x114C6) return TRUE; // TIRHUTA ABBREVIATION SIGN
	if (c == 0x115C1) return TRUE; // SIDDHAM SIGN SIDDHAM
	if (c == 0x115C2) return TRUE; // SIDDHAM DANDA
	if (c == 0x115C3) return TRUE; // SIDDHAM DOUBLE DANDA
	if (c == 0x115C4) return TRUE; // SIDDHAM SEPARATOR DOT
	if (c == 0x115C5) return TRUE; // SIDDHAM SEPARATOR BAR
	if (c == 0x115C6) return TRUE; // SIDDHAM REPETITION MARK-1
	if (c == 0x115C7) return TRUE; // SIDDHAM REPETITION MARK-2
	if (c == 0x115C8) return TRUE; // SIDDHAM REPETITION MARK-3
	if (c == 0x115C9) return TRUE; // SIDDHAM END OF TEXT MARK
	if (c == 0x115CA) return TRUE; // SIDDHAM SECTION MARK WITH TRIDENT AND U-SHAPED ORNAMENTS
	if (c == 0x115CB) return TRUE; // SIDDHAM SECTION MARK WITH TRIDENT AND DOTTED CRESCENTS
	if (c == 0x115CC) return TRUE; // SIDDHAM SECTION MARK WITH RAYS AND DOTTED CRESCENTS
	if (c == 0x115CD) return TRUE; // SIDDHAM SECTION MARK WITH RAYS AND DOTTED DOUBLE CRESCENTS
	if (c == 0x115CE) return TRUE; // SIDDHAM SECTION MARK WITH RAYS AND DOTTED TRIPLE CRESCENTS
	if (c == 0x115CF) return TRUE; // SIDDHAM SECTION MARK DOUBLE RING
	if (c == 0x115D0) return TRUE; // SIDDHAM SECTION MARK DOUBLE RING WITH RAYS
	if (c == 0x115D1) return TRUE; // SIDDHAM SECTION MARK WITH DOUBLE CRESCENTS
	if (c == 0x115D2) return TRUE; // SIDDHAM SECTION MARK WITH TRIPLE CRESCENTS
	if (c == 0x115D3) return TRUE; // SIDDHAM SECTION MARK WITH QUADRUPLE CRESCENTS
	if (c == 0x115D4) return TRUE; // SIDDHAM SECTION MARK WITH SEPTUPLE CRESCENTS
	if (c == 0x115D5) return TRUE; // SIDDHAM SECTION MARK WITH CIRCLES AND RAYS
	if (c == 0x115D6) return TRUE; // SIDDHAM SECTION MARK WITH CIRCLES AND TWO ENCLOSURES
	if (c == 0x115D7) return TRUE; // SIDDHAM SECTION MARK WITH CIRCLES AND FOUR ENCLOSURES
	if (c == 0x11641) return TRUE; // MODI DANDA
	if (c == 0x11642) return TRUE; // MODI DOUBLE DANDA
	if (c == 0x11643) return TRUE; // MODI ABBREVIATION SIGN
	if (c == 0x11660) return TRUE; // MONGOLIAN BIRGA WITH ORNAMENT
	if (c == 0x11661) return TRUE; // MONGOLIAN ROTATED BIRGA
	if (c == 0x11662) return TRUE; // MONGOLIAN DOUBLE BIRGA WITH ORNAMENT
	if (c == 0x11663) return TRUE; // MONGOLIAN TRIPLE BIRGA WITH ORNAMENT
	if (c == 0x11664) return TRUE; // MONGOLIAN BIRGA WITH DOUBLE ORNAMENT
	if (c == 0x11665) return TRUE; // MONGOLIAN ROTATED BIRGA WITH ORNAMENT
	if (c == 0x11666) return TRUE; // MONGOLIAN ROTATED BIRGA WITH DOUBLE ORNAMENT
	if (c == 0x11667) return TRUE; // MONGOLIAN INVERTED BIRGA
	if (c == 0x11668) return TRUE; // MONGOLIAN INVERTED BIRGA WITH DOUBLE ORNAMENT
	if (c == 0x11669) return TRUE; // MONGOLIAN SWIRL BIRGA
	if (c == 0x1166A) return TRUE; // MONGOLIAN SWIRL BIRGA WITH ORNAMENT
	if (c == 0x1166B) return TRUE; // MONGOLIAN SWIRL BIRGA WITH DOUBLE ORNAMENT
	if (c == 0x1166C) return TRUE; // MONGOLIAN TURNED SWIRL BIRGA WITH DOUBLE ORNAMENT
	if (c == 0x116B9) return TRUE; // TAKRI ABBREVIATION SIGN
	if (c == 0x1173C) return TRUE; // AHOM SIGN SMALL SECTION
	if (c == 0x1173D) return TRUE; // AHOM SIGN SECTION
	if (c == 0x1173E) return TRUE; // AHOM SIGN RULAI
	if (c == 0x1183B) return TRUE; // DOGRA ABBREVIATION SIGN
	if (c == 0x11944) return TRUE; // DIVES AKURU DOUBLE DANDA
	if (c == 0x11945) return TRUE; // DIVES AKURU GAP FILLER
	if (c == 0x11946) return TRUE; // DIVES AKURU END OF TEXT MARK
	if (c == 0x119E2) return TRUE; // NANDINAGARI SIGN SIDDHAM
	if (c == 0x11A3F) return TRUE; // ZANABAZAR SQUARE INITIAL HEAD MARK
	if (c == 0x11A40) return TRUE; // ZANABAZAR SQUARE CLOSING HEAD MARK
	if (c == 0x11A41) return TRUE; // ZANABAZAR SQUARE MARK TSHEG
	if (c == 0x11A42) return TRUE; // ZANABAZAR SQUARE MARK SHAD
	if (c == 0x11A43) return TRUE; // ZANABAZAR SQUARE MARK DOUBLE SHAD
	if (c == 0x11A44) return TRUE; // ZANABAZAR SQUARE MARK LONG TSHEG
	if (c == 0x11A45) return TRUE; // ZANABAZAR SQUARE INITIAL DOUBLE-LINED HEAD MARK
	if (c == 0x11A46) return TRUE; // ZANABAZAR SQUARE CLOSING DOUBLE-LINED HEAD MARK
	if (c == 0x11A9A) return TRUE; // SOYOMBO MARK TSHEG
	if (c == 0x11A9B) return TRUE; // SOYOMBO MARK SHAD
	if (c == 0x11A9C) return TRUE; // SOYOMBO MARK DOUBLE SHAD
	if (c == 0x11A9E) return TRUE; // SOYOMBO HEAD MARK WITH MOON AND SUN AND TRIPLE FLAME
	if (c == 0x11A9F) return TRUE; // SOYOMBO HEAD MARK WITH MOON AND SUN AND FLAME
	if (c == 0x11AA0) return TRUE; // SOYOMBO HEAD MARK WITH MOON AND SUN
	if (c == 0x11AA1) return TRUE; // SOYOMBO TERMINAL MARK-1
	if (c == 0x11AA2) return TRUE; // SOYOMBO TERMINAL MARK-2
	if (c == 0x11B00) return TRUE; // DEVANAGARI HEAD MARK
	if (c == 0x11B01) return TRUE; // DEVANAGARI HEAD MARK WITH HEADSTROKE
	if (c == 0x11B02) return TRUE; // DEVANAGARI SIGN BHALE
	if (c == 0x11B03) return TRUE; // DEVANAGARI SIGN BHALE WITH HOOK
	if (c == 0x11B04) return TRUE; // DEVANAGARI SIGN EXTENDED BHALE
	if (c == 0x11B05) return TRUE; // DEVANAGARI SIGN EXTENDED BHALE WITH HOOK
	if (c == 0x11B06) return TRUE; // DEVANAGARI SIGN WESTERN FIVE-LIKE BHALE
	if (c == 0x11B07) return TRUE; // DEVANAGARI SIGN WESTERN NINE-LIKE BHALE
	if (c == 0x11B08) return TRUE; // DEVANAGARI SIGN REVERSED NINE-LIKE BHALE
	if (c == 0x11B09) return TRUE; // DEVANAGARI SIGN MINDU
	if (c == 0x11C41) return TRUE; // BHAIKSUKI DANDA
	if (c == 0x11C42) return TRUE; // BHAIKSUKI DOUBLE DANDA
	if (c == 0x11C43) return TRUE; // BHAIKSUKI WORD SEPARATOR
	if (c == 0x11C44) return TRUE; // BHAIKSUKI GAP FILLER-1
	if (c == 0x11C45) return TRUE; // BHAIKSUKI GAP FILLER-2
	if (c == 0x11C70) return TRUE; // MARCHEN HEAD MARK
	if (c == 0x11C71) return TRUE; // MARCHEN MARK SHAD
	if (c == 0x11EF7) return TRUE; // MAKASAR PASSIMBANG
	if (c == 0x11EF8) return TRUE; // MAKASAR END OF SECTION
	if (c == 0x11F43) return TRUE; // KAWI DANDA
	if (c == 0x11F44) return TRUE; // KAWI DOUBLE DANDA
	if (c == 0x11F45) return TRUE; // KAWI PUNCTUATION SECTION MARKER
	if (c == 0x11F46) return TRUE; // KAWI PUNCTUATION ALTERNATE SECTION MARKER
	if (c == 0x11F47) return TRUE; // KAWI PUNCTUATION FLOWER
	if (c == 0x11F48) return TRUE; // KAWI PUNCTUATION SPACE FILLER
	if (c == 0x11F49) return TRUE; // KAWI PUNCTUATION DOT
	if (c == 0x11F4A) return TRUE; // KAWI PUNCTUATION DOUBLE DOT
	if (c == 0x11F4B) return TRUE; // KAWI PUNCTUATION TRIPLE DOT
	if (c == 0x11F4C) return TRUE; // KAWI PUNCTUATION CIRCLE
	if (c == 0x11F4D) return TRUE; // KAWI PUNCTUATION FILLED CIRCLE
	if (c == 0x11F4E) return TRUE; // KAWI PUNCTUATION SPIRAL
	if (c == 0x11F4F) return TRUE; // KAWI PUNCTUATION CLOSING SPIRAL
	if (c == 0x11FFF) return TRUE; // TAMIL PUNCTUATION END OF TEXT
	if (c == 0x12470) return TRUE; // CUNEIFORM PUNCTUATION SIGN OLD ASSYRIAN WORD DIVIDER
	if (c == 0x12471) return TRUE; // CUNEIFORM PUNCTUATION SIGN VERTICAL COLON
	if (c == 0x12472) return TRUE; // CUNEIFORM PUNCTUATION SIGN DIAGONAL COLON
	if (c == 0x12473) return TRUE; // CUNEIFORM PUNCTUATION SIGN DIAGONAL TRICOLON
	if (c == 0x12474) return TRUE; // CUNEIFORM PUNCTUATION SIGN DIAGONAL QUADCOLON
	if (c == 0x12FF1) return TRUE; // CYPRO-MINOAN SIGN CM301
	if (c == 0x12FF2) return TRUE; // CYPRO-MINOAN SIGN CM302
	if (c == 0x16A6E) return TRUE; // MRO DANDA
	if (c == 0x16A6F) return TRUE; // MRO DOUBLE DANDA
	if (c == 0x16AF5) return TRUE; // BASSA VAH FULL STOP
	if (c == 0x16B37) return TRUE; // PAHAWH HMONG SIGN VOS THOM
	if (c == 0x16B38) return TRUE; // PAHAWH HMONG SIGN VOS TSHAB CEEB
	if (c == 0x16B39) return TRUE; // PAHAWH HMONG SIGN CIM CHEEM
	if (c == 0x16B3A) return TRUE; // PAHAWH HMONG SIGN VOS THIAB
	if (c == 0x16B3B) return TRUE; // PAHAWH HMONG SIGN VOS FEEM
	if (c == 0x16B44) return TRUE; // PAHAWH HMONG SIGN XAUS
	if (c == 0x16E97) return TRUE; // MEDEFAIDRIN COMMA
	if (c == 0x16E98) return TRUE; // MEDEFAIDRIN FULL STOP
	if (c == 0x16E99) return TRUE; // MEDEFAIDRIN SYMBOL AIVA
	if (c == 0x16E9A) return TRUE; // MEDEFAIDRIN EXCLAMATION OH
	if (c == 0x16FE2) return TRUE; // OLD CHINESE HOOK MARK
	if (c == 0x1BC9F) return TRUE; // DUPLOYAN PUNCTUATION CHINOOK FULL STOP
	if (c == 0x1DA87) return TRUE; // SIGNWRITING COMMA
	if (c == 0x1DA88) return TRUE; // SIGNWRITING FULL STOP
	if (c == 0x1DA89) return TRUE; // SIGNWRITING SEMICOLON
	if (c == 0x1DA8A) return TRUE; // SIGNWRITING COLON
	if (c == 0x1DA8B) return TRUE; // SIGNWRITING PARENTHESIS
	if (c == 0x1E95E) return TRUE; // ADLAM INITIAL EXCLAMATION MARK
	if (c == 0x1E95F) return TRUE; // ADLAM INITIAL QUESTION MARK
	return FALSE;
}

@ Another epic, mechanically written function, performs the full case folding
defined by Unicode 15.0, turning |c| into a run of up to four characters
representing its canonical upper-case form.

=
void Characters::full_Unicode_fold(inchar32_t c, inchar32_t *F) {
	F[1] = 0; F[2] = 0; F[3] = 0;
	if (c < 0x0100) {
		if ((c >= 0x0041) && (c <= 0x005A)) { F[0] = 0x0061 + (c - 0x0041); return; } /* LATIN CAPITAL LETTER A to LATIN CAPITAL LETTER Z */
		if (c == 0x00B5) { F[0] = 0x03BC; return; } /* MICRO SIGN */
		if ((c >= 0x00C0) && (c <= 0x00D6)) { F[0] = 0x00E0 + (c - 0x00C0); return; } /* LATIN CAPITAL LETTER A WITH GRAVE to LATIN CAPITAL LETTER O WITH DIAERESIS */
		if ((c >= 0x00D8) && (c <= 0x00DE)) { F[0] = 0x00F8 + (c - 0x00D8); return; } /* LATIN CAPITAL LETTER O WITH STROKE to LATIN CAPITAL LETTER THORN */
		if (c == 0x00DF) { F[0] = 0x0073; F[1] = 0x0073; return; } /* LATIN SMALL LETTER SHARP S */
	} else if ((c >= 0x0100) && (c < 0x0200)) {
		if (c == 0x0100) { F[0] = 0x0101; return; } /* LATIN CAPITAL LETTER A WITH MACRON */
		if (c == 0x0102) { F[0] = 0x0103; return; } /* LATIN CAPITAL LETTER A WITH BREVE */
		if (c == 0x0104) { F[0] = 0x0105; return; } /* LATIN CAPITAL LETTER A WITH OGONEK */
		if (c == 0x0106) { F[0] = 0x0107; return; } /* LATIN CAPITAL LETTER C WITH ACUTE */
		if (c == 0x0108) { F[0] = 0x0109; return; } /* LATIN CAPITAL LETTER C WITH CIRCUMFLEX */
		if (c == 0x010A) { F[0] = 0x010B; return; } /* LATIN CAPITAL LETTER C WITH DOT ABOVE */
		if (c == 0x010C) { F[0] = 0x010D; return; } /* LATIN CAPITAL LETTER C WITH CARON */
		if (c == 0x010E) { F[0] = 0x010F; return; } /* LATIN CAPITAL LETTER D WITH CARON */
		if (c == 0x0110) { F[0] = 0x0111; return; } /* LATIN CAPITAL LETTER D WITH STROKE */
		if (c == 0x0112) { F[0] = 0x0113; return; } /* LATIN CAPITAL LETTER E WITH MACRON */
		if (c == 0x0114) { F[0] = 0x0115; return; } /* LATIN CAPITAL LETTER E WITH BREVE */
		if (c == 0x0116) { F[0] = 0x0117; return; } /* LATIN CAPITAL LETTER E WITH DOT ABOVE */
		if (c == 0x0118) { F[0] = 0x0119; return; } /* LATIN CAPITAL LETTER E WITH OGONEK */
		if (c == 0x011A) { F[0] = 0x011B; return; } /* LATIN CAPITAL LETTER E WITH CARON */
		if (c == 0x011C) { F[0] = 0x011D; return; } /* LATIN CAPITAL LETTER G WITH CIRCUMFLEX */
		if (c == 0x011E) { F[0] = 0x011F; return; } /* LATIN CAPITAL LETTER G WITH BREVE */
		if (c == 0x0120) { F[0] = 0x0121; return; } /* LATIN CAPITAL LETTER G WITH DOT ABOVE */
		if (c == 0x0122) { F[0] = 0x0123; return; } /* LATIN CAPITAL LETTER G WITH CEDILLA */
		if (c == 0x0124) { F[0] = 0x0125; return; } /* LATIN CAPITAL LETTER H WITH CIRCUMFLEX */
		if (c == 0x0126) { F[0] = 0x0127; return; } /* LATIN CAPITAL LETTER H WITH STROKE */
		if (c == 0x0128) { F[0] = 0x0129; return; } /* LATIN CAPITAL LETTER I WITH TILDE */
		if (c == 0x012A) { F[0] = 0x012B; return; } /* LATIN CAPITAL LETTER I WITH MACRON */
		if (c == 0x012C) { F[0] = 0x012D; return; } /* LATIN CAPITAL LETTER I WITH BREVE */
		if (c == 0x012E) { F[0] = 0x012F; return; } /* LATIN CAPITAL LETTER I WITH OGONEK */
		if (c == 0x0130) { F[0] = 0x0069; F[1] = 0x0307; return; } /* LATIN CAPITAL LETTER I WITH DOT ABOVE */
		if (c == 0x0132) { F[0] = 0x0133; return; } /* LATIN CAPITAL LIGATURE IJ */
		if (c == 0x0134) { F[0] = 0x0135; return; } /* LATIN CAPITAL LETTER J WITH CIRCUMFLEX */
		if (c == 0x0136) { F[0] = 0x0137; return; } /* LATIN CAPITAL LETTER K WITH CEDILLA */
		if (c == 0x0139) { F[0] = 0x013A; return; } /* LATIN CAPITAL LETTER L WITH ACUTE */
		if (c == 0x013B) { F[0] = 0x013C; return; } /* LATIN CAPITAL LETTER L WITH CEDILLA */
		if (c == 0x013D) { F[0] = 0x013E; return; } /* LATIN CAPITAL LETTER L WITH CARON */
		if (c == 0x013F) { F[0] = 0x0140; return; } /* LATIN CAPITAL LETTER L WITH MIDDLE DOT */
		if (c == 0x0141) { F[0] = 0x0142; return; } /* LATIN CAPITAL LETTER L WITH STROKE */
		if (c == 0x0143) { F[0] = 0x0144; return; } /* LATIN CAPITAL LETTER N WITH ACUTE */
		if (c == 0x0145) { F[0] = 0x0146; return; } /* LATIN CAPITAL LETTER N WITH CEDILLA */
		if (c == 0x0147) { F[0] = 0x0148; return; } /* LATIN CAPITAL LETTER N WITH CARON */
		if (c == 0x0149) { F[0] = 0x02BC; F[1] = 0x006E; return; } /* LATIN SMALL LETTER N PRECEDED BY APOSTROPHE */
		if (c == 0x014A) { F[0] = 0x014B; return; } /* LATIN CAPITAL LETTER ENG */
		if (c == 0x014C) { F[0] = 0x014D; return; } /* LATIN CAPITAL LETTER O WITH MACRON */
		if (c == 0x014E) { F[0] = 0x014F; return; } /* LATIN CAPITAL LETTER O WITH BREVE */
		if (c == 0x0150) { F[0] = 0x0151; return; } /* LATIN CAPITAL LETTER O WITH DOUBLE ACUTE */
		if (c == 0x0152) { F[0] = 0x0153; return; } /* LATIN CAPITAL LIGATURE OE */
		if (c == 0x0154) { F[0] = 0x0155; return; } /* LATIN CAPITAL LETTER R WITH ACUTE */
		if (c == 0x0156) { F[0] = 0x0157; return; } /* LATIN CAPITAL LETTER R WITH CEDILLA */
		if (c == 0x0158) { F[0] = 0x0159; return; } /* LATIN CAPITAL LETTER R WITH CARON */
		if (c == 0x015A) { F[0] = 0x015B; return; } /* LATIN CAPITAL LETTER S WITH ACUTE */
		if (c == 0x015C) { F[0] = 0x015D; return; } /* LATIN CAPITAL LETTER S WITH CIRCUMFLEX */
		if (c == 0x015E) { F[0] = 0x015F; return; } /* LATIN CAPITAL LETTER S WITH CEDILLA */
		if (c == 0x0160) { F[0] = 0x0161; return; } /* LATIN CAPITAL LETTER S WITH CARON */
		if (c == 0x0162) { F[0] = 0x0163; return; } /* LATIN CAPITAL LETTER T WITH CEDILLA */
		if (c == 0x0164) { F[0] = 0x0165; return; } /* LATIN CAPITAL LETTER T WITH CARON */
		if (c == 0x0166) { F[0] = 0x0167; return; } /* LATIN CAPITAL LETTER T WITH STROKE */
		if (c == 0x0168) { F[0] = 0x0169; return; } /* LATIN CAPITAL LETTER U WITH TILDE */
		if (c == 0x016A) { F[0] = 0x016B; return; } /* LATIN CAPITAL LETTER U WITH MACRON */
		if (c == 0x016C) { F[0] = 0x016D; return; } /* LATIN CAPITAL LETTER U WITH BREVE */
		if (c == 0x016E) { F[0] = 0x016F; return; } /* LATIN CAPITAL LETTER U WITH RING ABOVE */
		if (c == 0x0170) { F[0] = 0x0171; return; } /* LATIN CAPITAL LETTER U WITH DOUBLE ACUTE */
		if (c == 0x0172) { F[0] = 0x0173; return; } /* LATIN CAPITAL LETTER U WITH OGONEK */
		if (c == 0x0174) { F[0] = 0x0175; return; } /* LATIN CAPITAL LETTER W WITH CIRCUMFLEX */
		if (c == 0x0176) { F[0] = 0x0177; return; } /* LATIN CAPITAL LETTER Y WITH CIRCUMFLEX */
		if (c == 0x0178) { F[0] = 0x00FF; return; } /* LATIN CAPITAL LETTER Y WITH DIAERESIS */
		if (c == 0x0179) { F[0] = 0x017A; return; } /* LATIN CAPITAL LETTER Z WITH ACUTE */
		if (c == 0x017B) { F[0] = 0x017C; return; } /* LATIN CAPITAL LETTER Z WITH DOT ABOVE */
		if (c == 0x017D) { F[0] = 0x017E; return; } /* LATIN CAPITAL LETTER Z WITH CARON */
		if (c == 0x017F) { F[0] = 0x0073; return; } /* LATIN SMALL LETTER LONG S */
		if (c == 0x0181) { F[0] = 0x0253; return; } /* LATIN CAPITAL LETTER B WITH HOOK */
		if (c == 0x0182) { F[0] = 0x0183; return; } /* LATIN CAPITAL LETTER B WITH TOPBAR */
		if (c == 0x0184) { F[0] = 0x0185; return; } /* LATIN CAPITAL LETTER TONE SIX */
		if (c == 0x0186) { F[0] = 0x0254; return; } /* LATIN CAPITAL LETTER OPEN O */
		if (c == 0x0187) { F[0] = 0x0188; return; } /* LATIN CAPITAL LETTER C WITH HOOK */
		if (c == 0x0189) { F[0] = 0x0256; return; } /* LATIN CAPITAL LETTER AFRICAN D */
		if (c == 0x018A) { F[0] = 0x0257; return; } /* LATIN CAPITAL LETTER D WITH HOOK */
		if (c == 0x018B) { F[0] = 0x018C; return; } /* LATIN CAPITAL LETTER D WITH TOPBAR */
		if (c == 0x018E) { F[0] = 0x01DD; return; } /* LATIN CAPITAL LETTER REVERSED E */
		if (c == 0x018F) { F[0] = 0x0259; return; } /* LATIN CAPITAL LETTER SCHWA */
		if (c == 0x0190) { F[0] = 0x025B; return; } /* LATIN CAPITAL LETTER OPEN E */
		if (c == 0x0191) { F[0] = 0x0192; return; } /* LATIN CAPITAL LETTER F WITH HOOK */
		if (c == 0x0193) { F[0] = 0x0260; return; } /* LATIN CAPITAL LETTER G WITH HOOK */
		if (c == 0x0194) { F[0] = 0x0263; return; } /* LATIN CAPITAL LETTER GAMMA */
		if (c == 0x0196) { F[0] = 0x0269; return; } /* LATIN CAPITAL LETTER IOTA */
		if (c == 0x0197) { F[0] = 0x0268; return; } /* LATIN CAPITAL LETTER I WITH STROKE */
		if (c == 0x0198) { F[0] = 0x0199; return; } /* LATIN CAPITAL LETTER K WITH HOOK */
		if (c == 0x019C) { F[0] = 0x026F; return; } /* LATIN CAPITAL LETTER TURNED M */
		if (c == 0x019D) { F[0] = 0x0272; return; } /* LATIN CAPITAL LETTER N WITH LEFT HOOK */
		if (c == 0x019F) { F[0] = 0x0275; return; } /* LATIN CAPITAL LETTER O WITH MIDDLE TILDE */
		if (c == 0x01A0) { F[0] = 0x01A1; return; } /* LATIN CAPITAL LETTER O WITH HORN */
		if (c == 0x01A2) { F[0] = 0x01A3; return; } /* LATIN CAPITAL LETTER OI */
		if (c == 0x01A4) { F[0] = 0x01A5; return; } /* LATIN CAPITAL LETTER P WITH HOOK */
		if (c == 0x01A6) { F[0] = 0x0280; return; } /* LATIN LETTER YR */
		if (c == 0x01A7) { F[0] = 0x01A8; return; } /* LATIN CAPITAL LETTER TONE TWO */
		if (c == 0x01A9) { F[0] = 0x0283; return; } /* LATIN CAPITAL LETTER ESH */
		if (c == 0x01AC) { F[0] = 0x01AD; return; } /* LATIN CAPITAL LETTER T WITH HOOK */
		if (c == 0x01AE) { F[0] = 0x0288; return; } /* LATIN CAPITAL LETTER T WITH RETROFLEX HOOK */
		if (c == 0x01AF) { F[0] = 0x01B0; return; } /* LATIN CAPITAL LETTER U WITH HORN */
		if (c == 0x01B1) { F[0] = 0x028A; return; } /* LATIN CAPITAL LETTER UPSILON */
		if (c == 0x01B2) { F[0] = 0x028B; return; } /* LATIN CAPITAL LETTER V WITH HOOK */
		if (c == 0x01B3) { F[0] = 0x01B4; return; } /* LATIN CAPITAL LETTER Y WITH HOOK */
		if (c == 0x01B5) { F[0] = 0x01B6; return; } /* LATIN CAPITAL LETTER Z WITH STROKE */
		if (c == 0x01B7) { F[0] = 0x0292; return; } /* LATIN CAPITAL LETTER EZH */
		if (c == 0x01B8) { F[0] = 0x01B9; return; } /* LATIN CAPITAL LETTER EZH REVERSED */
		if (c == 0x01BC) { F[0] = 0x01BD; return; } /* LATIN CAPITAL LETTER TONE FIVE */
		if (c == 0x01C4) { F[0] = 0x01C6; return; } /* LATIN CAPITAL LETTER DZ WITH CARON */
		if (c == 0x01C5) { F[0] = 0x01C6; return; } /* LATIN CAPITAL LETTER D WITH SMALL LETTER Z WITH CARON */
		if (c == 0x01C7) { F[0] = 0x01C9; return; } /* LATIN CAPITAL LETTER LJ */
		if (c == 0x01C8) { F[0] = 0x01C9; return; } /* LATIN CAPITAL LETTER L WITH SMALL LETTER J */
		if (c == 0x01CA) { F[0] = 0x01CC; return; } /* LATIN CAPITAL LETTER NJ */
		if (c == 0x01CB) { F[0] = 0x01CC; return; } /* LATIN CAPITAL LETTER N WITH SMALL LETTER J */
		if (c == 0x01CD) { F[0] = 0x01CE; return; } /* LATIN CAPITAL LETTER A WITH CARON */
		if (c == 0x01CF) { F[0] = 0x01D0; return; } /* LATIN CAPITAL LETTER I WITH CARON */
		if (c == 0x01D1) { F[0] = 0x01D2; return; } /* LATIN CAPITAL LETTER O WITH CARON */
		if (c == 0x01D3) { F[0] = 0x01D4; return; } /* LATIN CAPITAL LETTER U WITH CARON */
		if (c == 0x01D5) { F[0] = 0x01D6; return; } /* LATIN CAPITAL LETTER U WITH DIAERESIS AND MACRON */
		if (c == 0x01D7) { F[0] = 0x01D8; return; } /* LATIN CAPITAL LETTER U WITH DIAERESIS AND ACUTE */
		if (c == 0x01D9) { F[0] = 0x01DA; return; } /* LATIN CAPITAL LETTER U WITH DIAERESIS AND CARON */
		if (c == 0x01DB) { F[0] = 0x01DC; return; } /* LATIN CAPITAL LETTER U WITH DIAERESIS AND GRAVE */
		if (c == 0x01DE) { F[0] = 0x01DF; return; } /* LATIN CAPITAL LETTER A WITH DIAERESIS AND MACRON */
		if (c == 0x01E0) { F[0] = 0x01E1; return; } /* LATIN CAPITAL LETTER A WITH DOT ABOVE AND MACRON */
		if (c == 0x01E2) { F[0] = 0x01E3; return; } /* LATIN CAPITAL LETTER AE WITH MACRON */
		if (c == 0x01E4) { F[0] = 0x01E5; return; } /* LATIN CAPITAL LETTER G WITH STROKE */
		if (c == 0x01E6) { F[0] = 0x01E7; return; } /* LATIN CAPITAL LETTER G WITH CARON */
		if (c == 0x01E8) { F[0] = 0x01E9; return; } /* LATIN CAPITAL LETTER K WITH CARON */
		if (c == 0x01EA) { F[0] = 0x01EB; return; } /* LATIN CAPITAL LETTER O WITH OGONEK */
		if (c == 0x01EC) { F[0] = 0x01ED; return; } /* LATIN CAPITAL LETTER O WITH OGONEK AND MACRON */
		if (c == 0x01EE) { F[0] = 0x01EF; return; } /* LATIN CAPITAL LETTER EZH WITH CARON */
		if (c == 0x01F0) { F[0] = 0x006A; F[1] = 0x030C; return; } /* LATIN SMALL LETTER J WITH CARON */
		if (c == 0x01F1) { F[0] = 0x01F3; return; } /* LATIN CAPITAL LETTER DZ */
		if (c == 0x01F2) { F[0] = 0x01F3; return; } /* LATIN CAPITAL LETTER D WITH SMALL LETTER Z */
		if (c == 0x01F4) { F[0] = 0x01F5; return; } /* LATIN CAPITAL LETTER G WITH ACUTE */
		if (c == 0x01F6) { F[0] = 0x0195; return; } /* LATIN CAPITAL LETTER HWAIR */
		if (c == 0x01F7) { F[0] = 0x01BF; return; } /* LATIN CAPITAL LETTER WYNN */
		if (c == 0x01F8) { F[0] = 0x01F9; return; } /* LATIN CAPITAL LETTER N WITH GRAVE */
		if (c == 0x01FA) { F[0] = 0x01FB; return; } /* LATIN CAPITAL LETTER A WITH RING ABOVE AND ACUTE */
		if (c == 0x01FC) { F[0] = 0x01FD; return; } /* LATIN CAPITAL LETTER AE WITH ACUTE */
		if (c == 0x01FE) { F[0] = 0x01FF; return; } /* LATIN CAPITAL LETTER O WITH STROKE AND ACUTE */
	} else if ((c >= 0x0200) && (c < 0x0300)) {
		if (c == 0x0200) { F[0] = 0x0201; return; } /* LATIN CAPITAL LETTER A WITH DOUBLE GRAVE */
		if (c == 0x0202) { F[0] = 0x0203; return; } /* LATIN CAPITAL LETTER A WITH INVERTED BREVE */
		if (c == 0x0204) { F[0] = 0x0205; return; } /* LATIN CAPITAL LETTER E WITH DOUBLE GRAVE */
		if (c == 0x0206) { F[0] = 0x0207; return; } /* LATIN CAPITAL LETTER E WITH INVERTED BREVE */
		if (c == 0x0208) { F[0] = 0x0209; return; } /* LATIN CAPITAL LETTER I WITH DOUBLE GRAVE */
		if (c == 0x020A) { F[0] = 0x020B; return; } /* LATIN CAPITAL LETTER I WITH INVERTED BREVE */
		if (c == 0x020C) { F[0] = 0x020D; return; } /* LATIN CAPITAL LETTER O WITH DOUBLE GRAVE */
		if (c == 0x020E) { F[0] = 0x020F; return; } /* LATIN CAPITAL LETTER O WITH INVERTED BREVE */
		if (c == 0x0210) { F[0] = 0x0211; return; } /* LATIN CAPITAL LETTER R WITH DOUBLE GRAVE */
		if (c == 0x0212) { F[0] = 0x0213; return; } /* LATIN CAPITAL LETTER R WITH INVERTED BREVE */
		if (c == 0x0214) { F[0] = 0x0215; return; } /* LATIN CAPITAL LETTER U WITH DOUBLE GRAVE */
		if (c == 0x0216) { F[0] = 0x0217; return; } /* LATIN CAPITAL LETTER U WITH INVERTED BREVE */
		if (c == 0x0218) { F[0] = 0x0219; return; } /* LATIN CAPITAL LETTER S WITH COMMA BELOW */
		if (c == 0x021A) { F[0] = 0x021B; return; } /* LATIN CAPITAL LETTER T WITH COMMA BELOW */
		if (c == 0x021C) { F[0] = 0x021D; return; } /* LATIN CAPITAL LETTER YOGH */
		if (c == 0x021E) { F[0] = 0x021F; return; } /* LATIN CAPITAL LETTER H WITH CARON */
		if (c == 0x0220) { F[0] = 0x019E; return; } /* LATIN CAPITAL LETTER N WITH LONG RIGHT LEG */
		if (c == 0x0222) { F[0] = 0x0223; return; } /* LATIN CAPITAL LETTER OU */
		if (c == 0x0224) { F[0] = 0x0225; return; } /* LATIN CAPITAL LETTER Z WITH HOOK */
		if (c == 0x0226) { F[0] = 0x0227; return; } /* LATIN CAPITAL LETTER A WITH DOT ABOVE */
		if (c == 0x0228) { F[0] = 0x0229; return; } /* LATIN CAPITAL LETTER E WITH CEDILLA */
		if (c == 0x022A) { F[0] = 0x022B; return; } /* LATIN CAPITAL LETTER O WITH DIAERESIS AND MACRON */
		if (c == 0x022C) { F[0] = 0x022D; return; } /* LATIN CAPITAL LETTER O WITH TILDE AND MACRON */
		if (c == 0x022E) { F[0] = 0x022F; return; } /* LATIN CAPITAL LETTER O WITH DOT ABOVE */
		if (c == 0x0230) { F[0] = 0x0231; return; } /* LATIN CAPITAL LETTER O WITH DOT ABOVE AND MACRON */
		if (c == 0x0232) { F[0] = 0x0233; return; } /* LATIN CAPITAL LETTER Y WITH MACRON */
		if (c == 0x023A) { F[0] = 0x2C65; return; } /* LATIN CAPITAL LETTER A WITH STROKE */
		if (c == 0x023B) { F[0] = 0x023C; return; } /* LATIN CAPITAL LETTER C WITH STROKE */
		if (c == 0x023D) { F[0] = 0x019A; return; } /* LATIN CAPITAL LETTER L WITH BAR */
		if (c == 0x023E) { F[0] = 0x2C66; return; } /* LATIN CAPITAL LETTER T WITH DIAGONAL STROKE */
		if (c == 0x0241) { F[0] = 0x0242; return; } /* LATIN CAPITAL LETTER GLOTTAL STOP */
		if (c == 0x0243) { F[0] = 0x0180; return; } /* LATIN CAPITAL LETTER B WITH STROKE */
		if (c == 0x0244) { F[0] = 0x0289; return; } /* LATIN CAPITAL LETTER U BAR */
		if (c == 0x0245) { F[0] = 0x028C; return; } /* LATIN CAPITAL LETTER TURNED V */
		if (c == 0x0246) { F[0] = 0x0247; return; } /* LATIN CAPITAL LETTER E WITH STROKE */
		if (c == 0x0248) { F[0] = 0x0249; return; } /* LATIN CAPITAL LETTER J WITH STROKE */
		if (c == 0x024A) { F[0] = 0x024B; return; } /* LATIN CAPITAL LETTER SMALL Q WITH HOOK TAIL */
		if (c == 0x024C) { F[0] = 0x024D; return; } /* LATIN CAPITAL LETTER R WITH STROKE */
		if (c == 0x024E) { F[0] = 0x024F; return; } /* LATIN CAPITAL LETTER Y WITH STROKE */
	} else if ((c >= 0x0300) && (c < 0x0400)) {
		if (c == 0x0345) { F[0] = 0x03B9; return; } /* COMBINING GREEK YPOGEGRAMMENI */
		if (c == 0x0370) { F[0] = 0x0371; return; } /* GREEK CAPITAL LETTER HETA */
		if (c == 0x0372) { F[0] = 0x0373; return; } /* GREEK CAPITAL LETTER ARCHAIC SAMPI */
		if (c == 0x0376) { F[0] = 0x0377; return; } /* GREEK CAPITAL LETTER PAMPHYLIAN DIGAMMA */
		if (c == 0x037F) { F[0] = 0x03F3; return; } /* GREEK CAPITAL LETTER YOT */
		if (c == 0x0386) { F[0] = 0x03AC; return; } /* GREEK CAPITAL LETTER ALPHA WITH TONOS */
		if ((c >= 0x0388) && (c <= 0x038A)) { F[0] = 0x03AD + (c - 0x0388); return; } /* GREEK CAPITAL LETTER EPSILON WITH TONOS to GREEK CAPITAL LETTER IOTA WITH TONOS */
		if (c == 0x038C) { F[0] = 0x03CC; return; } /* GREEK CAPITAL LETTER OMICRON WITH TONOS */
		if (c == 0x038E) { F[0] = 0x03CD; return; } /* GREEK CAPITAL LETTER UPSILON WITH TONOS */
		if (c == 0x038F) { F[0] = 0x03CE; return; } /* GREEK CAPITAL LETTER OMEGA WITH TONOS */
		if (c == 0x0390) { F[0] = 0x03B9; F[1] = 0x0308; F[2] = 0x0301; return; } /* GREEK SMALL LETTER IOTA WITH DIALYTIKA AND TONOS */
		if ((c >= 0x0391) && (c <= 0x03A1)) { F[0] = 0x03B1 + (c - 0x0391); return; } /* GREEK CAPITAL LETTER ALPHA to GREEK CAPITAL LETTER RHO */
		if ((c >= 0x03A3) && (c <= 0x03AB)) { F[0] = 0x03C3 + (c - 0x03A3); return; } /* GREEK CAPITAL LETTER SIGMA to GREEK CAPITAL LETTER UPSILON WITH DIALYTIKA */
		if (c == 0x03B0) { F[0] = 0x03C5; F[1] = 0x0308; F[2] = 0x0301; return; } /* GREEK SMALL LETTER UPSILON WITH DIALYTIKA AND TONOS */
		if (c == 0x03C2) { F[0] = 0x03C3; return; } /* GREEK SMALL LETTER FINAL SIGMA */
		if (c == 0x03CF) { F[0] = 0x03D7; return; } /* GREEK CAPITAL KAI SYMBOL */
		if (c == 0x03D0) { F[0] = 0x03B2; return; } /* GREEK BETA SYMBOL */
		if (c == 0x03D1) { F[0] = 0x03B8; return; } /* GREEK THETA SYMBOL */
		if (c == 0x03D5) { F[0] = 0x03C6; return; } /* GREEK PHI SYMBOL */
		if (c == 0x03D6) { F[0] = 0x03C0; return; } /* GREEK PI SYMBOL */
		if (c == 0x03D8) { F[0] = 0x03D9; return; } /* GREEK LETTER ARCHAIC KOPPA */
		if (c == 0x03DA) { F[0] = 0x03DB; return; } /* GREEK LETTER STIGMA */
		if (c == 0x03DC) { F[0] = 0x03DD; return; } /* GREEK LETTER DIGAMMA */
		if (c == 0x03DE) { F[0] = 0x03DF; return; } /* GREEK LETTER KOPPA */
		if (c == 0x03E0) { F[0] = 0x03E1; return; } /* GREEK LETTER SAMPI */
		if (c == 0x03E2) { F[0] = 0x03E3; return; } /* COPTIC CAPITAL LETTER SHEI */
		if (c == 0x03E4) { F[0] = 0x03E5; return; } /* COPTIC CAPITAL LETTER FEI */
		if (c == 0x03E6) { F[0] = 0x03E7; return; } /* COPTIC CAPITAL LETTER KHEI */
		if (c == 0x03E8) { F[0] = 0x03E9; return; } /* COPTIC CAPITAL LETTER HORI */
		if (c == 0x03EA) { F[0] = 0x03EB; return; } /* COPTIC CAPITAL LETTER GANGIA */
		if (c == 0x03EC) { F[0] = 0x03ED; return; } /* COPTIC CAPITAL LETTER SHIMA */
		if (c == 0x03EE) { F[0] = 0x03EF; return; } /* COPTIC CAPITAL LETTER DEI */
		if (c == 0x03F0) { F[0] = 0x03BA; return; } /* GREEK KAPPA SYMBOL */
		if (c == 0x03F1) { F[0] = 0x03C1; return; } /* GREEK RHO SYMBOL */
		if (c == 0x03F4) { F[0] = 0x03B8; return; } /* GREEK CAPITAL THETA SYMBOL */
		if (c == 0x03F5) { F[0] = 0x03B5; return; } /* GREEK LUNATE EPSILON SYMBOL */
		if (c == 0x03F7) { F[0] = 0x03F8; return; } /* GREEK CAPITAL LETTER SHO */
		if (c == 0x03F9) { F[0] = 0x03F2; return; } /* GREEK CAPITAL LUNATE SIGMA SYMBOL */
		if (c == 0x03FA) { F[0] = 0x03FB; return; } /* GREEK CAPITAL LETTER SAN */
		if ((c >= 0x03FD) && (c <= 0x03FF)) { F[0] = 0x037B + (c - 0x03FD); return; } /* GREEK CAPITAL REVERSED LUNATE SIGMA SYMBOL to GREEK CAPITAL REVERSED DOTTED LUNATE SIGMA SYMBOL */
	} else if ((c >= 0x0400) && (c < 0x0500)) {
		if ((c >= 0x0400) && (c <= 0x040F)) { F[0] = 0x0450 + (c - 0x0400); return; } /* CYRILLIC CAPITAL LETTER IE WITH GRAVE to CYRILLIC CAPITAL LETTER DZHE */
		if ((c >= 0x0410) && (c <= 0x042F)) { F[0] = 0x0430 + (c - 0x0410); return; } /* CYRILLIC CAPITAL LETTER A to CYRILLIC CAPITAL LETTER YA */
		if (c == 0x0460) { F[0] = 0x0461; return; } /* CYRILLIC CAPITAL LETTER OMEGA */
		if (c == 0x0462) { F[0] = 0x0463; return; } /* CYRILLIC CAPITAL LETTER YAT */
		if (c == 0x0464) { F[0] = 0x0465; return; } /* CYRILLIC CAPITAL LETTER IOTIFIED E */
		if (c == 0x0466) { F[0] = 0x0467; return; } /* CYRILLIC CAPITAL LETTER LITTLE YUS */
		if (c == 0x0468) { F[0] = 0x0469; return; } /* CYRILLIC CAPITAL LETTER IOTIFIED LITTLE YUS */
		if (c == 0x046A) { F[0] = 0x046B; return; } /* CYRILLIC CAPITAL LETTER BIG YUS */
		if (c == 0x046C) { F[0] = 0x046D; return; } /* CYRILLIC CAPITAL LETTER IOTIFIED BIG YUS */
		if (c == 0x046E) { F[0] = 0x046F; return; } /* CYRILLIC CAPITAL LETTER KSI */
		if (c == 0x0470) { F[0] = 0x0471; return; } /* CYRILLIC CAPITAL LETTER PSI */
		if (c == 0x0472) { F[0] = 0x0473; return; } /* CYRILLIC CAPITAL LETTER FITA */
		if (c == 0x0474) { F[0] = 0x0475; return; } /* CYRILLIC CAPITAL LETTER IZHITSA */
		if (c == 0x0476) { F[0] = 0x0477; return; } /* CYRILLIC CAPITAL LETTER IZHITSA WITH DOUBLE GRAVE ACCENT */
		if (c == 0x0478) { F[0] = 0x0479; return; } /* CYRILLIC CAPITAL LETTER UK */
		if (c == 0x047A) { F[0] = 0x047B; return; } /* CYRILLIC CAPITAL LETTER ROUND OMEGA */
		if (c == 0x047C) { F[0] = 0x047D; return; } /* CYRILLIC CAPITAL LETTER OMEGA WITH TITLO */
		if (c == 0x047E) { F[0] = 0x047F; return; } /* CYRILLIC CAPITAL LETTER OT */
		if (c == 0x0480) { F[0] = 0x0481; return; } /* CYRILLIC CAPITAL LETTER KOPPA */
		if (c == 0x048A) { F[0] = 0x048B; return; } /* CYRILLIC CAPITAL LETTER SHORT I WITH TAIL */
		if (c == 0x048C) { F[0] = 0x048D; return; } /* CYRILLIC CAPITAL LETTER SEMISOFT SIGN */
		if (c == 0x048E) { F[0] = 0x048F; return; } /* CYRILLIC CAPITAL LETTER ER WITH TICK */
		if (c == 0x0490) { F[0] = 0x0491; return; } /* CYRILLIC CAPITAL LETTER GHE WITH UPTURN */
		if (c == 0x0492) { F[0] = 0x0493; return; } /* CYRILLIC CAPITAL LETTER GHE WITH STROKE */
		if (c == 0x0494) { F[0] = 0x0495; return; } /* CYRILLIC CAPITAL LETTER GHE WITH MIDDLE HOOK */
		if (c == 0x0496) { F[0] = 0x0497; return; } /* CYRILLIC CAPITAL LETTER ZHE WITH DESCENDER */
		if (c == 0x0498) { F[0] = 0x0499; return; } /* CYRILLIC CAPITAL LETTER ZE WITH DESCENDER */
		if (c == 0x049A) { F[0] = 0x049B; return; } /* CYRILLIC CAPITAL LETTER KA WITH DESCENDER */
		if (c == 0x049C) { F[0] = 0x049D; return; } /* CYRILLIC CAPITAL LETTER KA WITH VERTICAL STROKE */
		if (c == 0x049E) { F[0] = 0x049F; return; } /* CYRILLIC CAPITAL LETTER KA WITH STROKE */
		if (c == 0x04A0) { F[0] = 0x04A1; return; } /* CYRILLIC CAPITAL LETTER BASHKIR KA */
		if (c == 0x04A2) { F[0] = 0x04A3; return; } /* CYRILLIC CAPITAL LETTER EN WITH DESCENDER */
		if (c == 0x04A4) { F[0] = 0x04A5; return; } /* CYRILLIC CAPITAL LIGATURE EN GHE */
		if (c == 0x04A6) { F[0] = 0x04A7; return; } /* CYRILLIC CAPITAL LETTER PE WITH MIDDLE HOOK */
		if (c == 0x04A8) { F[0] = 0x04A9; return; } /* CYRILLIC CAPITAL LETTER ABKHASIAN HA */
		if (c == 0x04AA) { F[0] = 0x04AB; return; } /* CYRILLIC CAPITAL LETTER ES WITH DESCENDER */
		if (c == 0x04AC) { F[0] = 0x04AD; return; } /* CYRILLIC CAPITAL LETTER TE WITH DESCENDER */
		if (c == 0x04AE) { F[0] = 0x04AF; return; } /* CYRILLIC CAPITAL LETTER STRAIGHT U */
		if (c == 0x04B0) { F[0] = 0x04B1; return; } /* CYRILLIC CAPITAL LETTER STRAIGHT U WITH STROKE */
		if (c == 0x04B2) { F[0] = 0x04B3; return; } /* CYRILLIC CAPITAL LETTER HA WITH DESCENDER */
		if (c == 0x04B4) { F[0] = 0x04B5; return; } /* CYRILLIC CAPITAL LIGATURE TE TSE */
		if (c == 0x04B6) { F[0] = 0x04B7; return; } /* CYRILLIC CAPITAL LETTER CHE WITH DESCENDER */
		if (c == 0x04B8) { F[0] = 0x04B9; return; } /* CYRILLIC CAPITAL LETTER CHE WITH VERTICAL STROKE */
		if (c == 0x04BA) { F[0] = 0x04BB; return; } /* CYRILLIC CAPITAL LETTER SHHA */
		if (c == 0x04BC) { F[0] = 0x04BD; return; } /* CYRILLIC CAPITAL LETTER ABKHASIAN CHE */
		if (c == 0x04BE) { F[0] = 0x04BF; return; } /* CYRILLIC CAPITAL LETTER ABKHASIAN CHE WITH DESCENDER */
		if (c == 0x04C0) { F[0] = 0x04CF; return; } /* CYRILLIC LETTER PALOCHKA */
		if (c == 0x04C1) { F[0] = 0x04C2; return; } /* CYRILLIC CAPITAL LETTER ZHE WITH BREVE */
		if (c == 0x04C3) { F[0] = 0x04C4; return; } /* CYRILLIC CAPITAL LETTER KA WITH HOOK */
		if (c == 0x04C5) { F[0] = 0x04C6; return; } /* CYRILLIC CAPITAL LETTER EL WITH TAIL */
		if (c == 0x04C7) { F[0] = 0x04C8; return; } /* CYRILLIC CAPITAL LETTER EN WITH HOOK */
		if (c == 0x04C9) { F[0] = 0x04CA; return; } /* CYRILLIC CAPITAL LETTER EN WITH TAIL */
		if (c == 0x04CB) { F[0] = 0x04CC; return; } /* CYRILLIC CAPITAL LETTER KHAKASSIAN CHE */
		if (c == 0x04CD) { F[0] = 0x04CE; return; } /* CYRILLIC CAPITAL LETTER EM WITH TAIL */
		if (c == 0x04D0) { F[0] = 0x04D1; return; } /* CYRILLIC CAPITAL LETTER A WITH BREVE */
		if (c == 0x04D2) { F[0] = 0x04D3; return; } /* CYRILLIC CAPITAL LETTER A WITH DIAERESIS */
		if (c == 0x04D4) { F[0] = 0x04D5; return; } /* CYRILLIC CAPITAL LIGATURE A IE */
		if (c == 0x04D6) { F[0] = 0x04D7; return; } /* CYRILLIC CAPITAL LETTER IE WITH BREVE */
		if (c == 0x04D8) { F[0] = 0x04D9; return; } /* CYRILLIC CAPITAL LETTER SCHWA */
		if (c == 0x04DA) { F[0] = 0x04DB; return; } /* CYRILLIC CAPITAL LETTER SCHWA WITH DIAERESIS */
		if (c == 0x04DC) { F[0] = 0x04DD; return; } /* CYRILLIC CAPITAL LETTER ZHE WITH DIAERESIS */
		if (c == 0x04DE) { F[0] = 0x04DF; return; } /* CYRILLIC CAPITAL LETTER ZE WITH DIAERESIS */
		if (c == 0x04E0) { F[0] = 0x04E1; return; } /* CYRILLIC CAPITAL LETTER ABKHASIAN DZE */
		if (c == 0x04E2) { F[0] = 0x04E3; return; } /* CYRILLIC CAPITAL LETTER I WITH MACRON */
		if (c == 0x04E4) { F[0] = 0x04E5; return; } /* CYRILLIC CAPITAL LETTER I WITH DIAERESIS */
		if (c == 0x04E6) { F[0] = 0x04E7; return; } /* CYRILLIC CAPITAL LETTER O WITH DIAERESIS */
		if (c == 0x04E8) { F[0] = 0x04E9; return; } /* CYRILLIC CAPITAL LETTER BARRED O */
		if (c == 0x04EA) { F[0] = 0x04EB; return; } /* CYRILLIC CAPITAL LETTER BARRED O WITH DIAERESIS */
		if (c == 0x04EC) { F[0] = 0x04ED; return; } /* CYRILLIC CAPITAL LETTER E WITH DIAERESIS */
		if (c == 0x04EE) { F[0] = 0x04EF; return; } /* CYRILLIC CAPITAL LETTER U WITH MACRON */
		if (c == 0x04F0) { F[0] = 0x04F1; return; } /* CYRILLIC CAPITAL LETTER U WITH DIAERESIS */
		if (c == 0x04F2) { F[0] = 0x04F3; return; } /* CYRILLIC CAPITAL LETTER U WITH DOUBLE ACUTE */
		if (c == 0x04F4) { F[0] = 0x04F5; return; } /* CYRILLIC CAPITAL LETTER CHE WITH DIAERESIS */
		if (c == 0x04F6) { F[0] = 0x04F7; return; } /* CYRILLIC CAPITAL LETTER GHE WITH DESCENDER */
		if (c == 0x04F8) { F[0] = 0x04F9; return; } /* CYRILLIC CAPITAL LETTER YERU WITH DIAERESIS */
		if (c == 0x04FA) { F[0] = 0x04FB; return; } /* CYRILLIC CAPITAL LETTER GHE WITH STROKE AND HOOK */
		if (c == 0x04FC) { F[0] = 0x04FD; return; } /* CYRILLIC CAPITAL LETTER HA WITH HOOK */
		if (c == 0x04FE) { F[0] = 0x04FF; return; } /* CYRILLIC CAPITAL LETTER HA WITH STROKE */
	} else if ((c >= 0x0500) && (c < 0x0600)) {
		if (c == 0x0500) { F[0] = 0x0501; return; } /* CYRILLIC CAPITAL LETTER KOMI DE */
		if (c == 0x0502) { F[0] = 0x0503; return; } /* CYRILLIC CAPITAL LETTER KOMI DJE */
		if (c == 0x0504) { F[0] = 0x0505; return; } /* CYRILLIC CAPITAL LETTER KOMI ZJE */
		if (c == 0x0506) { F[0] = 0x0507; return; } /* CYRILLIC CAPITAL LETTER KOMI DZJE */
		if (c == 0x0508) { F[0] = 0x0509; return; } /* CYRILLIC CAPITAL LETTER KOMI LJE */
		if (c == 0x050A) { F[0] = 0x050B; return; } /* CYRILLIC CAPITAL LETTER KOMI NJE */
		if (c == 0x050C) { F[0] = 0x050D; return; } /* CYRILLIC CAPITAL LETTER KOMI SJE */
		if (c == 0x050E) { F[0] = 0x050F; return; } /* CYRILLIC CAPITAL LETTER KOMI TJE */
		if (c == 0x0510) { F[0] = 0x0511; return; } /* CYRILLIC CAPITAL LETTER REVERSED ZE */
		if (c == 0x0512) { F[0] = 0x0513; return; } /* CYRILLIC CAPITAL LETTER EL WITH HOOK */
		if (c == 0x0514) { F[0] = 0x0515; return; } /* CYRILLIC CAPITAL LETTER LHA */
		if (c == 0x0516) { F[0] = 0x0517; return; } /* CYRILLIC CAPITAL LETTER RHA */
		if (c == 0x0518) { F[0] = 0x0519; return; } /* CYRILLIC CAPITAL LETTER YAE */
		if (c == 0x051A) { F[0] = 0x051B; return; } /* CYRILLIC CAPITAL LETTER QA */
		if (c == 0x051C) { F[0] = 0x051D; return; } /* CYRILLIC CAPITAL LETTER WE */
		if (c == 0x051E) { F[0] = 0x051F; return; } /* CYRILLIC CAPITAL LETTER ALEUT KA */
		if (c == 0x0520) { F[0] = 0x0521; return; } /* CYRILLIC CAPITAL LETTER EL WITH MIDDLE HOOK */
		if (c == 0x0522) { F[0] = 0x0523; return; } /* CYRILLIC CAPITAL LETTER EN WITH MIDDLE HOOK */
		if (c == 0x0524) { F[0] = 0x0525; return; } /* CYRILLIC CAPITAL LETTER PE WITH DESCENDER */
		if (c == 0x0526) { F[0] = 0x0527; return; } /* CYRILLIC CAPITAL LETTER SHHA WITH DESCENDER */
		if (c == 0x0528) { F[0] = 0x0529; return; } /* CYRILLIC CAPITAL LETTER EN WITH LEFT HOOK */
		if (c == 0x052A) { F[0] = 0x052B; return; } /* CYRILLIC CAPITAL LETTER DZZHE */
		if (c == 0x052C) { F[0] = 0x052D; return; } /* CYRILLIC CAPITAL LETTER DCHE */
		if (c == 0x052E) { F[0] = 0x052F; return; } /* CYRILLIC CAPITAL LETTER EL WITH DESCENDER */
		if ((c >= 0x0531) && (c <= 0x0556)) { F[0] = 0x0561 + (c - 0x0531); return; } /* ARMENIAN CAPITAL LETTER AYB to ARMENIAN CAPITAL LETTER FEH */
		if (c == 0x0587) { F[0] = 0x0565; F[1] = 0x0582; return; } /* ARMENIAN SMALL LIGATURE ECH YIWN */
	} else if ((c >= 0x1000) && (c < 0x2000)) {
		if ((c >= 0x10A0) && (c <= 0x10C5)) { F[0] = 0x2D00 + (c - 0x10A0); return; } /* GEORGIAN CAPITAL LETTER AN to GEORGIAN CAPITAL LETTER HOE */
		if (c == 0x10C7) { F[0] = 0x2D27; return; } /* GEORGIAN CAPITAL LETTER YN */
		if (c == 0x10CD) { F[0] = 0x2D2D; return; } /* GEORGIAN CAPITAL LETTER AEN */
		if ((c >= 0x13F8) && (c <= 0x13FD)) { F[0] = 0x13F0 + (c - 0x13F8); return; } /* CHEROKEE SMALL LETTER YE to CHEROKEE SMALL LETTER MV */
		if (c == 0x1C80) { F[0] = 0x0432; return; } /* CYRILLIC SMALL LETTER ROUNDED VE */
		if (c == 0x1C81) { F[0] = 0x0434; return; } /* CYRILLIC SMALL LETTER LONG-LEGGED DE */
		if (c == 0x1C82) { F[0] = 0x043E; return; } /* CYRILLIC SMALL LETTER NARROW O */
		if (c == 0x1C83) { F[0] = 0x0441; return; } /* CYRILLIC SMALL LETTER WIDE ES */
		if (c == 0x1C84) { F[0] = 0x0442; return; } /* CYRILLIC SMALL LETTER TALL TE */
		if (c == 0x1C85) { F[0] = 0x0442; return; } /* CYRILLIC SMALL LETTER THREE-LEGGED TE */
		if (c == 0x1C86) { F[0] = 0x044A; return; } /* CYRILLIC SMALL LETTER TALL HARD SIGN */
		if (c == 0x1C87) { F[0] = 0x0463; return; } /* CYRILLIC SMALL LETTER TALL YAT */
		if (c == 0x1C88) { F[0] = 0xA64B; return; } /* CYRILLIC SMALL LETTER UNBLENDED UK */
		if ((c >= 0x1C90) && (c <= 0x1CBA)) { F[0] = 0x10D0 + (c - 0x1C90); return; } /* GEORGIAN MTAVRULI CAPITAL LETTER AN to GEORGIAN MTAVRULI CAPITAL LETTER AIN */
		if ((c >= 0x1CBD) && (c <= 0x1CBF)) { F[0] = 0x10FD + (c - 0x1CBD); return; } /* GEORGIAN MTAVRULI CAPITAL LETTER AEN to GEORGIAN MTAVRULI CAPITAL LETTER LABIAL SIGN */
		if (c == 0x1E00) { F[0] = 0x1E01; return; } /* LATIN CAPITAL LETTER A WITH RING BELOW */
		if (c == 0x1E02) { F[0] = 0x1E03; return; } /* LATIN CAPITAL LETTER B WITH DOT ABOVE */
		if (c == 0x1E04) { F[0] = 0x1E05; return; } /* LATIN CAPITAL LETTER B WITH DOT BELOW */
		if (c == 0x1E06) { F[0] = 0x1E07; return; } /* LATIN CAPITAL LETTER B WITH LINE BELOW */
		if (c == 0x1E08) { F[0] = 0x1E09; return; } /* LATIN CAPITAL LETTER C WITH CEDILLA AND ACUTE */
		if (c == 0x1E0A) { F[0] = 0x1E0B; return; } /* LATIN CAPITAL LETTER D WITH DOT ABOVE */
		if (c == 0x1E0C) { F[0] = 0x1E0D; return; } /* LATIN CAPITAL LETTER D WITH DOT BELOW */
		if (c == 0x1E0E) { F[0] = 0x1E0F; return; } /* LATIN CAPITAL LETTER D WITH LINE BELOW */
		if (c == 0x1E10) { F[0] = 0x1E11; return; } /* LATIN CAPITAL LETTER D WITH CEDILLA */
		if (c == 0x1E12) { F[0] = 0x1E13; return; } /* LATIN CAPITAL LETTER D WITH CIRCUMFLEX BELOW */
		if (c == 0x1E14) { F[0] = 0x1E15; return; } /* LATIN CAPITAL LETTER E WITH MACRON AND GRAVE */
		if (c == 0x1E16) { F[0] = 0x1E17; return; } /* LATIN CAPITAL LETTER E WITH MACRON AND ACUTE */
		if (c == 0x1E18) { F[0] = 0x1E19; return; } /* LATIN CAPITAL LETTER E WITH CIRCUMFLEX BELOW */
		if (c == 0x1E1A) { F[0] = 0x1E1B; return; } /* LATIN CAPITAL LETTER E WITH TILDE BELOW */
		if (c == 0x1E1C) { F[0] = 0x1E1D; return; } /* LATIN CAPITAL LETTER E WITH CEDILLA AND BREVE */
		if (c == 0x1E1E) { F[0] = 0x1E1F; return; } /* LATIN CAPITAL LETTER F WITH DOT ABOVE */
		if (c == 0x1E20) { F[0] = 0x1E21; return; } /* LATIN CAPITAL LETTER G WITH MACRON */
		if (c == 0x1E22) { F[0] = 0x1E23; return; } /* LATIN CAPITAL LETTER H WITH DOT ABOVE */
		if (c == 0x1E24) { F[0] = 0x1E25; return; } /* LATIN CAPITAL LETTER H WITH DOT BELOW */
		if (c == 0x1E26) { F[0] = 0x1E27; return; } /* LATIN CAPITAL LETTER H WITH DIAERESIS */
		if (c == 0x1E28) { F[0] = 0x1E29; return; } /* LATIN CAPITAL LETTER H WITH CEDILLA */
		if (c == 0x1E2A) { F[0] = 0x1E2B; return; } /* LATIN CAPITAL LETTER H WITH BREVE BELOW */
		if (c == 0x1E2C) { F[0] = 0x1E2D; return; } /* LATIN CAPITAL LETTER I WITH TILDE BELOW */
		if (c == 0x1E2E) { F[0] = 0x1E2F; return; } /* LATIN CAPITAL LETTER I WITH DIAERESIS AND ACUTE */
		if (c == 0x1E30) { F[0] = 0x1E31; return; } /* LATIN CAPITAL LETTER K WITH ACUTE */
		if (c == 0x1E32) { F[0] = 0x1E33; return; } /* LATIN CAPITAL LETTER K WITH DOT BELOW */
		if (c == 0x1E34) { F[0] = 0x1E35; return; } /* LATIN CAPITAL LETTER K WITH LINE BELOW */
		if (c == 0x1E36) { F[0] = 0x1E37; return; } /* LATIN CAPITAL LETTER L WITH DOT BELOW */
		if (c == 0x1E38) { F[0] = 0x1E39; return; } /* LATIN CAPITAL LETTER L WITH DOT BELOW AND MACRON */
		if (c == 0x1E3A) { F[0] = 0x1E3B; return; } /* LATIN CAPITAL LETTER L WITH LINE BELOW */
		if (c == 0x1E3C) { F[0] = 0x1E3D; return; } /* LATIN CAPITAL LETTER L WITH CIRCUMFLEX BELOW */
		if (c == 0x1E3E) { F[0] = 0x1E3F; return; } /* LATIN CAPITAL LETTER M WITH ACUTE */
		if (c == 0x1E40) { F[0] = 0x1E41; return; } /* LATIN CAPITAL LETTER M WITH DOT ABOVE */
		if (c == 0x1E42) { F[0] = 0x1E43; return; } /* LATIN CAPITAL LETTER M WITH DOT BELOW */
		if (c == 0x1E44) { F[0] = 0x1E45; return; } /* LATIN CAPITAL LETTER N WITH DOT ABOVE */
		if (c == 0x1E46) { F[0] = 0x1E47; return; } /* LATIN CAPITAL LETTER N WITH DOT BELOW */
		if (c == 0x1E48) { F[0] = 0x1E49; return; } /* LATIN CAPITAL LETTER N WITH LINE BELOW */
		if (c == 0x1E4A) { F[0] = 0x1E4B; return; } /* LATIN CAPITAL LETTER N WITH CIRCUMFLEX BELOW */
		if (c == 0x1E4C) { F[0] = 0x1E4D; return; } /* LATIN CAPITAL LETTER O WITH TILDE AND ACUTE */
		if (c == 0x1E4E) { F[0] = 0x1E4F; return; } /* LATIN CAPITAL LETTER O WITH TILDE AND DIAERESIS */
		if (c == 0x1E50) { F[0] = 0x1E51; return; } /* LATIN CAPITAL LETTER O WITH MACRON AND GRAVE */
		if (c == 0x1E52) { F[0] = 0x1E53; return; } /* LATIN CAPITAL LETTER O WITH MACRON AND ACUTE */
		if (c == 0x1E54) { F[0] = 0x1E55; return; } /* LATIN CAPITAL LETTER P WITH ACUTE */
		if (c == 0x1E56) { F[0] = 0x1E57; return; } /* LATIN CAPITAL LETTER P WITH DOT ABOVE */
		if (c == 0x1E58) { F[0] = 0x1E59; return; } /* LATIN CAPITAL LETTER R WITH DOT ABOVE */
		if (c == 0x1E5A) { F[0] = 0x1E5B; return; } /* LATIN CAPITAL LETTER R WITH DOT BELOW */
		if (c == 0x1E5C) { F[0] = 0x1E5D; return; } /* LATIN CAPITAL LETTER R WITH DOT BELOW AND MACRON */
		if (c == 0x1E5E) { F[0] = 0x1E5F; return; } /* LATIN CAPITAL LETTER R WITH LINE BELOW */
		if (c == 0x1E60) { F[0] = 0x1E61; return; } /* LATIN CAPITAL LETTER S WITH DOT ABOVE */
		if (c == 0x1E62) { F[0] = 0x1E63; return; } /* LATIN CAPITAL LETTER S WITH DOT BELOW */
		if (c == 0x1E64) { F[0] = 0x1E65; return; } /* LATIN CAPITAL LETTER S WITH ACUTE AND DOT ABOVE */
		if (c == 0x1E66) { F[0] = 0x1E67; return; } /* LATIN CAPITAL LETTER S WITH CARON AND DOT ABOVE */
		if (c == 0x1E68) { F[0] = 0x1E69; return; } /* LATIN CAPITAL LETTER S WITH DOT BELOW AND DOT ABOVE */
		if (c == 0x1E6A) { F[0] = 0x1E6B; return; } /* LATIN CAPITAL LETTER T WITH DOT ABOVE */
		if (c == 0x1E6C) { F[0] = 0x1E6D; return; } /* LATIN CAPITAL LETTER T WITH DOT BELOW */
		if (c == 0x1E6E) { F[0] = 0x1E6F; return; } /* LATIN CAPITAL LETTER T WITH LINE BELOW */
		if (c == 0x1E70) { F[0] = 0x1E71; return; } /* LATIN CAPITAL LETTER T WITH CIRCUMFLEX BELOW */
		if (c == 0x1E72) { F[0] = 0x1E73; return; } /* LATIN CAPITAL LETTER U WITH DIAERESIS BELOW */
		if (c == 0x1E74) { F[0] = 0x1E75; return; } /* LATIN CAPITAL LETTER U WITH TILDE BELOW */
		if (c == 0x1E76) { F[0] = 0x1E77; return; } /* LATIN CAPITAL LETTER U WITH CIRCUMFLEX BELOW */
		if (c == 0x1E78) { F[0] = 0x1E79; return; } /* LATIN CAPITAL LETTER U WITH TILDE AND ACUTE */
		if (c == 0x1E7A) { F[0] = 0x1E7B; return; } /* LATIN CAPITAL LETTER U WITH MACRON AND DIAERESIS */
		if (c == 0x1E7C) { F[0] = 0x1E7D; return; } /* LATIN CAPITAL LETTER V WITH TILDE */
		if (c == 0x1E7E) { F[0] = 0x1E7F; return; } /* LATIN CAPITAL LETTER V WITH DOT BELOW */
		if (c == 0x1E80) { F[0] = 0x1E81; return; } /* LATIN CAPITAL LETTER W WITH GRAVE */
		if (c == 0x1E82) { F[0] = 0x1E83; return; } /* LATIN CAPITAL LETTER W WITH ACUTE */
		if (c == 0x1E84) { F[0] = 0x1E85; return; } /* LATIN CAPITAL LETTER W WITH DIAERESIS */
		if (c == 0x1E86) { F[0] = 0x1E87; return; } /* LATIN CAPITAL LETTER W WITH DOT ABOVE */
		if (c == 0x1E88) { F[0] = 0x1E89; return; } /* LATIN CAPITAL LETTER W WITH DOT BELOW */
		if (c == 0x1E8A) { F[0] = 0x1E8B; return; } /* LATIN CAPITAL LETTER X WITH DOT ABOVE */
		if (c == 0x1E8C) { F[0] = 0x1E8D; return; } /* LATIN CAPITAL LETTER X WITH DIAERESIS */
		if (c == 0x1E8E) { F[0] = 0x1E8F; return; } /* LATIN CAPITAL LETTER Y WITH DOT ABOVE */
		if (c == 0x1E90) { F[0] = 0x1E91; return; } /* LATIN CAPITAL LETTER Z WITH CIRCUMFLEX */
		if (c == 0x1E92) { F[0] = 0x1E93; return; } /* LATIN CAPITAL LETTER Z WITH DOT BELOW */
		if (c == 0x1E94) { F[0] = 0x1E95; return; } /* LATIN CAPITAL LETTER Z WITH LINE BELOW */
		if (c == 0x1E96) { F[0] = 0x0068; F[1] = 0x0331; return; } /* LATIN SMALL LETTER H WITH LINE BELOW */
		if (c == 0x1E97) { F[0] = 0x0074; F[1] = 0x0308; return; } /* LATIN SMALL LETTER T WITH DIAERESIS */
		if (c == 0x1E98) { F[0] = 0x0077; F[1] = 0x030A; return; } /* LATIN SMALL LETTER W WITH RING ABOVE */
		if (c == 0x1E99) { F[0] = 0x0079; F[1] = 0x030A; return; } /* LATIN SMALL LETTER Y WITH RING ABOVE */
		if (c == 0x1E9A) { F[0] = 0x0061; F[1] = 0x02BE; return; } /* LATIN SMALL LETTER A WITH RIGHT HALF RING */
		if (c == 0x1E9B) { F[0] = 0x1E61; return; } /* LATIN SMALL LETTER LONG S WITH DOT ABOVE */
		if (c == 0x1E9E) { F[0] = 0x0073; F[1] = 0x0073; return; } /* LATIN CAPITAL LETTER SHARP S */
		if (c == 0x1EA0) { F[0] = 0x1EA1; return; } /* LATIN CAPITAL LETTER A WITH DOT BELOW */
		if (c == 0x1EA2) { F[0] = 0x1EA3; return; } /* LATIN CAPITAL LETTER A WITH HOOK ABOVE */
		if (c == 0x1EA4) { F[0] = 0x1EA5; return; } /* LATIN CAPITAL LETTER A WITH CIRCUMFLEX AND ACUTE */
		if (c == 0x1EA6) { F[0] = 0x1EA7; return; } /* LATIN CAPITAL LETTER A WITH CIRCUMFLEX AND GRAVE */
		if (c == 0x1EA8) { F[0] = 0x1EA9; return; } /* LATIN CAPITAL LETTER A WITH CIRCUMFLEX AND HOOK ABOVE */
		if (c == 0x1EAA) { F[0] = 0x1EAB; return; } /* LATIN CAPITAL LETTER A WITH CIRCUMFLEX AND TILDE */
		if (c == 0x1EAC) { F[0] = 0x1EAD; return; } /* LATIN CAPITAL LETTER A WITH CIRCUMFLEX AND DOT BELOW */
		if (c == 0x1EAE) { F[0] = 0x1EAF; return; } /* LATIN CAPITAL LETTER A WITH BREVE AND ACUTE */
		if (c == 0x1EB0) { F[0] = 0x1EB1; return; } /* LATIN CAPITAL LETTER A WITH BREVE AND GRAVE */
		if (c == 0x1EB2) { F[0] = 0x1EB3; return; } /* LATIN CAPITAL LETTER A WITH BREVE AND HOOK ABOVE */
		if (c == 0x1EB4) { F[0] = 0x1EB5; return; } /* LATIN CAPITAL LETTER A WITH BREVE AND TILDE */
		if (c == 0x1EB6) { F[0] = 0x1EB7; return; } /* LATIN CAPITAL LETTER A WITH BREVE AND DOT BELOW */
		if (c == 0x1EB8) { F[0] = 0x1EB9; return; } /* LATIN CAPITAL LETTER E WITH DOT BELOW */
		if (c == 0x1EBA) { F[0] = 0x1EBB; return; } /* LATIN CAPITAL LETTER E WITH HOOK ABOVE */
		if (c == 0x1EBC) { F[0] = 0x1EBD; return; } /* LATIN CAPITAL LETTER E WITH TILDE */
		if (c == 0x1EBE) { F[0] = 0x1EBF; return; } /* LATIN CAPITAL LETTER E WITH CIRCUMFLEX AND ACUTE */
		if (c == 0x1EC0) { F[0] = 0x1EC1; return; } /* LATIN CAPITAL LETTER E WITH CIRCUMFLEX AND GRAVE */
		if (c == 0x1EC2) { F[0] = 0x1EC3; return; } /* LATIN CAPITAL LETTER E WITH CIRCUMFLEX AND HOOK ABOVE */
		if (c == 0x1EC4) { F[0] = 0x1EC5; return; } /* LATIN CAPITAL LETTER E WITH CIRCUMFLEX AND TILDE */
		if (c == 0x1EC6) { F[0] = 0x1EC7; return; } /* LATIN CAPITAL LETTER E WITH CIRCUMFLEX AND DOT BELOW */
		if (c == 0x1EC8) { F[0] = 0x1EC9; return; } /* LATIN CAPITAL LETTER I WITH HOOK ABOVE */
		if (c == 0x1ECA) { F[0] = 0x1ECB; return; } /* LATIN CAPITAL LETTER I WITH DOT BELOW */
		if (c == 0x1ECC) { F[0] = 0x1ECD; return; } /* LATIN CAPITAL LETTER O WITH DOT BELOW */
		if (c == 0x1ECE) { F[0] = 0x1ECF; return; } /* LATIN CAPITAL LETTER O WITH HOOK ABOVE */
		if (c == 0x1ED0) { F[0] = 0x1ED1; return; } /* LATIN CAPITAL LETTER O WITH CIRCUMFLEX AND ACUTE */
		if (c == 0x1ED2) { F[0] = 0x1ED3; return; } /* LATIN CAPITAL LETTER O WITH CIRCUMFLEX AND GRAVE */
		if (c == 0x1ED4) { F[0] = 0x1ED5; return; } /* LATIN CAPITAL LETTER O WITH CIRCUMFLEX AND HOOK ABOVE */
		if (c == 0x1ED6) { F[0] = 0x1ED7; return; } /* LATIN CAPITAL LETTER O WITH CIRCUMFLEX AND TILDE */
		if (c == 0x1ED8) { F[0] = 0x1ED9; return; } /* LATIN CAPITAL LETTER O WITH CIRCUMFLEX AND DOT BELOW */
		if (c == 0x1EDA) { F[0] = 0x1EDB; return; } /* LATIN CAPITAL LETTER O WITH HORN AND ACUTE */
		if (c == 0x1EDC) { F[0] = 0x1EDD; return; } /* LATIN CAPITAL LETTER O WITH HORN AND GRAVE */
		if (c == 0x1EDE) { F[0] = 0x1EDF; return; } /* LATIN CAPITAL LETTER O WITH HORN AND HOOK ABOVE */
		if (c == 0x1EE0) { F[0] = 0x1EE1; return; } /* LATIN CAPITAL LETTER O WITH HORN AND TILDE */
		if (c == 0x1EE2) { F[0] = 0x1EE3; return; } /* LATIN CAPITAL LETTER O WITH HORN AND DOT BELOW */
		if (c == 0x1EE4) { F[0] = 0x1EE5; return; } /* LATIN CAPITAL LETTER U WITH DOT BELOW */
		if (c == 0x1EE6) { F[0] = 0x1EE7; return; } /* LATIN CAPITAL LETTER U WITH HOOK ABOVE */
		if (c == 0x1EE8) { F[0] = 0x1EE9; return; } /* LATIN CAPITAL LETTER U WITH HORN AND ACUTE */
		if (c == 0x1EEA) { F[0] = 0x1EEB; return; } /* LATIN CAPITAL LETTER U WITH HORN AND GRAVE */
		if (c == 0x1EEC) { F[0] = 0x1EED; return; } /* LATIN CAPITAL LETTER U WITH HORN AND HOOK ABOVE */
		if (c == 0x1EEE) { F[0] = 0x1EEF; return; } /* LATIN CAPITAL LETTER U WITH HORN AND TILDE */
		if (c == 0x1EF0) { F[0] = 0x1EF1; return; } /* LATIN CAPITAL LETTER U WITH HORN AND DOT BELOW */
		if (c == 0x1EF2) { F[0] = 0x1EF3; return; } /* LATIN CAPITAL LETTER Y WITH GRAVE */
		if (c == 0x1EF4) { F[0] = 0x1EF5; return; } /* LATIN CAPITAL LETTER Y WITH DOT BELOW */
		if (c == 0x1EF6) { F[0] = 0x1EF7; return; } /* LATIN CAPITAL LETTER Y WITH HOOK ABOVE */
		if (c == 0x1EF8) { F[0] = 0x1EF9; return; } /* LATIN CAPITAL LETTER Y WITH TILDE */
		if (c == 0x1EFA) { F[0] = 0x1EFB; return; } /* LATIN CAPITAL LETTER MIDDLE-WELSH LL */
		if (c == 0x1EFC) { F[0] = 0x1EFD; return; } /* LATIN CAPITAL LETTER MIDDLE-WELSH V */
		if (c == 0x1EFE) { F[0] = 0x1EFF; return; } /* LATIN CAPITAL LETTER Y WITH LOOP */
		if ((c >= 0x1F08) && (c <= 0x1F0F)) { F[0] = 0x1F00 + (c - 0x1F08); return; } /* GREEK CAPITAL LETTER ALPHA WITH PSILI to GREEK CAPITAL LETTER ALPHA WITH DASIA AND PERISPOMENI */
		if ((c >= 0x1F18) && (c <= 0x1F1D)) { F[0] = 0x1F10 + (c - 0x1F18); return; } /* GREEK CAPITAL LETTER EPSILON WITH PSILI to GREEK CAPITAL LETTER EPSILON WITH DASIA AND OXIA */
		if ((c >= 0x1F28) && (c <= 0x1F2F)) { F[0] = 0x1F20 + (c - 0x1F28); return; } /* GREEK CAPITAL LETTER ETA WITH PSILI to GREEK CAPITAL LETTER ETA WITH DASIA AND PERISPOMENI */
		if ((c >= 0x1F38) && (c <= 0x1F3F)) { F[0] = 0x1F30 + (c - 0x1F38); return; } /* GREEK CAPITAL LETTER IOTA WITH PSILI to GREEK CAPITAL LETTER IOTA WITH DASIA AND PERISPOMENI */
		if ((c >= 0x1F48) && (c <= 0x1F4D)) { F[0] = 0x1F40 + (c - 0x1F48); return; } /* GREEK CAPITAL LETTER OMICRON WITH PSILI to GREEK CAPITAL LETTER OMICRON WITH DASIA AND OXIA */
		if (c == 0x1F50) { F[0] = 0x03C5; F[1] = 0x0313; return; } /* GREEK SMALL LETTER UPSILON WITH PSILI */
		if (c == 0x1F52) { F[0] = 0x03C5; F[1] = 0x0313; F[2] = 0x0300; return; } /* GREEK SMALL LETTER UPSILON WITH PSILI AND VARIA */
		if (c == 0x1F54) { F[0] = 0x03C5; F[1] = 0x0313; F[2] = 0x0301; return; } /* GREEK SMALL LETTER UPSILON WITH PSILI AND OXIA */
		if (c == 0x1F56) { F[0] = 0x03C5; F[1] = 0x0313; F[2] = 0x0342; return; } /* GREEK SMALL LETTER UPSILON WITH PSILI AND PERISPOMENI */
		if (c == 0x1F59) { F[0] = 0x1F51; return; } /* GREEK CAPITAL LETTER UPSILON WITH DASIA */
		if (c == 0x1F5B) { F[0] = 0x1F53; return; } /* GREEK CAPITAL LETTER UPSILON WITH DASIA AND VARIA */
		if (c == 0x1F5D) { F[0] = 0x1F55; return; } /* GREEK CAPITAL LETTER UPSILON WITH DASIA AND OXIA */
		if (c == 0x1F5F) { F[0] = 0x1F57; return; } /* GREEK CAPITAL LETTER UPSILON WITH DASIA AND PERISPOMENI */
		if ((c >= 0x1F68) && (c <= 0x1F6F)) { F[0] = 0x1F60 + (c - 0x1F68); return; } /* GREEK CAPITAL LETTER OMEGA WITH PSILI to GREEK CAPITAL LETTER OMEGA WITH DASIA AND PERISPOMENI */
		if (c == 0x1F80) { F[0] = 0x1F00; F[1] = 0x03B9; return; } /* GREEK SMALL LETTER ALPHA WITH PSILI AND YPOGEGRAMMENI */
		if (c == 0x1F81) { F[0] = 0x1F01; F[1] = 0x03B9; return; } /* GREEK SMALL LETTER ALPHA WITH DASIA AND YPOGEGRAMMENI */
		if (c == 0x1F82) { F[0] = 0x1F02; F[1] = 0x03B9; return; } /* GREEK SMALL LETTER ALPHA WITH PSILI AND VARIA AND YPOGEGRAMMENI */
		if (c == 0x1F83) { F[0] = 0x1F03; F[1] = 0x03B9; return; } /* GREEK SMALL LETTER ALPHA WITH DASIA AND VARIA AND YPOGEGRAMMENI */
		if (c == 0x1F84) { F[0] = 0x1F04; F[1] = 0x03B9; return; } /* GREEK SMALL LETTER ALPHA WITH PSILI AND OXIA AND YPOGEGRAMMENI */
		if (c == 0x1F85) { F[0] = 0x1F05; F[1] = 0x03B9; return; } /* GREEK SMALL LETTER ALPHA WITH DASIA AND OXIA AND YPOGEGRAMMENI */
		if (c == 0x1F86) { F[0] = 0x1F06; F[1] = 0x03B9; return; } /* GREEK SMALL LETTER ALPHA WITH PSILI AND PERISPOMENI AND YPOGEGRAMMENI */
		if (c == 0x1F87) { F[0] = 0x1F07; F[1] = 0x03B9; return; } /* GREEK SMALL LETTER ALPHA WITH DASIA AND PERISPOMENI AND YPOGEGRAMMENI */
		if (c == 0x1F88) { F[0] = 0x1F00; F[1] = 0x03B9; return; } /* GREEK CAPITAL LETTER ALPHA WITH PSILI AND PROSGEGRAMMENI */
		if (c == 0x1F89) { F[0] = 0x1F01; F[1] = 0x03B9; return; } /* GREEK CAPITAL LETTER ALPHA WITH DASIA AND PROSGEGRAMMENI */
		if (c == 0x1F8A) { F[0] = 0x1F02; F[1] = 0x03B9; return; } /* GREEK CAPITAL LETTER ALPHA WITH PSILI AND VARIA AND PROSGEGRAMMENI */
		if (c == 0x1F8B) { F[0] = 0x1F03; F[1] = 0x03B9; return; } /* GREEK CAPITAL LETTER ALPHA WITH DASIA AND VARIA AND PROSGEGRAMMENI */
		if (c == 0x1F8C) { F[0] = 0x1F04; F[1] = 0x03B9; return; } /* GREEK CAPITAL LETTER ALPHA WITH PSILI AND OXIA AND PROSGEGRAMMENI */
		if (c == 0x1F8D) { F[0] = 0x1F05; F[1] = 0x03B9; return; } /* GREEK CAPITAL LETTER ALPHA WITH DASIA AND OXIA AND PROSGEGRAMMENI */
		if (c == 0x1F8E) { F[0] = 0x1F06; F[1] = 0x03B9; return; } /* GREEK CAPITAL LETTER ALPHA WITH PSILI AND PERISPOMENI AND PROSGEGRAMMENI */
		if (c == 0x1F8F) { F[0] = 0x1F07; F[1] = 0x03B9; return; } /* GREEK CAPITAL LETTER ALPHA WITH DASIA AND PERISPOMENI AND PROSGEGRAMMENI */
		if (c == 0x1F90) { F[0] = 0x1F20; F[1] = 0x03B9; return; } /* GREEK SMALL LETTER ETA WITH PSILI AND YPOGEGRAMMENI */
		if (c == 0x1F91) { F[0] = 0x1F21; F[1] = 0x03B9; return; } /* GREEK SMALL LETTER ETA WITH DASIA AND YPOGEGRAMMENI */
		if (c == 0x1F92) { F[0] = 0x1F22; F[1] = 0x03B9; return; } /* GREEK SMALL LETTER ETA WITH PSILI AND VARIA AND YPOGEGRAMMENI */
		if (c == 0x1F93) { F[0] = 0x1F23; F[1] = 0x03B9; return; } /* GREEK SMALL LETTER ETA WITH DASIA AND VARIA AND YPOGEGRAMMENI */
		if (c == 0x1F94) { F[0] = 0x1F24; F[1] = 0x03B9; return; } /* GREEK SMALL LETTER ETA WITH PSILI AND OXIA AND YPOGEGRAMMENI */
		if (c == 0x1F95) { F[0] = 0x1F25; F[1] = 0x03B9; return; } /* GREEK SMALL LETTER ETA WITH DASIA AND OXIA AND YPOGEGRAMMENI */
		if (c == 0x1F96) { F[0] = 0x1F26; F[1] = 0x03B9; return; } /* GREEK SMALL LETTER ETA WITH PSILI AND PERISPOMENI AND YPOGEGRAMMENI */
		if (c == 0x1F97) { F[0] = 0x1F27; F[1] = 0x03B9; return; } /* GREEK SMALL LETTER ETA WITH DASIA AND PERISPOMENI AND YPOGEGRAMMENI */
		if (c == 0x1F98) { F[0] = 0x1F20; F[1] = 0x03B9; return; } /* GREEK CAPITAL LETTER ETA WITH PSILI AND PROSGEGRAMMENI */
		if (c == 0x1F99) { F[0] = 0x1F21; F[1] = 0x03B9; return; } /* GREEK CAPITAL LETTER ETA WITH DASIA AND PROSGEGRAMMENI */
		if (c == 0x1F9A) { F[0] = 0x1F22; F[1] = 0x03B9; return; } /* GREEK CAPITAL LETTER ETA WITH PSILI AND VARIA AND PROSGEGRAMMENI */
		if (c == 0x1F9B) { F[0] = 0x1F23; F[1] = 0x03B9; return; } /* GREEK CAPITAL LETTER ETA WITH DASIA AND VARIA AND PROSGEGRAMMENI */
		if (c == 0x1F9C) { F[0] = 0x1F24; F[1] = 0x03B9; return; } /* GREEK CAPITAL LETTER ETA WITH PSILI AND OXIA AND PROSGEGRAMMENI */
		if (c == 0x1F9D) { F[0] = 0x1F25; F[1] = 0x03B9; return; } /* GREEK CAPITAL LETTER ETA WITH DASIA AND OXIA AND PROSGEGRAMMENI */
		if (c == 0x1F9E) { F[0] = 0x1F26; F[1] = 0x03B9; return; } /* GREEK CAPITAL LETTER ETA WITH PSILI AND PERISPOMENI AND PROSGEGRAMMENI */
		if (c == 0x1F9F) { F[0] = 0x1F27; F[1] = 0x03B9; return; } /* GREEK CAPITAL LETTER ETA WITH DASIA AND PERISPOMENI AND PROSGEGRAMMENI */
		if (c == 0x1FA0) { F[0] = 0x1F60; F[1] = 0x03B9; return; } /* GREEK SMALL LETTER OMEGA WITH PSILI AND YPOGEGRAMMENI */
		if (c == 0x1FA1) { F[0] = 0x1F61; F[1] = 0x03B9; return; } /* GREEK SMALL LETTER OMEGA WITH DASIA AND YPOGEGRAMMENI */
		if (c == 0x1FA2) { F[0] = 0x1F62; F[1] = 0x03B9; return; } /* GREEK SMALL LETTER OMEGA WITH PSILI AND VARIA AND YPOGEGRAMMENI */
		if (c == 0x1FA3) { F[0] = 0x1F63; F[1] = 0x03B9; return; } /* GREEK SMALL LETTER OMEGA WITH DASIA AND VARIA AND YPOGEGRAMMENI */
		if (c == 0x1FA4) { F[0] = 0x1F64; F[1] = 0x03B9; return; } /* GREEK SMALL LETTER OMEGA WITH PSILI AND OXIA AND YPOGEGRAMMENI */
		if (c == 0x1FA5) { F[0] = 0x1F65; F[1] = 0x03B9; return; } /* GREEK SMALL LETTER OMEGA WITH DASIA AND OXIA AND YPOGEGRAMMENI */
		if (c == 0x1FA6) { F[0] = 0x1F66; F[1] = 0x03B9; return; } /* GREEK SMALL LETTER OMEGA WITH PSILI AND PERISPOMENI AND YPOGEGRAMMENI */
		if (c == 0x1FA7) { F[0] = 0x1F67; F[1] = 0x03B9; return; } /* GREEK SMALL LETTER OMEGA WITH DASIA AND PERISPOMENI AND YPOGEGRAMMENI */
		if (c == 0x1FA8) { F[0] = 0x1F60; F[1] = 0x03B9; return; } /* GREEK CAPITAL LETTER OMEGA WITH PSILI AND PROSGEGRAMMENI */
		if (c == 0x1FA9) { F[0] = 0x1F61; F[1] = 0x03B9; return; } /* GREEK CAPITAL LETTER OMEGA WITH DASIA AND PROSGEGRAMMENI */
		if (c == 0x1FAA) { F[0] = 0x1F62; F[1] = 0x03B9; return; } /* GREEK CAPITAL LETTER OMEGA WITH PSILI AND VARIA AND PROSGEGRAMMENI */
		if (c == 0x1FAB) { F[0] = 0x1F63; F[1] = 0x03B9; return; } /* GREEK CAPITAL LETTER OMEGA WITH DASIA AND VARIA AND PROSGEGRAMMENI */
		if (c == 0x1FAC) { F[0] = 0x1F64; F[1] = 0x03B9; return; } /* GREEK CAPITAL LETTER OMEGA WITH PSILI AND OXIA AND PROSGEGRAMMENI */
		if (c == 0x1FAD) { F[0] = 0x1F65; F[1] = 0x03B9; return; } /* GREEK CAPITAL LETTER OMEGA WITH DASIA AND OXIA AND PROSGEGRAMMENI */
		if (c == 0x1FAE) { F[0] = 0x1F66; F[1] = 0x03B9; return; } /* GREEK CAPITAL LETTER OMEGA WITH PSILI AND PERISPOMENI AND PROSGEGRAMMENI */
		if (c == 0x1FAF) { F[0] = 0x1F67; F[1] = 0x03B9; return; } /* GREEK CAPITAL LETTER OMEGA WITH DASIA AND PERISPOMENI AND PROSGEGRAMMENI */
		if (c == 0x1FB2) { F[0] = 0x1F70; F[1] = 0x03B9; return; } /* GREEK SMALL LETTER ALPHA WITH VARIA AND YPOGEGRAMMENI */
		if (c == 0x1FB3) { F[0] = 0x03B1; F[1] = 0x03B9; return; } /* GREEK SMALL LETTER ALPHA WITH YPOGEGRAMMENI */
		if (c == 0x1FB4) { F[0] = 0x03AC; F[1] = 0x03B9; return; } /* GREEK SMALL LETTER ALPHA WITH OXIA AND YPOGEGRAMMENI */
		if (c == 0x1FB6) { F[0] = 0x03B1; F[1] = 0x0342; return; } /* GREEK SMALL LETTER ALPHA WITH PERISPOMENI */
		if (c == 0x1FB7) { F[0] = 0x03B1; F[1] = 0x0342; F[2] = 0x03B9; return; } /* GREEK SMALL LETTER ALPHA WITH PERISPOMENI AND YPOGEGRAMMENI */
		if (c == 0x1FB8) { F[0] = 0x1FB0; return; } /* GREEK CAPITAL LETTER ALPHA WITH VRACHY */
		if (c == 0x1FB9) { F[0] = 0x1FB1; return; } /* GREEK CAPITAL LETTER ALPHA WITH MACRON */
		if (c == 0x1FBA) { F[0] = 0x1F70; return; } /* GREEK CAPITAL LETTER ALPHA WITH VARIA */
		if (c == 0x1FBB) { F[0] = 0x1F71; return; } /* GREEK CAPITAL LETTER ALPHA WITH OXIA */
		if (c == 0x1FBC) { F[0] = 0x03B1; F[1] = 0x03B9; return; } /* GREEK CAPITAL LETTER ALPHA WITH PROSGEGRAMMENI */
		if (c == 0x1FBE) { F[0] = 0x03B9; return; } /* GREEK PROSGEGRAMMENI */
		if (c == 0x1FC2) { F[0] = 0x1F74; F[1] = 0x03B9; return; } /* GREEK SMALL LETTER ETA WITH VARIA AND YPOGEGRAMMENI */
		if (c == 0x1FC3) { F[0] = 0x03B7; F[1] = 0x03B9; return; } /* GREEK SMALL LETTER ETA WITH YPOGEGRAMMENI */
		if (c == 0x1FC4) { F[0] = 0x03AE; F[1] = 0x03B9; return; } /* GREEK SMALL LETTER ETA WITH OXIA AND YPOGEGRAMMENI */
		if (c == 0x1FC6) { F[0] = 0x03B7; F[1] = 0x0342; return; } /* GREEK SMALL LETTER ETA WITH PERISPOMENI */
		if (c == 0x1FC7) { F[0] = 0x03B7; F[1] = 0x0342; F[2] = 0x03B9; return; } /* GREEK SMALL LETTER ETA WITH PERISPOMENI AND YPOGEGRAMMENI */
		if ((c >= 0x1FC8) && (c <= 0x1FCB)) { F[0] = 0x1F72 + (c - 0x1FC8); return; } /* GREEK CAPITAL LETTER EPSILON WITH VARIA to GREEK CAPITAL LETTER ETA WITH OXIA */
		if (c == 0x1FCC) { F[0] = 0x03B7; F[1] = 0x03B9; return; } /* GREEK CAPITAL LETTER ETA WITH PROSGEGRAMMENI */
		if (c == 0x1FD2) { F[0] = 0x03B9; F[1] = 0x0308; F[2] = 0x0300; return; } /* GREEK SMALL LETTER IOTA WITH DIALYTIKA AND VARIA */
		if (c == 0x1FD3) { F[0] = 0x03B9; F[1] = 0x0308; F[2] = 0x0301; return; } /* GREEK SMALL LETTER IOTA WITH DIALYTIKA AND OXIA */
		if (c == 0x1FD6) { F[0] = 0x03B9; F[1] = 0x0342; return; } /* GREEK SMALL LETTER IOTA WITH PERISPOMENI */
		if (c == 0x1FD7) { F[0] = 0x03B9; F[1] = 0x0308; F[2] = 0x0342; return; } /* GREEK SMALL LETTER IOTA WITH DIALYTIKA AND PERISPOMENI */
		if (c == 0x1FD8) { F[0] = 0x1FD0; return; } /* GREEK CAPITAL LETTER IOTA WITH VRACHY */
		if (c == 0x1FD9) { F[0] = 0x1FD1; return; } /* GREEK CAPITAL LETTER IOTA WITH MACRON */
		if (c == 0x1FDA) { F[0] = 0x1F76; return; } /* GREEK CAPITAL LETTER IOTA WITH VARIA */
		if (c == 0x1FDB) { F[0] = 0x1F77; return; } /* GREEK CAPITAL LETTER IOTA WITH OXIA */
		if (c == 0x1FE2) { F[0] = 0x03C5; F[1] = 0x0308; F[2] = 0x0300; return; } /* GREEK SMALL LETTER UPSILON WITH DIALYTIKA AND VARIA */
		if (c == 0x1FE3) { F[0] = 0x03C5; F[1] = 0x0308; F[2] = 0x0301; return; } /* GREEK SMALL LETTER UPSILON WITH DIALYTIKA AND OXIA */
		if (c == 0x1FE4) { F[0] = 0x03C1; F[1] = 0x0313; return; } /* GREEK SMALL LETTER RHO WITH PSILI */
		if (c == 0x1FE6) { F[0] = 0x03C5; F[1] = 0x0342; return; } /* GREEK SMALL LETTER UPSILON WITH PERISPOMENI */
		if (c == 0x1FE7) { F[0] = 0x03C5; F[1] = 0x0308; F[2] = 0x0342; return; } /* GREEK SMALL LETTER UPSILON WITH DIALYTIKA AND PERISPOMENI */
		if (c == 0x1FE8) { F[0] = 0x1FE0; return; } /* GREEK CAPITAL LETTER UPSILON WITH VRACHY */
		if (c == 0x1FE9) { F[0] = 0x1FE1; return; } /* GREEK CAPITAL LETTER UPSILON WITH MACRON */
		if (c == 0x1FEA) { F[0] = 0x1F7A; return; } /* GREEK CAPITAL LETTER UPSILON WITH VARIA */
		if (c == 0x1FEB) { F[0] = 0x1F7B; return; } /* GREEK CAPITAL LETTER UPSILON WITH OXIA */
		if (c == 0x1FEC) { F[0] = 0x1FE5; return; } /* GREEK CAPITAL LETTER RHO WITH DASIA */
		if (c == 0x1FF2) { F[0] = 0x1F7C; F[1] = 0x03B9; return; } /* GREEK SMALL LETTER OMEGA WITH VARIA AND YPOGEGRAMMENI */
		if (c == 0x1FF3) { F[0] = 0x03C9; F[1] = 0x03B9; return; } /* GREEK SMALL LETTER OMEGA WITH YPOGEGRAMMENI */
		if (c == 0x1FF4) { F[0] = 0x03CE; F[1] = 0x03B9; return; } /* GREEK SMALL LETTER OMEGA WITH OXIA AND YPOGEGRAMMENI */
		if (c == 0x1FF6) { F[0] = 0x03C9; F[1] = 0x0342; return; } /* GREEK SMALL LETTER OMEGA WITH PERISPOMENI */
		if (c == 0x1FF7) { F[0] = 0x03C9; F[1] = 0x0342; F[2] = 0x03B9; return; } /* GREEK SMALL LETTER OMEGA WITH PERISPOMENI AND YPOGEGRAMMENI */
		if (c == 0x1FF8) { F[0] = 0x1F78; return; } /* GREEK CAPITAL LETTER OMICRON WITH VARIA */
		if (c == 0x1FF9) { F[0] = 0x1F79; return; } /* GREEK CAPITAL LETTER OMICRON WITH OXIA */
		if (c == 0x1FFA) { F[0] = 0x1F7C; return; } /* GREEK CAPITAL LETTER OMEGA WITH VARIA */
		if (c == 0x1FFB) { F[0] = 0x1F7D; return; } /* GREEK CAPITAL LETTER OMEGA WITH OXIA */
		if (c == 0x1FFC) { F[0] = 0x03C9; F[1] = 0x03B9; return; } /* GREEK CAPITAL LETTER OMEGA WITH PROSGEGRAMMENI */
	} else if ((c >= 0x2000) && (c < 0x3000)) {
		if (c == 0x2126) { F[0] = 0x03C9; return; } /* OHM SIGN */
		if (c == 0x212A) { F[0] = 0x006B; return; } /* KELVIN SIGN */
		if (c == 0x212B) { F[0] = 0x00E5; return; } /* ANGSTROM SIGN */
		if (c == 0x2132) { F[0] = 0x214E; return; } /* TURNED CAPITAL F */
		if ((c >= 0x2160) && (c <= 0x216F)) { F[0] = 0x2170 + (c - 0x2160); return; } /* ROMAN NUMERAL ONE to ROMAN NUMERAL ONE THOUSAND */
		if (c == 0x2183) { F[0] = 0x2184; return; } /* ROMAN NUMERAL REVERSED ONE HUNDRED */
		if ((c >= 0x24B6) && (c <= 0x24CF)) { F[0] = 0x24D0 + (c - 0x24B6); return; } /* CIRCLED LATIN CAPITAL LETTER A to CIRCLED LATIN CAPITAL LETTER Z */
		if ((c >= 0x2C00) && (c <= 0x2C2F)) { F[0] = 0x2C30 + (c - 0x2C00); return; } /* GLAGOLITIC CAPITAL LETTER AZU to GLAGOLITIC CAPITAL LETTER CAUDATE CHRIVI */
		if (c == 0x2C60) { F[0] = 0x2C61; return; } /* LATIN CAPITAL LETTER L WITH DOUBLE BAR */
		if (c == 0x2C62) { F[0] = 0x026B; return; } /* LATIN CAPITAL LETTER L WITH MIDDLE TILDE */
		if (c == 0x2C63) { F[0] = 0x1D7D; return; } /* LATIN CAPITAL LETTER P WITH STROKE */
		if (c == 0x2C64) { F[0] = 0x027D; return; } /* LATIN CAPITAL LETTER R WITH TAIL */
		if (c == 0x2C67) { F[0] = 0x2C68; return; } /* LATIN CAPITAL LETTER H WITH DESCENDER */
		if (c == 0x2C69) { F[0] = 0x2C6A; return; } /* LATIN CAPITAL LETTER K WITH DESCENDER */
		if (c == 0x2C6B) { F[0] = 0x2C6C; return; } /* LATIN CAPITAL LETTER Z WITH DESCENDER */
		if (c == 0x2C6D) { F[0] = 0x0251; return; } /* LATIN CAPITAL LETTER ALPHA */
		if (c == 0x2C6E) { F[0] = 0x0271; return; } /* LATIN CAPITAL LETTER M WITH HOOK */
		if (c == 0x2C6F) { F[0] = 0x0250; return; } /* LATIN CAPITAL LETTER TURNED A */
		if (c == 0x2C70) { F[0] = 0x0252; return; } /* LATIN CAPITAL LETTER TURNED ALPHA */
		if (c == 0x2C72) { F[0] = 0x2C73; return; } /* LATIN CAPITAL LETTER W WITH HOOK */
		if (c == 0x2C75) { F[0] = 0x2C76; return; } /* LATIN CAPITAL LETTER HALF H */
		if (c == 0x2C7E) { F[0] = 0x023F; return; } /* LATIN CAPITAL LETTER S WITH SWASH TAIL */
		if (c == 0x2C7F) { F[0] = 0x0240; return; } /* LATIN CAPITAL LETTER Z WITH SWASH TAIL */
		if (c == 0x2C80) { F[0] = 0x2C81; return; } /* COPTIC CAPITAL LETTER ALFA */
		if (c == 0x2C82) { F[0] = 0x2C83; return; } /* COPTIC CAPITAL LETTER VIDA */
		if (c == 0x2C84) { F[0] = 0x2C85; return; } /* COPTIC CAPITAL LETTER GAMMA */
		if (c == 0x2C86) { F[0] = 0x2C87; return; } /* COPTIC CAPITAL LETTER DALDA */
		if (c == 0x2C88) { F[0] = 0x2C89; return; } /* COPTIC CAPITAL LETTER EIE */
		if (c == 0x2C8A) { F[0] = 0x2C8B; return; } /* COPTIC CAPITAL LETTER SOU */
		if (c == 0x2C8C) { F[0] = 0x2C8D; return; } /* COPTIC CAPITAL LETTER ZATA */
		if (c == 0x2C8E) { F[0] = 0x2C8F; return; } /* COPTIC CAPITAL LETTER HATE */
		if (c == 0x2C90) { F[0] = 0x2C91; return; } /* COPTIC CAPITAL LETTER THETHE */
		if (c == 0x2C92) { F[0] = 0x2C93; return; } /* COPTIC CAPITAL LETTER IAUDA */
		if (c == 0x2C94) { F[0] = 0x2C95; return; } /* COPTIC CAPITAL LETTER KAPA */
		if (c == 0x2C96) { F[0] = 0x2C97; return; } /* COPTIC CAPITAL LETTER LAULA */
		if (c == 0x2C98) { F[0] = 0x2C99; return; } /* COPTIC CAPITAL LETTER MI */
		if (c == 0x2C9A) { F[0] = 0x2C9B; return; } /* COPTIC CAPITAL LETTER NI */
		if (c == 0x2C9C) { F[0] = 0x2C9D; return; } /* COPTIC CAPITAL LETTER KSI */
		if (c == 0x2C9E) { F[0] = 0x2C9F; return; } /* COPTIC CAPITAL LETTER O */
		if (c == 0x2CA0) { F[0] = 0x2CA1; return; } /* COPTIC CAPITAL LETTER PI */
		if (c == 0x2CA2) { F[0] = 0x2CA3; return; } /* COPTIC CAPITAL LETTER RO */
		if (c == 0x2CA4) { F[0] = 0x2CA5; return; } /* COPTIC CAPITAL LETTER SIMA */
		if (c == 0x2CA6) { F[0] = 0x2CA7; return; } /* COPTIC CAPITAL LETTER TAU */
		if (c == 0x2CA8) { F[0] = 0x2CA9; return; } /* COPTIC CAPITAL LETTER UA */
		if (c == 0x2CAA) { F[0] = 0x2CAB; return; } /* COPTIC CAPITAL LETTER FI */
		if (c == 0x2CAC) { F[0] = 0x2CAD; return; } /* COPTIC CAPITAL LETTER KHI */
		if (c == 0x2CAE) { F[0] = 0x2CAF; return; } /* COPTIC CAPITAL LETTER PSI */
		if (c == 0x2CB0) { F[0] = 0x2CB1; return; } /* COPTIC CAPITAL LETTER OOU */
		if (c == 0x2CB2) { F[0] = 0x2CB3; return; } /* COPTIC CAPITAL LETTER DIALECT-P ALEF */
		if (c == 0x2CB4) { F[0] = 0x2CB5; return; } /* COPTIC CAPITAL LETTER OLD COPTIC AIN */
		if (c == 0x2CB6) { F[0] = 0x2CB7; return; } /* COPTIC CAPITAL LETTER CRYPTOGRAMMIC EIE */
		if (c == 0x2CB8) { F[0] = 0x2CB9; return; } /* COPTIC CAPITAL LETTER DIALECT-P KAPA */
		if (c == 0x2CBA) { F[0] = 0x2CBB; return; } /* COPTIC CAPITAL LETTER DIALECT-P NI */
		if (c == 0x2CBC) { F[0] = 0x2CBD; return; } /* COPTIC CAPITAL LETTER CRYPTOGRAMMIC NI */
		if (c == 0x2CBE) { F[0] = 0x2CBF; return; } /* COPTIC CAPITAL LETTER OLD COPTIC OOU */
		if (c == 0x2CC0) { F[0] = 0x2CC1; return; } /* COPTIC CAPITAL LETTER SAMPI */
		if (c == 0x2CC2) { F[0] = 0x2CC3; return; } /* COPTIC CAPITAL LETTER CROSSED SHEI */
		if (c == 0x2CC4) { F[0] = 0x2CC5; return; } /* COPTIC CAPITAL LETTER OLD COPTIC SHEI */
		if (c == 0x2CC6) { F[0] = 0x2CC7; return; } /* COPTIC CAPITAL LETTER OLD COPTIC ESH */
		if (c == 0x2CC8) { F[0] = 0x2CC9; return; } /* COPTIC CAPITAL LETTER AKHMIMIC KHEI */
		if (c == 0x2CCA) { F[0] = 0x2CCB; return; } /* COPTIC CAPITAL LETTER DIALECT-P HORI */
		if (c == 0x2CCC) { F[0] = 0x2CCD; return; } /* COPTIC CAPITAL LETTER OLD COPTIC HORI */
		if (c == 0x2CCE) { F[0] = 0x2CCF; return; } /* COPTIC CAPITAL LETTER OLD COPTIC HA */
		if (c == 0x2CD0) { F[0] = 0x2CD1; return; } /* COPTIC CAPITAL LETTER L-SHAPED HA */
		if (c == 0x2CD2) { F[0] = 0x2CD3; return; } /* COPTIC CAPITAL LETTER OLD COPTIC HEI */
		if (c == 0x2CD4) { F[0] = 0x2CD5; return; } /* COPTIC CAPITAL LETTER OLD COPTIC HAT */
		if (c == 0x2CD6) { F[0] = 0x2CD7; return; } /* COPTIC CAPITAL LETTER OLD COPTIC GANGIA */
		if (c == 0x2CD8) { F[0] = 0x2CD9; return; } /* COPTIC CAPITAL LETTER OLD COPTIC DJA */
		if (c == 0x2CDA) { F[0] = 0x2CDB; return; } /* COPTIC CAPITAL LETTER OLD COPTIC SHIMA */
		if (c == 0x2CDC) { F[0] = 0x2CDD; return; } /* COPTIC CAPITAL LETTER OLD NUBIAN SHIMA */
		if (c == 0x2CDE) { F[0] = 0x2CDF; return; } /* COPTIC CAPITAL LETTER OLD NUBIAN NGI */
		if (c == 0x2CE0) { F[0] = 0x2CE1; return; } /* COPTIC CAPITAL LETTER OLD NUBIAN NYI */
		if (c == 0x2CE2) { F[0] = 0x2CE3; return; } /* COPTIC CAPITAL LETTER OLD NUBIAN WAU */
		if (c == 0x2CEB) { F[0] = 0x2CEC; return; } /* COPTIC CAPITAL LETTER CRYPTOGRAMMIC SHEI */
		if (c == 0x2CED) { F[0] = 0x2CEE; return; } /* COPTIC CAPITAL LETTER CRYPTOGRAMMIC GANGIA */
		if (c == 0x2CF2) { F[0] = 0x2CF3; return; } /* COPTIC CAPITAL LETTER BOHAIRIC KHEI */
	} else if (c >= 0x3000) {
		if (c == 0xA640) { F[0] = 0xA641; return; } /* CYRILLIC CAPITAL LETTER ZEMLYA */
		if (c == 0xA642) { F[0] = 0xA643; return; } /* CYRILLIC CAPITAL LETTER DZELO */
		if (c == 0xA644) { F[0] = 0xA645; return; } /* CYRILLIC CAPITAL LETTER REVERSED DZE */
		if (c == 0xA646) { F[0] = 0xA647; return; } /* CYRILLIC CAPITAL LETTER IOTA */
		if (c == 0xA648) { F[0] = 0xA649; return; } /* CYRILLIC CAPITAL LETTER DJERV */
		if (c == 0xA64A) { F[0] = 0xA64B; return; } /* CYRILLIC CAPITAL LETTER MONOGRAPH UK */
		if (c == 0xA64C) { F[0] = 0xA64D; return; } /* CYRILLIC CAPITAL LETTER BROAD OMEGA */
		if (c == 0xA64E) { F[0] = 0xA64F; return; } /* CYRILLIC CAPITAL LETTER NEUTRAL YER */
		if (c == 0xA650) { F[0] = 0xA651; return; } /* CYRILLIC CAPITAL LETTER YERU WITH BACK YER */
		if (c == 0xA652) { F[0] = 0xA653; return; } /* CYRILLIC CAPITAL LETTER IOTIFIED YAT */
		if (c == 0xA654) { F[0] = 0xA655; return; } /* CYRILLIC CAPITAL LETTER REVERSED YU */
		if (c == 0xA656) { F[0] = 0xA657; return; } /* CYRILLIC CAPITAL LETTER IOTIFIED A */
		if (c == 0xA658) { F[0] = 0xA659; return; } /* CYRILLIC CAPITAL LETTER CLOSED LITTLE YUS */
		if (c == 0xA65A) { F[0] = 0xA65B; return; } /* CYRILLIC CAPITAL LETTER BLENDED YUS */
		if (c == 0xA65C) { F[0] = 0xA65D; return; } /* CYRILLIC CAPITAL LETTER IOTIFIED CLOSED LITTLE YUS */
		if (c == 0xA65E) { F[0] = 0xA65F; return; } /* CYRILLIC CAPITAL LETTER YN */
		if (c == 0xA660) { F[0] = 0xA661; return; } /* CYRILLIC CAPITAL LETTER REVERSED TSE */
		if (c == 0xA662) { F[0] = 0xA663; return; } /* CYRILLIC CAPITAL LETTER SOFT DE */
		if (c == 0xA664) { F[0] = 0xA665; return; } /* CYRILLIC CAPITAL LETTER SOFT EL */
		if (c == 0xA666) { F[0] = 0xA667; return; } /* CYRILLIC CAPITAL LETTER SOFT EM */
		if (c == 0xA668) { F[0] = 0xA669; return; } /* CYRILLIC CAPITAL LETTER MONOCULAR O */
		if (c == 0xA66A) { F[0] = 0xA66B; return; } /* CYRILLIC CAPITAL LETTER BINOCULAR O */
		if (c == 0xA66C) { F[0] = 0xA66D; return; } /* CYRILLIC CAPITAL LETTER DOUBLE MONOCULAR O */
		if (c == 0xA680) { F[0] = 0xA681; return; } /* CYRILLIC CAPITAL LETTER DWE */
		if (c == 0xA682) { F[0] = 0xA683; return; } /* CYRILLIC CAPITAL LETTER DZWE */
		if (c == 0xA684) { F[0] = 0xA685; return; } /* CYRILLIC CAPITAL LETTER ZHWE */
		if (c == 0xA686) { F[0] = 0xA687; return; } /* CYRILLIC CAPITAL LETTER CCHE */
		if (c == 0xA688) { F[0] = 0xA689; return; } /* CYRILLIC CAPITAL LETTER DZZE */
		if (c == 0xA68A) { F[0] = 0xA68B; return; } /* CYRILLIC CAPITAL LETTER TE WITH MIDDLE HOOK */
		if (c == 0xA68C) { F[0] = 0xA68D; return; } /* CYRILLIC CAPITAL LETTER TWE */
		if (c == 0xA68E) { F[0] = 0xA68F; return; } /* CYRILLIC CAPITAL LETTER TSWE */
		if (c == 0xA690) { F[0] = 0xA691; return; } /* CYRILLIC CAPITAL LETTER TSSE */
		if (c == 0xA692) { F[0] = 0xA693; return; } /* CYRILLIC CAPITAL LETTER TCHE */
		if (c == 0xA694) { F[0] = 0xA695; return; } /* CYRILLIC CAPITAL LETTER HWE */
		if (c == 0xA696) { F[0] = 0xA697; return; } /* CYRILLIC CAPITAL LETTER SHWE */
		if (c == 0xA698) { F[0] = 0xA699; return; } /* CYRILLIC CAPITAL LETTER DOUBLE O */
		if (c == 0xA69A) { F[0] = 0xA69B; return; } /* CYRILLIC CAPITAL LETTER CROSSED O */
		if (c == 0xA722) { F[0] = 0xA723; return; } /* LATIN CAPITAL LETTER EGYPTOLOGICAL ALEF */
		if (c == 0xA724) { F[0] = 0xA725; return; } /* LATIN CAPITAL LETTER EGYPTOLOGICAL AIN */
		if (c == 0xA726) { F[0] = 0xA727; return; } /* LATIN CAPITAL LETTER HENG */
		if (c == 0xA728) { F[0] = 0xA729; return; } /* LATIN CAPITAL LETTER TZ */
		if (c == 0xA72A) { F[0] = 0xA72B; return; } /* LATIN CAPITAL LETTER TRESILLO */
		if (c == 0xA72C) { F[0] = 0xA72D; return; } /* LATIN CAPITAL LETTER CUATRILLO */
		if (c == 0xA72E) { F[0] = 0xA72F; return; } /* LATIN CAPITAL LETTER CUATRILLO WITH COMMA */
		if (c == 0xA732) { F[0] = 0xA733; return; } /* LATIN CAPITAL LETTER AA */
		if (c == 0xA734) { F[0] = 0xA735; return; } /* LATIN CAPITAL LETTER AO */
		if (c == 0xA736) { F[0] = 0xA737; return; } /* LATIN CAPITAL LETTER AU */
		if (c == 0xA738) { F[0] = 0xA739; return; } /* LATIN CAPITAL LETTER AV */
		if (c == 0xA73A) { F[0] = 0xA73B; return; } /* LATIN CAPITAL LETTER AV WITH HORIZONTAL BAR */
		if (c == 0xA73C) { F[0] = 0xA73D; return; } /* LATIN CAPITAL LETTER AY */
		if (c == 0xA73E) { F[0] = 0xA73F; return; } /* LATIN CAPITAL LETTER REVERSED C WITH DOT */
		if (c == 0xA740) { F[0] = 0xA741; return; } /* LATIN CAPITAL LETTER K WITH STROKE */
		if (c == 0xA742) { F[0] = 0xA743; return; } /* LATIN CAPITAL LETTER K WITH DIAGONAL STROKE */
		if (c == 0xA744) { F[0] = 0xA745; return; } /* LATIN CAPITAL LETTER K WITH STROKE AND DIAGONAL STROKE */
		if (c == 0xA746) { F[0] = 0xA747; return; } /* LATIN CAPITAL LETTER BROKEN L */
		if (c == 0xA748) { F[0] = 0xA749; return; } /* LATIN CAPITAL LETTER L WITH HIGH STROKE */
		if (c == 0xA74A) { F[0] = 0xA74B; return; } /* LATIN CAPITAL LETTER O WITH LONG STROKE OVERLAY */
		if (c == 0xA74C) { F[0] = 0xA74D; return; } /* LATIN CAPITAL LETTER O WITH LOOP */
		if (c == 0xA74E) { F[0] = 0xA74F; return; } /* LATIN CAPITAL LETTER OO */
		if (c == 0xA750) { F[0] = 0xA751; return; } /* LATIN CAPITAL LETTER P WITH STROKE THROUGH DESCENDER */
		if (c == 0xA752) { F[0] = 0xA753; return; } /* LATIN CAPITAL LETTER P WITH FLOURISH */
		if (c == 0xA754) { F[0] = 0xA755; return; } /* LATIN CAPITAL LETTER P WITH SQUIRREL TAIL */
		if (c == 0xA756) { F[0] = 0xA757; return; } /* LATIN CAPITAL LETTER Q WITH STROKE THROUGH DESCENDER */
		if (c == 0xA758) { F[0] = 0xA759; return; } /* LATIN CAPITAL LETTER Q WITH DIAGONAL STROKE */
		if (c == 0xA75A) { F[0] = 0xA75B; return; } /* LATIN CAPITAL LETTER R ROTUNDA */
		if (c == 0xA75C) { F[0] = 0xA75D; return; } /* LATIN CAPITAL LETTER RUM ROTUNDA */
		if (c == 0xA75E) { F[0] = 0xA75F; return; } /* LATIN CAPITAL LETTER V WITH DIAGONAL STROKE */
		if (c == 0xA760) { F[0] = 0xA761; return; } /* LATIN CAPITAL LETTER VY */
		if (c == 0xA762) { F[0] = 0xA763; return; } /* LATIN CAPITAL LETTER VISIGOTHIC Z */
		if (c == 0xA764) { F[0] = 0xA765; return; } /* LATIN CAPITAL LETTER THORN WITH STROKE */
		if (c == 0xA766) { F[0] = 0xA767; return; } /* LATIN CAPITAL LETTER THORN WITH STROKE THROUGH DESCENDER */
		if (c == 0xA768) { F[0] = 0xA769; return; } /* LATIN CAPITAL LETTER VEND */
		if (c == 0xA76A) { F[0] = 0xA76B; return; } /* LATIN CAPITAL LETTER ET */
		if (c == 0xA76C) { F[0] = 0xA76D; return; } /* LATIN CAPITAL LETTER IS */
		if (c == 0xA76E) { F[0] = 0xA76F; return; } /* LATIN CAPITAL LETTER CON */
		if (c == 0xA779) { F[0] = 0xA77A; return; } /* LATIN CAPITAL LETTER INSULAR D */
		if (c == 0xA77B) { F[0] = 0xA77C; return; } /* LATIN CAPITAL LETTER INSULAR F */
		if (c == 0xA77D) { F[0] = 0x1D79; return; } /* LATIN CAPITAL LETTER INSULAR G */
		if (c == 0xA77E) { F[0] = 0xA77F; return; } /* LATIN CAPITAL LETTER TURNED INSULAR G */
		if (c == 0xA780) { F[0] = 0xA781; return; } /* LATIN CAPITAL LETTER TURNED L */
		if (c == 0xA782) { F[0] = 0xA783; return; } /* LATIN CAPITAL LETTER INSULAR R */
		if (c == 0xA784) { F[0] = 0xA785; return; } /* LATIN CAPITAL LETTER INSULAR S */
		if (c == 0xA786) { F[0] = 0xA787; return; } /* LATIN CAPITAL LETTER INSULAR T */
		if (c == 0xA78B) { F[0] = 0xA78C; return; } /* LATIN CAPITAL LETTER SALTILLO */
		if (c == 0xA78D) { F[0] = 0x0265; return; } /* LATIN CAPITAL LETTER TURNED H */
		if (c == 0xA790) { F[0] = 0xA791; return; } /* LATIN CAPITAL LETTER N WITH DESCENDER */
		if (c == 0xA792) { F[0] = 0xA793; return; } /* LATIN CAPITAL LETTER C WITH BAR */
		if (c == 0xA796) { F[0] = 0xA797; return; } /* LATIN CAPITAL LETTER B WITH FLOURISH */
		if (c == 0xA798) { F[0] = 0xA799; return; } /* LATIN CAPITAL LETTER F WITH STROKE */
		if (c == 0xA79A) { F[0] = 0xA79B; return; } /* LATIN CAPITAL LETTER VOLAPUK AE */
		if (c == 0xA79C) { F[0] = 0xA79D; return; } /* LATIN CAPITAL LETTER VOLAPUK OE */
		if (c == 0xA79E) { F[0] = 0xA79F; return; } /* LATIN CAPITAL LETTER VOLAPUK UE */
		if (c == 0xA7A0) { F[0] = 0xA7A1; return; } /* LATIN CAPITAL LETTER G WITH OBLIQUE STROKE */
		if (c == 0xA7A2) { F[0] = 0xA7A3; return; } /* LATIN CAPITAL LETTER K WITH OBLIQUE STROKE */
		if (c == 0xA7A4) { F[0] = 0xA7A5; return; } /* LATIN CAPITAL LETTER N WITH OBLIQUE STROKE */
		if (c == 0xA7A6) { F[0] = 0xA7A7; return; } /* LATIN CAPITAL LETTER R WITH OBLIQUE STROKE */
		if (c == 0xA7A8) { F[0] = 0xA7A9; return; } /* LATIN CAPITAL LETTER S WITH OBLIQUE STROKE */
		if (c == 0xA7AA) { F[0] = 0x0266; return; } /* LATIN CAPITAL LETTER H WITH HOOK */
		if (c == 0xA7AB) { F[0] = 0x025C; return; } /* LATIN CAPITAL LETTER REVERSED OPEN E */
		if (c == 0xA7AC) { F[0] = 0x0261; return; } /* LATIN CAPITAL LETTER SCRIPT G */
		if (c == 0xA7AD) { F[0] = 0x026C; return; } /* LATIN CAPITAL LETTER L WITH BELT */
		if (c == 0xA7AE) { F[0] = 0x026A; return; } /* LATIN CAPITAL LETTER SMALL CAPITAL I */
		if (c == 0xA7B0) { F[0] = 0x029E; return; } /* LATIN CAPITAL LETTER TURNED K */
		if (c == 0xA7B1) { F[0] = 0x0287; return; } /* LATIN CAPITAL LETTER TURNED T */
		if (c == 0xA7B2) { F[0] = 0x029D; return; } /* LATIN CAPITAL LETTER J WITH CROSSED-TAIL */
		if (c == 0xA7B3) { F[0] = 0xAB53; return; } /* LATIN CAPITAL LETTER CHI */
		if (c == 0xA7B4) { F[0] = 0xA7B5; return; } /* LATIN CAPITAL LETTER BETA */
		if (c == 0xA7B6) { F[0] = 0xA7B7; return; } /* LATIN CAPITAL LETTER OMEGA */
		if (c == 0xA7B8) { F[0] = 0xA7B9; return; } /* LATIN CAPITAL LETTER U WITH STROKE */
		if (c == 0xA7BA) { F[0] = 0xA7BB; return; } /* LATIN CAPITAL LETTER GLOTTAL A */
		if (c == 0xA7BC) { F[0] = 0xA7BD; return; } /* LATIN CAPITAL LETTER GLOTTAL I */
		if (c == 0xA7BE) { F[0] = 0xA7BF; return; } /* LATIN CAPITAL LETTER GLOTTAL U */
		if (c == 0xA7C0) { F[0] = 0xA7C1; return; } /* LATIN CAPITAL LETTER OLD POLISH O */
		if (c == 0xA7C2) { F[0] = 0xA7C3; return; } /* LATIN CAPITAL LETTER ANGLICANA W */
		if (c == 0xA7C4) { F[0] = 0xA794; return; } /* LATIN CAPITAL LETTER C WITH PALATAL HOOK */
		if (c == 0xA7C5) { F[0] = 0x0282; return; } /* LATIN CAPITAL LETTER S WITH HOOK */
		if (c == 0xA7C6) { F[0] = 0x1D8E; return; } /* LATIN CAPITAL LETTER Z WITH PALATAL HOOK */
		if (c == 0xA7C7) { F[0] = 0xA7C8; return; } /* LATIN CAPITAL LETTER D WITH SHORT STROKE OVERLAY */
		if (c == 0xA7C9) { F[0] = 0xA7CA; return; } /* LATIN CAPITAL LETTER S WITH SHORT STROKE OVERLAY */
		if (c == 0xA7D0) { F[0] = 0xA7D1; return; } /* LATIN CAPITAL LETTER CLOSED INSULAR G */
		if (c == 0xA7D6) { F[0] = 0xA7D7; return; } /* LATIN CAPITAL LETTER MIDDLE SCOTS S */
		if (c == 0xA7D8) { F[0] = 0xA7D9; return; } /* LATIN CAPITAL LETTER SIGMOID S */
		if (c == 0xA7F5) { F[0] = 0xA7F6; return; } /* LATIN CAPITAL LETTER REVERSED HALF H */
		if ((c >= 0xAB70) && (c <= 0xABBF)) { F[0] = 0x13A0 + (c - 0xAB70); return; } /* CHEROKEE SMALL LETTER A to CHEROKEE SMALL LETTER YA */
		if (c == 0xFB00) { F[0] = 0x0066; F[1] = 0x0066; return; } /* LATIN SMALL LIGATURE FF */
		if (c == 0xFB01) { F[0] = 0x0066; F[1] = 0x0069; return; } /* LATIN SMALL LIGATURE FI */
		if (c == 0xFB02) { F[0] = 0x0066; F[1] = 0x006C; return; } /* LATIN SMALL LIGATURE FL */
		if (c == 0xFB03) { F[0] = 0x0066; F[1] = 0x0066; F[2] = 0x0069; return; } /* LATIN SMALL LIGATURE FFI */
		if (c == 0xFB04) { F[0] = 0x0066; F[1] = 0x0066; F[2] = 0x006C; return; } /* LATIN SMALL LIGATURE FFL */
		if (c == 0xFB05) { F[0] = 0x0073; F[1] = 0x0074; return; } /* LATIN SMALL LIGATURE LONG S T */
		if (c == 0xFB06) { F[0] = 0x0073; F[1] = 0x0074; return; } /* LATIN SMALL LIGATURE ST */
		if (c == 0xFB13) { F[0] = 0x0574; F[1] = 0x0576; return; } /* ARMENIAN SMALL LIGATURE MEN NOW */
		if (c == 0xFB14) { F[0] = 0x0574; F[1] = 0x0565; return; } /* ARMENIAN SMALL LIGATURE MEN ECH */
		if (c == 0xFB15) { F[0] = 0x0574; F[1] = 0x056B; return; } /* ARMENIAN SMALL LIGATURE MEN INI */
		if (c == 0xFB16) { F[0] = 0x057E; F[1] = 0x0576; return; } /* ARMENIAN SMALL LIGATURE VEW NOW */
		if (c == 0xFB17) { F[0] = 0x0574; F[1] = 0x056D; return; } /* ARMENIAN SMALL LIGATURE MEN XEH */
		if ((c >= 0xFF21) && (c <= 0xFF3A)) { F[0] = 0xFF41 + (c - 0xFF21); return; } /* FULLWIDTH LATIN CAPITAL LETTER A to FULLWIDTH LATIN CAPITAL LETTER Z */
		if ((c >= 0x10400) && (c <= 0x10427)) { F[0] = 0x10428 + (c - 0x10400); return; } /* DESERET CAPITAL LETTER LONG I to DESERET CAPITAL LETTER EW */
		if ((c >= 0x104B0) && (c <= 0x104D3)) { F[0] = 0x104D8 + (c - 0x104B0); return; } /* OSAGE CAPITAL LETTER A to OSAGE CAPITAL LETTER ZHA */
		if ((c >= 0x10570) && (c <= 0x1057A)) { F[0] = 0x10597 + (c - 0x10570); return; } /* VITHKUQI CAPITAL LETTER A to VITHKUQI CAPITAL LETTER GA */
		if ((c >= 0x1057C) && (c <= 0x1058A)) { F[0] = 0x105A3 + (c - 0x1057C); return; } /* VITHKUQI CAPITAL LETTER HA to VITHKUQI CAPITAL LETTER RE */
		if ((c >= 0x1058C) && (c <= 0x10592)) { F[0] = 0x105B3 + (c - 0x1058C); return; } /* VITHKUQI CAPITAL LETTER SE to VITHKUQI CAPITAL LETTER XE */
		if (c == 0x10594) { F[0] = 0x105BB; return; } /* VITHKUQI CAPITAL LETTER Y */
		if (c == 0x10595) { F[0] = 0x105BC; return; } /* VITHKUQI CAPITAL LETTER ZE */
		if ((c >= 0x10C80) && (c <= 0x10CB2)) { F[0] = 0x10CC0 + (c - 0x10C80); return; } /* OLD HUNGARIAN CAPITAL LETTER A to OLD HUNGARIAN CAPITAL LETTER US */
		if ((c >= 0x118A0) && (c <= 0x118BF)) { F[0] = 0x118C0 + (c - 0x118A0); return; } /* WARANG CITI CAPITAL LETTER NGAA to WARANG CITI CAPITAL LETTER VIYO */
		if ((c >= 0x16E40) && (c <= 0x16E5F)) { F[0] = 0x16E60 + (c - 0x16E40); return; } /* MEDEFAIDRIN CAPITAL LETTER M to MEDEFAIDRIN CAPITAL LETTER Y */
		if ((c >= 0x1E900) && (c <= 0x1E921)) { F[0] = 0x1E922 + (c - 0x1E900); return; } /* ADLAM CAPITAL LETTER ALIF to ADLAM CAPITAL LETTER SHA */
	}
	F[0] = c; return;
}

@ Whereas these are fairly unarguable.

=
int Characters::is_ASCII_letter(inchar32_t c) {
	if ((c >= 'a') && (c <= 'z')) return TRUE;
	if ((c >= 'A') && (c <= 'Z')) return TRUE;
	return FALSE;
}

int Characters::is_ASCII_digit(inchar32_t c) {
	if ((c >= '0') && (c <= '9')) return TRUE;
	return FALSE;
}

int Characters::is_control_character(inchar32_t c) {
	if ((c >= 0x0001) && (c <= 0x001f)) return TRUE;
	if (c == 0x007f) return TRUE;
	return FALSE;
}

@h Unicode composition.
A routine which converts the Unicode combining accents with letters,
sufficient correctly to handle all characters in the ZSCII set.
Returns a combined character code, or 0 if there is no combining
to be done.

=
int Characters::combine_accent(inchar32_t accent, inchar32_t letter) {
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
	return 0;
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

inchar32_t Characters::make_wchar_t_filename_safe(inchar32_t charcode) {
	charcode = Characters::remove_wchar_t_accent(charcode);
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

inchar32_t Characters::remove_wchar_t_accent(inchar32_t charcode) {
	return (inchar32_t) Characters::remove_accent((int) charcode);
}

@ This will do until we properly use Unicode character classes some day:

=
int Characters::isalphabetic(inchar32_t letter) {
	return Characters::isalpha(Characters::remove_wchar_t_accent(letter));
}

