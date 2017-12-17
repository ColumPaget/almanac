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

If you find any other public calendars that people might be interested in, you can email them to me at 'colums.projects@gmail.com' and I'll add them to this list

## Usage
```
almanac [options] [calendar]...

google and meetup calendars are identified in the following format:
g:calendar@hackercons.org          - a google calendar
m:fizzPOP-Birminghams-Makerspace   - a meetup calendar
the users default google calendar can be specified as 'g:primary' 
ical and rss webcalendars are identified by a url as normal.
Currently only .ical or .ics files can be loaded from disk.
Events can also be uploaded to google calendars that the user has permission for.

options:
   -d <n>      show events for the next 'n' days. The 'n' argument is optional, if missing 1 day will be assumed
   -day  <n>   show events for the next 'n' days. The 'n' argument is optional, if missing 1 day will be assumed
   -w <n>      show events for the next 'n' weeks. The 'n' argument is optional, if missing 1 week will be assumed
   -week <n>   show events for the next 'n' weeks. The 'n' argument is optional, if missing 1 week will be assumed
   -m <n>      show events for the next 'n' weeks. The 'n' argument is optional, if missing 1 month will be assumed
   -month <n>  show events for the next 'n' weeks. The 'n' argument is optional, if missing 1 month will be assumed
   -y <n>      show events for the next 'n' weeks. The 'n' argument is optional, if missing 1 year will be assumed
   -year <n>   show events for the next 'n' weeks. The 'n' argument is optional, if missing 1 year will be assumed
   -detail     print event description/details
   -hide <pattern>  hide an event whose title matches fnmatch/shell style pattern 'pattern'
   -old        show events that are in the past
   -of <fmt>   specify format to output. 'csv' will output comma-seperated-values sutitable for reading into a spreadsheet, 'ical' will output ical/ics format, 'txt' will output plain text format, anything else will output text with ANSI color formatting
   -?          This help
   -h          This help
   -help       This help
   --help      This help

The following options all relate to inserting an event into a google calendar. if no google calendar is specified then the users primary calendar (g:primary) is assumed
   -add <title>           add an event with specified title using the destination calendars default privacy setting
   -addpub <title>        add a public event with specified title
   -addpriv <title>       add a private event with specified title
   -start <datetime>      start time of event (see 'time formats' below)
   -end <datetime>        end time of event (see 'time formats' below)
   -at <location>         location of event
   -where <location>      location of event
   -location <location>   location of event
   -import <path>         import events from a .ical/.ics file and upload them to a calendar
```


