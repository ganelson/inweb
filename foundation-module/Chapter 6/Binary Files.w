[BinaryFiles::] Binary Files.

Routines for reading raw data from binary files.

@h Reading binary data.
To begin with, integers of 8, 16, 32 and 64 bit widths respectively,
arranged with most significant byte (MSB) first.

=
int BinaryFiles::read_int8(FILE *binary_file, unsigned int *result) {
    int c1 = getc(binary_file);
    if (c1 == EOF) return FALSE;

    *result = (unsigned int) c1;
    return TRUE;
}

int BinaryFiles::read_int16(FILE *binary_file, unsigned int *result) {
    int c1, c2;

    c1 = getc(binary_file);
    c2 = getc(binary_file);
    if (c1 == EOF || c2 == EOF) return FALSE;

    *result = (((unsigned int) c1) << 8) + ((unsigned int) c2);
    return TRUE;
}

int BinaryFiles::read_int32(FILE *binary_file, unsigned int *result) {
    int c1, c2, c3, c4;

    c1 = getc(binary_file);
    c2 = getc(binary_file);
    c3 = getc(binary_file);
    c4 = getc(binary_file);
    if (c1 == EOF || c2 == EOF || c3 == EOF || c4 == EOF) return FALSE;

    *result = (((unsigned int) c1) << 24) +
    			(((unsigned int) c2) << 16) +
    			(((unsigned int) c3) << 8) + ((unsigned int) c4);
    return TRUE;
}

int BinaryFiles::read_int64(FILE *binary_file, unsigned long long *result) {
    int c1, c2, c3, c4, c5, c6, c7, c8;

    c1 = getc(binary_file);
    c2 = getc(binary_file);
    c3 = getc(binary_file);
    c4 = getc(binary_file);
    c5 = getc(binary_file);
    c6 = getc(binary_file);
    c7 = getc(binary_file);
    c8 = getc(binary_file);
    if (c1 == EOF || c2 == EOF || c3 == EOF || c4 == EOF || c5 == EOF
    	|| c6 == EOF || c7 == EOF || c8 == EOF) return FALSE;

    *result = (((unsigned long long) c1) << 56) +
               (((unsigned long long) c2) << 48) +
               (((unsigned long long) c3) << 40) +
               (((unsigned long long) c4) << 32) +
               (((unsigned long long) c5) << 24) +
               (((unsigned long long) c6) << 16) +
               (((unsigned long long) c7) << 8) +
                ((unsigned long long) c8);
    return TRUE;
}

@ =
int BinaryFiles::write_int32(FILE *binary_file, unsigned int val) {
    int c1 = (int) ((val >> 24) & 0xFF);
    int c2 = (int) ((val >> 16) & 0xFF);
    int c3 = (int) ((val >> 8) & 0xFF);
    int c4 = (int) (val & 0xFF);
	if (putc(c1, binary_file) == EOF) return FALSE;
	if (putc(c2, binary_file) == EOF) return FALSE;
	if (putc(c3, binary_file) == EOF) return FALSE;
	if (putc(c4, binary_file) == EOF) return FALSE;

    return TRUE;
}

@ We will sometimes need to toggle between MSB and LSB representation of
integers 32 or 64 bits wide:

=
void BinaryFiles::swap_bytes32(unsigned int *value) {
    unsigned int result = (((*value & 0xff) << 24) +
                            ((*value & 0xff00) << 8) +
                            ((*value & 0xff0000) >> 8) +
                            ((*value & 0xff000000) >> 24 ) );
    *value = result;
}

void BinaryFiles::swap_bytes64(unsigned long long *value) {
    unsigned long long result = (((*value & 0xff) << 56) +
                                  ((*value & 0xff00) << 40) +
                                  ((*value & 0xff0000) << 24) +
                                  ((*value & 0xff000000) << 8) +
                                  ((*value >> 8)  & 0xff000000) +
                                  ((*value >> 24) & 0xff0000) +
                                  ((*value >> 40) & 0xff00) +
                                  ((*value >> 56) & 0xff) );
    *value = result;
}

@ Some file formats also have variable-sized integers, as a sequence of
bytes (most significant first) in which each byte consists of seven bits
of data plus a most significant bit which marks that a continuation byte
follows:

=
int BinaryFiles::read_variable_length_integer(FILE *binary_file, unsigned int *result) {
    int c;

    *result = 0;
    do {
        c = getc(binary_file);
        if (c == EOF) return FALSE;
        *result = (*result << 7) + (((unsigned char) c) & 0x7F);
    } while  (((unsigned char) c) & 0x80);

    return TRUE;
}

@ Here we read just the mantissa of a particular representation of
floating-point numbers:

=
int BinaryFiles::read_float80(FILE *binary_file, unsigned int *result) {
    int c1, c2, exp;
    unsigned int prev = 0, mantissa;

    c1 = getc(binary_file);
    c2 = getc(binary_file);
    if (c1 == EOF || c2 == EOF) return FALSE;
    if (!BinaryFiles::read_int32(binary_file, &mantissa)) return FALSE;

    exp = 30 - c2;
    while  (exp--) {
        prev = mantissa;
        mantissa >>= 1;
    }
    if (prev & 1) mantissa++;

    *result = (unsigned int) mantissa;
    return TRUE;
}

@ And lastly we read a string of a supplied length from the file, and
then null terminate it to make it valid C string. (|string| must therefore
be at least |length| plus 1 bytes long.)

=
int BinaryFiles::read_string(FILE *binary_file, char *string, unsigned int length) {
    if (length > 0) {
        if (fread(string, 1, length, binary_file) != length) return FALSE;
    }
    string[length] = 0;

    return TRUE;
}

@h Size.

=
long int BinaryFiles::size(filename *F) {
	FILE *TEST_FILE = BinaryFiles::try_to_open_for_reading(F);
	if (TEST_FILE) {
		if (fseek(TEST_FILE, 0, SEEK_END) == 0) {
			long int file_size = ftell(TEST_FILE);
			if (file_size == -1L) Errors::fatal_with_file("ftell failed on linked file", F);
			BinaryFiles::close(TEST_FILE);
			return file_size;
		} else Errors::fatal_with_file("fseek failed on linked file", F);
		BinaryFiles::close(TEST_FILE);
	}
	return -1L;
}

@h Opening.

=
FILE *BinaryFiles::open_for_reading(filename *F) {
	FILE *handle = Filenames::fopen(F, "rb");
	if (handle == NULL) Errors::fatal_with_file("unable to read file", F);
	return handle;
}

FILE *BinaryFiles::try_to_open_for_reading(filename *F) {
	return Filenames::fopen(F, "rb");
}

FILE *BinaryFiles::open_for_writing(filename *F) {
	FILE *handle = Filenames::fopen(F, "wb");
	if (handle == NULL) Errors::fatal_with_file("unable to write file", F);
	return handle;
}

FILE *BinaryFiles::try_to_open_for_writing(filename *F) {
	return Filenames::fopen(F, "wb");
}

void BinaryFiles::close(FILE *handle) {
	fclose(handle);
}

@h Copying.
This achieves a binary copy of a file when we haven't got access to the shell,
or to system APIs.

=
int BinaryFiles::copy(filename *from, filename *to, int suppress_error) {
	if ((from == NULL) || (to == NULL))
		Errors::fatal("files confused in copier");

	FILE *FROM = BinaryFiles::try_to_open_for_reading(from);
	if (FROM == NULL) {
		if (suppress_error == FALSE) Errors::fatal_with_file("unable to read file", from);
		return -1;
	}
	FILE *TO = BinaryFiles::try_to_open_for_writing(to);
	if (TO == NULL) {
		if (suppress_error == FALSE) Errors::fatal_with_file("unable to write to file", to);
		return -1;
	}

	int size = 0;
	while (TRUE) {
		int c = fgetc(FROM);
		if (c == EOF) break;
		size++;
		putc(c, TO);
	}

	BinaryFiles::close(FROM); BinaryFiles::close(TO);
	return size;
}

@h MD5 hash computation.
Though now seen as insecure from a cryptographic point of view, Message Digest 5,
a form of checksum created by Ronald Rivest in 1992, remains very useful as a
way to compare files quickly, at least when we're sure nobody is being malicious.

There are thousands of amateur implementations, most of them, like this one,
paraphrased from the pseudocode at the Wikipedia page. The |mask| function allows
certain fixed byte positions in the file to be considered as if they were zero bytes,
which is helpful when testing comparing files whose headers change in uninteresting
ways. If |mask| is |NULL|, or always returns |FALSE|, then the hash computed is
exactly the canonical md5.

The code below is about as enigmatic as a page of well-meaning code can be, but
that's down to the algorithm itself. The |K| array hold bits drawn from the sines
of the integers 1 to 64: sines computed in radians, so that in a sense the md5
algorithm relies on the irrationality of $\pi$ to make these so unpredictable.
At any rate, the magic numbers below are all drawn from RFC 1321.

=
void BinaryFiles::md5(OUTPUT_STREAM, filename *F, int (*mask)(uint64_t)) {
	uint32_t s[64] = {
		7, 12, 17, 22,  7, 12, 17, 22,  7, 12, 17, 22,  7, 12, 17, 22,
		5,  9, 14, 20,  5,  9, 14, 20,  5,  9, 14, 20,  5,  9, 14, 20,
		4, 11, 16, 23,  4, 11, 16, 23,  4, 11, 16, 23,  4, 11, 16, 23,
		6, 10, 15, 21,  6, 10, 15, 21,  6, 10, 15, 21,  6, 10, 15, 21 };
	uint32_t K[64] = {
		0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee,
		0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,
		0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be,
		0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821,
		0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa,
		0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,
		0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed,
		0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a,
		0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c,
		0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,
		0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05,
		0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
		0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039,
		0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
		0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1,
		0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391 };

	uint32_t a0 = 0x67452301;
	uint32_t b0 = 0xefcdab89;
	uint32_t c0 = 0x98badcfe;
	uint32_t d0 = 0x10325476;

	unsigned int buffer[64];
	int bc = 0;

	FILE *bin = BinaryFiles::open_for_reading(F);
	if (bin == NULL) Errors::fatal_with_file("unable to open binary file", F);
	unsigned int b = 0;
	uint64_t L = 0;
	while (BinaryFiles::read_int8(bin, &b)) {
		if ((mask) && (mask(L))) b = 0;
		@<Process one byte of message@>;
		L++;
	}
	uint64_t original_length = L*8;
	
	b = 0x80;
	@<Process one byte of message@>;
	L++;
	while (L % 64 != 56) {
		b = 0;
		@<Process one byte of message@>;
		L++;
	}

	b = (original_length & 0x00000000000000FF) >> 0;
	@<Process one byte of message@>;
	b = (original_length & 0x000000000000FF00) >> 8;
	@<Process one byte of message@>;
	b = (original_length & 0x0000000000FF0000) >> 16;
	@<Process one byte of message@>;
	b = (original_length & 0x00000000FF000000) >> 24;
	@<Process one byte of message@>;
	b = (original_length & 0x000000FF00000000) >> 32;
	@<Process one byte of message@>;
	b = (original_length & 0x0000FF0000000000) >> 40;
	@<Process one byte of message@>;
	b = (original_length & 0x00FF000000000000) >> 48;
	@<Process one byte of message@>;
	b = (original_length & 0xFF00000000000000) >> 56;
	@<Process one byte of message@>;

	WRITE("%02x%02x%02x%02x",
		a0 % 0x100, (a0 >> 8) % 0x100, (a0 >> 16) % 0x100, (a0 >> 24) % 0x100);
	WRITE("%02x%02x%02x%02x",
		b0 % 0x100, (b0 >> 8) % 0x100, (b0 >> 16) % 0x100, (b0 >> 24) % 0x100);
	WRITE("%02x%02x%02x%02x",
		c0 % 0x100, (c0 >> 8) % 0x100, (c0 >> 16) % 0x100, (c0 >> 24) % 0x100);
	WRITE("%02x%02x%02x%02x",
		d0 % 0x100, (d0 >> 8) % 0x100, (d0 >> 16) % 0x100, (d0 >> 24) % 0x100);
		
	BinaryFiles::close(bin);
}

@<Process one byte of message@> =
	buffer[bc++] = (b % 0x100);
	if (bc == 64) {
		bc = 0;
		uint32_t M[16];
		for (uint32_t i=0; i<16; i++)
			M[i] = buffer[i*4+3]*0x1000000 + buffer[i*4+2]*0x10000 +
					buffer[i*4+1]*0x100 + buffer[i*4+0];
		uint32_t A = a0;
		uint32_t B = b0;
		uint32_t C = c0;
		uint32_t D = d0;
		for (uint32_t i=0; i<64; i++) {
       		uint32_t F, g;
			if (i < 16) {
				F = (B & C) | ((~ B) & D);
				g = i;
			} else if (i < 32) {
				F = (D & B) | ((~ D) & C);
				g = (5*i + 1) % 16;
			} else if (i < 48) {
				F = B ^ C ^ D;
				g = (3*i + 5) % 16;
			} else {
				F = C ^ (B | (~ D));
				g = (7*i) % 16;
			}
			F += A + K[i] + M[g];
			A = D;
			D = C;
			C = B;
			B = B + BinaryFiles::rotate(F, s[i]);
		}
   		a0 += A;
    	b0 += B;
    	c0 += C;
    	d0 += D;
	}

@ This is a C-compiler safe way to rotate a 32-bit unsigned integer left
by |shift| number of bits. Enjoy:

=
uint32_t BinaryFiles::rotate(uint32_t value, uint32_t shift) {
    if ((shift &= sizeof(value)*8 - 1) == 0) return value;
    return (value << shift) | (value >> (sizeof(value)*8 - shift));
}
