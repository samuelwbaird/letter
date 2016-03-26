#! /bin/bash
# package a love file using symbolic links to assemble the zip content

# get a reference to the correct folder
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# ensure we're running from the correct folder
cd $DIR

# remove previous build
rm stones.love

# symbolic link the required paths into place for zipping
ln -sf ../game .
ln -sf ../../source/core .
ln -sf ../../source/util .
ln -sf ../../source/lt .
ln -sf ../assets .

# zip up the love file
zip -r stones.love conf.lua main.lua core util lt game assets
