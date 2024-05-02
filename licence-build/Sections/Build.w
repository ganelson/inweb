[Main::] Build.

The whole utility in one tool.

@h Main routine.

@d PROGRAM_NAME "licence-build"

@e FROM_CLSW

=
int main(int argc, char **argv) {
	Foundation::start(argc, argv);
	CommandLine::declare_heading(U"licence-build: process JSON licence-list data\n");

	CommandLine::declare_switch(FROM_CLSW, U"from", 2,
		U"use data in file X");

	CommandLine::read(argc, argv, NULL, &Main::respond, &Main::ignore);
	Foundation::end();
	return 0;
}

void Main::respond(int id, int val, text_stream *arg, void *state) {
	switch (id) {
		case FROM_CLSW: Main::process_JSON(Filenames::from_text(arg)); break;
	}
}

void Main::ignore(int id, text_stream *arg, void *state) {
	Errors::fatal("only switches may be used at the command line");
}

void Main::process_JSON(filename *F) {
	TEMPORARY_TEXT(json)
	TextFiles::write_file_contents(json, F);
	text_file_position tfp = TextFiles::at(F, 1);
	JSON_value *obj = JSON::decode(json, &tfp);
	DISCARD_TEXT(json)

	JSON_value *licences_list = JSON::look_up_object(obj, I"licenses");
	JSON_value *version = JSON::look_up_object(obj, I"licenseListVersion");
	JSON_value *date = JSON::look_up_object(obj, I"releaseDate");
	if (licences_list == NULL) Errors::fatal("JSON object has no licenses field");
	if (version == NULL) Errors::fatal("JSON object has no licenseListVersion field");
	if (date == NULL) Errors::fatal("JSON object has no releaseDate field");

	PRINT("[SPDXLicences:"); PRINT(":] SPDX Licenses.\n\n");
	PRINT("This section was mechanically generated from the JSON file provided by\n");
	PRINT("https://spdx.org/licenses/. The version used was %S, dated %S.\n\n",
		version->if_string, date->if_string);
	PRINT("@h Raw data.\nEmbedding the data this way avoids processing a JSON file on each\n");
	PRINT("run of any of our tools.\n\n=\nvoid SPDXLicences:"); PRINT(":create(void) {\n");
	JSON_value *licence;
	LOOP_OVER_LINKED_LIST(licence, JSON_value, licences_list->if_list) {
		JSON_value *id = JSON::look_up_object(licence, I"licenseId");
		JSON_value *deprecated_field = JSON::look_up_object(licence, I"isDeprecatedLicenseId");
		JSON_value *name_field = JSON::look_up_object(licence, I"name");
		PRINT("\tLicenceData:"); PRINT(":new_licence(I\"%S\",\n", id->if_string);
		PRINT("\t\tI\"");
		LOOP_THROUGH_TEXT(pos, name_field->if_string) {
			inchar32_t c = Str::get(pos);
			if (c == '"') PUT_TO(STDOUT, '\'');
			else PUT_TO(STDOUT, Characters::remove_accent(c));
		}
		PRINT("\", %s);\n", (deprecated_field->if_boolean == TRUE)?"TRUE":"FALSE");
	}
	PRINT("}\n");
}
