[Time::] Time.

Managing how we record and use the current time and date.

@h Clock.
From the local environment, we'll extract the time at which we're running.

=
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
stop it from coinciding with the Jewish Passover (a change motivated purely
by anti-Semitism). However, since they botched this tampering, it sometimes
does.

Knuth remarks that calculating Easter was almost the only algorithmic
research in the West for many centuries. Nevertheless the result is
practically a random-number generator. The one thing to be said in its
favour is that it can be computed accurately with integer arithmetic using
fairly low numbers, and this we now do.

@d CHRISTMAS_FEAST 1
@d EASTER_FEAST 2
@d NON_FEAST 3

=
int Time::feast(void) {
	int this_month = the_present->tm_mon + 1;
	int this_day = the_present->tm_mday;
	int this_year = the_present->tm_year + 1900;

	int c, y, k, i, n, j, l, m, d;
	y = this_year;
	c = y/100;
	n = y-19*(y/19);
	k = (c-17)/25;
	i = c-c/4-(c-k)/3+19*n+15;
	i = i-30*(i/30);
	i = i-(i/28)*(1-(i/28)*(29/(i+1))*((21-n)/11));
	j = y+y/4+i+2-c+c/4;
	j = j-7*(j/7);
	l = i-j;
	m = 3+(l+40)/44;
	d = l+28-31*(m/4);

	if ((this_month == m) && (this_day >= d-2) && (this_day <= d+1))
		return EASTER_FEAST; /* that is, Good Friday to Easter Monday */
	if ((this_year == 2018) && (this_month == 3) && (this_day >= 30))
		return EASTER_FEAST; /* Easter Sunday falls on 1 April in 2018 */

	if ((this_month == 12) && (this_day >= 25))
		return CHRISTMAS_FEAST; /* that is, Christmas Day to New Year's Eve */

	return NON_FEAST;
}
