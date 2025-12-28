[InwebMap::] inweb map Subcommand.

The inweb inspect subcommand describes a web or other resource without changing it.

@ The command line interface and help text:

@e MAP_CLSUB
@e MAP_FULLY_CLSW

=
void InwebMap::cli(void) {
	CommandLine::begin_subcommand(MAP_CLSUB, U"map");
	CommandLine::declare_heading(
		U"Usage: inweb map [WEB | FILE]\n\n"
		U"Shows a sitemap for the website which is (or would be) woven from the "
		U"colony of the WEB, or the colony whose colony file is FILE.");

	CommandLine::declare_boolean_switch(MAP_FULLY_CLSW, U"fuller", 1,
		U"draw up a larger map (may take some time)", FALSE);

	CommandLine::end_subcommand();
}

@ Changing the settings:

=
typedef struct inweb_map_settings {
	int full;
} inweb_map_settings;

void InwebMap::initialise(inweb_map_settings *ims) {
	ims->full = FALSE;
}

int InwebMap::switch(inweb_instructions *ins, int id, int val, text_stream *arg) {
	inweb_map_settings *ims = &(ins->map_settings);
	switch (id) {
		case MAP_FULLY_CLSW: ims->full = val; return TRUE;
	}
	return FALSE;
}

@ In operation:

=
void InwebMap::run(inweb_instructions *ins) {
	inweb_map_settings *ims = &(ins->map_settings);
	inweb_operand op = Configuration::operand(ins, WEB_OPERAND_ALLOWED, FALSE, FALSE);
	if (op.C == NULL) Errors::fatal("inweb map must be applied to a colony");
	Colonies::write_map(STDOUT, op.C, ims->full);
}
