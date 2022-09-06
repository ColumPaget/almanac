






-- create a blank event object
function EventCreate()
local Event={}

Event.Attendees=0
Event.UTCoffset=0;
Event.UID=string.format("%x",time.secs())
Event.Title=""
Event.Details=""
Event.Status=""
Event.Location=""
Event.Details=""
Event.Visibility=""
Event.Start=0
Event.End=0
Event.URL=""

return Event
end





function ImportEventsToCalendar(url, calendars)
local Events={}

DocumentLoadEvents(Events, url)
for i,event in ipairs(Events)
do
GCalAddEvent(calendars, event)
AlmanacAddEvent(event)
end
end





-- called by 'OutputCalendar' to check if an event has been 'hidden' and should not be displayed
function EventVisible(event, config)
local TOK, pattern, invert
local result=false

if config.EventsStart==nil then io.stderr:write("ERROR: Events start==nil\n") end

if event.Start == nil then return false end
if event.Start < config.EventsStart then return false end
if config.EventsEnd > 0 and event.Start > config.EventsEnd then return false end

if strutil.strlen(config.selections)==0 then return true end

TOK=strutil.TOKENIZER(config.selections,",")
pattern=TOK:next()
while pattern ~= nil
do
	invert=false
	if string.sub(pattern, 1, 1) == "!" then 
		invert=true 
		pattern=string.sub(pattern, 2)
	end

	if strutil.pmatch(pattern, event.Title) == false 
	then 
		if invert then result=false
		else result=true end
	else
		if invert then result=true
		else result=false end
	end
	pattern=TOK:next()
end

return result
end


function OutputEvent(event)

if event ~= nil
then
if Settings.OutputFormat=="csv" then OutputEventCSV(Out, event) 
elseif Settings.OutputFormat=="ical" then OutputEventICAL(Out, event) 
elseif Settings.OutputFormat=="sgical" then OutputEventSGIcal(Out, event) 
elseif Settings.OutputFormat=="txt" then OutputEventTXT(event) 
else OutputEventANSI(event)
end
end

end


function OutputCalendar(Events, config)
local i, event
local displayed_events_count=0

if Settings.OutputFormat=="csv" then OutputCSVHeader(Out) 
elseif Settings.OutputFormat=="ical" then OutputICALHeader(Out) 
elseif Settings.OutputFormat=="sgical" then OutputSGIcalHeader(Out) 
end

for i,event in ipairs(Events)
do
	if EventVisible(event, config) 
	then
	OutputEvent(event)
	displayed_events_count=displayed_events_count + 1
	end
end

if Settings.OutputFormat=="csv" then OutputCSVTrailer(Out) 
elseif Settings.OutputFormat=="ical" then OutputICALTrailer(Out)
elseif Settings.OutputFormat==""
then  
	if displayed_events_count==0 then print(terminal.format("~r" .. "no events to display" .. "~0")) end
end

end



-- Sort events callback function. Sorts in date order and also finds the most recent event (which is used to decide whether to display events older than today)
function EventsSort(ev1, ev2)

if ev1.Start > EventsNewest then EventsNewest=ev1.Start end
if ev2.Start > EventsNewest then EventsNewest=ev2.Start end

if ev1.Start < ev2.Start then return true end
return false
end



function LoadCalendarEvents(calendars, selections, Events)
local toks, cal

toks=strutil.TOKENIZER(calendars,",")
cal=toks:next()
while cal ~= nil
do
if strutil.strlen(cal) > 0
then
	if string.sub(cal,1, 2) == "a:" then AlmanacLoadCalendar(Events, string.sub(cal, 3), config.EventsStart, config.EventsEnd) 
	elseif string.sub(cal,1, 2) == "g:" then GCalLoadCalendar(Events, string.sub(cal, 3)) 
	elseif string.sub(cal,1, 2) == "m:" then MeetupLoadCalendar(Events, string.sub(cal, 3)) 
	elseif string.sub(cal,1, 7) == "webcal:" then DocumentLoadEvents(Events, "http://" .. string.sub(cal, 8))
	else DocumentLoadEvents(Events, cal)
	end
end
cal=toks:next()
end

if #Events > 0
then
	table.sort(Events, EventsSort)
	--if EventsNewest < Now or #Events < 2 then config.EventsStart=0 end
end

end





function ImportItems(action, items)
local toks, url

toks=strutil.TOKENIZER(items, "\n")
url=toks:next()
while url ~= nil
do
	if action=="import-email"
	then
	EmailExtractCalendarItems(url, AlmanacAddEvent)
	else
	ImportEventsToCalendar(url, calendars)
	end
url=toks:next()
end

end


function ConvertItems(action, items)
local toks, url
local Events={}

toks=strutil.TOKENIZER(items, "\n")
url=toks:next()
while url ~= nil
do
	if action=="convert-email"
	then
	EmailExtractCalendarItems(url, OutputEvent)
	else
	DocumentLoadEvents(Events, url)
	OutputCalendar(Events, config)
	end

url=toks:next()
end

end



function LoadAndOutputCalendar(config)
local Events={}

LoadCalendarEvents(config.calendars, config.selections, Events)
OutputCalendar(Events, config)

end









--this function sets up initial values of some settings
function Init()
Out=stream.STREAM("-")

-- output format can be 'csv', 'ical', 'sgical', 'txt' and 'ansi'. default is ansi
Settings.OutputFormat=""

-- persist means instead of just print out a list of events, print out the list, sleep for a bit,
-- clear screen and print out again in an eternal loop
Settings.Persist=false

-- if 'ShowDetail' is true then display event descriptions as well as summary/title
Settings.ShowDetail=false

-- if 'ShowURL' is true then display URL (e.g. teams meeting url) as well as summary/title
Settings.ShowURL=false

-- xterm title line to display when in persist mode
Settings.XtermTitle="Almanac: $(version) Today: $(dayname) $(day) $(monthname)"

Settings.RefreshTime=ParseDuration("2m")

-- 'DisplayFormat' is used in 'ansi' output (the default display type) 
Settings.DisplayFormat="~c$(daynick_color)~0 $(date) $(time_color) $(duration) ~r$(status)~0 ~m$(title)~0 $(location)"

-- When importing from calendars that have long events, or events with open or misconfigured lengths, 
-- you can set an upper limit on length. This sets a default value of -1 to indicate no such limit
Settings.MaxEventLength=-1


--google calendar ClientID and ClientSecret for this app
Settings.GCalClientID="280062219812-m3qcd80umr6fk152fckstbmdm30tt2sa.apps.googleusercontent.com"
Settings.GCalClientSecret="5eyXi7huoe99ylXqMiaIxVMd"

Settings.WarnTime=0
Settings.WarnRaisedTime=0
Settings.CacheTime=120

UpdateTimes()
end


------------   Main starts here  -----------------------
Init()
config,event=ParseCommandLine(arg)
UpdateTimes()

if config.action=="help" 
then
	PrintHelp()
elseif config.action=="add"
then
	AlmanacAddEvent(event)
	--if strutil.strlen(NewEvent.Title) > 0 then GCalAddEvent(calendars, NewEvent) end
elseif config.action=="import" or config.action=="import-email"
then
	ImportItems(config.action, config.selections)
elseif config.action=="convert" or config.action=="convert-email"
then
	ConvertItems(config.action, config.selections)
elseif Settings.Persist==true
then
	PersistentScheduleDisplay(config)
else
	LoadAndOutputCalendar(config)
end
