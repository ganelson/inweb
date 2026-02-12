# Showcasing Illiterate Programs

One easy use of notations is to turn an existing program, never written to be
literate, into a valid web, by recognising certain patterns in the source code
and dividing up the material accordingly.

While this will never be useful from the point of view of compilation — these
webs will never need to be tangled — it makes it possible for Inweb to weave
many existing programs into legible websites.

## Example: An assembly language classic

Here is a fragment from the BBC Micro MOS, "machine operating system", written
by Acorn in around 1982 for its breakthrough microcomputer. The source here is
tidily set out (using ACME assembly language for the 6502 microprocessor), and
is taken from Toby Nelson's excellent commentary. So there is content worth
reading. But it is not in any obvious way a literate program able to be run
through Inweb:

	; ***************************************************************************************
	;
	;   VDU 1       Send next byte to printer only
	;
	; ***************************************************************************************
	.vdu1EntryPoint
		TAX                                                 ; remember A
		LDA .vduStatusByte                                  ; get VDU status byte
		LSR                                                 ; get bit 0 into carry (printer enabled bit)
		BCC .exit                                           ; if (printer not enabled) then branch (exit)
		TXA                                                 ; restore A
		JMP .sendValidByteToPrinter                         ; send byte in A (next byte) to printer
	
	; ***************************************************************************************
	.explicitAddressNoParameters
		STA .vduJumpVectorHigh                              ; upper byte of link address
		TYA                                                 ; restore A (the VDU number)
	
		; set carry if VDU number is within range 8-13 (cursor movement)
		CMP #8                                              ;
		BCC +                                               ; if (VDU number < 8) then branch (carry clear)
		EOR #$FF                                            ; invert value
		CMP #$F2                                            ; if (VDU number > 13) then clear carry
		EOR #$FF                                            ; re-invert value back again

Of course, there's a lot more of that: the MOS occupied a 16K ROM, and was a
masterpiece of design for its time.

Suppose we take that material and put it into a file called `vdu.a.mossy`. The
`.a` part refers to ACME assembly language: one of the languages which Inweb
knows how to syntax-colour, as it happens. The `.mossy` part indicates the
notation — we will create a new notation called "Mossy", just for the MOS.

And really, there's nothing to it. Here is `mossy.inweb`:

	Notation "Mossy" {
		recognise .mossy
		recognise .*.mossy
	
		classify
			; *************************************************************************************** ==> beginparagraph if in extract context
			; *************************************************************************************** ==> commentary
			; MATERIAL          ==> commentary
			;                   ==> commentary
			MATERIAL			==> code
		end
	}

Even this tiny definition gets things well under way. The basic split is that
lines with `;` in column 1 are comments, and other lines are code. But within
the comment, we also want to clear out those fences of asterisks. Note the
way these are dealt with: if Inweb is reading code, it treats the asterisks
as a paragraph break, thus ending code and entering commentary; if it isn't
reading code, it ignores the asterisks completely — that's because, although
the line is classified as `commentary`, nothing was put into `MATERIAL`, so
no actual content got through.

And now we're off to the races:

	inweb weave vdu.a.mossy -using mossy.inweb -creating
	weaving web "Untitled" (ACME program in Mossy notation) as HTML
	(created directory 'vdu-assets')
		generated: vdu.html
		11 files copied to: vdu-assets
	
So much for a single fragment of code. More ambitiously, the next task is to
present a slew of assembly files, which will become the sections of a multi-file web.

For simplicity, we'll suppose just two source files, called `star.a` and `vdu.a`,
and put them in a directory called `mos`. That will be the web directory. There's
no need now to tack `.mossy` onto the filenames, because the contents page will
see to all that. The contents page will be called `Contents.inweb`, and will look
like this:

	Title: MOS
	Author: Acorn Computers
	Notation: Mossy
	Language: ACME
	Purpose: The operating system used by the 1982 BBC Micro.
	Version Number: 1.2
	
	Sections
		"VDU" at "vdu.a"
		"Star commands" at "star.a"
	
	Notation "Mossy" {
		recognise .mossy
		recognise .*.mossy
	
		classify
			; Chapter: MATERIAL     ==> title
			; *************************************************************************************** ==> beginparagraph if in extract context
			; *************************************************************************************** ==> commentary
			; MATERIAL              ==> commentary
			;                       ==> commentary
			MATERIAL				==> code
		end
	}

Note that it _contains_ the definition of `Mossy`, so there's no need now for a
sidekick file called `mossy.inweb`, and no need to keep saying `-using mossy.inweb`
in commands about the `mos` web: the web sees this definition all by itself.

Another plus of having a contents page is that it gives the web some metadata:

	$ inweb inspect mos -metadata
	web "MOS" (ACME program in Mossy notation): 2 sections : 9 paragraphs : 179 lines
	
	Title: MOS
	Author: Acorn Computers
	Purpose: The operating system used by the 1982 BBC Micro.
	Language: ACME
	Notation: Mossy
	Semantic Version Number: 1.2
	Version Number: 1.2

The source files, here `vdu.a` and `star.a`, are longer now. Suppose they start
like this:

	; ***************************************************************************************
	; ***************************************************************************************
	;
	; Chapter: Star commands
	;
	; ***************************************************************************************
	; ***************************************************************************************
	
	; ***************************************************************************************
	;
	; Clear four consecutive bytes in the OSFILE block
	;
	; The data required by the OSFILE call is stored at .osfileBlockStart, is 18 bytes long, and
	; is as follows:

...and so on. We want to pick the chapter headings out, which is why the notation
slipped in an extra classification line:

			; Chapter: MATERIAL     ==> title

This means Inweb reads the section `star.a` as having the title "Star commands".

Because of Inweb's rule that the contents page must always agree with the section
files themselves about what the titles of the sections are, we have to write
the contents like this:
	
	Sections
		"VDU" at "vdu.a"
		"Star commands" at "star.a"

rather than like this:

	Sections
		vdu.a
		star.a

(If we wrote the latter, Inweb would complain that the section entitled "star.a"
seemed actually to be called "Star commands".)

Setting up the contents page was a little fuss, but now we get a neat little
website as the reward:

	inweb weave mos -creating
	weaving web "MOS" (ACME program in Mossy notation) as HTML
	(created directory 'mos/Woven/assets')
		[mos/Woven/vd.html] [stcm] 
		[index] 
		10 files copied to: mos/Woven/assets

## Example: Semiliterate C

An alternative use case now: taking a non-literate program, adding comments to
it in a particular format, and making it "semiliterate" — that is, able to
be woven attractively, but with no need for it to be tangled.

This time the program will be:

	/// # Getting started
	
	#include<stdio.h>
	
	/// # Numerical approximations
	///
	/// The actual work is done here, and relies on the power series expansion:
	/// $$ e^x = \sum_{n=0}^\infty {{x^n}\over{n!}} $$
	/// so that we can at least hope that
	/// $$ e \approx  \sum_{n=0}^{20} {{1}\over{n!}} $$
	
	double compute_e(void) {
		double e = 0.0, factorial = 1.0;
		for (int n=0; n<=20; n++) {
			if (n > 0) factorial *= n;
			e += 1.0/factorial;
		}
		return e;
	}
	
	/// # Main
	///
	/// And we wrap that in the usual C interface.
	
	int main(int argc, char *argv[]) {
		printf("e = %.10g\n", compute_e());
		return 0;       /* this is **very important** to ensure a clean exit */
	}

Note that this is a valid ANSI C program, and requires no tangling to run:

	$ cd jasmine
	$ clang main.c
	$ ./a.out
	e = 2.718281828

(which, despite the crudeness of the method, is the right answer). So there
is no point in tangling: but if we supply also the following contents page —

	Title: Jasmine
	Author: Graham Nelson
	Notation: SemiliterateC
	Language: C
	Purpose: Exemplary.
	
	Sections
		main.c
	
	Notation "SemiliterateC" {
		classify
			/// # MATERIAL      ==> beginparagraph
			/// MATERIAL        ==> commentary
			///                 ==> commentary
			MATERIAL		    ==> code
		end
		
		Conventions {
			comments can contain styling
		}
	}

then we can weave the program directly to a website which contains mathematical
formulae, headings, a contents page, and so on:

	inweb weave jasmine -creating
	weaving web "Jasmine" (C program in SemiliterateC notation) as HTML
		[jasmine/Woven/mn.html] 
		[index] 
		11 files copied to: jasmine/Woven/assets
