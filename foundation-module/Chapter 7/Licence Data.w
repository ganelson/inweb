[LicenceData::] Licence Data.

Storing names and standard SPDX identifiers for common open source licences.

@ This is little more than a dictionary of IDs to records about the standard
set of open source licences maintained by SPDX.

=
typedef struct open_source_licence {
	struct text_stream *SPDX_id;
	struct text_stream *name;
	int deprecated;
	CLASS_DEFINITION
} open_source_licence;

dictionary *SPDX_licence_identifiers = NULL;

void LicenceData::new_licence(text_stream *id, text_stream *name, int deprecated) {
	open_source_licence *L = CREATE(open_source_licence);
	L->SPDX_id = Str::duplicate(id);
	L->name = Str::duplicate(name);
	L->deprecated = deprecated;
	if (SPDX_licence_identifiers == NULL)
		SPDX_licence_identifiers = Dictionaries::new(256, FALSE);
	Dictionaries::create(SPDX_licence_identifiers, L->SPDX_id);
	Dictionaries::write_value(SPDX_licence_identifiers, L->SPDX_id, L);
}

open_source_licence *LicenceData::from_SPDX_id(text_stream *id) {
	if (SPDX_licence_identifiers == NULL) return NULL;
	if (Dictionaries::find(SPDX_licence_identifiers, id) == NULL) return NULL;
	return Dictionaries::read_value(SPDX_licence_identifiers, id);
}
