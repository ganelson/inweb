[VersionNumberRanges::] Version Number Ranges.

Ranges of acceptable version numbers.

@h Ranges.
We often want to check if a semver lies in a given precedence range, which we
store as an "interval" in the mathematical sense. For example, the range |[2,6)|
means all versions from 2.0.0 (inclusve) up to, but not equal to, 6.0.0. The
lower end is called "closed" because it includes the end-value 2.0.0, and the
upper end "open" because it does not. An infinite end means that there
os no restriction in that direction; an empty end means that, in fact, the
interval is the empty set, that is, that no version number can ever satisfy it.

The |end_value| element is meaningful only for |CLOSED_RANGE_END| and |OPEN_RANGE_END|
ends. If one end is marked |EMPTY_RANGE_END|, so must the other be: it makes
no sense for an interval to be empty seen from one end but not the other.

@e CLOSED_RANGE_END from 1
@e OPEN_RANGE_END
@e INFINITE_RANGE_END
@e EMPTY_RANGE_END

=
typedef struct range_end {
	int end_type;
	struct semantic_version_number end_value;
} range_end;

typedef struct semver_range {
	struct range_end lower;
	struct range_end upper;
	MEMORY_MANAGEMENT
} semver_range;

@ As hinted above, the notation |[| and |]| is used for closed ends, and |(|
and |)| for open ones.

=
void VersionNumberRanges::write_range(OUTPUT_STREAM, semver_range *R) {
	if (R == NULL) internal_error("no range");
	switch(R->lower.end_type) {
		case CLOSED_RANGE_END: WRITE("[%v,", &(R->lower.end_value)); break;
		case OPEN_RANGE_END: WRITE("(%v,", &(R->lower.end_value)); break;
		case INFINITE_RANGE_END: WRITE("(-infty,"); break;
		case EMPTY_RANGE_END: WRITE("empty"); break;
	}
	switch(R->upper.end_type) {
		case CLOSED_RANGE_END: WRITE("%v]", &(R->upper.end_value)); break;
		case OPEN_RANGE_END: WRITE("%v)", &(R->upper.end_value)); break;
		case INFINITE_RANGE_END: WRITE("infty)"); break;
	}
}

@ The "allow anything" range runs from minus to plus infinity. Every version
number lies in this range.

=
semver_range *VersionNumberRanges::any_range(void) {
	semver_range *R = CREATE(semver_range);
	R->lower.end_type = INFINITE_RANGE_END;
	R->lower.end_value = VersionNumbers::null();
	R->upper.end_type = INFINITE_RANGE_END;
	R->upper.end_value = VersionNumbers::null();
	return R;
}

int VersionNumberRanges::is_any_range(semver_range *R) {
	if (R == NULL) return TRUE;
	if ((R->lower.end_type == INFINITE_RANGE_END) && (R->upper.end_type == INFINITE_RANGE_END))
		return TRUE;
	return FALSE;
}

@ The "compatibility" range for a given version lies at the heart of semver:
to be compatible with version |V|, version |W| must be of equal or greater
precedence, and must have the same major version number. For example,
for |2.1.7| the range will be |[2.1.7, 3-A)|, all versions at least 2.1.7 but
not as high as 3.0.0-A.

Note that |3.0.0-A| is the least precendent version allowed by semver with
major version 3. The |-| gives it lower precedence than all release versions of
3.0.0; the fact that upper case |A| is alphabetically the earliest non-empty
alphanumeric string gives it lower precendence than all other prerelease
versions.

=
semver_range *VersionNumberRanges::compatibility_range(semantic_version_number V) {
	semver_range *R = VersionNumberRanges::any_range();
	if (VersionNumbers::is_null(V) == FALSE) {
		R->lower.end_type = CLOSED_RANGE_END;
		R->lower.end_value = V;
		R->upper.end_type = OPEN_RANGE_END;
		semantic_version_number W = VersionNumbers::null();
		W.version_numbers[0] = V.version_numbers[0] + 1;
		W.prerelease_segments = NEW_LINKED_LIST(text_stream);
		ADD_TO_LINKED_LIST(I"A", text_stream, W.prerelease_segments);
		R->upper.end_value = W;
	}
	return R;
}

@ More straightforwardly, these ranges are for anything from V, or up to V,
inclusive:

=
semver_range *VersionNumberRanges::at_least_range(semantic_version_number V) {
	semver_range *R = VersionNumberRanges::any_range();
	R->lower.end_type = CLOSED_RANGE_END;
	R->lower.end_value = V;
	return R;
}

semver_range *VersionNumberRanges::at_most_range(semantic_version_number V) {
	semver_range *R = VersionNumberRanges::any_range();
	R->upper.end_type = CLOSED_RANGE_END;
	R->upper.end_value = V;
	return R;
}

@ Here we test whether V is at least a given end, and then at most:

=
int VersionNumberRanges::version_ge_end(semantic_version_number V, range_end E) {
	switch (E.end_type) {
		case CLOSED_RANGE_END:
			if (VersionNumbers::is_null(V)) return FALSE;
			if (VersionNumbers::ge(V, E.end_value)) return TRUE;
			break;
		case OPEN_RANGE_END:
			if (VersionNumbers::is_null(V)) return FALSE;
			if (VersionNumbers::gt(V, E.end_value)) return TRUE;
			break;
		case INFINITE_RANGE_END: return TRUE;
		case EMPTY_RANGE_END: return FALSE;
	}
	return FALSE;
}

int VersionNumberRanges::version_le_end(semantic_version_number V, range_end E) {
	switch (E.end_type) {
		case CLOSED_RANGE_END:
			if (VersionNumbers::is_null(V)) return FALSE;
			if (VersionNumbers::le(V, E.end_value)) return TRUE;
			break;
		case OPEN_RANGE_END:
			if (VersionNumbers::is_null(V)) return FALSE;
			if (VersionNumbers::lt(V, E.end_value)) return TRUE;
			break;
		case INFINITE_RANGE_END: return TRUE;
		case EMPTY_RANGE_END: return FALSE;
	}
	return FALSE;
}

@ This allows a simple way to write:

=
int VersionNumberRanges::in_range(semantic_version_number V, semver_range *R) {
	if (R == NULL) return TRUE;
	if ((VersionNumberRanges::version_ge_end(V, R->lower)) &&
		(VersionNumberRanges::version_le_end(V, R->upper))) return TRUE;
	return FALSE;
}

@ The following decides which end restriction is stricter: it returns 1
of |E1| is, -1 if |E2| is, and 0 if they are equally onerous.

The empty set is as strict as it gets: nothing qualifies.

Similarly, infinite ends are as relaxed as can be: everything qualifies.

And otherwise, we need to know which end we're looking at in order to decide:
a lower end of |[4, ...]| is stricter than a lower end of |[3, ...]|, but an
upper end of |[..., 4]| is not as strict as an upper end of |[..., 3]|. Where
the boundary value is the same, open ends are stricter than closed ends.

=
int VersionNumberRanges::stricter(range_end E1, range_end E2, int lower) {
	if ((E1.end_type == EMPTY_RANGE_END) && (E2.end_type == EMPTY_RANGE_END)) return 0;
	if (E1.end_type == EMPTY_RANGE_END) return 1;
	if (E2.end_type == EMPTY_RANGE_END) return -1;
	if ((E1.end_type == INFINITE_RANGE_END) && (E2.end_type == INFINITE_RANGE_END)) return 0;
	if (E1.end_type == INFINITE_RANGE_END) return -1;
	if (E2.end_type == INFINITE_RANGE_END) return 1;
	int c = VersionNumbers::cmp(E1.end_value, E2.end_value);
	if (c != 0) {
		if (lower) return c; else return -c;
	}
	if (E1.end_type == E2.end_type) return 0;
	if (E1.end_type == CLOSED_RANGE_END) return -1;
	return 1;
}

@ And so we finally arrive at the following, which intersects two ranges:
that is, it changes |R1| to the range of versions which lie inside both the
original |R1| and also |R2|. (This is used by Inbuild when an extension is
included in two different places in the source text, but with possibly
different version needs.) The return value is true if an actual change took
place, and false otherwise.

=
int VersionNumberRanges::intersect_range(semver_range *R1, semver_range *R2) {
	int lc = VersionNumberRanges::stricter(R1->lower, R2->lower, TRUE);
	int uc = VersionNumberRanges::stricter(R1->upper, R2->upper, FALSE);
	if ((lc >= 0) && (uc >= 0)) return FALSE;
	if (lc < 0) R1->lower = R2->lower;
	if (uc < 0) R1->upper = R2->upper;
	if (R1->lower.end_type == EMPTY_RANGE_END) R1->upper.end_type = EMPTY_RANGE_END;
	else if (R1->upper.end_type == EMPTY_RANGE_END) R1->lower.end_type = EMPTY_RANGE_END;
	else if ((R1->lower.end_type != INFINITE_RANGE_END) && (R1->upper.end_type != INFINITE_RANGE_END)) {
		int c = VersionNumbers::cmp(R1->lower.end_value, R1->upper.end_value);
		if ((c > 0) ||
			((c == 0) && ((R1->lower.end_type == OPEN_RANGE_END) ||
				(R1->upper.end_type == OPEN_RANGE_END)))) {
			R1->lower.end_type = EMPTY_RANGE_END; R1->upper.end_type = EMPTY_RANGE_END;
		}
	}
	return TRUE;
}
