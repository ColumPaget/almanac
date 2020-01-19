## almanac - a calendar viewer written in lua for unix systems

author: Colum Paget (colums.projects@gmail.com)  
licence: GPLv3  

Almanac is a calendar app that can download events from google calendars, meetup.com calendars, rss feeds with xCal extensions and iCal/ics feeds. It can also insert events into a google calendar.

To use almanac you will need to have the following installed:

lua              http://www.lua.org                          at least version 5.3  
libUseful        http://github.com/ColumPaget/libUseful      at least verson 3.6  
libUseful-lua    http://github.com/ColumPaget/libUseful-lua  at least version 1.2  

you will need swig (http://www.swig.org) installed to compile libUseful-lua


Some example calendars you might want to view are:

## Google calendars. Note leading 'g:' prefix for use with almanac
```
g:calendar@hackercons.org
g:ukkchmv8h0pofbg4if8bekv5d4@group.calendar.google.com   - Royal Astronomical Society public lectures
g:t60v6emjlovt3b6udm0bgie1l8@group.calendar.google.com   - Royal Astronomical Society meetings
g:theuniversityofedinburgh@gmail.com                     - Events at edingburgh uni
g:whatson@sheffield.ac.uk                                - Events at sheffield uni
g:o4m8d0vra0ocig1etsuvbb1d6uckv519@import.calendar.google.com  - Bristol Uni philosophy department
g:ledd3p7h7mpfulbn5hih6pohj8@group.calendar.google.com   - Sheffield Hackspace
```


## Meetup calendars. Note leading 'm:' prefix for use with almanac
```
m:fizzPOP-Birminghams-Makerspace   - my local hacker/maker space
```

## ICAL calendars online
```
http://events.ucl.ac.uk/calendar/events.ics                        - Events at University College London 
http://www.sussex.ac.uk/broadcast/feed/event/sussex-lectures.ics   - Sussex Uni public lectures
https://www.dur.ac.uk/scripts/events/ical.php?category=51          - Durham Uni public lectures
https://www.snb.ch/en/mmr/events/id/calendar_full_2018.en.ics      - Bank of Switzerland events 2018
```

## RSS/xCal calendars
```
http://rss.royalsociety.org/events/upcoming    - Royal society events
```

You can find a bunch of ical calendars here:

```
http://icalshare.com/
```

If you find any other public calendars that people might be interested in, you can email them to me at 'colums.projects@gmail.com' and I'll add them to this list

## Usage
```
usage:  almanac [options] [calendar]...

almanac can pull calendar feeds from webcalendars using the google calendar api, meetup api, ical format, or xcal rss format
google and meetup calendars are identified in the following format:
g:calendar@hackercons.org          - a google calendar
m:fizzPOP-Birminghams-Makerspace   - a meetup calendar

The default calendar is stored on disk, and is referred to as 'a:default',  and if no calendar is supplied then it will be displayed by default
ical and rss webcalendars are identified by a url as normal.
Events can also be uploaded to google calendars that the user has permission for. If pushing events to a user's google calendar, or displaying events from it, this can be specified as 'g:primary'

options:
   -h <n>      show events for the next 'n' hours. The 'n' argument is optional, if missing 1 day will be assumed
   -hour <n>   show events for the next 'n' hours. The 'n' argument is optional, if missing 1 day will be assumed
   -d <n>      show events for the next 'n' days. The 'n' argument is optional, if missing 1 day will be assumed
   -day  <n>   show events for the next 'n' days. The 'n' argument is optional, if missing 1 day will be assumed
   -days <n>   show events for the next 'n' days. The 'n' argument is optional, if missing 1 day will be assumed
   -w <n>      show events for the next 'n' weeks. The 'n' argument is optional, if missing 1 week will be assumed
   -week <n>   show events for the next 'n' weeks. The 'n' argument is optional, if missing 1 week will be assumed
   -m <n>      show events for the next 'n' weeks. The 'n' argument is optional, if missing 1 month will be assumed
   -month <n>  show events for the next 'n' weeks. The 'n' argument is optional, if missing 1 month will be assumed
   -y <n>      show events for the next 'n' weeks. The 'n' argument is optional, if missing 1 year will be assumed
   -year <n>   show events for the next 'n' weeks. The 'n' argument is optional, if missing 1 year will be assumed
   -at <loc>   show events at location 'loc'
   -where <loc>     show events at location 'loc'
   -location <loc>  show events at location 'loc'
   -hide <pattern>  hide events whose title matches fnmatch/shell style pattern 'pattern'
   -show <pattern>  show only events whose title matches fnmatch/shell style pattern 'pattern'
   -detail     print event description/details
   -details    print event description/details
   -old        show events that are in the past
   -import <url>  Import events from specified URL (usually an ical file) into calendar
   -import-email <url>  Import events from ical attachments within an email file at the specified URL into calendar
   -persist    don't exit, but print out events in a loop. This can be used to create an updating window that displays upcoming events.
   -lfmt <format string>          line format for ansi output (see 'display formats' for details of title strings)
   -xt <title string>             when -persist is used, also set the xterm title to be <title string> (see 'display formats' for details of title strings)
   -xtitle <title string>         when -persist is used, also set the xterm title to be <title string> (see 'display formats' for details of title strings)
   -xterm-title <title string>    when -persist is used, also set the xterm title to be <title string> (see 'display formats' for details of title strings)
   -of <fmt>   specify format to output. 'csv' will output comma-seperated-values sutitable for reading into a spreadsheet, 'ical' will output ical/ics format, 'txt' will output plain text format, anything else will output text with ANSI color formatting
   -maxlen <len>     When importing calendars set the max length of an event to <len> where len is a number postfixed by 'm' 'h' 'd' or 'w' for 'minutes', 'hours', 'days' or 'weeks'. e.g. '2d' two days, '30m' thiry minutes.
   -u         Terminal supports unicode up to code 0x8000
   -unicode   Terminal supports unicode up to code 0x8000
   -u2        Terminal supports unicode up to code 0x8000
   -unicode2  Terminal supports unicode up to code 0x10000
   -?          This help
   -h          This help
   -help       This help
   --help      This help

ADD EVENTS
The following options all relate to inserting an event into an almanac or a google calendar. if calendar is specified then the default almanac calendar (a:default) is assumed. You can instead use the user's primary google calendar by specifiying 'g:primary'
   -add <title>           add an event with specified title using the destination calendars default privacy setting
   -addpub <title>        add a public event with specified title
   -addpriv <title>       add a private event with specified title
   -start <datetime>      start time of event (see 'time formats' below)
   -end <datetime>        end time of event (see 'time formats' below)
   -at <location>         location of event
   -where <location>      location of event
   -location <location>   location of event
   -import <path>         import events from a .ical/.ics file and upload them to a calendar

example: almanac.lua -add "dental appointment" -start "2020/01/23"

DISPLAY FORMATS
In the default mode, ansi display mode, you can specify the line-by-line output format by using a combination of color identifiers and data identifiers.
data identifiers: these are strings that will be replaced by the specified value
$(title)        event title/summary
$(date)         start date in Y/m/d format
$(time)         start time in H:M:S format
$(day)          numeric day of month
$(month)        numeric month of year
$(Year)         year in 4-digit format
$(year)         year in 2-digit format
$(monthname)    name of month
$(dayname)      name of day (Mon, Tue, Wed...)
$(dayid)        like dayname, except including 'today' and 'tomorrow'
$(dayid_color)  like dayid, but today will be in ansi red, tomorrow in ansi yellow
$(location)     event location
$(duration)     event duration

color identifiers: format strings that specifier colors
~0      reset colors
~r      red
~g      green
~b      blue
~y      yellow
~m      magenta
~c      cyan
~w      white
~n      noir (black)
~e      bold (emphasis)
default display format is:  ~c$(dayid_color)~0 $(date) $(time_color) $(duration) ~e~m$(title)~0 $(location)
```
