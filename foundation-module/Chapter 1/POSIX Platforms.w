[Platform::] POSIX Platforms.

A version of our operating system interface suitable for POSIX-compliant
operating systems.

@ The C standard library leaves many questions unanswered about how to deal
with the host operating system: for example, it knows very little about
directories, or about concurrency. The POSIX standard ("Portable Operating
System Interface") aims to fill these gaps by providing facilities which
ought to exist across any Unix-like system. POSIX is neither fully present
on Unix-like systems nor fully absent from Windows, but for the limited
purposes we need here, it's simplest to divide all operating systems into
two groups: the POSIX group, and Windows.

This Foundation module therefore comes with two variant versions of the
|Platform::| section of code. The one you're reading compiles on a POSIX
operating system, and the other one on Windows.

@ Some basics that apply to all POSIX-supporting systems.

@d FOLDER_SEPARATOR '/'
@d SHELL_QUOTE_CHARACTER '\''

= (very early code)
#include <sys/stat.h>
#include <sys/types.h>
#include <errno.h>
#include <dirent.h>
#include <pthread.h>
#include <limits.h>
#include <unistd.h>

@h Mac OS X. ^"ifdef-PLATFORM_MACOS"

@d PLATFORM_STRING "macos"
@d SHELL_QUOTE_CHARACTER '\''
@d INFORM_FOLDER_RELATIVE_TO_HOME "Library"

@h Generic Unix. ^"ifdef-PLATFORM_UNIX"
These settings are used both for the Linux versions (both command-line, by
Adam Thornton, and for Ubuntu, Fedora, Debian and so forth, by Philip
Chimento) and also for Solaris variants: they can probably be used for any
Unix-based system.

@d PLATFORM_STRING "unix"
@d INFORM_FOLDER_RELATIVE_TO_HOME ""

= (very early code)
#include <strings.h>

@h Linux. ^"ifdef-PLATFORM_LINUX"
These settings are used both for the Linux versions (both command-line, by
Adam Thornton, and for Ubuntu, Fedora, Debian and so forth, by Philip
Chimento) and also for Solaris variants: they can probably be used for any
Unix-based system.

@d PLATFORM_STRING "linux"
@d INFORM_FOLDER_RELATIVE_TO_HOME ""

= (very early code)
#include <strings.h>

@h Android. ^"ifdef-PLATFORM_ANDROID"
These settings are used for Nathan Summers's Android versions.

@d PLATFORM_STRING "android"
@d SUPPRESS_MAIN
@d INFORM_FOLDER_RELATIVE_TO_HOME ""

= (very early code)
#include <strings.h>

@h Folder separator.
When using a Unix-like system such as Cygwin or MSYS2 on Windows, it's
inevitable that paths will sometimes contain backslashes and sometimes forward
slashes, meaning a folder (i.e. directory) divide in either case. So:

- When writing such a divider, always write |FOLDER_SEPARATOR|, a backslash;
- When testing for such a divider, call the following.

=
int Platform::is_folder_separator(inchar32_t c) {
	return (c == FOLDER_SEPARATOR);
}

@h Locale.
The following definition handles possible differences of text encoding
in filenames, which depend on the current "locale". Locale is an odd piece
of old Unix terminology, but one thing it includes is how the textual names
of files are encoded (as ASCII, as ISO Latin-1, as UTF-8, etc.). The default
here is UTF-8 since OS X and Linux both adopt this.

=
#ifndef LOCALE_IS_ISO
#ifndef LOCALE_IS_UTF8
#define LOCALE_IS_UTF8 1
#endif
#endif

@h Environment variables.

=
char *Platform::getenv(const char *name) {
	return getenv(name);
}

@h Executable location. ^"ifdef-PLATFORM_LINUX"
Fill the wide-char buffer |p| with the path to the current executable, up to
length |length|. This function is guaranteed to be called from only one
thread. Should the information be unavailable, or fail to fit into |p|,
truncate |p| to zero length. (On some platforms, the information will
always be unavailable: that doesn't mean we can't run on those platforms,
just that installation and use of Foundation-built tools is less convenient.)

=
void Platform::where_am_i(inchar32_t *p, size_t length) {
    char buffer[PATH_MAX + 1];
    @<Follow the proc filesystem symlink to the real filesystem's file@>;
	@<Transcode buffer, which is locale-encoded, into the wide-char buffer@>;
}

@ On Linux, |/proc/self/exe| is a symlink to the current process's executable.
Follow that link to find the path. Normally when reading a symlink, one uses
|lstat()| to find the path length instead of guessing |PATH_MAX|, but the
symlinks in |/proc| are special and don't provide a length to |lstat()|.

@<Follow the proc filesystem symlink to the real filesystem's file@> =
	ssize_t link_len = readlink("/proc/self/exe", buffer, PATH_MAX);
    if (link_len < 0) @<Fail@>; // unable to find
    buffer[link_len] = '\0';

@ Next, convert the obtained buffer (which is a string in the local filename
encoding, and possibly in a multibyte encoding such as UTF-8) to a wide-char
string.

@<Transcode buffer, which is locale-encoded, into the wide-char buffer@> =
    size_t convert_len = mbstowcs((wchar_t *) p, buffer, length);
    if (convert_len == (size_t)-1) @<Fail@>; // wouldn't fit

@ And now the Mac version: ^"ifdef-PLATFORM_MACOS"
 
= (very early code)
int _NSGetExecutablePath(char* buf, uint32_t* bufsize);

void Platform::where_am_i(inchar32_t *p, size_t length) {
    char relative_path[4 * PATH_MAX + 1];
    char absolute_path[PATH_MAX + 1];
    size_t convert_len;
    uint32_t pathsize = sizeof(relative_path);
    uint32_t tempsize = pathsize;

    /* Get "a path" to the executable */
    if (_NSGetExecutablePath(relative_path, &tempsize) != 0) @<Fail@>;

    /* Convert to canonical absolute path */
    if (realpath(relative_path, absolute_path) == NULL) @<Fail@>;

    /* Next, convert the obtained buffer (which is a string in the local
     * filename encoding, possibly multibyte) to a wide-char string. */
    convert_len = mbstowcs((wchar_t *) p, absolute_path, length);
    if (convert_len == (size_t)-1) @<Fail@>;
}

@ For Unix, there's nothing we can generically do. ^"ifdef-PLATFORM_UNIX"
 
=
void Platform::where_am_i(inchar32_t *p, size_t length) {
	@<Fail@>;
}

@ On Android, there's no real need for this. ^"ifdef-PLATFORM_ANDROID"
 
=
void Platform::where_am_i(inchar32_t *p, size_t length) {
	@<Fail@>;
}

@ All of the above make use of:

@<Fail@> =
	p[0] = '\0';
	return;

@h Shell commands. ^"ifndef-PLATFORM_MACOS"

=
int Platform::system(const char *cmd) {
	return system(cmd);
}

@ ^"ifdef-PLATFORM_MACOS"
In MacOS 10.5, a new implementation of the C standard library 
crippled performance of |system()| by placing it behind a global mutex, so
that it was impossible for two cores to be calling the function at the same
time. The net effect of this is that the Inform test suite, executing in
Intest, ran in 1/16th speed. This issue didn't come to light until 2019,
however, because the build setting |-mmacosx-version-min=10.4| turned out
to force use of the (perfectly good) pre-10.5 library, where |system()|
continued to run in a multi-threaded way, just as it does on Linux and
most all other Unixes. The old library was eventually withdrawn by Apple
in 2018, and in any case would stop working at some point in 2019-20 due
to the final removal of 32-bit binary support from MacOS.

It took several days to find a pthread-safe way to reimplement |system()|.
The obvious way, using |fork()| and then running |execve()| on the child
process -- essentially the standard way to implement |system()|, if you forget
about signal-handling -- led to obscure and unrepeatable memory corruption
bugs in Intest, with the worker threads apparently writing on each other's
memory space. Using |posix_spawn()| instead appears to work better.

=
#include <spawn.h>
#include <sys/wait.h>

extern char **environ;

int Platform::system(const char *cmd) {
    char *argv[] = {"sh", "-c", (char *) cmd, NULL};
    pid_t pid;
    int status = posix_spawn(&pid, "/bin/sh", NULL, NULL, argv, environ);
    if (status == 0) {
        if (waitpid(pid, &status, 0) != -1) return status;
    	internal_error("waitpid failed");
    } else {
        WRITE_TO(STDERR, "posix_spawn: %s\n", strerror(status));
        internal_error("posix_spawn failed");
    }
    return -1;
}

@h Directory handling.

=
int Platform::mkdir(char *transcoded_pathname) {
	errno = 0;
	int rv = mkdir(transcoded_pathname, S_IRWXU | S_IRWXG | S_IROTH | S_IXOTH);
	if (rv == 0) return TRUE;
	if (errno == EEXIST) return TRUE;
	return FALSE;
}

void *Platform::opendir(char *dir_name) {
	DIR *dirp = opendir(dir_name);
	return (void *) dirp;
}

int Platform::readdir(void *D, char *dir_name, char *leafname) {
	char path_to[2*MAX_FILENAME_LENGTH+2];
	struct stat file_status;
	int rv;
	DIR *dirp = (DIR *) D;
	struct dirent *dp;
	do {
	  dp = readdir(dirp);
	  if (dp == NULL) return FALSE;
	  sprintf(path_to, "%s%c%s", dir_name, FOLDER_SEPARATOR, dp->d_name);
  	  errno = 0;
	  rv = stat(path_to, &file_status);
        } while (dp && (errno == ENOENT));
	if (rv != 0) return FALSE;
	if (S_ISDIR(file_status.st_mode)) sprintf(leafname, "%s/", dp->d_name);
	else strcpy(leafname, dp->d_name);
	return TRUE;
}

void Platform::closedir(void *D) {
	DIR *dirp = (DIR *) D;
	closedir(dirp);
}

@h Renaming.

=
int Platform::rename_file(char *old_transcoded_pathname, char *new_transcoded_pathname) {
	if (rename(old_transcoded_pathname, new_transcoded_pathname) != 0)
		return FALSE;
	return TRUE;
}

int Platform::rename_directory(char *old_transcoded_pathname, char *new_transcoded_pathname) {
	if (rename(old_transcoded_pathname, new_transcoded_pathname) != 0)
		return FALSE;
	return TRUE;
}

@h Deleting.

=
int Platform::delete_file(char *transcoded_pathname) {
	char rm_command[2*MAX_FILENAME_LENGTH];
	sprintf(rm_command, "rm -f ");
	Platform::quote_text(rm_command + strlen(rm_command), transcoded_pathname, FALSE);
	return Platform::system(rm_command);
}

@h Copying.

=
void Platform::copy_file(char *from_transcoded_pathname, char *to_transcoded_pathname) {
	char cp_command[10*MAX_FILENAME_LENGTH];
	sprintf(cp_command, "cp -f ");
	Platform::quote_text(cp_command + strlen(cp_command), from_transcoded_pathname, FALSE);
	sprintf(cp_command + strlen(cp_command), " ");
	Platform::quote_text(cp_command + strlen(cp_command), to_transcoded_pathname, FALSE);
	Platform::system(cp_command);
}

@h Timestamp and file size.
There are implementations of the C standard library where |time_t| has
super-weird behaviour, but on almost all POSIX systems, time 0 corresponds to
midnight on 1 January 1970. All we really need is that the "never" value
is one which is earlier than any possible timestamp on the files we'll
be dealing with.

=
time_t Platform::never_time(void) {
	return (time_t) 0;
}

time_t Platform::timestamp(char *transcoded_filename) {
	struct stat filestat;
	if (stat(transcoded_filename, &filestat) != -1) return filestat.st_mtime;
	return Platform::never_time();
}

off_t Platform::size(char *transcoded_filename) {
	struct stat filestat;
	if (stat(transcoded_filename, &filestat) != -1) return filestat.st_size;
	return (off_t) 0;
}

@h Sync.
Both names here are of directories which do exist. The function makes
the |dest| tree an exact copy of the |source| tree (and therefore deletes
anything different which was originally in |dest|).

In POSIX world, we can fairly well depend on |rsync| being around:

=
int Platform::rsync(char *transcoded_source, char *transcoded_dest) {
	char rsync_command[10*MAX_FILENAME_LENGTH];
	sprintf(rsync_command, "rsync -a --delete ");
	Platform::quote_text(rsync_command + strlen(rsync_command), transcoded_source, TRUE);
	sprintf(rsync_command + strlen(rsync_command), " ");
	Platform::quote_text(rsync_command + strlen(rsync_command), transcoded_dest, FALSE);
	return Platform::system(rsync_command);
}

void Platform::quote_text(char *quoted, char *raw, int terminate) {
	quoted[0] = SHELL_QUOTE_CHARACTER;
	int qp = 1;
	for (int rp = 0; raw[rp]; rp++) {
		char c = raw[rp];
		if (c == SHELL_QUOTE_CHARACTER) quoted[qp++] = '\\';
		quoted[qp++] = c;
	}
	if (terminate) quoted[qp++] = FOLDER_SEPARATOR;
	quoted[qp++] = SHELL_QUOTE_CHARACTER;
	quoted[qp++] = 0;
}

@h Sleep.

=
void Platform::sleep(int seconds) {
	sleep((unsigned int) seconds);
}

@h Notifications. ^"ifdef-PLATFORM_MACOS"
The "submarine" sound is a gloomy thunk; the "bell" is the three-tone rising
alert noise which iPhones make when they receive texts, but which hackers of a
certain age will remember as the "I have ripped your music CD now" alert from
SoundJam, the program which Apple bought and rebranded as iTunes. Apple now
seems to consider this alert a general-purpose "something good has happened".

It is anybody's guess how long Apple will permit the shell command |osascript|
to survive, given the MacOS team's current hostility to scripting; we're
actually running a one-line AppleScript here.

=
void Platform::notification(text_stream *text, int happy) {
	char *sound_name = "Bell.aiff";
	if (happy == FALSE) sound_name = "Submarine.aiff";
	TEMPORARY_TEXT(TEMP)
	WRITE_TO(TEMP, "osascript -e 'display notification \"%S\" "
		"sound name \"%s\" with title \"intest Results\"'", text, sound_name);
	Shell::run(TEMP);
	DISCARD_TEXT(TEMP)
}

@ ^"ifndef-PLATFORM_MACOS"

= 
void Platform::notification(text_stream *text, int happy) {
}

@h Terminal setup.
The idea of this function is that if anything needs to be done to enable the
output of ANSI-standard coloured terminal output, then this function has the
chance to do it; similarly, it may need to configure itself to receive console
output with the correct locale (calling |Locales::get(CONSOLE_LOCALE)| to
find this).

On POSIX platforms, so far as we know, nothing need be done.

=
void Platform::configure_terminal(void) {
}

@h Concurrency.
The following abstracts the pthread library, so that it can all be done
differently on Windows.

= (very early code)
typedef pthread_t foundation_thread;
typedef pthread_attr_t foundation_thread_attributes;

@ =
int Platform::create_thread(foundation_thread *pt,
	const foundation_thread_attributes *pa, void *(*fn)(void *), void *arg) {
	return pthread_create(pt, pa, fn, arg);
}

int Platform::join_thread(foundation_thread pt, void** rv) {
	return pthread_join(pt, rv);
}

void Platform::init_thread(foundation_thread_attributes *pa, size_t size) {
	if (pthread_attr_init(pa) != 0) internal_error("thread initialisation failed");
	if (pthread_attr_setstacksize(pa, size) != 0) internal_error("thread stack sizing failed");
}

size_t Platform::get_thread_stack_size(foundation_thread_attributes *pa) {
	size_t mystacksize;
	pthread_attr_getstacksize(pa, &mystacksize);
	return mystacksize;
}

@ ^"ifdef-PLATFORM_LINUX"
This function returns the number of logical cores in the host computer --
i.e., twice the number of physical cores if there's hyperthreading. The
result is used as a guess for an appropriate number of simultaneous threads
to launch.

It's not easy to find a function which reliably does this on all POSIX platforms.
On Linux we can use |sys/sysinfo.h|, but this header is a POSIX extension which
MacOS does not support.

= (very early code)
#include <sys/sysinfo.h>

@ ^"ifdef-PLATFORM_LINUX"
= 
int Platform::get_core_count(void) {
	int N = get_nprocs();
	if (N < 1) return 1;
	return N;
}

@ ^"ifdef-PLATFORM_MACOS"
While MacOS lacks |sysinfo.h|, it does have |sysctl.h|:

= (very early code)
#include <sys/sysctl.h>

@ ^"ifdef-PLATFORM_MACOS"
=
int Platform::get_core_count(void) {
	int N;
	size_t N_size = sizeof(int);
	sysctlbyname("hw.logicalcpu", &N, &N_size, NULL, 0);
	if (N < 1) return 1;
	return N;
}

@ ^"ifdef-PLATFORM_ANDROID"
For Android it seems prudent simply to ignore multithreading:

= 
int Platform::get_core_count(void) {
	return 1;
}

@h Mutexes.

@d CREATE_MUTEX(name)
	static pthread_mutex_t name = PTHREAD_MUTEX_INITIALIZER;
@d LOCK_MUTEX(name) pthread_mutex_lock(&name);
@d UNLOCK_MUTEX(name) pthread_mutex_unlock(&name);
