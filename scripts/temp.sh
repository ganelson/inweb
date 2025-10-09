XPATH="$PWD/inweb/Tangled"
PATH="$XPATH:$PATH"
echo $PATH

echo "(Step 4 of 4: adding the executable's path '$XPATH' to your PATH)"
export PATH="$PATH";
if ! ( export PATH="$PATH"; ) then
	echo "(Okay, so that failed. I've no idea why.)"
	exit 1
fi
echo $PATH
echo "(Done!)"
