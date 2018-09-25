#!/usr/bin/env sh
# Author: Gilles Biagomba
# Program: GraveDigger.sh
# Description: This script was designed to help you find files, mass copy files and zip them.\n

# Setting working directory
pth=$(pwd)

# Prompting user for questions
echo "What filetype are you trying to ind?"
read FTYPE
echo

echo "What is keyword you would like to use to filter down your search?"
echo "If you have none, just press ENTER"
read FILTER
echo

echo "What is the name of the zip (output) file you would like to use?"
read ZFILE
echo

echo "What is the password for the zip file?"
read ZPSS
echo

# Checking to see if variables are empty
if [ -z $FTYPE ]; then
	echo "You did not enter a filetype to search, please try again"
	exit
elif [ -z $ZFILE ]; then
	echo "You did not enter a name for the zip file output, please try again"
	exit
elif [ -z $ZPSS ]; then
	echo "You did not enter a password for the zip file output, please try again"
	exit
else
	echo
	echo "We are good to go!"
	echo
fi

# Updating the file databse
echo "Seat tight, I am updating you file database (i.e., updatedb)"
updatedb

# Locating the fie(s) in question
n=0
echo "Locating your files....hang in there, we are almost done"
if [ -z $FILTER ]; then
	FILES=($(locate *.$FTYPE | grep $FTYPE))
else
	FILES=($(locate *.$FTYPE | grep $FTYPE | grep -i $FILTER))
fi

# Zipping up said files
touch $FTYPE-FILE_MANIFESTO.txt
echo "See patience pays off! Compressing your files now!"
for FILE in ${FILES[*]}; do
	echo "Compressing $FILE"
	zip --password $ZPSS -ru -9 $pth/$ZFILE.zip $FILE | tee -a $FTYPE-FILE_MANIFESTO.txt
done

# CLeaning up
unset pth
unset FTYPE
unset FILTER
unset ZFILE
unset FILES
unset FILE
unset n
unset ZPSS
set -u
