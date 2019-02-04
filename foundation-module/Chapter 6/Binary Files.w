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
