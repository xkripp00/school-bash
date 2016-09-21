#!/bin/bash

##############################
#      IOS - Projekt 1       #
#----------------------------#
# vypracoval: Martin Krippel #
# login: xkripp00            #
##############################

LC_ALL=C
export LC_ALL

EC=0

## help
function help ()
{
	echo "Usage: $0 [-vtrsc] TEST_DIR [REGEX]"
	echo ""
	echo "	-v  validate tree"
	echo "	-t  run tests"
	echo "	-r  report results"
	echo "	-s  synchronize expected results"
	echo "	-c  clear generated files"
	echo ""
    echo "	It is mandatory to supply at least one option."
}

function v_adresare ()		## funkcia volana pri prepinaci v, kontrole ci su splnene podmienky pre adresare
{
	d=0
	f=0
	L=0
	cmdg=0
	
	for i in $( ls ); do
		if [ -d $i ];then	## existencia adresarov
			d=1
		fi
		
		if [ -f $i ];then	## existencia suborov + praca so subormi
			f=1
			
			if [ $i = cmd-given ]; then  ##  existuje cmd-given
				cmdg=1
			fi
			
			if [ $i = stdin-given -a ! -r $i ]; then		## citatelny subor
				EC=1;
				echo "$x/stdin-given nie je na citanie" >&2
			fi
			
			if [[ $i =~ (stderr|stdout|status)-(expected|captured|delta) ]]; then	## zapisovatelny subor
				if [ ! -w $i ];then
					EC=1;
					echo "$x/$i neumoznuje zapis" >&2
				fi
			fi
			
			if [[ $i =~ status-expected|status-captured ]]; then		## obsah suboru, je cislo ?  
				cislo=`cat $i`
				if [[ $cislo =~ ^[0-9][0-9]*$ ]]; then
					echo "je tam cislo" > /dev/null 
				else
					echo "nespravny obsah v $x/$i" >&2
					EC=1
				fi
			fi
			
			## kontrola nazvom suborov
			if [[ ! $i =~ (stderr|stdout|status)-(expected|captured|delta)|cmd-given|stdin-given|status-expected|status-captured ]]; then
				EC=1
				echo "$i nazov suboru nezodpoveda predpokladom" >&2
			fi
			
		fi
		
		if [ -L $i ];then	## existencia symbolickych odkazov
			L=1
		fi
		
	done
	
	if [ $d -eq 0 -a $f -eq 1 -a $cmdg -eq 1 ]; then		## cmd-given sa da spustit
		if [ ! -x cmd-given ]; then
			echo "$x - cmd-given sa neda spustit" >&2
			EC=1
		fi
	fi
		
	if [ $d -eq 1 -a $f -eq 1 ]; then
		echo "v '$x' su adresare so subormi" >&2
		EC=1
	fi
	
	if [ $L -eq 1 ];then
		echo "existencia symbolickych odkazov v '$prem'" >&2
		EC=1
	fi
}

function c_mazanie ()		## funkcia volana pri prepinaci c
{
	for i in $( ls ); do
		if [[ $i =~ (stderr|stdout|status)-(captured|delta) ]]; then
			rm $i
		fi
	done
}

function s_premenovanie ()		## funkcia volana pri prepinaci r
{
	for i in $( ls ); do
		case $i in
			stdout-captured)	mv -f $i stdout-expected;;
			stderr-captured)	mv -f $i stderr-expected;;
			status-captured)	mv -f $i status-expected;;
		esac
	done
}

function diff_t_r ()		## funkcia na porovnavanie suborov v adresaroch pre operacie r a t
{
	if [ -e stdout-expected -a -e stdout-captured ] ;then
		diff -up stdout-expected stdout-captured > stdout-delta
	fi
	if [ -e stderr-expected -a -e stderr-captured ];then
		diff -up stderr-expected stderr-captured > stderr-delta
	fi
	if [ -e status-expected -a -e status-captured ];then
		diff -up status-expected status-captured > status-delta
	fi
	if [ -s status-delta -o -s stdout-delta -o -s stderr-delta ];then
		RESULT=FAILED
		allresult=1
	else
		RESULT=OK
	fi
	w=`echo $x | sed -e 's/\.\///g'`		## upravenie cesty k adresaru na kanonicky tvar
}

function op_t ()		## funkcia volana pri prepinaci t
{
	diff_t_r
	if [ -t 2 ];then
		if [ $RESULT = OK ];then
			echo -e "$w: \033[1;32mOK\033[0m" >&2
		fi
		
		if [ $RESULT = FAILED ];then
			echo -e "$w: \033[1;31mFAILED\033[0m" >&2
		fi
	else
		echo "$w: $RESULT" >&2	
	fi
}

function operacia_r ()			## funkcia volana pri prepinaci r
{
	diff_t_r
	if [ -t 1 ];then
		if [ $RESULT = OK ];then
		echo -e "$w: \033[1;32mOK\033[0m" >&1
		fi
		
		if [ $RESULT = FAILED ];then
		echo -e "$w: \033[1;31mFAILED\033[0m" >&1
		fi
	else
		echo "$w: $RESULT" >&1
	fi
}

function bez_regex ()		## osetenie nezadania REGEXu, ak nie je zadany REGEX, do premennej ulozi hodnotu adresara, cize bude
{							## povazovat za filter meno daneho adresara
	if [ $ARGC -eq 1 ]; then
		regex=$adresar
	fi
}

function nacitanie_adresarov ()		## nacita vsetky adresare do premennej a potom z nej spravi pole
{
	prem=`find $adresar -type d | grep -E $regex | sort`
	arr=$(echo $prem | tr " " "\n")
}

function kontrola_cd ()
{
	if [ $? -ne 0 ];then
		echo "prikaz cd sa nevykonal" >&2
		exit 2
	fi
}

function hardlink ()
{
	hard=`find $adresar -type f -links +1 | grep -E $regex`
	if [ -z "$hard" ];then
		echo "nic" > /dev/null
	else 
		echo "existuje/u pevny/e odkaz/y" >&2
		EC=1
	fi
}

#####################################################################################
## nastavenie flagov ci boli pouzite parametre, ak nie ostanu nula + pomocne premenne
vflag=0
tflag=0
rflag=0
sflag=0
cflag=0
allresult=0
ercmd=0



## spracovanie prepinacov
	while getopts :vtrsc opt
	do  	case "$opt" in
				v)	vflag=1;;
				t)	tflag=1;;
				r)	rflag=1;;
				s)	sflag=1;;
				c)	cflag=1;;
				*)  help >&2 
					exit 2;;
			esac
	done

	((OPTIND--))
	shift $OPTIND
	
	
## kontrola ci bol nejaky prepinac vobec zadany
if [ $vflag -eq 0 -a $tflag -eq 0 -a $rflag -eq 0 -a $sflag -eq 0 -a $cflag -eq 0 ]; then 
		help >&2
		exit 2
fi

## spracovanie operandov
	ARGV=("$@")
	ARGC=("$#")
	case $ARGC in
		1)	adresar=${ARGV[0]};;
		2)	adresar=${ARGV[0]}
			regex=${ARGV[1]};;
		*)	help >&2
			exit 2;;
	esac



################ prepinac v ##############################################
if [ $vflag -eq 1 ]; then
	bez_regex
	hardlink
	nacitanie_adresarov
	
	for x in $arr
	do
		if [ -r $x -a -w $x -a -x $x ];then
			cd $x
			kontrola_cd
			v_adresare
			cd ~-
			kontrola_cd
		else
			echo "nedostatocne opravnenia pre pristup k suboru $x" >&2
			EC=2
		fi
	done
fi

################## prepinac t ####################################################
if [ $tflag -eq 1 ]; then
	bez_regex
	nacitanie_adresarov
	
	for x in $arr
	do
		if [ -r $x -a -w $x -a -x $x ];then
			cd $x
			kontrola_cd
			ecmd=0			## pomocne premenne na vyhodnetenie existencie cmd-given a stdin-given
			estdin=0

			for i in $( ls ); do
					if [ -f $i -a $i = cmd-given ];then
						ecmd=1
					fi
					if [ -f $i -a $i = stdin-given ];then	
						estdin=1
					fi
			done

			if [ $ecmd -eq 1 -a $estdin -eq 1 ];then
				./cmd-given < stdin-given > stdout-captured 2> stderr-captured
				echo "$?" > status-captured
				op_t
			elif [ $ecmd -eq 1 -a $estdin -eq 0 ];then
				./cmd-given < /dev/null > stdout-captured 2> stderr-captured
				echo "$?" > status-captured
				op_t
			fi
			cd ~-
			kontrola_cd
		else
			echo "nedostatocne opravnenia pre pristup k suboru $x" >&2
			EC=2
		fi
	done

	if [ $allresult -eq 0 ];then			## ak je v allresult 0, tak su same OK, inak je nejake FAILED
		EC=0
	else
		EC=1
	fi
	
fi

################ prepinac r ###########################################
if [ $rflag -eq 1 ]; then
	bez_regex
	nacitanie_adresarov
	
	for x in $arr
	do
		if [ -r $x -a -w $x -a -x $x ];then
			cd $x
			kontrola_cd
			for i in $( ls ); do
				if [ -f $i -a $i = cmd-given ];then
						ercmd=1							## kontroluje ci je v adresari cmd-given
				fi
			done
			if [ $ercmd -eq 1 ];then
				operacia_r
			fi
			ercmd=0
			cd ~-
			kontrola_cd
		else
			echo "nedostatocne opravnenia pre pristup k suboru $x" >&2
			EC=2
		fi
	done
	
fi

############## prepinac s ##############################################
if [ $sflag -eq 1 ]; then
	bez_regex
	nacitanie_adresarov
	
	for x in $arr
	do
		if [ -r $x -a -w $x -a -x $x ];then
			cd $x
			kontrola_cd
			s_premenovanie
			cd ~-
			kontrola_cd
		else
			echo "nedostatocne opravnenia pre pristup k suboru $x" >&2
			EC=2
		fi
	done
fi

############## prepinac c #########################################
if [ $cflag -eq 1 ]; then
	bez_regex
	nacitanie_adresarov
	
	for x in $arr
	do
		if [ -r $x -a -w $x -a -x $x ];then
			cd $x
			kontrola_cd
			c_mazanie
			cd ~-
			kontrola_cd
		else
			echo "nedostatocne opravnenia pre pristup k suboru $x" >&2
			EC=2
		fi
	done
fi

exit $EC

