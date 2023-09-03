[Main::] Reporting the Date.

This is really the whole Eastertide program, in a single section.

@ This utility, or perhaps futility, is a minimal example of the use of the
Foundation library, which comes supplied with //inweb// for the benefit
of C programs wanting to use it. We will do everything in an unnecessarily
fancy way, just to give the tires a kick.

Any program using Foundation must define this constant:

@d PROGRAM_NAME "eastertide"

@ The |main| routine must start and end Foundation, and is not allowed to
do much after that; but it is allowed to ask if error messages were generated,
so that it can return conventional Unix return values 0 (okay) or 1 (not okay).

=
int main(int argc, char *argv[]) {
	Foundation::start();

	@<Read the command line@>;
	@<Write the report to the console@>;

	Foundation::end();
	if (Errors::have_occurred()) return 1;
	return 0;
}

@ The general scheme here is that we read the command line to work out which
the user is interested in, and store those in memory; but eventually we will
actually report on them, thus. |STDOUT| is the "text stream" for standard
output, i.e., writing to it will print to the Terminal or similar console.

@<Write the report to the console@> =
	Main::report_on_years(STDOUT);

@ All this program does is to print the date of Easter on any years requested,
but we'll give it some command-line options anyway. Foundation will add also
|-help| and a few others to the mix.

@e CALENDAR_FILE_CLSW

@e QUALIFYING_CLSG
@e VERBOSE_CLSW
@e AMERICAN_CLSW

@<Read the command line@> =
	CommandLine::declare_heading(
		U"eastertide: an Easter date calculator\n\n"
		U"usage: eastertide [OPTIONS] year1 year2 ...\n");

	CommandLine::declare_switch(CALENDAR_FILE_CLSW, U"calendar-file", 2,
		U"specify file X as a list of year requests, one per line");

	CommandLine::begin_group(QUALIFYING_CLSG, I"for qualifying the output");
	CommandLine::declare_boolean_switch(VERBOSE_CLSW, U"verbose", 1,
		U"print output verbosely", FALSE);
	CommandLine::declare_boolean_switch(AMERICAN_CLSW, U"american", 1,
		U"print dates in American MM/DD format", FALSE);
	CommandLine::end_group();
	CommandLine::read(argc, argv, NULL, &Main::switch, &Main::bareword);

@ That results in dialogue like the following:
= (text as ConsoleText)
	$ eastertide 2020
	12/4/2020
	$ eastertide -help
	eastertide: an Easter date calculator

	usage: eastertide [OPTIONS] year1 year2 ...

	-calendar-file X    specify file X as a list of year requests, one per line

	for qualifying the output:
	  -american         print dates in American MM/DD format (default is -no-american)
	  -verbose          print output verbosely (default is -no-verbose)

	-at X               specify that this tool is installed at X
	-crash              intentionally crash on internal errors, for backtracing
	-fixtime            pretend the time is 11 a.m. on 28 March 2016 for testing
	-help               print this help information
	-log X              write the debugging log to include diagnostics on X
	-version            print out version number
	$ eastertide -verbose 2021 2022
	Easter in 2021 falls on 4/4.
	Easter in 2022 falls on 17/4.
	$ eastertide 1496
	eastertide: Gregorian calendar only valid from 1582
	$ eastertide 1685 1750
	22/4/1685
	29/3/1750
	$ eastertide -calendar-file cal.txt 
	eastertide: cal.txt, line 2: not a year: '1791b'
	15/4/1770
	15/4/1827

@ So let's get back to how this is done. The Foundation function //CommandLine::read//
calls our function |Main::switch| when any of our three switches is used
(we don't need to handle the ones Foundation added, only our own); and
|Main::bareword| for any other words given on the command line. For example,
= (text as ConsoleText)
	$ eastertide -american -calendar-file cal.txt 1982 2007 
=
...results in two calls to |Main::switch|, then two to |Main::bareword|.

=
int verbose_mode = FALSE;
int american_mode = FALSE;

void Main::bareword(int id, text_stream *arg, void *state) {
	Main::request(arg, NULL);
}

void Main::switch(int id, int val, text_stream *arg, void *state) {
	switch (id) {
		case VERBOSE_CLSW: verbose_mode = val; break;
		case AMERICAN_CLSW: american_mode = val; break;
		case CALENDAR_FILE_CLSW: @<Process calendar file@>; break;
	}
}

@ We will read in the calendar file as soon as it is mentioned:

@<Process calendar file@> =
	filename *F = Filenames::from_text(arg);
	TextFiles::read(F, FALSE, "can't open calendar file",
		TRUE, Main::calendar_line, NULL, NULL);

@ To make this a little more gratuitous, we'll give calendar files some
syntax. The following function is called on each line in turn; we're going
to trim white space, ignore blank lines, and also ignore any line beginning
withn a |#| as being a comment.

=
void Main::calendar_line(text_stream *line, text_file_position *tfp, void *state) {
	Str::trim_white_space(line);
	if (Str::len(line) == 0) return;
	if (Str::get_first_char(line) == '#') return;
	Main::request(line, tfp);
}

@ And with that done, we can process a request for a year, which comes from
either the command lihe (in which case |tfp| here is null), or from the
calendar file (in which case it remembers the filename and line number).

=
void Main::request(text_stream *year, text_file_position *tfp) {
	int bad_digit = FALSE;
	LOOP_THROUGH_TEXT(pos, year)
		if (Characters::isdigit(Str::get(pos)) == FALSE)
			bad_digit = TRUE;
	if (bad_digit) {
		TEMPORARY_TEXT(err);
		WRITE_TO(err, "not a year: '%S'", year);
		Errors::in_text_file_S(err, tfp);
		return;
	}
	int Y = Str::atoi(year, 0);
	if (Y < 1582) {
		Errors::in_text_file("Gregorian calendar only valid from 1582", tfp);
		return;
	}
	Main::new_year(Y);
}

@ Now it's time to actually store a request. There are many simpler ways to
do this, but we want to demonstrate Foundation's objects system in action,
so we'll wrap each year supplied in an object. First, we have to define an
ID constant for this new class of object, and use a macro which causes
Foundation to generate the necessary handling functions:

@e year_request_MT

=
ALLOCATE_INDIVIDUALLY(year_request)

@ Now we should define the rather unnecessary structure itself, and then
a sort of constructor function. We won't need a destructor: we will never
destroy the years.

=
typedef struct year_request {
	int year;
	MEMORY_MANAGEMENT
} year_request;

year_request *Main::new_year(int Y) {
	year_request *YR = CREATE(year_request);
	YR->year = Y;
	return YR;
}

@ We can't spin this out much longer, though... This is the actually
functional part of the program, and even so, it only calls a routine
in Foundation. (See //Time::easter//.)

=
void Main::report_on_years(text_stream *OUT) {
	year_request *YR;
	LOOP_OVER(YR, year_request) {
		int d, m;
		Time::easter(YR->year, &d, &m);
		if (american_mode) { int x = d; d = m; m = x; }
		if (verbose_mode) WRITE("Easter in %d falls on %d/%d.\n", YR->year, d, m);
		else WRITE("%d/%d/%d\n", d, m, YR->year);
	}
}
