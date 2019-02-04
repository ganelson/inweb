[SoundFiles::] Sound Durations.

These utility routines look at the headers of AIFF, OGG Vorbis or MIDI files
to find the durations, and verify that they are what they purport to be.

@h AIFF files.
The code in this section was once again originated by Toby Nelson. To
explicate the following, see the specifications for AIFF and OGG headers.
Durations are measured in centiseconds.

=
int SoundFiles::get_AIFF_duration(FILE *pFile, unsigned int *pDuration,
	unsigned int *pBitsPerSecond, unsigned int *pChannels, unsigned int *pSampleRate) {
    unsigned int sig;
    unsigned int chunkID;
    unsigned int chunkLength;
    unsigned int numSampleFrames;
    unsigned int sampleSize;

    if (!BinaryFiles::read_int32(pFile, &sig)) return FALSE;
    if (sig != 0x464F524D) return FALSE; /* |"FORM"| indicating an IFF file */

    if (!BinaryFiles::read_int32(pFile, &sig)) return FALSE;

    if (!BinaryFiles::read_int32(pFile, &sig)) return FALSE;
    if (sig != 0x41494646) return FALSE; /* |"AIFF"| indicating an AIFF file */

    /* Read chunks, skipping over those we are not interested in */
    while (TRUE) {
        if (!BinaryFiles::read_int32(pFile, &chunkID)) return FALSE;
        if (!BinaryFiles::read_int32(pFile, &chunkLength)) return FALSE;

        if (chunkID == 0x434F4D4D) { /* |"COMM"| indicates common AIFF data */
            if (chunkLength < 18) return FALSE; /* Check we have enough data to read */

            if (!BinaryFiles::read_int16(pFile, pChannels))          return FALSE;
            if (!BinaryFiles::read_int32(pFile, &numSampleFrames))  return FALSE;
            if (!BinaryFiles::read_int16(pFile, &sampleSize))       return FALSE;
            if (!BinaryFiles::read_float80(pFile, pSampleRate))      return FALSE;

            if (*pSampleRate == 0) return FALSE; /* Sanity check to avoid a divide by zero */

            /* Result is in centiseconds */
            *pDuration = (unsigned int) (((unsigned long long) numSampleFrames * 100) / *pSampleRate);
            *pBitsPerSecond = *pSampleRate * *pChannels * sampleSize;
            break;
        } else {
            /* Skip unwanted chunk */
            if (fseek(pFile, (long) chunkLength, SEEK_CUR) != 0) return FALSE;
        }
    }

	return TRUE;
}

@h OGG Vorbis files.

=
int SoundFiles::get_OggVorbis_duration(FILE *pFile, unsigned int *pDuration,
	unsigned int *pBitsPerSecond, unsigned int *pChannels, unsigned int *pSampleRate) {
    unsigned int sig;
    unsigned int version;
    unsigned int numSegments;
    unsigned int packetType;
    unsigned int vorbisSig1;
    unsigned int vorbisSig2;
    unsigned int seekPos;
    unsigned int fileLength, bytesToRead, lastSig, index;
    unsigned long long granulePosition;
    unsigned char buffer[256];

    if (!BinaryFiles::read_int32(pFile, &sig)) return FALSE;
    if (sig != 0x4F676753) return FALSE; /* |"OggS"| indicating an OGG file */

    /* Check OGG version is zero */
    if (!BinaryFiles::read_int8(pFile, &version)) return FALSE;
    if (version != 0) return FALSE;

    /* Skip header type, granule position, serial number, page sequence and CRC */
    if (fseek(pFile, 21, SEEK_CUR) != 0) return FALSE;

    /* Read number of page segments */
    if (!BinaryFiles::read_int8(pFile, &numSegments)) return FALSE;

    /* Skip segment table */
    if (fseek(pFile, (long) numSegments, SEEK_CUR) != 0) return FALSE;

    /* Vorbis Identification header */
    if (!BinaryFiles::read_int8(pFile, &packetType)) return FALSE;
    if (packetType != 1) return FALSE;

    if (!BinaryFiles::read_int32(pFile, &vorbisSig1)) return FALSE;
    if (vorbisSig1 != 0x766F7262) return FALSE;   /* |"VORB"| */

    if (!BinaryFiles::read_int16(pFile, &vorbisSig2)) return FALSE;
    if (vorbisSig2 != 0x6973) return FALSE;   /* |"IS"| */

    /* Check Vorbis version is zero */
    if (!BinaryFiles::read_int32(pFile, &version)) return FALSE;
    if (version != 0) return FALSE;

    /* Read number of channels */
    if (!BinaryFiles::read_int8(pFile, pChannels)) return FALSE;

    /* Read sample rate */
    if (!BinaryFiles::read_int32(pFile, pSampleRate)) return FALSE;
    BinaryFiles::swap_bytes32(pSampleRate);  /* Ogg Vorbis uses LSB first */

    /* Skip bitrate maximum */
    if (fseek(pFile, 4, SEEK_CUR) != 0) return FALSE;

    /* Read Nominal Bitrate */
    if (!BinaryFiles::read_int32(pFile, pBitsPerSecond)) return FALSE;
    BinaryFiles::swap_bytes32(pBitsPerSecond);  /* Ogg Vorbis uses LSB first */

    /* Encoders can be unhelpful and give no bitrate in the header */
    if (pBitsPerSecond == 0) return FALSE;

    /* Search for the final Ogg page (near the end of the file) to read duration, */
    /* i.e., read the last 4K of the file and look for the final |"OggS"| sig */
    if (fseek(pFile, 0, SEEK_END) != 0) return FALSE;
    fileLength = (unsigned int) ftell(pFile);
    if (fileLength < 4096) seekPos = 0;
    else seekPos = fileLength - 4096;

    lastSig = 0xFFFFFFFF;
    while (seekPos < fileLength) {
        if (fseek(pFile, (long) seekPos, SEEK_SET) != 0) return FALSE;
        bytesToRead = fileLength - seekPos;
        if (bytesToRead > 256) bytesToRead = 256;
        if (fread(buffer, 1, bytesToRead, pFile) != bytesToRead) return FALSE;

        for(index = 0; index < bytesToRead; index++) {
            if ((buffer[index] == 0x4F) &&
                (buffer[index + 1] == 0x67) &&
                (buffer[index + 2] == 0x67) &&
                (buffer[index + 3] == 0x53)) {
                lastSig = seekPos + index;
            }
        }

        /* Next place to read from is 256 bytes further on, but to catch */
        /* sigs that span between these blocks, read the last four bytes again */
        seekPos += 256 - 4;
    }

    if (lastSig == 0xFFFFFFFF) return FALSE;

    if (fseek(pFile, (long) lastSig, SEEK_SET) != 0) return FALSE;
    if (!BinaryFiles::read_int32(pFile, &sig)) return FALSE;
    if (sig != 0x4F676753) return FALSE; /* |"OggS"| indicating an OGG file */

    /* Check OGG version is zero */
    if (!BinaryFiles::read_int8(pFile, &version)) return FALSE;
    if (version != 0) return FALSE;

    /* Skip header Type */
    if (fseek(pFile, 1, SEEK_CUR) != 0) return FALSE;

    if (!BinaryFiles::read_int64(pFile, &granulePosition)) return FALSE;
    BinaryFiles::swap_bytes64(&granulePosition);

    *pDuration = (unsigned int) ((granulePosition * 100) /
			    	(unsigned long long) *pSampleRate);

    return TRUE;
}

@h MIDI files.
At one time it was proposed that Inform 7 should allow a third sound file
format: MIDI. This provoked considerable debate in July 2007 and enough
doubts were raised that the implementation below was never in fact
officially used. It is preserved here in case we ever revive the issue.

Inform is not really able to decide this for itself, in any case, since
it can only usefully provide sound files which the virtual machines it
compiles for will allow. At present, the Glulx virtual machine does not
officially support MIDI, which makes the question moot.

=
int SoundFiles::get_MIDI_information(FILE *pFile, unsigned int *pType,
	unsigned int *pNumTracks) {
    unsigned int sig;
    unsigned int length;
    unsigned int pulses;
    unsigned int frames_per_second;
    unsigned int subframes_per_frame;
    unsigned int clocks_per_second;
    unsigned int start_of_chunk_data;
    unsigned int status;
    unsigned int clocks;
    unsigned int sysex_length;
    unsigned int non_midi_event_length;
    unsigned int start_of_non_midi_data;
    unsigned int non_midi_event;

    if (!BinaryFiles::read_int32(pFile, &sig)) return FALSE;

    /* |"RIFF"| indicating a RIFF file */
    if (sig == 0x52494646) {
        /* Skip the filesize and typeID */
        if (fseek(pFile, 8, SEEK_CUR) != 0) return FALSE;

        /* now read the real MIDI sig */
        if (!BinaryFiles::read_int32(pFile, &sig)) return FALSE;
    }

    /* |"MThd"| indicating a MIDI file */
    if (sig != 0x4D546864) return FALSE;

    /* Read length of chunk */
    if (!BinaryFiles::read_int32(pFile, &length)) return FALSE;

    /* Make sure we have enough data to read */
    if (length < 6) return FALSE;

    /* Read the MIDI type: 0,1 or 2 */
    /*   0 means one track containing up to 16 channels to make a single tune */
    /*   1 means one or more tracks, commonly each with a single channel, making up a single tune */
    /*   2 means one or more tracks, where each is a separate tune in it's own right */
    if (!BinaryFiles::read_int16(pFile, pType)) return FALSE;

    /* Read the number of tracks */
    if (!BinaryFiles::read_int16(pFile, pNumTracks)) return FALSE;

    /* Read "Pulses Per Quarter Note" (PPQN) */
    if (!BinaryFiles::read_int16(pFile, &pulses)) return FALSE;

    /* if top bit set, then number of subframes per second can be deduced */
    if (pulses >= 0x8000) {
        /* First byte is a negative number for the frames per second */
        /* Second byte is the number of subframes in each frame */
        frames_per_second    = (256 - (pulses & 0xff));
        subframes_per_frame  = (pulses >> 8);
        clocks_per_second    = frames_per_second * subframes_per_frame;
        LOG("frames_per_second   = %d\n",   frames_per_second);
        LOG("subframes_per_frame = %d\n", subframes_per_frame);
        LOG("clocks_per_second   = %d\n",   clocks_per_second);

        /* Number of pulses per quarter note unknown */
        pulses = 0;
    } else {
        /* unknown values */
        frames_per_second    = 0;
        subframes_per_frame  = 0;
        clocks_per_second    = 0;
        LOG("pulses per quarter note = %d\n",   pulses);
    }

    /* Skip any remaining bytes in the MThd chunk */
    if (fseek(pFile, (long) (length - 6), SEEK_CUR) != 0) return FALSE;

    /* Keep reading chunks, looking for |"MTrk"| */
    do {
        /* Read chunk signature and length */
        if (!BinaryFiles::read_int32(pFile, &sig)) {
            if (feof(pFile)) return TRUE;
            return FALSE;
        }
        if (!BinaryFiles::read_int32(pFile, &length)) return FALSE;

        start_of_chunk_data = (unsigned int) ftell(pFile);

        if (sig == 0x4D54726B) { /* |"MTrk"| */
            LOG("track starts\n");
            /* Read each event, looking for information before the real tune starts, e.g., tempo */
            do {
                /* Read the number of clocks since the previous event */
                if (!BinaryFiles::read_variable_length_integer(pFile, &clocks))
                	return FALSE;

                /* We bail out when the track starts */
                if (clocks > 0) break;

                /* Read the MIDI Status byte */
                if (!BinaryFiles::read_int8(pFile, &status)) return FALSE;

                /* Start or continuation of system exclusive data */
                if ((status == 0xF0) || (status == 0xF7)) {
                    /* Read length of system exclusive event data */
                    if (!BinaryFiles::read_variable_length_integer(pFile, &sysex_length)) return FALSE;

                    /* Skip sysex event */
                    if (fseek(pFile, (long) sysex_length, SEEK_CUR) != 0) return FALSE;
                } else if (status == 0xFF) { /* Non-MIDI event */
                    /* Read the Non-MIDI event type and length */
                    if (!BinaryFiles::read_int8(pFile, &non_midi_event)) return FALSE;
                    if (!BinaryFiles::read_variable_length_integer(pFile, &non_midi_event_length))
                    	return FALSE;

                    start_of_non_midi_data = (unsigned int) ftell(pFile);

                    switch(non_midi_event) {
                        case 0x01: /* Comment text */
                        case 0x02: /* Copyright text */
                        case 0x03: /* Track name */
                        case 0x04: { /* Instrument name */
                            char text[257];
                            if (!BinaryFiles::read_string(pFile, text, non_midi_event_length))
                            	return FALSE;
                            LOG("%d: %s\n", non_midi_event, text);
                            break;
                        }

                        case 0x51: /* Tempo change */
                        case 0x58: /* Time signature */
                        case 0x59: /* Key signature */
							break;
                    }

                    /* Skip non-midi event */
                    if (fseek(pFile,
                    	(long) (start_of_non_midi_data + non_midi_event_length), SEEK_SET) != 0)
                    	return FALSE;
                } else {
                    /* Real MIDI data found: we've read all we can so bail out at this point */
                    break;
                }
            }
            while (TRUE);
        }

        /* Seek to start of next chunk */
        if (fseek(pFile, (long) (start_of_chunk_data + length), SEEK_SET) != 0) return FALSE;

        /* Reached end of file */
        if (feof(pFile)) return TRUE;

        /* Did we try to seek beyond the end of the file? */
        unsigned int position_in_file = (unsigned int) ftell(pFile);
        if (position_in_file < (start_of_chunk_data + length)) return TRUE;
    }
    while (TRUE);

    return TRUE;
}
