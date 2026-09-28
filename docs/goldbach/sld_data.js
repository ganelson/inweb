document.addEventListener('DOMContentLoaded', function () {
	const scout = new SeekLocateDisplay({
	  container: '#docs-search',
	  placeholder: 'Search The Goldbach Conjecture...',
	  pages: 
[ {
    "url": "smpr.html",
    "title": "Summing Primes",
    "sections": [ {
        "id": "SP1",
        "heading": "\u00a71",
        "text": "On 7 June 1742, Christian Goldbach wrote a letter from Moscow to Leonhard\nEuler in Berlin making \"eine conjecture hazardiren\" that every even number\ngreater than 2 can be written as a sum of two primes.[1] Euler did not\nknow if this was true, and nor does anyone else.\n\n[Image: Goldbach's letter]\n\n\nGoldbach, a professor at St Petersburg and tutor to Tsar Peter II, wrote in\nseveral languages in an elegant cursive script, and was much valued as a\nletter-writer, though his reputation stands less high today.[2] All the same,\nthe general belief now is that primes are just plentiful enough, and just\nevenly-enough spread, for Goldbach to be right. It is known that:\n\n\n\n    * every even number is a sum of at most six primes (Ramar\u00e9, 1995), and\n\n    * every odd number is a sum of at most five (Tao, 2012).\n\n[1] \"Greater than 2\" is our later proviso: Goldbach needed no such exception\nbecause he considered 1 a prime number, as was normal then, and was sometimes\nsaid as late as the early twentieth century.\n\n[2] Goldbach, almost exactly a contemporary of Voltaire, was a good citizen\nof the great age of Enlightenment letter-writing. He and Euler exchanged\nscholarly letters for over thirty years, not something Euler would have\nkept up with a duffer. Goldbach was also\nnot, as is sometimes said, a lawyer.\nAn edited transcription of the letter is online here.\n\n\n"
    }, {
        "id": "SP2",
        "heading": "\u00a72",
        "text": "Computer verification has been made up to around 10^{18}, but by rather\nbetter methods than the one we use here. We will only go up to:\n\n\n#include <stdio.h>\n\nint main(int argc, char *argv[]) {\n\tfor (int i=4; i<RANGE; i=i+2) \nstepping in twos to stay even\n\t\t\n{{Solve Goldbach's conjecture for i}}\n;\n}\n"
    }, {
        "id": "SP2_1",
        "heading": "\u00a72.1",
        "text": "This ought to print:\n\n\t$ goldbach/Tangled/goldbach\n\t4 = 2+2\n\t6 = 3+3\n\t8 = 3+5\n\t10 = 3+7 = 5+5\n\t12 = 5+7\n\t14 = 3+11 = 7+7\n\t...\nWe'll print each different pair of primes adding up to i. We\nonly check in the range 2 <= j <= i/2 to avoid counting pairs\ntwice over (thus 8 = 3+5 = 5+3, but that's hardly two different ways).\n\n\n\tprintf(\"%d\", i);\n\tfor (int j=2; j<=i/2; j++)\n\t\tif ((isprime(j)) && (isprime(i-j)))\n\t\t\tprintf(\" = %d+%d\", j, i-j);\n\tprintf(\"\\n\");\n"
    } ]
}, {
    "url": "tsoe.html",
    "title": "The Sieve of Eratosthenes",
    "sections": [ {
        "id": "SP1",
        "heading": "\u00a71. Storage",
        "text": "This technique, still essentially the best sieve for finding prime\nnumbers, is attributed to Eratosthenes of Cyrene and dates from the 200s BC.\nSince composite numbers are exactly those numbers which are multiples of\nsomething, the idea is to remove everything which is a multiple: whatever\nis left, must be prime.\n\nThis is very fast (and can be done more quickly than the implementation\nbelow), but (a) uses storage to hold the sieve, and (b) has to start right\nback at 2 - so it can't efficiently test just, say, the eight-digit numbers\nfor primality.\n\n\nint still_in_sieve[RANGE + 1];\nint sieve_performed = FALSE;\n"
    }, {
        "id": "SP2",
        "heading": "\u00a72. Primality",
        "text": "We provide this as a function which determines whether a number is prime:\n\n\nint isprime(int n) {\n\tif (n <= 1) return FALSE;\n\tif (n > RANGE) { printf(\"Out of range!\\n\"); return FALSE; }\n\tif (!sieve_performed) \n{{Perform the sieve}}\n;\n\treturn still_in_sieve[n];\n}\n"
    }, {
        "id": "SP2_1",
        "heading": "\u00a72.1 (under Primality)",
        "text": "We save a little time by noting that if a number up to RANGE is composite\nthen one of its factors must be smaller than the square root of RANGE. Thus,\nin a sieve of size 10000, one only needs to remove multiples of 2 up to 100,\nfor example.\n\n\n\t\n{{Start with all numbers from 2 upwards in the sieve}}\n;\n\tfor (int n=2; n*n <= RANGE; n++)\n\t\tif (still_in_sieve[n])\n\t\t\t\n{{Shake out multiples of n}}\n;\n\tsieve_performed = TRUE;\n"
    }, {
        "id": "SP2_1_1",
        "heading": "\u00a72.1.1 (under Primality)",
        "text": "\tstill_in_sieve[1] = FALSE;\n\tfor (int n=2; n <= RANGE; n++) still_in_sieve[n] = TRUE;\n"
    }, {
        "id": "SP2_1_2",
        "heading": "\u00a72.1.2 (under Primality)",
        "text": "\tfor (int m= n+n; m <= RANGE; m += n) still_in_sieve[m] = FALSE;\n"
    } ]
} ],
	  onNavigate: function (url) {
		window.location.href = url;
	  }
	});
}); // end DOMContentLoaded

