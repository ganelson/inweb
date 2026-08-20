# Labels

Labels are not to be confused with //Tags//, which mark paragraphs internally
as having certain properties (say, containing a picture). Labels are outwardly
visible, and are a way for the author of a web to draw attention to specific
lines of code. For example:

	The Collatz in the function name at //#A// is Lothar Collatz (1910-1990).
	Iteration of this function seems at first likely to race away into ever higher
	numbers, because the tripling at //#B// looks likely to win in a tug of war
	against the alternative possibility of halving. But if you think of this more as
	a process of dividing by $2^n$, where $n$ is the number of factors of 2 in $x$,
	the advantage seems to swing back the other way. It's now known that almost all
	iterations (from a positive start position) end in the 4, 2, 1, 4, 2, 1, ... cycle.
	
		int collatz(int x) { /* A */
			if (x % 2 == 0) return x/2;
			return 3*x + 1; /* B */
		}

Here the author picks out two noteworthy lines for discussion, marking those
in the code as `/* A */` and `/* B */`. When weaving this content, Inweb
then converts the notations `//#A//` and `//#B//` in the commentary into links
to the relevant lines. In so short an example, this is all a little contrived, but
with longer and more complex algorithms labels are a nice touch.

This can only work if Inweb knows how to recognise a label in the code, and
it can do so only if told explicitly how. This is done with a convention. Thus,
the above needs:

	Conventions {
		labels match //\* ([A-Z]) \*//
	}

The pattern for labels to match is a _regular expression_: those will be
detailed properly in //Regular Expressions//. Briefly, though, the above
pattern means "`/*` then a space then a capital letter then a space then `*/`".
The round brackets around the letter mean that this is the actual name part:
thus, the text `/* X */` matches this pattern, and the name "X" is extracted
from it.

The reason this example chose that way of writing labels is that it made
them valid C comments in what was, after all, a C program. But there is no
actual need to do that. If the convention is changed thus:

	Conventions {
		labels match //\* ([A-Z]) \*// replacing with //
	}

then the labels are automatically removed (since they have been replaced with
nothing) from the source code during both weaving and tangling. In other
words, the C compiler will only see the code:

	int collatz(int x) { 
		if (x % 2 == 0) return x/2;
		return 3*x + 1; 
	}

If we're removing them anyway, there's no actual need for these labels to be
valid C comments. We could for example have:

	Conventions {
		labels match / *{([A-Z])}/ replacing with //
	}

and then mark up the code as:

		int collatz(int x) {                {A}
			if (x % 2 == 0) return x/2;
			return 3*x + 1;                 {B}
		}

Those `{A}` and `{B}` markers are certainly not valid C, but that doesn't
matter, because they are removed during tangling.

## Heavier labelling

The example labels above were single letters, but that's just because
the convention called for that. Consider the following diassembly of a
machine code program:

    ; If there are no bytes to shift, then branch to shift by bits.
    beq shift_float8B_mantissa_bits                     ; a522: f0 19
    ; Shift right three times to divide by 8, to get the number of bytes.
    lsr                                                 ; a524: 4a
    lsr                                                 ; a525: 4a
    lsr                                                 ; a526: 4a

As is customary with disassemblies, the actual bytes of the code are recorded
over on the right, at given addresses (in hexadecimal). With the following
convention:

 	Conventions {
       labels match /; ([a-f0-9][a-f0-9][a-f0-9][a-f0-9]):/ replacing with /;/
	}

each line containing an instruction is automatically labelled with the
address of that instruction. For example, the first `lsr` line is
labelled `a524`, and commentary could say something like:

	Division by 8 costs only three bytes: see for example //#a524//.

## Terms and conditions apply

- Unless a convention is set up, as above, there are no labels.

- A single line cannot have more than one label.

- Even an otherwise blank line of code can have a label.

- Only a line in the actual program of the web can have a label, not a
  line in some other code extract, or a line in the commentary.

- Label names are read case sensitively: `a` is a different label name
  from `A`.

- The empty text is not a valid label name, that is, a label name has to
  contain at least one character.

- A label name can contain only English letters (upper or lower case),
  digits, hyphens `-`, underscores `_`, full stops `.`, and colons `:`.
  For example `3` and `old-trick` are valid labels, but `in & out` is not.

- The same label name can be used for multiple lines, but not in the same
  paragraph. So, for example, two consecutive paragraphs could each have
  a line labelled `A`, but a single paragraph cannot have two lines labelled
  `A`.

- When resolving a link such as `//#Name//`, Inweb first looks for a label of
  that name in the current paragraph. (This will be unique, if it exists.)
  Failing that, it looks for a label in the current section; and, failing
  that too, anywhere else in the web. An error is thrown if all three fail.
