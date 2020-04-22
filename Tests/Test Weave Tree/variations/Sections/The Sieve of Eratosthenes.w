The Sieve of Eratosthenes.

A fairly fast way to determine if small numbers are prime, given storage.

@h Storage.
This technique, still essentially the best sieve for finding prime
numbers, is attributed to Eratosthenes of Cyrene and dates from the 200s BC.
Since composite numbers are exactly those numbers which are multiples of
something, the idea is to remove everything which is a multiple: whatever
is left, must be prime.

This is very fast (and can be done more quickly than the implementation
below), but (a) uses storage to hold the sieve, and (b) has to start right
back at 2 - so it can't efficiently test just, say, the eight-digit numbers
for primality.

=
int still_in_sieve[RANGE + 1];
int sieve_performed = FALSE;

@h Primality.
We provide this as a function which determines whether a number is prime:

@d TRUE 1
@d FALSE 0

=
int isprime(int n) {
	if (n <= 1) return FALSE;
	if (n > RANGE) { printf("Out of range!\n"); return FALSE; }
	if (!sieve_performed) @<Perform the sieve@>;
	return still_in_sieve[n];
}

@ We save a little time by noting that if a number up to |RANGE| is composite
then one of its factors must be smaller than the square root of |RANGE|. Thus,
in a sieve of size 10000, one only needs to remove multiples of 2 up to 100,
for example.

@<Perform the sieve@> =
	@<Start with all numbers from 2 upwards in the sieve@>;
	for (int n=2; n*n <= RANGE; n++)
		if (still_in_sieve[n])
			@<Shake out multiples of n@>;
	sieve_performed = TRUE;

@<Start with all numbers from 2 upwards in the sieve@> =
	still_in_sieve[1] = FALSE;
	for (int n=2; n <= RANGE; n++) still_in_sieve[n] = TRUE;

@<Shake out multiples of n@> =
	for (int m= n+n; m <= RANGE; m += n) still_in_sieve[m] = FALSE;
