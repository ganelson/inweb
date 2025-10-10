How to Write a Web.

How to mark up code for literate programming.

@h The title of a section.
In any section file, there will be a few lines at the top which occur before
the first paragraph of code begins. (The first paragraph begins on the first
line which starts with an |@| character.)

The first line should be the title of the section, followed by a full stop.
For example:
= (text)
	The Sieve of Eratosthenes.
=
A section title must contain only filename-safe characters, and it's probably
wise to make them filename-safe on all platforms: so don't include either
kind of slash, or a colon, and in general go easy on punctuation marks.

Optionally, a section heading can also specify its own range abbreviation,
which must be given in round brackets and followed by a colon:
= (text)
	(S/sieve): The Sieve of Eratosthenes.
=
If this is not done (and usually it is not), Inweb will construct a range
abbreviation itself: in this case, it comes up with |S/tsoe|.

Subsequent lines of text are then taken as the optional description of the
purpose of the code in this section. (This is used on contents pages.) For
example:
= (text)
	A fairly fast way to determine if small numbers are prime, given storage.
=
@h Paragraphing.
A standard paragraph is introduced with an |@| command, which must place
that magic character in the first column of the line:
= (text as Inweb)
	@ This is some comment at the start of a new paragraph, which...
=
A fancier paragraph with a subheading attached is introduced using the
|@h| or |@heading| command instead. (This is simply a long and short version
of the same command.) The text of the subheading then follows, up to the
first full stop.
= (text as Inweb)
	@heading Reflections on the method.
=
Paragraphs can contain three ingredients, all optional, but if given then
given in this order: comment, definitions, and code. The following
example shows all three being used:
= (text as Inweb)
	@h Primality.
	We provide this as a function which determines whether a number
	is prime:
	
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
=
@ Definitions are made using one of three commands: |@d| or |@define|; or
|@e| or |@enum|; or |@default|, which is rarely used and has no abbreviation.
These create new constants in the program, with the values given: they are
the equivalent of a |#define| directive in C. |@define| is the simpler form.
For example,
= (text as Inweb)
	@define ENIGMATIC_NUMBER 90125
=
sets |ENIGMATIC_NUMBER| to 90125. Unlike in the C preprocessor, multi-line
definitions are automatically handled, so for example:
= (text as Inweb)
	@ The following macro defines a function:
	@d EAT_FRUIT(variety)
	    int consume_by_##variety(variety *frp) {
	        return frp->eat_by_date;
	    }
	=
	banana my_banana; /* initialised somewhere else, let's suppose */
	EAT_FRUIT(banana) /* expands with the definition above */
	void consider_fruit(void) {
	    printf("The banana has an eat-by date of %d.", consume_by_banana(&my_banana));
	}
=
In fact, a definition continues until the next definition, or until the code
part of the paragraph begins, or until the paragraph ends, whichever comes
first.

Enumerations with |@enum| are a convenience to define enumerated constants.
For example,
= (text as Inweb)
	@enum JANUARY_MNTH from 0
	@enum FEBRUARY_MNTH
	@enum MARCH_MNTH
=
and so on, is equivalent to
= (text as Inweb)
	@define JANUARY_MNTH 0
	@define FEBRUARY_MNTH 1
	@define MARCH_MNTH 2
=
What happens is that |@enum| looks at the tail of the name, from the last
underscore to the end: in this case, |_MNTH|. The first time an enumerated
value is asked for with this tail, |from| is used to specify the lowest
number to be used - in the above case, months begin counting from 0. With
each subsequent |_MNTH| request, |@enum| allocates the next unused value.

All symbols defined with |@define| or |@enum| are global, and can be used
from anywhere in the web, including in sections or paragraphs earlier than
the ones in which they are defined. (The tangler automatically arranges code
as necessary to make this work.)

A symbol defined with |@default| has the given value only if some other use
of |@d| or |@e| in the web has not already defined it. For example, if the
web contains:
= (text as Inweb)
	@default MAX_HEADROOM 100
	@d MAX_HEADROOM 99
=
or
= (text as Inweb)
	@d MAX_HEADROOM 99
	@default MAX_HEADROOM 100
=
then the value is 99, but if only
= (text as Inweb)
	@default MAX_HEADROOM 100
=
then the value is 100.

@ Finally, a paragraph can contain code. This is introduced with an equals
sign: in some sense, the value of the paragraph is the code it contains.
In many paragraphs, as in the example above, the divider is just
= (text as Inweb)
	=
=
and this means that the rest of the paragraph is part of the program.
Ordinarily, this must appear in column 1, but a special abbreviation is
allowed for paragraphs with no comment and no definitions:
= (text as Inweb)
	@ =
=
This is exactly equivalent to:
= (text as Inweb)
	@
	
	=
=
We can tell the tangler to place the code early in the tangled program,
rather than at its natural place in the sequence, by annotating
= (text as Inweb)
	= (early code)
=
instead of just |=|. (This is occasionally useful where, for example, it's
necessary to create global variables which will be referred to in other
sections of code.) The more extreme |= (very early code)| can be used in C
for complicated header file inclusions, but should be kept to an absolute
minimum, if only for clarity.

@ One last feature, but it's the most important. Some code extracts are
given names, in angle brackets. If so, then the paragraph is the definition
of that extract. For example:
= (text as Inweb)
	@<Dramatic finale@> =
	    printf("I'm ruined! Ruined, I say!\n");
	    exit(1);
=
Notice that the equals sign is still there: it's just that the chunk of code
is given a name, written inside |@<| and |@>| "brackets". (This notation
goes all the way back to Knuth's original WEB.)

What does the tangler do with this? It doesn't place the code as the next
item in the program. Instead, it expands any mention of |@<Dramatic finale@>|
elsewhere in the section with this block of code. It can be expanded as
many times as necessary, but only within the same section. Another section
would be quite free to define its own |@<Dramatic finale@>|, but it would
not be able to see this one.

Why is this important? One of the points of literate programming is to
subdivide the program on conceptual lines, even within single functions.
For example:
= (text as Inweb)
	@<Perform the sieve@> =
	    @<Start with all numbers from 2 upwards in the sieve@>;
	    for (int n=2; n*n <= RANGE; n++)
	        if (still_in_sieve[n])
	            @<Shake out multiples of n@>;
	    sieve_performed = TRUE;
=
This is easier to understand than writing the function all in one go, and
more practicable than breaking it up into smaller functions.

Named paragraphs behave, in some ways, like macro definitions, and those
have a bad name nowadays - probably fairly. But Inweb makes them much
safer to use than traditional macros, because it tangles them into code
blocks, not just into runs of statements. A variable defined inside a
named paragraph has, as its scope, just that paragraph. And this:
= (text as Inweb)
	        if (still_in_sieve[n])
	            @<Shake out multiples of n@>;
=
works safely because |@<Shake out multiples of n@>| is, thanks to being a
code block, semantically a single statement.

Finally, note that if there are no commentary or definitions attached to
the paragraph then it's not necessary to type the initial |@|. That is,
this:
= (text as Inweb)
	@
	
	@<Prepare to exit@> =
=
...is not necessary, and it's sufficient to type just:
= (text as Inweb)
	@<Prepare to exit@> =
=
@h Conditional compilation.
In some languages, especially C, it's very hard to write a program which will
run on multiple operating systems without some use of conditional compilation:
that is, putting some code or definitions inside |#ifdef| clauses or the like.

Inweb can't alter this sad fact of life, but it can make the process tidier.
If a paragraph has the tag |^"ifdef-SYMBOL"|, then any material in it will
be tangled in such a way that it takes effect only if |SYMBOL| is defined.
For example, in a C-language web with the paragraph:
= (text as Inweb)
	@h Windows stuff. ^"ifdef-PLATFORM_WINDOWS"
	
	@d THREADS_AVAILABLE 12
	=
	void start_threads(int n) {
	    ...
	}
=
...the definition of |THREADS_AVAILABLE| and the function |start_threads|
would be made only inside a |#ifdef PLATFORM_WINDOWS| clause; the same would
happen for any typedefs or |#include|s made.

Similarly, tagging a paragraph |^"ifndef-SYMBOL"| causes it to have effect
only if |SYMBOL| is undefined. A paragraph can have any number of such
conditions applied to it, and if so then all of the conditions must be met.

Note that since tags can be applied to entire sections of a web, at the
Contents listing, it's straightforward to give, say, two versions of a
section file, one with effect on MacOS, one with effect on Windows.

@h Commentary.
The comment part of a paragraph is ignored by the tangler, and appears only
in weaves. For the most part, the text is simply copied over verbatim: but
Inweb quietly tries to improve the appearance of what it copies, and a
few special notations are allowed, to help with this.

@ A doubled hyphen becomes an em-rule; double-quotation marks automatically
smarten (in TeX format, at least).

@ Lines beginning with what look like bracketed list numbers or letters are
set as such, running on into little indented paragraphs. Thus
= (text as Inweb)
	(a) Intellectual property has the shelf life of a banana. (Bill Gates)
	(b) He is the very pineapple of politeness! (Richard Brinsley Sheridan)
	(c) Harvard takes perfectly good plums as students, and turns them into
	prunes. (Frank Lloyd Wright)
=
will be typeset thus:

(a) Intellectual property has the shelf life of a banana. (Bill Gates)
(b) He is the very pineapple of politeness! (Richard Brinsley Sheridan)
(c) Harvard takes perfectly good plums as students, and turns them into
prunes. (Frank Lloyd Wright)

A line which begins |(...)| will be treated as a continuation of indented
matter (following on from some break-off such as a source quotation).
A line which begins |(-X)| will be treated as if it were |(X)|, but
indented one tab stop further in, like so:

(c) Harvard blah, blah, blah. (Frank Lloyd Wright)
(-d) Pick a song and sing a yellow nectarine. (Scott Weiland)

Finally, bracketed asterisks are considered to be bullets. Thus:
= (text as Inweb)
	(*) Do I dare to eat a peach? (T. S. Eliot)
	(*) You sit on the veranda drinking tea and your ducklings swim on the pond,
	and everything smells good... and there are gooseberries. (Anton Chekhov)
=
becomes:
(*) Do I dare to eat a peach? (T. S. Eliot)
(*) You sit on the veranda drinking tea and your ducklings swim on the pond,
and everything smells good... and there are gooseberries. (Anton Chekhov)

@ Text placed between vertical strokes will be set in a fixed-space, code
style font, |thus|. This paragraph appears in the web you are reading thus:
= (text as Inweb)
	@ Text placed between vertical strokes will be set in a fixed-space, code
	style font, |thus|. This paragraph appears in the web you are reading thus:
=
This notation may be inconvenient if you need the vertical stroke character
for something else, especially as the notation is used both in code comments
and in paragraph commentary. But both notations can be configured in the
Contents page of a web, thus:
= (text as Inweb)
Code In Code Comments Notation: Off
Code In Commentary Notation: %%
=
This example would turn off the feature in code comments, but allow it in
paragraph commentary; we would then need to write...
= (text as Inweb)
	@ Text placed between vertical strokes will be set in a fixed-space, code
	style font, %%thus%%. This paragraph appears in the web you are reading thus:
=

@ A line written thus:
= (text as Inweb)
	>> The monkey carries the blue scarf.
=
is typeset as an extract of text thus:

>> The monkey carries the blue scarf.

(This is a feature used for Inform 7 "code" samples, those being essentially
natural language text.)

@h Code samples and other extraneous matter.
When is code not code? When it's an extract of text being displayed for
documentation reasons, is the answer. We can include this like so:
= (text as Inweb)
	= (text)
	Here is my sample bit of text.
	= (undisplayed text)
=
This is assumed to be plain text, and is syntax-coloured (or rather, not)
as such, but otherwise it's woven as code. Using the word |undisplayed|
before |text| tells Inweb to do so less showily, on HTML weaves:
= (text as Inweb)
	= (undisplayed text)
=
Sometimes, though, we do want syntax colouring. If in fact it is a
hypothetical piece of code from the program -- for example, a demonstration of
an API, but for reading and not to be compiled -- we can instead write:
= (text as Inweb)
	= (text as code)
=
and the text will then be treated visually exactly as the surrounding
program is. If, on the other hand, it's a sample piece of code from a
different language altogether, we can specify which:
= (text as Inweb)
	= (text as ACME)
=
This will then be syntax-coloured following the rules for ACME (or any
other language supported by Inweb).

Note that if your web is written in, for example, C, then these are
subtly different:
= (text as Inweb)
	= (text as C)
	= (text as code)
=
The difference is that syntax-colouring in the first case doesn't know
the names of any surrounding functions or data structures; in the second
case, it knows the names of all those in your program.

Samples of code are, uniquely, allowed to end mid-way in a paragraph (unlike
real code): placing a |=| on the left margin allows the commentary to resume.
For example,
= (text as Inweb)
	= (text as ACME)
	    BEQ .adjustXRegister
	=
	...which is essential in order to restore the state of
=

@h Extract files.
Many programs can only properly function if accompanied by a configuration file
of some kind: a set of default preferences, for example, or some other associated
data. This is not part of the program, and will instead be read in every time
the program runs.

To explain such a program properly, one really needs to explain this sidekick
file as well. So Inweb provides a feature for including these files inside the
body of a web, as what are called "extracts". For example:
= (text as Inweb)
	= (text to magic-settings.txt)
	    top-hat-capacity = 6 rabbits
	    cabinet-trapdoor = closed
	=
=
The result weaves like so:
= (text to magic-settings.txt)
	top-hat-capacity = 6 rabbits
	cabinet-trapdoor = closed
=
When the web is tangled, the file |magic-settings.txt| will be created with these
contents and placed alongside the main tangled output, i.e., usually in the web's
|Tangled| directory.

There can be up to 10 differently-named extract files. If there are multiple
extracts naming the same file -- for example, if we also have:
= (text as Inweb)
	= (text to magic-settings.txt)
	    marked-card = 6 of clubs
	=
=
which weaves like so:
= (text to magic-settings.txt)
	marked-card = 6 of clubs
=
then the extracts are tangled together into one file. So the result of the two
example extracts above, after tangling, would be a single file which reads:
= (text)
	top-hat-capacity = 6 rabbits
	cabinet-trapdoor = closed
	marked-card = 6 of clubs
=

@h Links.
URLs in the web are automatically recognised and a weave to HTML will
make them into links. For example:
= (text)
	For further reading, see: https://en.wikipedia.org/wiki/How_to_Avoid_Huge_Ships.
=
For further reading, see: https://en.wikipedia.org/wiki/How_to_Avoid_Huge_Ships.

Note that URLs are considered to continue to the next white space, except
that any final full stops, question or exclamation marks, commas, brackets,
semicolons, or colons are disregarded. (This is why the above sentence ended
with a full stop and yet the full stop wasn't part of the reference URL.)

URLs will also be recognised in any text extract marked as |hyperlinked|.
For example,
= (text)
	Compare: https://en.wikipedia.org/wiki/Crocheting_Adventures_with_Hyperbolic_Planes!
=
produces:
= (hyperlinked text)
	Compare: https://en.wikipedia.org/wiki/Crocheting_Adventures_with_Hyperbolic_Planes!
=

@h Cross-references.
These are like links, but are internal. These are normally written within |//|
signs and are only available in the commentary of a web. They allow us to
place cross-references like so:
= (text)
	To see how cross-references are implemented, see //Format Methods//,
	or more generally the whole of //Weaving//; to decipher the text,
	Inweb uses code from //literate// at //literate: Web Modules//.
=
To see how cross-references are implemented, see //Format Methods//,
or more generally the whole of //Weaving//; to decipher the text,
Inweb uses code from //literate// at //literate: Web Modules//.

What happened in that last sentence is that Inweb noticed the following:
(a) "Format Methods" is the name of a section of code in the Inweb web;
(b) The web also has a chapter called "Weaving";
(c) It uses a module called "literate";
(d) And that module has a section called "Web Modules".

Inweb then made links accordingly. Chapters, which can be referred to either
numerically, link to the first section in them; modules likewise. Errors are
thrown if these references to sections are in any way ambiguous. They are not
case sensitive.

@ Sometimes we want to make a link without literally showing the destination.
This is simple: for example,
= (text)
	First //the program has to configure itself -> Configuration//, then...
=
produces: "First //the program has to configure itself -> Configuration//,
then..."; the text "the program has to configure itself" links to //Configuration//.
This is especially useful if the destination is given as an explicit URL, which
is also allowed:
= (text)
	See //this biographical note -> http://mathshistory.st-andrews.ac.uk/Biographies/Gauss.html//.
=
See //this biographical note -> http://mathshistory.st-andrews.ac.uk/Biographies/Gauss.html//.

@ It's also possible to reference function names and type names, provided that
the language definition supports these (see //Supporting Programming Languages//):
this is certainly the case for C-like languages. For example,
= (text)
	Individual sections of a web are stored in //ls_section// structures,
	and mostly created by //WebStructure::new_ls_section//.
=
produces: Individual lines of a web are stored in //ls_section// structures,
and mostly created by //WebStructure::new_ls_section//. And that should link to the
structure definition and function of these names inside the Inweb program.

Lastly, cross-references can even be made to webs quite separate from the
current one, but this requires the use of a Colony file.
See //Making Weaves into Websites//.

@ Cross-references also work inside text extracts marked as |hyperlinked|.
= (text as Inweb)
	= (hyperlinked text)
		See the //Manual// for more on this.
	=
=
produces:
= (hyperlinked text)
	See the //Manual// for more on this.
=

@ Cross-references must begin after white space, or a punctuation mark (other
than a colon), and must end to be followed by more white space or another
punctuation mark (this time allowing a colon). In practice, that reduces
the risk of misunderstanding a |//| occurring in the commentary for some
other reason. All the same, you might want a different notation, so this
can be configured in the Contents page of a web, say like so:
= (text as Inweb)
Cross-References Notation: &&&
=
It's also possible to disable cross-referencing entirely with:
= (text as Inweb)
Cross-References Notation: Off
=

@h Figures.
Images to be included in weaves of a web are called "Figures", as they
would be in a printed book. These images should ideally be in PNG, JPG or PDF
format and placed in a subdirectory of the web called |Figures|: for instance,
the weaver would seek |Fig_2_3.pdf| at pathname |Figures/Fig_2_3.pdf|.

To embed an image, we write like so:
= (text as Inweb)
	= (figure mars.jpg)
=
With results like so:
= (figure mars.jpg)

Inweb also has some limited ability to control the dimensions of an image:
= (text as Inweb)
	= (figure Whatever.jpg at width 500)
	= (figure Something.jpg at height 2cm)
=
Dimensions given in cm are scaled at 72 times dimensions given without a
measurement; in practice, rendering to TeX produces roughly the number of
centimeters asked for, and rendering to HTML makes the image width or height
correspond. If you really want to monkey with the aspect ratio,
= (text as Inweb)
	= (figure Whatever.jpg at 20 by 100)
=

@h Carousels.
A carousel is a slide-show of (usually but not always) figures; there's a
set of slides with captions, only one of which is visible at a time.
= (carousel "Royal Albert Hall, London: King Crimson's 50th Anniversary Concert")
= (figure rah.jpg)
= (carousel "Brighton Beach")
= (figure brighton.jpg)
= (carousel "Roman Amphitheatre, Pula")
= (figure pula.jpg)
= (carousel "St Mark's Basilica, Venice")
= (figure venice.jpg)
= (carousel end)
That carousel was produced by:
= (text as Inweb)
	= (carousel "Royal Albert Hall, London: King Crimson's 50th Anniversary Concert")
	= (figure rah.jpg)
	= (carousel "Brighton Beach")
	= (figure brighton.jpg)
	= (carousel "Roman Amphitheatre, Pula")
	= (figure pula.jpg)
	= (carousel "St Mark's Basilica, Venice")
	= (figure venice.jpg)
	= (carousel end)
=
That carousel contained only figures, but almost any material can go into the
slides, paragraph breaks excepted. For example:
= (carousel "Stage 1 - Raw tree" above)
= (text as BoxArt)
	ROOT ---> DOCUMENT
=
= (carousel "Stage 2 - Developed tree" above)
= (text as BoxArt)
	ROOT ---> DOCUMENT
	            |
	          NODE 1  ---  NODE 2  ---  NODE 3  --- ...
=
= (carousel "Stage 3 - Completed tree" above)
= (text as BoxArt)
	ROOT ---> DOCUMENT
	            |
	          NODE 1  ---  NODE 2  ---  NODE 3  --- ...
	            |            |            |
	          text 1       text 2       text 3  ...
=
= (carousel end)
This carousel has differently placed captions, too: that's because the
slide lines were typed as:
= (text as Inweb)
	= (carousel "Stage 2 - Developed tree" above)
=
and the like. By default, a caption overlaps slightly with the content; but
it can also be |above| or |below|. A slide can also have no caption at all:
= (text as Inweb)
	= (carousel)
	= (figure anonymous.jpg)
	= (carousel)
	= (figure furtive.jpg)
	= (carousel end)
=

@h Video and audio.
To include audio samples, place them as MP3 files in the subdirectory |Audio|
of the web. For example, in the present web,
= (text as Inweb)
	= (audio SP014.mp3)
=
produces Space Patrol episode 14, from 1953: "Brain Bank And Space Binoculars" --
= (audio SP014.mp3)
Similarly,
= (text as Inweb)
	= (video DW014.mp4)
=
produces Doctor Who episode 14, from 1963: "The Roof of the World". Still, video
takes up space, so for economy's sake a demonstration is omitted from this manual.

@h Embedded video and audio.
One way to get around such space limitations is to embed players for video or
audio hosted on some external service. For example:
= (text as Inweb)
	= (embedded YouTube video GR3aImy7dWw)
=
With results like so:
= (embedded YouTube video GR3aImy7dWw)

The YouTube ID number |GR3aImy7dWw| can be read from its Share URL, which in
this case was |https://youtu.be/GR3aImy7dWw|.

Similarly for Vimeo:
= (text as Inweb)
	= (embedded Vimeo video 204519)
=
With results like so:
= (embedded Vimeo video 204519)

For audio, you may like to try SoundCloud:
= (text as Inweb)
	= (embedded SoundCloud audio 42803139)
=
With results like so:
= (embedded SoundCloud audio 42803139)

@ Adding width and height is straightforward; by default the dimensions are
720 by 405.
= (text as Inweb)
	= (embedded Vimeo video 204519 at 400 by 300)
	= (embedded SoundCloud audio 42803139 at height 200)
=
The latter sets just the height (of the displayed waveform, that is --
arguably music has width and not height, but SoundCloud thinks otherwise).

@h Downloads.
Occasional small downloads may be useful as a way to present examples to
try with a program being documented. These are very simple:
= (text as Inweb)
	= (download alice.crt "certificate file")
=
produces:
= (download alice.crt "certificate file")
The file to download, in this case |alice.crt|, must be placed in a |Downloads|
subdirectory of the web. The explanatory text -- usually just an indication
of what sort of file this is -- is optional.

@h Raw HTML snippets.
Finally, it's possible to include a chunk of raw HTML code, though of course
this will only be viewable if the web is being woven to HTML.
= (text as Inweb)
	= (html fireworks.html)
=
incorporates the contents of the file from the subdirectory |HTML| of the web.

@h Mathematics notation.
Literate programming is a good technique to justify code which hangs on
unobvious pieces of mathematics or computer science, and which must therefore
be explained carefully. Formulae or equations are a real convenience for that.

For example, it's known that the average running time of Euclid's GCD
algorithm on $a$ and numbers coprime to $a$ is:
$$ \tau (a)={\frac {12}{\pi ^{2}}}\ln 2\ln a+C+O(a^{-1/6-\varepsilon }) $$
where $C$ is Porter's constant,
$$ C=-{\frac {1}{2}}+{\frac {6\ln 2}{\pi ^{2}}}\left(4\gamma - {\frac {24}{\pi ^{2}}}\zeta'(2)+3\ln 2-2\right)\approx 1.467 $$
which involves evaluating Euler's constant $\gamma$ and the first derivative
of the Riemann zeta function $\zeta'(z)$ at $z=2$.

That passage was achieved by typing this as the Inweb source:
= (text as Inweb)
	For example, it's known that the average running time of Euclid's GCD
	algorithm on $a$ and numbers coprime to $a$ is:
	$$ \tau (a)={\frac {12}{\pi ^{2}}}\ln 2\ln a+C+O(a^{-1/6-\varepsilon }) $$
	where $C$ is Porter's constant,
	$$ C=-{\frac {1}{2}}+{\frac {6\ln 2}{\pi ^{2}}} \left(4\gamma - {\frac {24}{\pi^{2}}}\zeta'(2)+3\ln 2-2\right)\approx 1.467 $$
	which involves evaluating Euler's constant $\gamma$ and the first derivative
	of the Riemann zeta function $\zeta'(z)$ at $z=2$.
=
Mathematical formulae is typed in TeX notation between dollar signs,
as usual for TeX formulae. If those notations are inconvenient, they can be
changed. The defaults are:
= (text as Inweb)
	TeX Mathematics Notation: $
	TeX Mathematics Displayed Notation: $$
=
Changing these to |None| causes Inweb to disregard mathematics entirely, and
treat it as any other text would be treated.

@h Footnotes.
Not everyone likes footnotes,[1] but sometimes they're a tidy way to make
references.[2]

[1] But see Anthony Grafton, "The Footnote: A Curious History" (Harvard
University Press, 1999).
[2] For example, to cite Donald Knuth, "Evaluation of Porter's constant",
Computers & Mathematics with Applications, 2, 137-39 (1976).

@ The content of that sentence was typed as follows:
= (text as Inweb)
	Not everyone likes footnotes,[1] but sometimes they're a tidy way to make
	references.[2]

	[1] But see Anthony Grafton, "The Footnote: A Curious History" (Harvard
	University Press, 1999).
	[2] For example, to cite Donald Knuth, "Evaluation of Porter's constant",
	Computers & Mathematics with Applications, 2, 137-39 (1976).
=
Note that footnotes should be numbered upwards from 1 in each individual
paragraph; Inweb automatically renumbers them for each woven section, but
we don't have to worry about that when typing.

If you're reading this as a web page (with Javascript on), then you should
have seen clickable footnote blobs, which reveal the text. If Javascript is
off, there's a more conventionally textual presentation.

Once again, notation may be an issue, and so it's controllable. By default,
we have:
= (text as Inweb)
	Footnote Begins Notation: [
	Footnote Ends Notation: ]
=
but if you need squares for something else in your commentary, then perhaps:
= (text as Inweb)
	Footnote Begins Notation: [fn
	Footnote Ends Notation: ]
=
would be sensible. The "cue" between these notations is required to be a
string of digits; each must occur just once in its section; and each must
have a text and a cue which match up correctly.
