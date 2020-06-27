[Directories::] Directories.

Scanning directories on the host filing system.

@ All of this abstracts the code already found in the platform definitions.

=
typedef struct scan_directory {
	void *directory_handle;
	char directory_name_written_out[4*MAX_FILENAME_LENGTH];
	CLASS_DEFINITION
} scan_directory;

@ The directory name going out has to be transcoded from flat Unicode to
whatever the locale encoding is; the filenames coming back have to be
transcoded the other way.

=
scan_directory *Directories::open(pathname *P) {
	scan_directory *D = CREATE(scan_directory);
	TEMPORARY_TEXT(pn)
	WRITE_TO(pn, "%p", P);
	Str::copy_to_locale_string(D->directory_name_written_out, pn, 4*MAX_FILENAME_LENGTH);
	DISCARD_TEXT(pn)
	D->directory_handle = Platform::opendir(D->directory_name_written_out);
	if (D->directory_handle == NULL) return NULL;
	return D;
}

int Directories::next(scan_directory *D, text_stream *leafname) {
	char leafname_Cs[MAX_FILENAME_LENGTH];
	int rv = TRUE;
	while (rv) {
		rv = Platform::readdir(D->directory_handle, D->directory_name_written_out, leafname_Cs);
		if (leafname_Cs[0] != '.') break;
	}
	Str::clear(leafname);
	if (rv) Streams::write_locale_string(leafname, leafname_Cs);
	return rv;
}

void Directories::close(scan_directory *D) {
	Platform::closedir(D->directory_handle);
}
