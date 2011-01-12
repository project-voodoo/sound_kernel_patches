#!/bin/bash
# see README for usage

my_pwd=`dirname $(readlink -f $0)`

# parse command line options
while getopts "m:s:d:" opt
do
	case "$opt" in
		m) method="$OPTARG";;
		s) patchs_source=`readlink -f "$my_pwd/$OPTARG"`;;
		d) dest_kernel=`readlink -f "$OPTARG"`;;
	esac
done

patch_apply()
{
	cd $dest_kernel || exit 1
	for x in $patchs_source/*.patch; do
		echo -e "for $x:"

		if patch -p1 --forward --dry-run < "$x" > /dev/null 2>&1; then 
			patch -p1 --forward --reject-file=- < "$x"
		else
			echo "patch does not apply: is probably already applied"
		fi
		echo 
	done
}

apply()
{
	if test "$method" = git; then
		test_patch() { git apply --check $1 ;}
		merge_patch() { git am $1 ;}
	else
		test_patch() { patch -p1 --dry-run -i $1 ;}
		merge_patch() { patch -p1 < $1 ;}
	fi
	
	cd $dest_kernel || exit 1
	for x in $versions_to_apply; do
		echo -e "\n=== Applying version $x patches ===\n"
		for y in `ls $patchs_source/v$x/*.patch 2>/dev/null`; do
			echo -e "for $y:"
			if output=`test_patch $y 2>&1`; then 
				merge_patch "$y"
				echo -e "  success !\n"
			else
				echo "$output"
				error_with_message "\nthis patch doesn't apply, you will need to merge it manually.\nexiting."
			fi
		done
	done
}

error_with_message()
{
	echo -e "$1"
	echo
	exit 1
}


echo -e "\nScript directory:	$my_pwd"
echo "Method:			$method"
echo "Patchs source:		$patchs_source"
echo "Kernel directory:	$dest_kernel"

if test "$method" != "git" && test "$method" != "patch"; then
	error_with_message "Please specify a method to apply Voodoo sound patches: -m git or -m patch"
fi

if test "$method" = git; then
	# make sure git is installed
	git > /dev/null 2>&1
	returncode=$?
	if test "$returncode" = 127 || test "$returncode" = 126; then
		error_with_message "git is not installed but required"
	fi
fi

if ! test -n "$patchs_source" || ! test -d "$patchs_source"; then
	error_with_message "Please specify a patch source name: -s patchs-for-your-kernel"
fi
if ! test -n "$dest_kernel" || ! test -d "$dest_kernel"; then
	error_with_message "Please specify a kernel source directory: -d your/kernel/tree"
fi

# read the Voodoo sound current version in kernel
version=`grep "#define VOODOO_SOUND_VERSION 1" Kernel/sound/soc/codecs/wm8994_voodoo.c 2>/dev/null | cut -d' ' -f3`
patches_version=`ls -1v $patchs_source | tail -1 | tr -d v`

versions_to_apply=`seq -s ' ' $((version + 1)) $patches_version`

test -n "$version" || version=0
echo -e "\nVoodoo sound versions:"
echo "  in sources = $version"
echo "  in patches = $patches_version"
echo "  to apply   = $versions_to_apply"

apply

