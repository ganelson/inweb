#line 25 "inweb/Examples/twinprimes.c.w"
#include <stdio.h>

#define RANGE 100
#define TRUE 1
#define FALSE 0
#line 27 "inweb/Examples/twinprimes.c.w"
int  main(int argc, char *argv[]) ;
#line 48 "inweb/Examples/twinprimes.c.w"
int  isprime(int n) ;

#line 26 "inweb/Examples/twinprimes.c.w"

int main(int argc, char *argv[]) {
	for (int i=1; i<RANGE; i++)
		
{
#line 33 "inweb/Examples/twinprimes.c.w"
	if ((isprime(i)) && (isprime(i+2)))
		printf("%d and %d\n", i, i+2);

}
#line 29 "inweb/Examples/twinprimes.c.w"
;
}

#line 48 "inweb/Examples/twinprimes.c.w"
int isprime(int n) {
	if (n <= 1) return FALSE;
	for (int m = 2; m*m <= n; m++)
		if (n % m == 0)
			return FALSE;
	return TRUE;
}

