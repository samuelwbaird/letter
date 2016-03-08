local build = require('build_utils')

build.output('dist')

-- add a relative path to asset files, and the path the files should 'appear' in in the build, with option filter
build.add_asset_path('../../assets/output/', 'assets/output', '_x2')

-- add a relative path to source files and then path the files should 'appear' in in the build
build.add_source_path('../../../source/core', 'core')
build.add_source_path('../../../source/util', 'util')
build.add_source_path('../../../source/lt', 'lt')
build.add_source_path('../../game', 'game')

-- for HTML output specify, the top level lua script to launch the game
build.html('main.lua')
