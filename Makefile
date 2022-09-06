UNITS=common.lua text_functions.lua parse_dates.lua oauth-prompt.lua csv.lua ical.lua rss.lua email.lua caldoc.lua googlecal.lua meetupcal.lua nativecal.lua event_format.lua output.lua sgical.lua xterm.lua help.lua command-line.lua interactive.lua main.lua

almanac.lua: $(UNITS)
	cat $(UNITS) > almanac.lua
	chmod a+x almanac.lua

install:
	cp -f almanac.lua /usr/local/bin
