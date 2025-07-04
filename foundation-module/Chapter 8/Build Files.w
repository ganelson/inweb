[BuildFiles::] Build Files.

Manages the build metadata for an inweb project.

@h About build files.
When we read a web, we look for a file in it called |build.txt|. If no such
file exists, we look for the same thing in the current working directory.

=
filename *BuildFiles::build_file_for_web(ls_web *WS) {
	filename *F = Filenames::in(WS->path_to_web, I"build.txt");
	if (TextFiles::exists(F)) return F;
	F = Filenames::in(NULL, I"build.txt");
	if (TextFiles::exists(F)) return F;
	return NULL;
}

@ The format of such a file is very simple: up to three text fields:

=
typedef struct build_file_data {
	struct text_stream *prerelease_text;
	struct text_stream *build_code;
	struct text_stream *build_date;
} build_file_data;

@ Here's how to read in a build file:

=
build_file_data BuildFiles::read(filename *F) {
	build_file_data bfd;
	bfd.prerelease_text = Str::new();
	bfd.build_code = Str::new();
	bfd.build_date = Str::new();
	TextFiles::read(F, FALSE, "unable to read build file", TRUE,
		&BuildFiles::build_file_helper, NULL, (void *) &bfd);
	return bfd;
}

void BuildFiles::build_file_helper(text_stream *text, text_file_position *tfp, void *state) {
	build_file_data *bfd = (build_file_data *) state;
	if (Str::len(text) == 0) return;
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, text, U"Build Date: *(%c*)")) {
		bfd->build_date = Str::duplicate(mr.exp[0]);
	} else if (Regexp::match(&mr, text, U"Build Number: *(%c*)")) {
		bfd->build_code = Str::duplicate(mr.exp[0]);
	} else if (Regexp::match(&mr, text, U"Prerelease: *(%c*)")) {
		bfd->prerelease_text = Str::duplicate(mr.exp[0]);
	} else {
		Errors::in_text_file("can't parse build file line", tfp);
	}
	Regexp::dispose_of(&mr);
}

@ And here is how to write one:

=
void BuildFiles::write(build_file_data bfd, filename *F) {
	text_stream vr_stream;
	text_stream *OUT = &vr_stream;
	if (Streams::open_to_file(OUT, F, UTF8_ENC) == FALSE)
		Errors::fatal_with_file("can't write build file", F);
	if (Str::len(bfd.prerelease_text) > 0)
		WRITE("Prerelease: %S\n", bfd.prerelease_text);
	WRITE("Build Date: %S\n", bfd.build_date);
	if (Str::len(bfd.build_code) > 0)
		WRITE("Build Number: %S\n", bfd.build_code);
	Streams::close(OUT);		
}

@h Bibliographic implications.
Whenever a web is read in, its build file (if it has one) is looked at in order to
set some bibliographic data.

=
void BuildFiles::set_bibliographic_data_for(ls_web *WS) {
	filename *F = BuildFiles::build_file_for_web(WS);
	if (F) {
		build_file_data bfd = BuildFiles::read(F);
		if (Str::len(bfd.prerelease_text) > 0)
			Bibliographic::set_datum(WS, I"Prerelease", bfd.prerelease_text);
		if (Str::len(bfd.build_code) > 0)
			Bibliographic::set_datum(WS, I"Build Number", bfd.build_code);
		if (Str::len(bfd.build_date) > 0)
			Bibliographic::set_datum(WS, I"Build Date", bfd.build_date);
	}
}

@ A little later on, i.e., once the Contents page has been read, we want to
synthesize the semantic version number for the project. Note that this is
called even if no build file had ever been found, so it's quite legal for
the Contents page to specify all of this.

If no error occurs, then the expansion |[[Semantic Version Number]]| is
guaranteed to produce a semver-legal version number.

=
void BuildFiles::deduce_semver(ls_web *WS) {
	TEMPORARY_TEXT(combined)
	text_stream *s = Bibliographic::get_datum(WS, I"Semantic Version Number");
	if (Str::len(s) > 0) WRITE_TO(combined, "%S", s);
	else {
		text_stream *v = Bibliographic::get_datum(WS, I"Version Number");
		if (Str::len(v) > 0) WRITE_TO(combined, "%S", v);
		text_stream *p = Bibliographic::get_datum(WS, I"Prerelease");
		if (Str::len(p) > 0) WRITE_TO(combined, "-%S", p);
		text_stream *b = Bibliographic::get_datum(WS, I"Build Number");
		if (Str::len(b) > 0) WRITE_TO(combined, "+%S", b);
	}
	if (Str::len(combined) > 0) {
		WS->version_number = VersionNumbers::from_text(combined);
		if (VersionNumbers::is_null(WS->version_number)) {
			Errors::fatal_with_text(
				"Combined version '%S' does not comply with the semver standard",
				combined);
		} else {
			Bibliographic::set_datum(WS, I"Semantic Version Number", combined);
		}
	}
	DISCARD_TEXT(combined)
}

@h Advancing.
We update the build date to today and, if supplied, also increment the build
number if we find that the date has changed.

=
void BuildFiles::advance_for_web(ls_web *WS) {
	filename *F = BuildFiles::build_file_for_web(WS);
	if (F) BuildFiles::advance(F);
	else Errors::fatal("web has no build file");
}

void BuildFiles::advance(filename *F) {
	build_file_data bfd = BuildFiles::read(F);
	if (BuildFiles::dated_today(bfd.build_date) == FALSE) {
		BuildFiles::increment(bfd.build_code);
		BuildFiles::write(bfd, F);
	}
}

@ The standard date format we use is "26 February 2018". If the contents of
|dateline| match today's date in this format, we return |TRUE|; otherwise we
rewrite |dateline| to today and return |FALSE|.

=
int BuildFiles::dated_today(text_stream *dateline) {
	char *monthname[12] = { "January", "February", "March", "April", "May", "June",
		"July", "August", "September", "October", "November", "December" };
	TEMPORARY_TEXT(today)
	WRITE_TO(today, "%d %s %d",
		the_present->tm_mday, monthname[the_present->tm_mon], the_present->tm_year+1900);
	int rv = TRUE;
	if (Str::ne(dateline, today)) {
		rv = FALSE;
		Str::clear(dateline);
		Str::copy(dateline, today);
	}
	DISCARD_TEXT(today)
	return rv;
}

@ Traditional Inform build codes are four-character, e.g., |3Q27|. Here, we
read such a code and increase it by one. The two-digit code at the back is
incremented, but rolls around from |99| to |01|, in which case the letter is
advanced, except that |I| and |O| are skipped, and if the letter passes |Z|
then it rolls back around to |A| and the initial digit is incremented.

This allows for 21384 distinct build codes, enough to use one each day for
some 58 years.

=
void BuildFiles::increment(text_stream *T) {
	if (Str::len(T) != 4) Errors::with_text("build code malformed: %S", T);
	else {
		inchar32_t N = Str::get_at(T, 0) - '0';
		inchar32_t L = Str::get_at(T, 1);
		inchar32_t M1 = Str::get_at(T, 2) - '0';
		inchar32_t M2 = Str::get_at(T, 3) - '0';
		if ((N > 9) || (L < 'A') || (L > 'Z') || (M1 > 9) || (M2 > 9)) {
			Errors::with_text("build code malformed: %S", T);
		} else {
			M2++;
			if (M2 == 10) { M2 = 0; M1++; }
			if (M1 == 10) { M1 = 0; M2 = 1; L++; }
			if ((L == 'I') || (L == 'O')) L++;
			if (L > 'Z') { L = 'A'; N++; }
			if (N == 10) Errors::with_text("build code overflowed: %S", T);
			else {
				Str::clear(T);
				WRITE_TO(T, "%d%c%d%d", N, L, M1, M2);
				PRINT("Build code advanced to %S\n", T);
			}
		}
	}
}
