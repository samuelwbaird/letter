This is a first pass at supporting the same Lua code based on the letter library published via the Punchdrunk / Moonshine Lua vm for browsers.

package_web.lua attempts to produce the required files ready for dropping in a copy of Punchdrunk after which its grunt process will take over.

File loading is handled quite differently within the browser, this package script embeds all modules and all lua data files in a single Lua file to avoid some issues.

Punchdrunk does not currently support all the same features as Love2D so some key classes are substituted in the build. Moonshine and Punchdrunk both do a pretty amazing job of transparently supporting Lua in the browser but the current limits are probably roadblocks for any significant games. As Punchdrunk matures, and with some extra work here, this could become a viable path for putting fairly basic games onto the web.