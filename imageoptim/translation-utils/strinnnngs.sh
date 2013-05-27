#!/usr/bin/env bash

# ensure all vars are initialised
set -o nounset

me=$(basename ${BASH_SOURCE[0]})

currDir="$(basename "$PWD")"

if [ $currDir != "translation-utils" ]; then
	printf "$(tput setaf 1)x %s$(tput sgr0)\n" "In the wrong directory, must be in translation-utils"
	exit 1;
fi

source utils.sh

# Display usage information
function usage {
  e_header  "Usage: $me [arg]"
  echo ""
  echo "Options:"
  echo ""
  echo "  -i, --init            Create initial xib strings files. This will overwrite MainMenu.strings and Prefs.strings."
  echo "  -t, --translate       Get updates from Transifex and use ibtool to create new xib files. Defaults to just new files. See -f."
  echo "  -u, --upload          DISABLED! Upload strings files to Transifex"
  echo "  -d, --diffs           See if there are any diffs between Transifex and the local project"
  echo "  -f, --force           Same as -t BUT forces ALL languages and resources to be updated. EASY NOW."
  echo "  -s, --source          DISABLED! Same as -u BUT also uploads the SOURCE English files - and OVERWRITES them. EASY NOW."
  echo "  -h, --help            Output usage information"

}

# need to cd .. 
cd ..

# quick arg check
if [[ $# == 0  || "$1" == --help  || "$1" == -h ]] 
then
	usage
	exit
fi

# set logfile name
LOGFILE_PREFIX=tx-`date +%Y-%m-%d`
LOGFILE_SUFFIX=log

logCount=$(ls -l . | egrep -c "$LOGFILE_PREFIX.*\.$LOGFILE_SUFFIX"  | tr -d '\n')

LOGFILE="$LOGFILE_PREFIX.$logCount.$LOGFILE_SUFFIX"

if [ -z "$LOGFILE" ]
then
	LOGFILE="$LOGFILE_PREFIX.$LOGFILE_SUFFIX"
  	e_warning "LOGFILE not set, defaulting to $LOGFILE" 
fi  

e_success "Logging to $LOGFILE"

# global vars - yeah
# not sure if we should include en yet
# excluding for the moment
# could probably put this somewhere else, not always used.
declare -a transifexLangs=($(tx status | grep -v "en:"  | awk '{ print $2}' | grep '^[a-z]' | tr -d ":" | sort | uniq | sed "s/_CN$/\-Hant/" | sed "s/_GB$/\-GB/" | sed "s/_LT$/\-LT/" | sed "s/_BR$/\-BR/"))
declare -a localLangs=($(ls -d *.lproj | grep -v en.l | cut -d "." -f 1))


function count_transifex_langs () {
	
	echo ${#transifexLangs[@]}
}

function count_local_langs () {

	echo ${#localLangs[@]} 
}

function uploadToTX {


	e_error "Uploading to Transifex is DISABLED. " | tee -a $LOGFILE 

	exit;

	e_header "Uploading to Transifex" | tee -a $LOGFILE 

	if [ "${sourceFiles:-unset}" = -s ]; then
		seek_confirmation "Are you sure you want to upload the SOURCE files?"
		if ! is_confirmed; then
			e_error "ABORTING source upload. Use -u to just upload new translations." | tee -a $LOGFILE 
			exit;
		else
			echo "Uploading new translations AND SOURCE files to Transifex..." | tee -a $LOGFILE 
		fi
	else
		echo "Just uploading new files to Transifex..." | tee -a $LOGFILE 
	fi

	tx push -t ${sourceFiles:- } 2>&1 | tee -a $LOGFILE 

	#declare -a updatedFiles=($(grep "\->" $LOGFILE | cut -d ":" -f 2))

	#fileCount=${#updatedFiles[@]}

}

function init {

	e_header "Generating strings files from XIBs using ibtool"

	for dir in $(ls -d *.lproj | grep -v en.)
	do
		echo $dir
		
		#hmmmm ... might not need to convert to UTF-8. Transifex uses UTF-16

		# dont use -f utf-16le -t utf-8 as this creates a UTF-8 file with a BOM
		ibtool --generate-strings-file $dir/MainMenu.strings $dir/MainMenu.xib
		#iconv -f utf-16 -t utf-8 $dir/MainMenu.strings > $dir/MainMenu.strings.utf8
		#mv  $dir/MainMenu.strings.utf8 $dir/MainMenu.strings

		ibtool --generate-strings-file $dir/Prefs.strings $dir/PrefsController.xib
		#iconv -f utf-16 -t utf-8 $dir/Prefs.strings > $dir/Prefs.strings.utf8
		#mv  $dir/Prefs.strings.utf8 $dir/Prefs.strings

		# this might not be needed
		#iconv -f utf-8 -t utf-8 $dir/Help/index.html > $dir/Help/index.html.utf8
		#mv $dir/Help/index.html.utf8 $dir/Help/index.html

		#iconv -f utf-8 -t utf-8 $dir/Help/prefs.html > $dir/Help/prefs.html.utf8
		#mv $dir/Help/prefs.html.utf8 $dir/Help/prefs.html

		# Transifex doesn't take RTF, so convert to HTML
		#textutil -convert html $dir/Credits.rtf

	done 

	e_success "Generating Localizable.strings in en.lproj"
	genstrings -o en.lproj/ *.m

}

function getDiffs {

	localizedDirsCount=$(count_local_langs)

	transifexLangsCount=$(count_transifex_langs)

	if [ $localizedDirsCount -lt $transifexLangsCount ]; then
		echo 1
	elif [ $localizedDirsCount -gt $transifexLangsCount ]; then
		echo 2
	fi
}

function doDiffs {

	for xx in ${!transifexLangs[*]}; do
		match=0
		for yy in ${!localLangs[*]}; do
	    # see if the two variables match:
	    if [[ ${transifexLangs[xx]} = ${localLangs[yy]} ]]; then
	    	match=1
	      	# if so, add them into an array to print at the end.
	      	common+=( ${localLangs[yy]} )
	      fi
	  done

	  if [ $match -eq 0 ]; then
	  	#echo "${localLangs[yy]} = ${transifexLangs[xx]}"
	  	diffs+=( ${transifexLangs[xx]} )
	  fi
	done

	#echo "Common: ${common[*]}"

	if [[ ${diffs[@]:-notset} = notset ]]
	then
		e_error "No diffs - strange. Investigate." | tee -a $LOGFILE 
	else
		echo "Diffs: ${diffs[*]}" | tee -a $LOGFILE 
	fi  

}

function listDiffs () {

	e_header "Checking for diffs" | tee -a $LOGFILE 

	diffType=$(getDiffs)

	if [ -z "$diffType" ]
	then
	  	e_success "No new local or remote languages" | tee -a $LOGFILE 
	fi  

	if [[ $diffType -eq 1 ]]; then
		e_warning "Transifex has more languages to download" | tee -a $LOGFILE 
		doDiffs
		echo "Execute: $me updateFromTX [lang.lproj folders will be created]" | tee -a $LOGFILE 

	fi
	if [[ $diffType -eq 2 ]]; then
		e_warning "Transifex has LESS languages than Xcode project" | tee -a $LOGFILE 
		doDiffs
		echo "Update .tx/config and then execute: $me updateTX" | tee -a $LOGFILE 
	fi
}

# probably not needed 
function convertToUTF8() {

    declare -a filesToCheck=("${!1}")

	e_header "Converting any UTF-16 encoded files to UTF8" | tee -a $LOGFILE 

    for xx in ${!filesToCheck[*]}; do

		# the file command can sometimes return an error
		# so we can't use: encType=$(file -I  ${filesToCheck[xx]} | awk '{ print $3 }' | cut -d "=" -f 2)
		# instead get the full output from file..
		tempEnc=$(file -I  ${filesToCheck[xx]})

		# and take the right sustring after charset=
		encType=${tempEnc#*charset=}

		if [[ "$encType" =~ ^utf-16 ]]; 
		then
			echo -n  "${filesToCheck[xx]} is: " | tee -a $LOGFILE 
			echo $encType | tee -a $LOGFILE 
			iconv -f $encType -t utf8 ${filesToCheck[xx]} > ${filesToCheck[xx]}.utf8
			
			RC=$?

        	if [ $RC -ne 0 ] 
        	then
        		e_error "Could not convert ${filesToCheck[xx]} from $encType to utf-8" | tee -a $LOGFILE 

        		if file_exists "${filesToCheck[xx]}.utf8"; 
        		then
        			echo "Deleting ${filesToCheck[xx]}.utf8" | tee -a $LOGFILE 
        			rm "${filesToCheck[xx]}.utf8"
        		fi
        	else
        		# iconv on my Mac creates UTF-8 files with a BOM, not sure why.
				# there should not be a BOM in a UTF-8 file: http://www.unicode.org/versions/Unicode6.0.0/ch02.pdf
				# bottom of page 30: Use of a BOM is neither required nor recommended for UTF-8
        		if file_has_bom "${filesToCheck[xx]}.utf8" ; then
    				echo "File has BOM, removing" | tee -a $LOGFILE 
    				tail -c +4 ${filesToCheck[xx]}.utf8 > ${filesToCheck[xx]}
    				rm "${filesToCheck[xx]}.utf8"
    			else
					echo "Moving ${filesToCheck[xx]}.utf8 to ${filesToCheck[xx]}" | tee -a $LOGFILE 
					mv ${filesToCheck[xx]}.utf8 ${filesToCheck[xx]}
				fi
			fi
		fi
	done

	echo "Checking for errors" | tee -a $LOGFILE 

    for xx in ${!filesToCheck[*]}; do
    	if file_has_error "${filesToCheck[xx]}" ; then
    		e_error "${filesToCheck[xx]} has errors. Investigate." | tee -a $LOGFILE 
    		echo "could prob do:"  | tee -a $LOGFILE  
    		echo "tail -c +5 ${filesToCheck[xx]} > ${filesToCheck[xx]}.nobom"  | tee -a $LOGFILE 
    		echo "mv -f ${filesToCheck[xx]}.nobom ${filesToCheck[xx]}" | tee -a $LOGFILE 
    	fi
	done
}


function updateFromTX {

	e_header "Updating local files from Transifex"

	if [ "${force:-unset}" = -f ]; then
		seek_confirmation "Are you sure you want to overwrite ALL files?"
		if ! is_confirmed; then
			e_error "ABORTING force overwrite." | tee -a $LOGFILE 
			exit;
		else
			echo "Force downloading ALL files from Transifex..." | tee -a $LOGFILE 
		fi
	else
		echo "Just downloading new files from Transifex..." | tee -a $LOGFILE 
	fi

	tx pull ${force:- } 2>&1 | tee -a $LOGFILE 

	declare -a updatedFiles=($(grep "\->" $LOGFILE | cut -d ":" -f 2))

	fileCount=${#updatedFiles[@]}

    if [ $fileCount = "0" ]; then
		e_success "No updated files. Finisssssss." | tee -a $LOGFILE 
    else
 		e_success "Updated files:" | tee -a $LOGFILE 
		for xx in ${!updatedFiles[*]}; do
			echo ${updatedFiles[xx]} | tee -a $LOGFILE 
		done

		# we no longer need this. UTF-16 is the way to go. Maybe.
		#convertToUTF8 updatedFiles[@] 

		createNewXibs updatedFiles[@]
	fi
}

function createNewXibs {
    
	declare -a filesToCheck=("${!1}")

	e_header "Creating new XIBs from strings files" | tee -a $LOGFILE 

    for xx in ${!filesToCheck[*]}; do

		if [[ "${filesToCheck[xx]}" =~ MainMenu.strings ]] ; 
		then
			#echo " need to ibtool ${filesToCheck[xx]}"
			mmXibPref=${filesToCheck[xx]%.*strings}
			mmXibNew="$mmXibPref.NEW.xib"
			mmXib="$mmXibPref.xib"
			# take a copy of orig in case we need to use the en.lproj default
			mmXibOrig="$mmXibPref.xib"

			#echo "mmXibPref = $mmXibPref"  | tee -a $LOGFILE 
			#echo "mmXibNew = $mmXibNew"  | tee -a $LOGFILE 

			if ! file_exists "$mmXib"; then
				e_warning "$mmXib does not exist, using default en.lproj" | tee -a $LOGFILE 
				mmXib="en.lproj/MainMenu.xib"
			fi

			echo "commm is: ibtool --strings-file ${filesToCheck[xx]} --write $mmXibNew $mmXib"  | tee -a $LOGFILE 
			ibtool --strings-file ${filesToCheck[xx]} --write $mmXibNew $mmXib
			mv $mmXibNew $mmXibOrig

		fi

		if [[ "${filesToCheck[xx]}" =~ Prefs.strings ]] ; 
		then
			#echo " need to ibtool ${filesToCheck[xx]}"
			prefXibPref=${filesToCheck[xx]%Prefs.strings}
			prefXibNew="${prefXibPref}PrefsController.NEW.xib"
			prefXib="${prefXibPref}PrefsController.xib"
			prefXibOrig="${prefXibPref}PrefsController.xib"

			#echo "prefXibPref = $prefXibPref"  | tee -a $LOGFILE 
			#echo "prefXibNew = $prefXibNew"  | tee -a $LOGFILE 

			if ! file_exists "$prefXib"; then
				e_warning "$prefXib does not exist, using default en.lproj" | tee -a $LOGFILE 
				prefXib="en.lproj/PrefsController.xib"
			fi

			echo "commm is: ibtool --strings-file ${filesToCheck[xx]} --write $prefXibNew $prefXib"  | tee -a $LOGFILE 
			ibtool --strings-file ${filesToCheck[xx]} --write $prefXibNew $prefXib
			mv $prefXibNew $prefXibOrig
		fi
	done

	e_success "New XIBs created. Please ensure you build and manually check in Xcode." | tee -a $LOGFILE 

}

# actual start
# check opts and call function...
for opt in $@
do
    case $opt in
        -i | --init) init ;;
        -t | --translate) updateFromTX ;;
        -u | --upload) uploadToTX ;;
        -d | --diffs) listDiffs ;;
        -f | --force) force=-f && updateFromTX ;;
        -s | --source) sourceFiles=-s && uploadToTX ;;
        -h | --help) usage ;;
        -*|--*) e_warning "Warning: invalid option $opt"  && usage;;
    esac
done

exit;


