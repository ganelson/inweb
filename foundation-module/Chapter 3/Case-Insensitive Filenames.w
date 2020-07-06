[CIFilingSystem::] Case-Insensitive Filenames.

On some of the Unix-derived file systems on which Inform runs,
filenames are case-sensitive, so that FISH and fish might be different files.
This makes extension files, installed by the user, prone to being missed. The
code in this section provides a routine to carry out file opening as if
filenames are case-insensitive, and is used only for extensions.

@ This section contains a single utility routine, contributed by Adam
Thornton: a specialised, case-insensitive form of |fopen()|. It is specialised
in that it is designed for opening extensions, where the file path will be
case-correct up to the last two components of the path (the leafname and the
immediately containing directory), but where the casing may be wrong in those
last two components.

@ If the exact filename or extension directory (case-correct) exists,
|CIFilingSystem::fopen()| will choose it to open. If not, it will
use |strcasecmp()| to find a file or directory with the same name but
differing in case and use it instead. If it finds exactly one candidate file,
it will then attempt to |fopen()| it and return the result.

If |CIFilingSystem::fopen()| succeeds, it returns a |FILE *|
(passed back to it from the underlying |fopen()|). If
|CIFilingSystem::fopen()| fails, it returns |NULL|, and
|errno| is set accordingly:
(a) If no suitable file was found, |errno| is set to |ENOENT|.
(b) If more than one possibility was found, but none of them exactly match
the supplied case, |errno| is set to |EBADF|.
(c) Note that if multiple directories which match case-insensitively are
found, but none is an exact match, |EBADF| will be set regardless of the
contents of the directories.
(d) If |CIFilingSystem::fopen()| fails during its allocation of
space to hold its intermediate strings for comparison, or for its various
data structures, |errno| is set to |ENOMEM|.
(e) If an unambiguous filename is found but the |fopen()| fails, |errno| is
left at whatever value the underlying |fopen()| set it to.

@h The routine. ^"ifdef-PLATFORM_POSIX"
The routine is available only on POSIX platforms where |PLATFORM_POSIX|
is defined (see "Platform-Specific Definitions"). In practice this means
everywhere except Windows, but all Windows file systems are case-preserving
and case-insensitive in any case.

Briefly, we try to get the extension directory name right first, by looking
for the given casing, then if that fails, for a unique alternative with
different casing; and then repeat within that directory for the extension
file itself.

=
FILE *CIFilingSystem::fopen(const char *path, const char *mode) {
	char *topdirpath = NULL, *ciextdirpath = NULL, *cistring = NULL, *ciextname = NULL;
	char *workstring = NULL, *workstring2 = NULL;
	DIR *topdir = NULL, *extdir = NULL; FILE *handle;
	size_t length;

	/* for efficiency's sake, though it's logically equivalent, we try... */
	handle = fopen(path, mode); if (handle) @<Happy ending to ci-fopen@>;

	@<Find the length of the path, giving an error if it is empty or NULL@>;
	@<Allocate memory for strings large enough to hold any subpath of the path@>;
	@<Parse the path to break it into topdir path, extension directory and leafname@>;

	topdir = opendir(topdirpath); /* whose pathname is assumed case-correct... */
	if (topdir == NULL) @<Sad ending to ci-fopen@>; /* ...so that failure is fatal; |errno| is set by |opendir| */

	sprintf(workstring, "%s%c%s", topdirpath, FOLDER_SEPARATOR, ciextdirpath);
	extdir = opendir(workstring); /* try with supplied extension directory name */
	if (extdir == NULL) @<Try to find a unique insensitively matching directory name in topdir@>
	else strcpy(cistring, workstring);

	sprintf(workstring, "%s%c%s", cistring, FOLDER_SEPARATOR, ciextname);
	handle = fopen(workstring, mode); /* try with supplied name */
	if (handle) @<Happy ending to ci-fopen@>;

	@<Try to find a unique insensitively matching entry in extdir@>;
}

@h Looking for case-insensitive matches instead.
We emerge from the following only in the happy case where a unique matching
directory name can be found.

@<Try to find a unique insensitively matching directory name in topdir@> =
	int rc = CIFilingSystem::match_in_directory(topdir, ciextdirpath, workstring);
	switch (rc) {
		case 0:
			errno = ENOENT; @<Sad ending to ci-fopen@>;
		case 1:
			sprintf(cistring, "%s%c%s", topdirpath, FOLDER_SEPARATOR, workstring);
			extdir = opendir(cistring);
			if (extdir == NULL) {
				errno = ENOENT; @<Sad ending to ci-fopen@>;
			}
			break;
		default:
			errno = EBADF; @<Sad ending to ci-fopen@>;
	}

@ More or less the same, but we never emerge at all: all cases of the switch
return from the function.

@<Try to find a unique insensitively matching entry in extdir@> =
	int rc = CIFilingSystem::match_in_directory(extdir, ciextname, workstring);

	switch (rc) {
		case 0:
			errno = ENOENT; @<Sad ending to ci-fopen@>;
		case 1:
			sprintf(workstring2, "%s%c%s", cistring, FOLDER_SEPARATOR, workstring);
			workstring2[length] = 0;
			handle = fopen(workstring2, mode);
			if (handle) @<Happy ending to ci-fopen@>;
			errno = ENOENT; @<Sad ending to ci-fopen@>;
		default:
			errno = EBADF; @<Sad ending to ci-fopen@>;
	}

@h Allocation and deallocation.
We use six strings to hold full or partial pathnames.

@<Allocate memory for strings large enough to hold any subpath of the path@> =
	workstring = calloc(length+1, sizeof(char));
	if (workstring == NULL) { errno = ENOMEM; @<Sad ending to ci-fopen@>; }
	workstring2 = calloc(length+1, sizeof(char));
	if (workstring2 == NULL) { errno = ENOMEM; @<Sad ending to ci-fopen@>; }
	topdirpath = calloc(length+1, sizeof(char));
	if (topdirpath == NULL) { errno = ENOMEM; @<Sad ending to ci-fopen@>; }
	ciextdirpath = calloc(length+1, sizeof(char));
	if (ciextdirpath == NULL) { errno = ENOMEM; @<Sad ending to ci-fopen@>; }
	cistring = calloc(length+1, sizeof(char));
	if (cistring == NULL) { errno = ENOMEM; @<Sad ending to ci-fopen@>; }
	ciextname = calloc(length+1, sizeof(char));
	if (ciextname == NULL) { errno = ENOMEM; @<Sad ending to ci-fopen@>; }

@ If we are successful, we return a valid file handle...

@<Happy ending to ci-fopen@> =
	@<Prepare to exit ci-fopen cleanly@>;
	return handle;

@ ...and otherwise |NULL|, having already set |errno| with the reason why.

@<Sad ending to ci-fopen@> =
	@<Prepare to exit ci-fopen cleanly@>;
	return NULL;

@<Prepare to exit ci-fopen cleanly@> =
	if (workstring) free(workstring);
	if (workstring2) free(workstring2);
	if (topdirpath) free(topdirpath);
	if (ciextdirpath) free(ciextdirpath);
	if (cistring) free(cistring);
	if (ciextname) free(ciextname);
	if (topdir) closedir(topdir);
	if (extdir) closedir(extdir);

@h Pathname hacking.

@<Find the length of the path, giving an error if it is empty or NULL@> =
	length = 0;
	if (path) length = (size_t) strlen(path);
	if (length < 1) { errno = ENOENT; return NULL; }

@ And here we break up a pathname like
= (text)
	/Users/bobama/Library/Inform/Extensions/Hillary Clinton/Health Care.i7x
=
into three components:
(a) |topdirpath| is |/Users/bobama/Library/Inform/Extensions|, and its casing is correct.
(b) |ciextdirpath| is |Hillary Clinton|, but its casing may not be correct.
(c) |ciextname| is |Health Care.i7x|, but its casing may not be correct.

The contents of |workstring| are not significant afterwards.

@<Parse the path to break it into topdir path, extension directory and leafname@> =
	char *p;
	size_t extdirindex = 0, extindex = 0, namelen = 0, dirlen = 0;

	p = CIFilingSystem::strrchr(path);
	if (p) {
		extindex = (size_t) (p - path);
		namelen = length - extindex - 1;
		strncpy(ciextname, path + extindex + 1, namelen);
	}
	ciextname[namelen] = 0;
	
	strncpy(workstring, path, extindex);
	workstring[extindex] = 0;
	p = CIFilingSystem::strrchr(workstring);
	if (p) {
		extdirindex = (size_t) (p - workstring);
		strncpy(topdirpath, path, extdirindex);
	}
	topdirpath[extdirindex] = 0;

	dirlen = extindex - extdirindex;
	if (dirlen > 0) dirlen -= 1;
	strncpy(ciextdirpath, path + extdirindex + 1, dirlen);
	ciextdirpath[dirlen] = 0;

@h strrchr.
This is an elderly C library function, really, but rewritten so that it
can recognise any folder separator character.

=
char *CIFilingSystem::strrchr(const char *p) {
	const char *q = NULL;
	while (*p) {
		if (Platform::is_folder_separator((wchar_t) (*p))) q = p;
		p++;
	}
	return (char *) q;
}

@h Counting matches.
We count the number of names within the directory which case-insensitively
match against |name|, and copy the last which matches into |last_match|.
This must be at least as long as |name|. (We ought to be just a little careful
in case of improbable cases where the matched name contains a different
number of characters from |name|, for instance because on a strict reading
of Unicode "SS" is casing-equivalent to the eszet, but it's unlikely
that many contemporary implementations of |strcasecmp| are aware of this,
and in any case the code above contains much larger buffers than needed.)

=
int CIFilingSystem::match_in_directory(void *vd,
	char *name, char *last_match) {
	DIR *d = (DIR *) vd;
	struct dirent *dirp;
	int rc = 0;

	last_match[0] = 0;
	while ((dirp = readdir(d)) != NULL) {
		if (strcasecmp(name, dirp->d_name) == 0) {
			rc++;
			strcpy(last_match, dirp->d_name);
		}
	}
	return rc;
}

@h Non-POSIX tail. ^"ifndef-PLATFORM_POSIX"
On platforms without POSIX directory handling, we revert to regular |fopen|.

=
FILE *CIFilingSystem::fopen(const char *path, const char *mode) {
	return fopen(path, mode);
}
