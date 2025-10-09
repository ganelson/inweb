echo "(A script to make a first build of Inweb)"

PLATFORM="$1"

if [ "$PLATFORM" = "" ]; then
	echo "This script needs a parameter for the platform you are working on: macos, macos32, macosarm, macosuniv, linux, windows, unix"
	exit 1
fi

echo "(You have chosen the platform '$PLATFORM')"

echo "(Step 1 of 4: copying the platform settings)"
if ! ( cp -f inweb/Materials/platforms/$PLATFORM.mk inweb/platform-settings.mk; ) then
	echo "(Okay, so that failed. Is this a platform supported by Inweb?)"
	exit 1
fi

echo "(Step 2 of 4: copying the right flavour of inweb.mk)"
if ! ( cp -f inweb/Materials/platforms/inweb-on-$PLATFORM.mk inweb/inweb.mk; ) then
	echo "(Okay, so that failed. Is this a platform supported by Inweb?)"
	exit 1
fi

echo "(Step 3 of 4: building inweb from its ready-tangled form)"
if ! ( make -f inweb/inweb.mk initial; ) then
	echo "(Okay, so that failed. Maybe your environment doesn't have the compilers anticipated?)"
	exit 1
fi

XPATH="$(shell pwd)/inweb/Tangled"

echo "(Step 4 of 4: adding the executable's path '$XPATH' to your PATH)"
if ! ( export PATH=($XPATH:$PATH; ) then
	echo "(Okay, so that failed. I've no idea why.)"
	exit 1
fi

echo "(Done!)"
