[Platform::] Windows Platform.

A version of our operating system interface suitable for Microsoft Windows.

@ This Foundation module comes with two variant versions of the |Platform::|
section of code. The one you're reading compiles on Windows, and the other
on a POSIX operating system.

@h Microsoft Windows.

@d PLATFORM_STRING "windows"
@d LOCALE_IS_ISO
@d FOLDER_SEPARATOR '\\'
@d SHELL_QUOTE_CHARACTER '\"'
@d WINDOWS_JAVASCRIPT
@d INFORM_FOLDER_RELATIVE_TO_HOME ""
@d HTML_MAP_FONT_SIZE 11

= (very early code)
#include <sys/stat.h>
#include <dirent.h>
#include <errno.h>
#include <io.h>
#include <windows.h>

@ A Windows-safe form of |isdigit|. Annoyingly, the C specification allows
the implementation to have |char| either signed or unsigned. On Windows it's
generally signed. Now, consider what happens with a character value of
acute-e. This has an |unsigned char| value of 233. When stored in a |char|
on Windows, this becomes a value of |-23|. When this is passed to |isdigit()|,
we need to consider the prototype for |isdigit()|:

|int isdigit(int);|

So, when casting to int we get |-23|, not |233|. Unfortunately the return value
from |isdigit()| is only defined by the C specification for values in the
range 0 to 255 (and also EOF), so the return value for |-23| is undefined.
And with Windows GCC, |isdigit(-23)| returns a non-zero value.

@d isdigit(x) Platform::Windows_isdigit(x)

=
int Platform::Windows_isdigit(int c) {
	return ((c >= '0') && (c <= '9')) ? 1 : 0;
}

@h Environment variables.

= (very early code)
unsigned long __stdcall GetCurrentDirectoryA(unsigned long len, char* buffer);
unsigned long __stdcall SHGetFolderPathA(unsigned long wnd, int folder,
	unsigned long token, unsigned long flags, char* path);

char *Platform::getenv(const char *name) {
	static char env[260];
	env[0] = 0;
	if (strcmp(name,"PWD") == 0) {
		if (GetCurrentDirectoryA(260,env) > 0) return env;
	} else if (strcmp(name,"HOME") == 0) {
		if (SHGetFolderPathA(0,5,0,0,env) == 0) return env;
	}
	return getenv(name);
}

@h Executable location.
Fill the wide-char buffer |p| with the path to the current executable, up to
length |length|. This function is guaranteed to be called from only one
thread. Should the information be unavailable, or fail to fit into |p|,
truncate |p| to zero length. (On some platforms, the information will
always be unavailable: that doesn't mean we can't run on those platforms,
just that installation and use of Foundation-built tools is less convenient.)

=
void Platform::where_am_i(wchar_t *p, size_t length) {
	DWORD result = GetModuleFileNameW(NULL, p, length);	
	if ((result == 0) || (result == length)) p[0] = 0;
}

@h Shell commands.

= (very early code)
struct Win32_Startup_Info {
	long v1; char* v2; char* v3; char* v4; long v5; long v6;
	long v7; long v8; long v9; long v10; long v11;
	unsigned long flags; unsigned short showWindow;
	short v12; char* v13; long v14; long v15; long v16; };
struct Win32_Process_Info {
	unsigned long process; unsigned long thread; long v1; long v2; };
unsigned long __stdcall CloseHandle(unsigned long handle);
unsigned long __stdcall WaitForSingleObject(unsigned long handle, unsigned long ms);
unsigned long __stdcall CreateProcessA(void* app, char* cmd, void* pa,
	void* ta, long inherit, unsigned long flags, void* env, void* dir,
	struct Win32_Startup_Info* start, struct Win32_Process_Info* process);
unsigned long __stdcall GetExitCodeProcess(unsigned long proc, unsigned long* code);

int Platform::system(const char *cmd) {
	if (strncmp(cmd,"md5 ", 4) == 0) return 0;

	char cmdline[4096];
	sprintf(cmdline,"cmd /s /c \"%s\"", cmd);

	struct Win32_Startup_Info start = { sizeof (struct Win32_Startup_Info), 0 };
	start.flags = 1;
	start.showWindow = 0;

	struct Win32_Process_Info process;
	if (CreateProcessA(0, cmdline, 0, 0, 0, 0x8000000, 0, 0, &start, &process) == 0)
		return -1;

	CloseHandle(process.thread);
	if (WaitForSingleObject(process.process, -1) != 0) {
		CloseHandle(process.process);
		return -1;
	}

	unsigned long code = 10;
	GetExitCodeProcess(process.process, &code);
	CloseHandle(process.process);

	return code;
}

@h Directory handling.

=
int Platform::mkdir(char *transcoded_pathname) {
	errno = 0;
	int rv = _mkdir(transcoded_pathname);
	if (rv == 0) return TRUE;
	if (errno == EEXIST) return TRUE;
	return FALSE;
}

void *Platform::opendir(char *dir_name) {
	DIR *dirp = opendir(dir_name);
    return (void *) dirp;
}

int Platform::readdir(void *D, char *dir_name,
	char *leafname) {
	char path_to[2*MAX_FILENAME_LENGTH+2];
	struct _stat file_status;
	int rv;
	DIR *dirp = (DIR *) D;
	struct dirent *dp;
	if ((dp = readdir(dirp)) == NULL) return FALSE;
	sprintf(path_to, "%s%c%s", dir_name, FOLDER_SEPARATOR, dp->d_name);
	rv = _stat(path_to, &file_status);
	if (rv != 0) return FALSE;
	if (S_ISDIR(file_status.st_mode))
		sprintf(leafname, "%s%c", dp->d_name, FOLDER_SEPARATOR);
	else strcpy(leafname, dp->d_name);
	return TRUE;
}

void Platform::closedir(void *D) {
	DIR *dirp = (DIR *) D;
	closedir(dirp);
}

@h Sleep. The Windows |Sleep| call measures time in milliseconds, whereas
POSIX |sleep| is for seconds.

= (very early code)
void __stdcall Sleep(unsigned long ms);
void Platform::sleep(int seconds) {
	Sleep((unsigned long) 1000*seconds);
}

@h Notifications.

= 
void Platform::notification(text_stream *text, int happy) {
}

@h Concurrency.
The following predeclarations come from the Windows SDK.

= (very early code)
unsigned long __stdcall CreateThread(void* attrs, unsigned long stack,
	void* func, void* param, unsigned long flags, unsigned long* id);

struct Win32_Thread_Attrs {};
struct Win32_Thread_Start { void *(*fn)(void *); void* arg; };

typedef unsigned long foundation_thread;
typedef struct Win32_Thread_Attrs foundation_thread_attributes;

@
=
unsigned long __stdcall Platform::Win32_Thread_Func(unsigned long param) {
	struct Win32_Thread_Start* start = (struct Win32_Thread_Start*)param;
	(start->fn)(start->arg);
	free(start);
	return 0;
}

int Platform::create_thread(foundation_thread *pt, const foundation_thread_attributes *pa,
	void *(*fn)(void *), void *arg) {
	struct Win32_Thread_Start* start = (struct Win32_Thread_Start*) malloc(sizeof (struct Win32_Thread_Start));
	start->fn = fn;
	start->arg = arg;
	unsigned long thread = CreateThread(0,0,Platform::Win32_Thread_Func,start,0,0);
	if (thread == 0) {
		free(start);
		return 1;
	} else {
		*pt = thread;
		return 0;
	}
}

int Platform::join_thread(pthread_t pt, void** rv) {
	return (WaitForSingleObject(pt,-1) == 0) ? 0 : 1;
}

void Platform::init_thread(pthread_attr_t* pa, size_t size) {
}

size_t Platform::get_thread_stack_size(pthread_attr_t* pa) {
	return 0;
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
	if (stat(transcoded_pathname, &filestat) != -1) return filestat.st_mtime;
	return Platform::never_time();
}

off_t Platform::size(char *transcoded_filename) {
	struct stat filestat;
	if (stat(transcoded_filename, &filestat) != -1) return filestat.st_size;
	return (off_t) 0;
}

@h Mutexes.

@d CREATE_MUTEX(name)
	struct Win32_Critical_Section name { (void*)-1, -1, 0, 0, 0, 0 };
@d LOCK_MUTEX(name) EnterCriticalSection(&name);
@d UNLOCK_MUTEX(name) LeaveCriticalSection(&name);

= (very early code)
struct Win32_Critical_Section {
	void* v1; long v2; long v3; long v4; long v5; void* v6; };
void __stdcall EnterCriticalSection(struct Win32_Critical_Section* cs);
void __stdcall LeaveCriticalSection(struct Win32_Critical_Section* cs);
