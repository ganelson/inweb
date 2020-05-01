Summing Primes.

Here we verify the conjecture for small numbers.

@ On 7 June 1742, Christian Goldbach wrote a letter from Moscow to Leonhard
Euler in Berlin making "eine conjecture hazardiren" that every even number
greater than $2$ can be written as a sum of two primes.[1] Euler did not
know if this was true, and nor does anyone else.
= (figure Letter.jpg at height 10cm)
Goldbach, a professor at St Petersburg and tutor to Tsar Peter II, wrote in
several languages in an elegant cursive script, and was much valued as a
letter-writer, though his reputation stands less high today.[2] All the same,
the general belief now is that primes are just plentiful enough, and just
evenly-enough spread, for Goldbach to be right. It is known that:

(a) every even number is a sum of at most six primes (Ramaré, 1995), and
(b) every odd number is a sum of at most five (Tao, 2012).

[1] "Greater than 2" is our later proviso: Goldbach needed no such exception
because he considered 1 a prime number, as was normal then, and was sometimes
said as late as the early twentieth century.

[2] Goldbach, almost exactly a contemporary of Voltaire, was a good citizen
of the great age of Enlightenment letter-writing. He and Euler exchanged
scholarly letters for over thirty years, not something Euler would have
kept up with a duffer. Goldbach was also not, as is sometimes said, a lawyer.
See: http://mathshistory.st-andrews.ac.uk/Biographies/Goldbach.html.
An edited transcription of the letter is at: http://eulerarchive.maa.org//correspondence/letters/OO0765.pdf

@ Computer verification has been made up to around $10^{18}$, but by rather
better methods than the one we use here. We will only go up to:

@d RANGE 100

=
#include <stdio.h>

int main(int argc, char *argv[]) {
	for (int i=4; i<RANGE; i=i+2) /* stepping in twos to stay even */
		@<Solve Goldbach's conjecture for i@>;
}

@ This ought to print:
= (text as ConsoleText)
	$ goldbach/Tangled/goldbach
	4 = 2+2
	6 = 3+3
	8 = 3+5
	10 = 3+7 = 5+5
	12 = 5+7
	14 = 3+11 = 7+7
	...
=
We'll print each different pair of primes adding up to $i$. We
only check in the range $2 \leq j \leq i/2$ to avoid counting pairs
twice over (thus $8 = 3+5 = 5+3$, but that's hardly two different ways).

@<Solve Goldbach's conjecture for i@> =
	printf("%d", i);
	for (int j=2; j<=i/2; j++)
		if ((isprime(j)) && (isprime(i-j)))
			printf(" = %d+%d", j, i-j);
	printf("\n");
