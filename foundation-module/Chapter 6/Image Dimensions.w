[ImageFiles::] Image Dimensions.

These utility routines look at the headers of JPEG and PNG files to find the
pixel dimensions of any images supplied by the user for cover art and figures.

@h JPEG files.
The following code, contributed by Toby Nelson, either finds the pixel width
and height of a given JPEG file and returns |TRUE| or, if it can't read the
file or doesn't recognise the header as having JPEG format, returns |FALSE|.

JPEG is properly speaking not a file format but a compression technique:
the routine below works with either JIF (JPEG Interchange Format) or its
simpler cousin JFIF (JPEG File Interchange Format).

We scan the file looking for "markers", each of which begins with an
|0xFF| byte and is followed by a marker-type byte which is neither |0x00|
nor |0xFF|. The compulsory marker SOI must appear at the start of the file,
providing one way to detect probable JPEGs by looking at the first two
bytes. There must also eventually be a start of frame marker, for the
actual image: this can have many forms, but in all cases tells us the
height and width.

=
int ImageFiles::get_JPEG_dimensions(FILE *JPEG_file, unsigned int *width, unsigned int *height) {
    unsigned int sig, length;
    int marker;

    if (!BinaryFiles::read_int16(JPEG_file, &sig)) return FALSE;
    if (sig != 0xFFD8) return FALSE; /* |0xFF| (marker) then |0xD8| (SOI) */

    do {
        do {
            marker = getc(JPEG_file);
            if (marker == EOF) return FALSE;
        } while (marker != 0xff); /* skip to next |0xFF| byte */

        do {
            marker = getc(JPEG_file);
        } while (marker == 0xff); /* skip to next non |FF| byte */

        if (!BinaryFiles::read_int16(JPEG_file, &length)) return FALSE; /* length of marker */

        switch(marker) {
        	/* all variant forms of "start of frame": e.g., |0xC0| is a baseline DCT image */
            case 0xc0:
            case 0xc1: case 0xc2: case 0xc3:
            case 0xc5: case 0xc6: case 0xc7:
            case 0xc9: case 0xca: case 0xcb:
            case 0xcd: case 0xce: case 0xcf: {

 				/* fortunately these markers all then open with the same format */
                if (getc(JPEG_file) == EOF) return FALSE; /* skip 1 byte of data precision  */

                if (!BinaryFiles::read_int16(JPEG_file, height)) return FALSE;
                if (!BinaryFiles::read_int16(JPEG_file, width)) return FALSE;

                return TRUE;
            }
            default:
                if (fseek(JPEG_file, (long) (length - 2), SEEK_CUR) != 0) return FALSE; /* skip rest of marker */
        }
    }
    while (marker != EOF);

    return FALSE;
}

@h PNG files.
The PNG file must start with a signature which indicates that the
remainder contains a single PNG image, consisting of a series of chunks
beginning with an IHDR chunk and ending with an IEND chunk ("Portable
Network Graphics (PNG) Specification", 2nd edition, section 5.2). We only
need to scan the IHDR chunk, of which the pixel width and height are the
first two words (section 11.2.2).

=
int ImageFiles::get_PNG_dimensions(FILE *PNG_file, unsigned int *width, unsigned int *height) {
    unsigned int sig1, sig2, length, type;

    /* Check PNG signature */
    if (!BinaryFiles::read_int32(PNG_file, &sig1)) return FALSE;
    if (!BinaryFiles::read_int32(PNG_file, &sig2)) return FALSE;
    if ((sig1 != 0x89504e47) || (sig2 != 0x0d0a1a0a)) return FALSE;

    /* Read first chunk */
    if (!BinaryFiles::read_int32(PNG_file, &length)) return FALSE;
    if (!BinaryFiles::read_int32(PNG_file, &type)) return FALSE;

    /* First chunk must be IHDR */
    if (type != 0x49484452) return FALSE;

    /* Width and height follow */
    if (!BinaryFiles::read_int32(PNG_file, width)) return FALSE;
    if (!BinaryFiles::read_int32(PNG_file, height)) return FALSE;
    return TRUE;
}
