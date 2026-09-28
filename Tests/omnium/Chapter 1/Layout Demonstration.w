Layout Demonstration.

This section exercises paragraph structure, direct notations for inserted
gadgets, and footnotes.

@h Disclaimer.
The content of this web is essentially meaningless. It exists only to test
the renderers.

@{- This is a web comment, and should not be tangled or woven. @-}

@h Named paragraph.
This paragraph has a name, and is usually rendered with a modest subheading.[1]
There is very little else to it.[2]

[1] Also two footnotes.

[2] Save for the formula $n\mapsto 3n + 1$.

@ This paragraph is anonymous, and will contain some definitions.

@define ONE 1
@d MULTIPLE 3
@default MULTIPLE 10
@e RED_COLOUR from 1
@e GREEN_COLOUR
@e BLUE_COLOUR

@ The trivial function at //#A// implements the famous iteration of
Lothar Collatz (1910-1990). The use of `MULTIPLE` at //#B// triples and adds 1.

=
int collatz(int x) {            /* A */
	@<Print out x@>
	if (x % 2 == 0) return x/2;
	return MULTIPLE*x + 1;      /* B */
}

@ A named holon appears next. This one appears after some commentary, but
that is not obligatory, as the next will show.

@<Print out x@> =
	printf("x = %d\n", x);		/* `x` here is what we called $n$ above */
	@=sleep(1);@>				// that was done with a verbatim splice

@<Print out x@> +=
	print("x is still %d\n", x);

@h Another named paragraph.
Note the duplicate label here: the link //#A// goes to the one in this function.

=
int lothar(int n) { /* A */
	return collatz(n);
}

@h Gadgetry.
This uses notation for insertions by hand, so to speak, rather than via a
Markdown extension, so the following involves non-commentary chunks in the
literate source tree.

= (download limerick.zip "An early limerick")

= (figure stlucia.jpg "Flag of St Lucia")

= (embedded YouTube video GR3aImy7dWw)
	
= (embedded Vimeo video 204519)
	
= (embedded SoundCloud audio 42803139)

= (video centipede.mov)

@ If this renders to a format which supports audio, then this will be the call
of Steller's Jay, from the Cornell Lab of Ornithology collection
[Voices of Western Backyard Birds](https://dl.allaboutbirds.org):

= (audio jay.mp3)

@ This doesn't look much (and isn't): a raw piece of HTML pasted in from a
file, and visible only when this web is rendered to HTML.

= (html fragment.html)

@ A modest slide carousel, again using direct insertions:

= (carousel "Stage 1 - Raw tree")

``` BoxArt
	ROOT ---> DOCUMENT
```

= (carousel "Stage 2 - Developed tree" above)

``` BoxArt
	ROOT ---> DOCUMENT
				|
			  NODE 1  ---  NODE 2  ---  NODE 3  --- ...
```

= (carousel "Stage 3 - Completed tree" below)

``` BoxArt
	ROOT ---> DOCUMENT
				|
			  NODE 1  ---  NODE 2  ---  NODE 3  --- ...
				|            |            |
			  text 1       text 2       text 3  ...
```

= (carousel end)
