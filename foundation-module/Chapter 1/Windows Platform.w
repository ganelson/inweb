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
@d INFORM_FOLDER_RELATIVE_TO_HOME ""

= (very early code)
#include <dirent.h>
#include <errno.h>
#include <io.h>
#include <sys/stat.h>

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <shellapi.h>
#include <shlobj.h>
#undef IN
#undef OUT

@h Folder separator.
When using a Unix-like system such as Cygwin or MSYS2 on Windows, it's
inevitable that paths will sometimes contain backslashes and sometimes forward
slashes, meaning a folder (i.e. directory) divide in either case. So:
(a) When writing such a divider, always write |FOLDER_SEPARATOR|, a backslash;
(b) When testing for such a divider, call the following.

=
int Platform::is_folder_separator(inchar32_t c) {
	return ((c == '\\') || (c == '/'));
}

@h Environment variables.

= (very early code)
char *Platform::getenv(const char *name) {
	char *env = getenv(name);
	if (env == 0) {
		char value[MAX_PATH];
		if (strcmp(name, "PWD") == 0) {
			if (GetCurrentDirectoryA(MAX_PATH, value) != 0)
				_putenv_s(name, value);
		} else if (strcmp(name, "HOME") == 0) {
			if (SHGetFolderPathA(0, CSIDL_PERSONAL, 0, SHGFP_TYPE_CURRENT, value) == 0)
				_putenv_s(name, value);
		}
		env = getenv(name);
	}
	return env;
}

@h Executable location.
Fill the wide-char buffer |p| with the path to the current executable, up to
length |length|. This function is guaranteed to be called from only one
thread. Should the information be unavailable, or fail to fit into |p|,
truncate |p| to zero length. (On some platforms, the information will
always be unavailable: that doesn't mean we can't run on those platforms,
just that installation and use of Foundation-built tools is less convenient.)

=
void Platform::where_am_i(inchar32_t *p, size_t length) {
	WCHAR path[_MAX_PATH];
	DWORD result = GetModuleFileNameW(NULL, path, _MAX_PATH);
	if ((result == 0) || (result >= _MAX_PATH))
	{
		p[0] = 0;
		return;
	}

	size_t i = 0;
	while (1)
	{
		if ((i >= length) || (i >= _MAX_PATH))
		{
			p[0] = 0;
			return;
		}
		p[i] = (inchar32_t)path[i];
		if (p[i] == '\0') return;
		i++;
	}
}

@h Shell commands.

= (very early code)
/* Check the first element of the command: if it has path separators in
   it, we assume we are running one of our commands, otherwise it is a
   Unix style command. */
int Platform::Win32_is_unix_cmd(const char* cmd) {
	char stop = ' ';
	int i = 0;

	if (cmd[0] == '\"') {
		stop = '\"';
		i = 1;
	}
	while ((cmd[i] != 0) && (cmd[i] != stop)) {
		if ((cmd[i] == '/') || (cmd[i] == '\\'))
			return 0;
		i++;
	}
	return 1;
}

int Platform::system(const char *cmd) {
	char cmd_line[10*MAX_PATH];

	/* Check if the command should be executed with the Windows cmd interpreter
	   or a Unix-like shell. */
	int unix = Platform::Win32_is_unix_cmd(cmd);
	if (unix) {
		/* Some Cygwin commands cannot handle backslashes in paths. */
		int forward_slash = 0;
		if (strncmp(cmd,"pdftex ",7) == 0)
			forward_slash = 1;

		/* For a Unix shell command, escape any double quotes and backslashes. */
		char *pcl;
		const char *pc;
		strcpy(cmd_line, "sh -c \"");
		for (pc = cmd, pcl = cmd_line+strlen(cmd_line); *pc != 0; ++pc, ++pcl) {
			if (*pc == '\"') {
				*(pcl++) = '\\';
				*pcl = *pc;
			}
			else if (*pc == '\\') {
				if (forward_slash)
					*pcl = '/';
				else {
					*(pcl++) = '\\';
					*pcl = *pc;
				}
			}
			else
				*pcl = *pc;
		}
		*(pcl++) = '\"';
		*(pcl++) = 0;
	} else {
		/* Otherwise, run with the Windows command interpreter. */
		strcpy(cmd_line, "cmd /s /c \"");
		strcat(cmd_line, cmd);
		strcat(cmd_line, "\"");
	}

	STARTUPINFOA start;
	memset(&start, 0, sizeof start);
	start.cb = sizeof start;
	start.dwFlags = STARTF_USESHOWWINDOW;
	start.wShowWindow = SW_HIDE;

	PROCESS_INFORMATION process;
	if (CreateProcessA(0, cmd_line, 0, 0, FALSE, CREATE_NO_WINDOW, 0, 0, &start, &process) == 0) {
		if (unix)
			fprintf(stderr, "A Unix-like shell \"sh\" (such as that from MSYS2 or Cygwin) must be in the path.\n");
		return -1;
	}

	CloseHandle(process.hThread);
	if (WaitForSingleObject(process.hProcess, INFINITE) != WAIT_OBJECT_0) {
		CloseHandle(process.hProcess);
		return -1;
	}

	DWORD code = 10;
	GetExitCodeProcess(process.hProcess, &code);
	CloseHandle(process.hProcess);

	return (int)code;
}

@h Directory handling.

=
int Platform::mkdir(char *transcoded_pathname) {
	errno = 0;
	int rv = mkdir(transcoded_pathname);
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

@h Copying.

=
void Platform::copy_file(char *from_transcoded_pathname, char *to_transcoded_pathname) {
	CopyFile(from_transcoded_pathname, to_transcoded_pathname, FALSE);
}

@h Sync.

=
void Platform::path_add(const char* base, const char* add, char* path) {
	char last;

	strcpy(path, base);
	last = path[strlen(path) - 1];
	if ((last != '/') && (last != '\\'))
		strcat(path, "\\");
	strcat(path, add);
}

void Platform::rsync(char *transcoded_source, char *transcoded_dest) {
	char srcPath[MAX_PATH], destPath[MAX_PATH];
	WIN32_FIND_DATA findData = { 0 };

	SHCreateDirectoryExA(0, transcoded_dest, NULL);

	Platform::path_add(transcoded_dest, "*", destPath);
	HANDLE findHandle = FindFirstFileA(destPath, &findData);
	if (findHandle != INVALID_HANDLE_VALUE) {
		do {
			if ((strcmp(findData.cFileName, ".") == 0) || (strcmp(findData.cFileName, "..") == 0))
				continue;

			Platform::path_add(transcoded_source, findData.cFileName, srcPath);

			int remove = 1;
			{
				DWORD srcAttrs = GetFileAttributesA(srcPath);
				if (srcAttrs != INVALID_FILE_ATTRIBUTES) {
					if ((findData.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) == (srcAttrs & FILE_ATTRIBUTE_DIRECTORY))
						remove = 0;
				}
			}
			if (remove) {
				Platform::path_add(transcoded_dest, findData.cFileName, destPath);
				if (findData.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
					SHFILEOPSTRUCTA oper = { 0 };
					oper.wFunc = FO_DELETE;
					oper.pFrom = destPath;
					oper.fFlags = FOF_NO_UI;
					SHFileOperationA(&oper);
				}
				else DeleteFileA(destPath);
			}
		}
		while (FindNextFileA(findHandle, &findData) != 0);
		FindClose(findHandle);
	}

	Platform::path_add(transcoded_source, "*", srcPath);
	findHandle = FindFirstFileA(srcPath, &findData);
	if (findHandle != INVALID_HANDLE_VALUE) {
		do {
			if ((strcmp(findData.cFileName, ".") == 0) || (strcmp(findData.cFileName, "..") == 0))
				continue;

			Platform::path_add(transcoded_source, findData.cFileName, srcPath);
			Platform::path_add(transcoded_dest, findData.cFileName, destPath);

			if (findData.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
				CreateDirectoryA(destPath, 0);
				Platform::rsync(srcPath, destPath);
			} else {
				int needCopy = 1;
				{
					WIN32_FIND_DATA destFindData = { 0 };
					HANDLE destFindHandle = FindFirstFileA(destPath, &destFindData);
					if (destFindHandle != INVALID_HANDLE_VALUE) {
						if ((findData.nFileSizeLow == destFindData.nFileSizeLow) && (findData.nFileSizeHigh == destFindData.nFileSizeHigh)) {
							if (CompareFileTime(&(findData.ftLastWriteTime), &(destFindData.ftLastWriteTime)) == 0)
								needCopy = 0;
						}
						FindClose(destFindHandle);
					}
				}

				if (needCopy)
					CopyFileA(srcPath, destPath, 0);
			}
		}
		while (FindNextFileA(findHandle, &findData) != 0);
		FindClose(findHandle);
	}
}

@h Sleep. The Windows |Sleep| call measures time in milliseconds, whereas
POSIX |sleep| is for seconds.

=
void Platform::sleep(int seconds) {
	Sleep((DWORD)(1000*seconds));
}

@h Notifications.

= 
void Platform::notification(text_stream *text, int happy) {
}

@h Terminal setup.
The idea of this function is that if anything needs to be done to enable the
output of ANSI-standard coloured terminal output, then this function has the
chance to do it; similarly, it may need to configure itself to receive console
output with the correct locale (calling |Locales::get(CONSOLE_LOCALE)| to
find this).

=
#define WIN32CONS_RESET_MODE 1
#define WIN32CONS_RESET_OUTCP 2

int Win32_ResetConsole = 0;
DWORD Win32_ConsoleMode = 0;
UINT Win32_ConsoleOutCP = 0;

void Platform::Win32_ResetConsole(void) {
	if (Win32_ResetConsole & WIN32CONS_RESET_MODE) {
		HANDLE cons = GetStdHandle(STD_ERROR_HANDLE);
		if (cons) SetConsoleMode(cons, Win32_ConsoleMode);
	}
	if (Win32_ResetConsole & WIN32CONS_RESET_OUTCP)
		SetConsoleOutputCP(Win32_ConsoleOutCP);
}

void Platform::configure_terminal(void) {
	HANDLE cons = GetStdHandle(STD_ERROR_HANDLE);
	if (cons) {
		if (GetConsoleMode(cons, &Win32_ConsoleMode)) {
			if ((Win32_ConsoleMode & ENABLE_VIRTUAL_TERMINAL_PROCESSING) == 0) {
				if (SetConsoleMode(cons, Win32_ConsoleMode | ENABLE_VIRTUAL_TERMINAL_PROCESSING)) {
					Win32_ResetConsole |= WIN32CONS_RESET_MODE;
				}
			}
		}
	}

	Win32_ConsoleOutCP = GetConsoleOutputCP();
	UINT newCP = 0;
	int loc = Locales::get(CONSOLE_LOCALE);
	if (loc == FILE_ENCODING_ISO_STRF)
		newCP = 28591; /* ISO 8859-1 Latin */
	else if (loc == FILE_ENCODING_UTF8_STRF)
		newCP = CP_UTF8;
	if ((newCP != 0) && SetConsoleOutputCP(newCP))
		Win32_ResetConsole |= WIN32CONS_RESET_OUTCP;

	if (Win32_ResetConsole != 0) atexit(Platform::Win32_ResetConsole);
}

@h Concurrency.

= (very early code)
typedef HANDLE foundation_thread;
typedef struct Win32_Thread_Attrs
{
	SIZE_T StackSize;
}
foundation_thread_attributes;

struct Win32_Thread_Start { void *(*fn)(void *); void* arg; };

@
=
DWORD WINAPI Platform::Win32_Thread_Func(LPVOID param) {
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
	HANDLE thread = CreateThread(0, pa->StackSize, Platform::Win32_Thread_Func, start, 0, 0);
	if (thread == 0) {
		free(start);
		return 1;
	} else {
		*pt = thread;
		return 0;
	}
}

int Platform::join_thread(foundation_thread pt, void** rv) {
	return (WaitForSingleObject(pt, INFINITE) == WAIT_OBJECT_0) ? 0 : 1;
}

void Platform::init_thread(foundation_thread_attributes* pa, size_t size) {
	pa->StackSize = size;
}

size_t Platform::get_thread_stack_size(foundation_thread_attributes* pa) {
	return pa->StackSize;
}

@ This function returns the number of logical cores in the host computer --
i.e., twice the number of physical cores if there's hyperthreading. The
result is used as a guess for an appropriate number of simultaneous threads
to launch.

=
int Platform::get_core_count(void) {
	int count = 0;
	SYSTEM_INFO sysInfo;
	GetSystemInfo(&sysInfo);
	count = (int) sysInfo.dwNumberOfProcessors;

	/* Leave one core idle by default */
	if (count > 1)
		count--;

	return count;
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

@h Mutexes.

@d CREATE_MUTEX(name)
	static struct Win32_Mutex name = { INIT_ONCE_STATIC_INIT, { 0 }};
@d LOCK_MUTEX(name) {
	BOOL pending;
	InitOnceBeginInitialize(&(name.init), 0, &pending, 0);
	if (pending) {
		InitializeCriticalSection(&(name.crit));
		InitOnceComplete(&(name.init), 0, 0);
	}
	EnterCriticalSection(&(name.crit));
}
@d UNLOCK_MUTEX(name) {
	LeaveCriticalSection(&(name.crit));
}

= (very early code)
struct Win32_Mutex { INIT_ONCE init; CRITICAL_SECTION crit; };
