The Goldbach Conjecture.

Here we verify the conjecture for small numbers.

@h The conjecture.
So, this is a program to see if even numbers from 4 to 100 can all be written
as a sum of two primes. Christian Goldbach asked Euler in 1742 if every even
number greater than 2 can be written this way. This remains open, though
every even number is a sum of at most six primes (Ramaré, 1995) and every
odd number is a sum of at most five (Tao, 2012).

[[Letter.jpg height 10cm]]

Computer verification has been made up to around $10^{18}$, but by rather better
methods.

@d RANGE 100

=
#include <stdio.h>

int main(int argc, char *argv[]) {
	for (int i=4; i<RANGE; i=i+2)
		@<Solve Goldbach's conjecture for i@>;
}

@ This ought to print:

= (not code)
	4 = 2+2
	6 = 3+3
	8 = 3+5
	10 = 3+7 5+5
	12 = 5+7
	14 = 3+11 7+7
	...

@ We'll print each different pair of primes adding up to i. We
only check in the range $2 \leq j \leq i/2$ to avoid counting pairs
twice over (thus $8 = 3+5 = 5+3$, but that's hardly two different ways).

@<Solve Goldbach's conjecture for i@> =
	printf("%d =", i);
	for (int j=2; j<=i/2; j++)
		if ((isprime(j)) && (isprime(i-j)))
			printf(" %d+%d", j, i-j);
	printf("\n");
