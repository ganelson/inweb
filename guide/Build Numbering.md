# Build Numbering

The `inweb advance-build` command can create or update a _build file_ for a web.
This is an entirely optional feature, and an idiosyncratic one, but it follows
conventions used by the Inform project.

While in principle this command can work with freestanding build files, or build
files for single-file webs, it is only likely to be useful at all for larger
programs in multi-section webs stored in directories. So the following description
assumes we want to track build codes for the web `smorgasbord`:

	$ inweb advance-build smorgasbord
	inweb: fatal error: web has no build file

And nor has it. But we can make one:

	$ inweb advance-build -creating smorgasbord
	Build file begun at build 1A01 on 21 December 2025

Very little has happened here: a small text file has been created.

	$ cat smorgasbord/build.txt
	Build Date: 21 December 2025
	Build Number: 1A01

Today's date has been filled in, and the "build number" has been started at 1A01.
If we try to advance again:

	$ inweb advance-build smorgasbord
	Build number remains 1A01 since it is still 21 December 2025

This is the convention: the build number only actually advances on each new day.
(That wasn't an error, and Inweb did not return an error code, so it won't halt
a make file.) If we come back next day:

	$ inweb advance-build smorgasbord
	Build number advanced from 1A01 (set on 21 December 2025) to 1A02

And indeed:

	$ cat smorgasbord/build.txt
	Build Date: 22 December 2025
	Build Number: 1A02

Build numbers progress from 1A01, 1A02, ..., 1A99, 2A01, 2A02, ..., and so on,
except that 1I01, ..., 1I99 and 1O01, ..., 1O99, are skipped because the letters
I and O look too much like digits. An error is thrown if we reach 9Z99 and then
try to `inweb advance-build` further: but that seems unlikely, as the scheme
allows for 21384 distinct build codes, enough to use one each day for 58 years.

Nothing prevents the build file from being edited by hand, of course. An
optional field can be added in this way:

	Prerelease: early-beta
	Build Date: 22 December 2025
	Build Number: 1A02

Any `Prerelease` value is preserved by `inweb advance-build`, so it will stay
there until changed or removed by hand-editing.

What do we get for all this trouble? The answer is that the build code
contributes to the metadata for a web:

	$ inweb inspect -metadata smorgasbord
	...
	Build Date: 21 December 2025
	Build Number: 1A02
	Prerelease: early-beta
	Semantic Version Number: 1-early-beta+1A02

So that, for example, the web could include the following source line:

	printf("This is v[[Semantic Version Number]], built on [[Build Date]].\n");

and the result would print:

	This is v1-early-beta+1A02, built on 21 December 2025.
