#! /bin/bash
# run (and re-run and re-run) in a console for debug output
# MacOSX specific

# get a reference to the correct folder
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# ensure we're running from the correct folder
cd $DIR

# symbolic link the required paths into place for love
ln -sf ../game .
ln -sf ../../source/core .
ln -sf ../../source/util .
ln -sf ../../source/lt .
ln -sf ../assets .

while [ 1 ]
do
	#! /bin/bash
	echo ""
	echo `date` "- restarting"

	# kill love
	killall love >/dev/null 2>/dev/null

	# launch love
	/Applications/love.app/Contents/MacOS/love . &

	# monitor for a file system change then repeat this process
	# fswatch -r -1 main.lua conf.lua core util simple lt game
	
	# or manual restart after keypress
	read -n 1 -s
done
