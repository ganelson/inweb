[Time::] Time.

Managing how we record and use the current time and date.

@h Clock.
From the local environment, we'll extract the time at which we're running.

=
time_t right_now;
struct tm *the_present = NULL;
int fix_time_mode = FALSE;

void Time::begin(void) {
	time_t right_now = time(NULL);
	the_present = localtime(&right_now);
	fix_time_mode = FALSE;
}

@ The command line option |-fixtime| causes any tool compiled with Foundation
to fix the date as 11 a.m. on 28 March 2016, which is Inform's birthday. This
makes it easier to automate testing, since we can compare output generated
in one session with output generated another, even though that was on two
different dates.

=
void Time::fix(void) {
	struct tm start;
	start.tm_sec = 0; start.tm_min = 0; start.tm_hour = 11;
	start.tm_mday = 28; start.tm_mon = 3; start.tm_year = 116; start.tm_isdst = -1;
	time_t pretend_time = mktime(&start);
	the_present = localtime(&pretend_time);
	fix_time_mode = TRUE;
}

int Time::fixed(void) {
	return fix_time_mode;
}

@h Calendrical.
The date of Easter depends on who and where you are. Inform's notional home
is England. Following League of Nations advice in 1926, Easter is legally
celebrated in England on the Sunday after the second Saturday in April, unless
the Church requests otherwise. Since the Church has made this request every
year since 1926 and shows no sign of coming around, we instead have to turn to
church law, which is where it becomes complicated. There are five main
algorithms ordained by major Christian churches: Catholic, continental
European Protestant, Church of England, Eastern and Russian Orthodox. The
first three always agree on the date, but usually disagree with the last
two. The two eastern algorithms only disagree with each other once or twice
a century, but the usual result has been riots with significant loss of life.

The official Church of England algorithm is a clumsy one adopted during the
reign of George II. It was then thought important to use a non-Catholic
method of calculation even though the same answer was required. We'll
instead follow the algorithm of J.-M. Oudin, first published in the
Bulletin astronomique in 1940, as adapted by the US Naval Observatory.
Oudin corrected a small mistake in the calculation by Gauss (1800) of the
Allgemeiner Reichskalender (1776) which reconciled Lutheran Easter with
Gregorian, which in turn followed the reforms of Clavius et al. (1582),
which in turn... and so on. See Leofranc Holford-Strevens, "The History of
Time" (Oxford, 2005).

In principle we calculate the first Sunday after the first ecclesiastical
moon that occurs on or after March 21. An "ecclesiastical moon" is one as
seen from a longitude near Rome, except that the ratios used to adjust lunar and
solar calendars are not quite right. The result is also tampered with to
stop Easter from coinciding with the pagan anniversary of the founding of
Rome (for the convenience of people living in the Vatican) and also to
stop it from coinciding with Passover (because of anti-Semitism). However,
since they botched this tampering, it sometimes does.

Knuth remarks that calculating Easter was almost the only algorithmic
research in the West for many centuries. Nevertheless the result is
practically a random-number generator. The one thing to be said in its
favour is that it can be computed accurately with integer arithmetic using
fairly low numbers, and this we now do.

=
void Time::easter(int year, int *d, int *m) {
	int c, y, k, i, n, j, l;
	y = year;
	c = y/100;
	n = y-19*(y/19);
	k = (c-17)/25;
	i = c-c/4-(c-k)/3+19*n+15;
	i = i-30*(i/30);
	i = i-(i/28)*(1-(i/28)*(29/(i+1))*((21-n)/11));
	j = y+y/4+i+2-c+c/4;
	j = j-7*(j/7);
	l = i-j;
	*m = 3+(l+40)/44;
	*d = l+28-31*(*m/4);
}

@ And we can use this to tell if the season's merry:

@d CHRISTMAS_FEAST 1
@d EASTER_FEAST 2
@d NON_FEAST 3

=
int Time::feast(void) {
	int this_month = the_present->tm_mon + 1;
	int this_day = the_present->tm_mday;
	int this_year = the_present->tm_year + 1900;

	int m, d;
	Time::easter(this_year, &m, &d);

	if ((this_month == m) && (this_day >= d-2) && (this_day <= d+1))
		return EASTER_FEAST; /* that is, Good Friday to Easter Monday */
	if ((this_year == 2018) && (this_month == 3) && (this_day >= 30))
		return EASTER_FEAST; /* Easter Sunday falls on 1 April in 2018 */

	if ((this_month == 12) && (this_day >= 25))
		return CHRISTMAS_FEAST; /* that is, Christmas Day to New Year's Eve */

	return NON_FEAST;
}

@h Stopwatch timings.
The following provides a sort of hierarchical stopwatch. In principle it
could time anything (though not very accurately), but it's mainly intended
for monitoring how long programs internally work, since it reads time from
the |clock()| (i.e., how much CPU time the current process has taken) rather
than from the actual time of day.

=
typedef struct stopwatch_timer {
	int running; /* set if this has been started but not stopped */
	struct text_stream *event;
	clock_t start_time;
	clock_t end_time;
	int time_taken; /* measured in centiseconds of CPU time */
	linked_list *stages_chronological; /* of |stopwatch_timer| */
	linked_list *stages_sorted; /* of |stopwatch_timer| */
	CLASS_DEFINITION
} stopwatch_timer;

@ If |within| is not null, it must be another stopwatch which is also running;
the idea is that the new stopwatch is to time a sub-task of the main task which
|within| is timing.

=
stopwatch_timer *Time::start_stopwatch(stopwatch_timer *within, text_stream *name) {
	stopwatch_timer *st = CREATE(stopwatch_timer);
	st->event = Str::duplicate(name);
	st->start_time = clock();
	st->end_time = st->start_time;
	st->time_taken = 0;
	st->stages_chronological = NEW_LINKED_LIST(stopwatch_timer);
	st->stages_sorted = NULL;
	st->running = TRUE;
	if (within) {
		if (within->running == FALSE)
			internal_error("stopwatch started in event not under way");
		ADD_TO_LINKED_LIST(st, stopwatch_timer, within->stages_chronological);
	}
	return st;
}

@ Every started stopwatch must be stopped in order to register time having
been used. Once this is done

=
int Time::stop_stopwatch(stopwatch_timer *st) {
	if (st->running == FALSE) internal_error("already stopped");
	st->running = FALSE;
	st->end_time = clock();
	st->time_taken += (((int) (st->end_time)) - ((int) (st->start_time))) / (CLOCKS_PER_SEC/100);
	int N = LinkedLists::len(st->stages_chronological);
	if (N > 0) @<Sort the subtasks in descreasing order of how much time they took@>;
	return st->time_taken;
}

@<Sort the subtasks in descreasing order of how much time they took@> =
	st->stages_sorted = NEW_LINKED_LIST(stopwatch_timer);
	stopwatch_timer **as_array = (stopwatch_timer **)
		(Memory::calloc(N, sizeof(stopwatch_timer *), ARRAY_SORTING_MREASON));
	stopwatch_timer *sst; int i = 0;
	LOOP_OVER_LINKED_LIST(sst, stopwatch_timer, st->stages_chronological)
		as_array[i++] = sst;
	qsort(as_array, (size_t) N, sizeof(stopwatch_timer *), Time::compare_watches);
	for (i=0; i<N; i++)
		ADD_TO_LINKED_LIST(as_array[i], stopwatch_timer, st->stages_sorted);
	Memory::I7_array_free(as_array,
		ARRAY_SORTING_MREASON, N, sizeof(stopwatch_timer *));

@ This sorts first by elapsed time, then by event name in alphabetical order:

=
int Time::compare_watches(const void *w1, const void *w2) {
	const stopwatch_timer **st1 = (const stopwatch_timer **) w1;
	const stopwatch_timer **st2 = (const stopwatch_timer **) w2;
	if ((*st1 == NULL) || (*st2 == NULL))
		internal_error("Disaster while sorting stopwatch timings");
	int t1 = (*st1)->time_taken, t2 = (*st2)->time_taken;
	if (t1 > t2) return -1;
	if (t1 < t2) return 1;
	return Str::cmp((*st1)->event, (*st2)->event);
}

@ Once started and then stopped, a stopwatch can be "resumed", provided it
is then stopped again. The elapsed time is accumulated.

=
void Time::resume_stopwatch(stopwatch_timer *st) {
	if (st->running) internal_error("already running");
	st->running = TRUE;
	st->start_time = clock();
	st->end_time = st->start_time;
}

@ All of which enables a neat hierarchical printout. The task is timed to
an accuracy of 1/1000th of the |total| supplied, and sub-tasks taking less
than that are omitted from the log.

=
void Time::log_timing(stopwatch_timer *st, int total) {
	if (st) {
		int N = 1000*st->time_taken/total;
		if (N > 0) {
			LOG("%3d.%d%% in %S\n", N/10, N%10, st->event);
			LOG_INDENT;
			int T = 0, no_details = 0;
			if (st->stages_sorted) {
				stopwatch_timer *sst;
				LOOP_OVER_LINKED_LIST(sst, stopwatch_timer, st->stages_sorted) {
					no_details++;
					T += sst->time_taken;
					Time::log_timing(sst, total);
				}
			}
			if (no_details > 0) {
				int M = N - 1000*T/total;
				if (M > 0) LOG("%3d.%d%% not specifically accounted for\n", M/10, M%10);
			}
			LOG_OUTDENT;
		}
	}
}
