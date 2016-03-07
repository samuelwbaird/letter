#! /bin/bash
# set up moonshines cool debug tools to debug the build output

# get a reference to the correct folder
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# ensure we're running from the correct folder
cd $DIR

# clean up old debug processes?
killall node
killall python

# moonshine debug server with the output path mapped to the combined source path
moonshine debug -m "stones:." &

# python debug web server from this location
python -m SimpleHTTPServer &

# open the debug window in a browser window
open "http://127.0.0.1:1969" &

# open the game in another browser window
open "http://localhost:8000/dist" &

# wait for a key press and then tidy up again
read -n 1 -s
killall node
killall python
