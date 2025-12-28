begin
file: colony.inweb
    Colony {
    	member: "twinprimes" at "twinprimes.c.w"
    	member: "perl" at "perl.pl.w"
    	member: "plain" at "plain.txt.w"
    	member: "hellow" at "hellow.c.w"
    	member: "exhaustive" at "exhaustive.c.w"
    	member: "empty" at "empty.c.w"
    	member: "conditional" at "conditional.c.w"
    }

file: colony.rmscript
    # Colonial README file

    Member | Title | Current version | Build date
    ------ | ----- | --------------- | ----------
    {repeat with: W in: {list-of-webs}}
    {W} | {metadata: Title of: {W}} | {metadata: Semantic Version Number of: {W}} | {metadata: Build Date of: {W}}
    {end-repeat}

file: conditional.c.w
    Title: hellow
    Author: Graham Nelson
    Purpose: A minimal example of a C program written for inweb.
    Language: C

    @ =
    #include <stdio.h>

    int main(int argc, char *argv[]) {
    	printf("Hello world!\n");
    }

    @ ^"ifdef-PLATFORM_WINDOWS"

    @d PEACH 1
    @e A_COM from 1
    @e B_COM
    @e C_COM

    =
    #include "nonexistent.h"

    typedef struct bong {
    	int f;
    } bong;

    void banana(int n) {
    }

    @ ^"ifndef-PLATFORM_WINDOWS" ^"ifdef-POSIX"

    =
    #include "existent.h"

    typedef struct bong {
    	unsigned int f;
    } bong;

file: empty.c.w
    Title: test
    Author: Graham Nelson
    Purpose: A minimal example of a C program written for inweb.
    Language: C

    @ Blah. Lorum.
    Ipsum. But |identifier| as well.

    	|Green.|
    	|Blue.|

    is my essential palette.

file: exhaustive.c.w
    Title: The Inweb Syntax Exhausted
    Author: Graham Nelson
    Purpose: Some of everything you can write in this syntax.
    Language: C

    @ A regular paragraph begins here,
    and continues here.

    @ ^"Cosmopolitan" ^"Banal"
    This paragraph has two tags.

    >> Also a quotation, which is curiously structured like this,
    >> continuing thus.

    @h Subheading here. This is now text placed
    under that subheading.

    @ Some definitions:

    @d ALPHA 1
    @d BETA_GAMMA 201 /* one more than 200 */
    @d DELTA 200
    	+ 300
    	+ more_delta
    @define EPSILON ALPHA
    @default LAMBDA 10

    @d MU printf("mu");

    @e X_FAM from 1
    @e Y_FAM
    @e Z_FAM
    @enum X_ALT from 100
    @e Y_ALT

    @ Some code:

    @d RANGE 100

    =
    #include <stdio.h>

    int main(int argc, char *argv[]) {
    	for (int i=1; i<RANGE; i++)
    		@<Test for twin prime at i@>;
    }

    @<Test for twin prime at i@> =
    	if ((isprime(i)) && (isprime(i+2)))
    		printf("%d and %d\n", i, i+2);

    @ Let's have some extracts now.

    = (text)
    This is not code, but an
    extract spanning two lines.
    =

    = (hyperlinked text)
    This is //hyperlinked//, but still an
    extract spanning two lines.
    =

    = (undisplayed text)
    This is undisplayed, but still an
    extract spanning two lines.
    =

    = (hyperlinked undisplayed text)
    This is //hyperlinked// and undisplayed, but still an
    extract spanning two lines.
    =

    = (text to something)
    This is not code, but an
    extract spanning two lines.
    =

    = (text as code)
    int example_not_in_program(void) {
    	return 0;
    }
    =

    = (text as Perl)
    # Here's some Perl.
    my $var = "22";
    =

    = (text from associated/elsewhere.txt)

    = (text from associated/elsewhere.txt as code)

    = (text from associated/elsewhere.txt as Perl)

    @ And now some insertions.

    = (html somefile.html)
    = (figure somefile.jpg)
    = (audio somefile.mp3)
    = (video somefile.m4v)
    = (download whatever/else.mp3)
    = (download whatever/else.mp3 "Some text")

    = (carousel "Phase I")
    This is some text about Phase I.
    = (carousel "Phase II" above)
    This one has the caption above.
    = (carousel "Phase III" below)
    This one has the caption below.
    = (carousel)
    No caption at all this time.
    = (carousel end)

file: hellow.c.w
    Title: hellow
    Author: Graham Nelson
    Purpose: A minimal example of a C program written for inweb.
    Language: C

    @ =
    #include <stdio.h>

    int main(int argc, char *argv[]) {
    	printf("Hello world!\n");
    }

file: perl.pl.w
    Title: perl
    Author: Graham Nelson
    Purpose: A test Perl script for inweb.
    Language: Perl

    @ =
    print recolour("Santa likes red and green socks.\n");

    @ =
    sub recolour {
    	my $text = $_[0];
    	@<Change the hues@>;
    	return $text;
    }

    @<Change the hues@> =
    	$text =~ s/red/blue/;
    	$text =~ s/green/purple/;

file: plain.txt.w
    Title: plain
    Author: Graham Nelson
    Purpose: Tangling and weaving some text file.
    Language: Plain Text

    @ =
    @<Titling@>
    No one would have believed in the last years of the
    nineteenth century that this world was being watched keenly
    and closely by intelligences greater than man's and yet as
    mortal as his own; that as men busied themselves about their
    various concerns they were scrutinised and studied, perhaps
    almost as narrowly as a man with a microscope might scrutinise
    the transient creatures that swarm and multiply in a drop of water.

    @<Titling@> =
    Book One
    The Coming of the Martians

    @ =
    With infinite complacency men went to and fro over this globe about
    their little affairs, serene in their assurance of their empire over matter. 

file: twinprimes.c.w
    Title: The Twin Primes Conjecture
    Author: Graham Nelson
    Purpose: This example of using inweb is a whole web in a single short file, to look for twin primes, a classic problem in number theory.
    Language: C

    @h The conjecture.
    It is widely believed that there are an infinite number of twin primes, that
    is, prime numbers occurring in pairs different by 2. Twins are known to exist
    at least as far out as $10^{388,342}$ (as of 2016), and there are infinitely
    many pairs of primes closer together than about 250 (Zhang, 2013; Tao, Maynard,
    and many others, 2014).

    This program finds a few small pairs of twins, by the simplest method possible,
    and should print output like so:
    = (text)
    	3 and 5
    	5 and 7
    	11 and 13
    	...
    =

    @d RANGE 100 /* the upper limit to the numbers we will consider */

    =
    #include <stdio.h>

    int main(int argc, char *argv[]) {
    	for (int i=1; i<RANGE; i++)
    		@<Test for twin prime at i@>;
    }

    @<Test for twin prime at i@> =
    	if ((isprime(i)) && (isprime(i+2)))
    		printf("%d and %d\n", i, i+2);

    @h Primality.
    This simple and slow test tries to divide by every whole number at least
    2 and up to the square root: if none divide exactly, the number is prime.
    A common error with this algorithm is to check where $m^2 < n$, rather
    than $m^2 \leq n$, thus wrongly considering 4, 9, 25, 49, ... as prime:
    Cambridge folklore has it that this bug occurred on the first computation
    of the EDSAC computer on 6 May 1949.

    @d TRUE 1
    @d FALSE 0

    =
    int isprime(int n) {
    	if (n <= 1) return FALSE;
    	for (int m = 2; m*m <= n; m++)
    		if (n % m == 0)
    			return FALSE;
    	return TRUE;
    }

end
