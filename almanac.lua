
require("oauth")
require("process")
require("strutil")
require("stream")
require("dataparser")
require("terminal")
require("filesys")
require("time")

--process.lu_set("HTTP:Debug","true")

VERSION="1.3"
ClientID="280062219812-m3qcd80umr6fk152fckstbmdm30tt2sa.apps.googleusercontent.com"
ClientSecret="5eyXi7huoe99ylXqMiaIxVMd"
Now=time.secs()
ShowDetail=false
EventsStart=Now
EventsEnd=0
EventsNewest=0
OutputFormat=""
Today=time.formatsecs("%Y%m%d", Now)
Tomorrow=time.formatsecs("%Y%m%d", Now+3600*24)
Persist=false


--GENERIC FUNCTIONS


--this function builds a single line from file formats (email headers and ical) that set limits on line length.
--these formats split long lines and start the continuation lines with a whitespace to indicate it's a
--continuation of the previousline
function UnSplitLine(lines)
local line, tok, char1

line=lines:next()
tok=lines:peek()

while line ~= nil and tok ~= nil
do
	char1=string.sub(tok, 1, 1)
	if char1 ~= " " and char1 ~= "  " then break end

	--now really read the peeked token
	line=line .. lines:next()
	tok=lines:peek()
end

return line
end

--count digits at start of a string, mostly used by ParseDate 
function CountDigits(str)
local i=0

for i=1,strutil.strlen(str),1
do
if tonumber(string.sub(str,i,i)) == nil then return i-1 end
end

return i
end


--Parse a date from a number of different formats
function ParseDate(datestr)
local len
local str=""
local when=0

len=string.len(datestr)

if len==8
then
	str="20"..string.sub(datestr,1,2).."-"..string.sub(datestr,4,5).."-"..string.sub(datestr,7,8).."T00:00:00"
elseif len==10
then
	if CountDigits(str) == 4
	then
		str=string.sub(datestr,1,4).."-"..string.sub(datestr,6,7).."-"..string.sub(datestr,9,10).."T00:00:00"
	else
		str=string.sub(datestr,7,10).."-"..string.sub(datestr,4,5).."-"..string.sub(datestr,1,2).."T00:00:00"
	end
elseif len==14
then
	str="20"..string.sub(datestr,1,2).."-"..string.sub(datestr,4,5).."-"..string.sub(datestr,7,8).."T"..string.sub(datestr,10,11)..":"..string.sub(datestr,13,14)
elseif len==16
then
	if CountDigits(str) == 4
	then
		str=string.sub(datestr,1,4).."-"..string.sub(datestr,6,7).."-"..string.sub(datestr,9,10).."T"..string.sub(datestr,12,13)..":"..string.sub(datestr, 15, 16)..":00"
	else
		str=string.sub(datestr,7,10).."-"..string.sub(datestr,4,5).."-"..string.sub(datestr,1,2).."T"..string.sub(datestr,12,13)..":"..string.sub(datestr, 15, 16)..":00"
	end
end

when=time.tosecs("%Y-%m-%dT%H:%M:%S", str)
return when
end


-- Parse a location string, 
function LocationParse(Event, str)
local tmpstr=""


if str ~= nil
then
tmpstr=strutil.unQuote(str)
tmpstr=string.gsub(tmpstr,'\n','')
tmpstr=string.gsub(tmpstr,"United States","USA")
else
tempstr=""
end

Event.Location=tmpstr
end




-- create a blank event object
function EventCreate()
local Event={}

Event.Attendees=0
Event.UTCoffset=0;
Event.Title=""
Event.Details=""
Event.Status=""
Event.Location=""
Event.Details=""
Event.Visibility=""
Event.Start=0
Event.End=0

return Event
end


-- do initial oauth authentication
function OAuthGet(OA)

str=strutil.httpQuote("urn:ietf:wg:oauth:2.0:oob");
OA:set("redirect_uri", str);
OA:stage1("https://accounts.google.com/o/oauth2/v2/auth");

print()
print("GOOGLE CALENDAR REQUIRES OAUTH LOGIN. Goto the url below, grant permission, and then copy the resulting code into this app.");
print()
print("GOTO: ".. OA:auth_url());

OA:listen(8989, "https://www.googleapis.com/oauth2/v4/token");
OA:save("");
print()
end


-- FUNCTIONS FOR PARSING ICAL FILES
function ICalNextLine(lines)
local toks, tok, key, extra, line

line=UnSplitLine(lines)
if line==nil then return nil end

line=strutil.stripTrailingWhitespace(line);
toks=strutil.TOKENIZER(strutil.stripTrailingWhitespace(line),":|;","ms")
key=toks:next()
tok=toks:next()
while tok==";"
do
	tok=toks:next()
	if strutil.strlen(extra) > 0 
	then 
		extra=extra..";"..tok
	else 
		extra=tok
	end
	tok=toks:next()
end

return key, toks:remaining(), extra
end


function ICalReadPastSubItem(lines, itemtype)
local key, value, extra, tmpstr

key,value,extra=ICalNextLine(lines)
while key ~= nil
do
	if key=="END" and value==itemtype then break end
	key,value,extra=ICalNextLine(lines)
end

end


function ICalParseTime(value, extra)
local Tokens, str
local Timezone=""

value=strutil.stripTrailingWhitespace(value);
value=strutil.stripLeadingWhitespace(value);

Tokens=strutil.TOKENIZER(extra,";")
str=Tokens:next()
while str ~= nil
do
if string.sub(str,1,5) =="TZID=" then Timezone=string.sub(str,6) end
str=Tokens:next()
end

return(time.tosecs("%Y%m%dT%H%M%S", value, Timezone))
end



function ICalParseEvent(lines, Events)
local key, value, extra, tmpstr
local Event

Event=EventCreate()
key,value,extra=ICalNextLine(lines)
while key ~= nil
do
	if key=="END" and value=="VEVENT" then break end
	if key=="BEGIN" then ICalReadPastSubItem(lines, value) end
	if key=="SUMMARY" then 
		tmpstr=string.gsub(strutil.unQuote(value),"\n"," ")
		Event.Title=strutil.stripCRLF(tmpstr)
	 end
	if key=="DESCRIPTION" 
	then 
		tmpstr=string.gsub(strutil.unQuote(value),"\n\n","\n")
		Event.Details=strutil.stripCRLF(tmpstr)
	end
	if key=="LOCATION" then LocationParse(Event, value) end
	if key=="STATUS" then Event.Status=value end
	if key=="DTSTART" then Event.Start=ICalParseTime(value, extra) end
	if key=="DTEND" then Event.End=ICalParseTime(value, extra) end
	if key=="ATTENDEE" then Event.Attendees=Event.Attendees+1 end

	key,value,extra=ICalNextLine(lines)
end

table.insert(Events, Event)
end


function ICalLoadEvents(Events, doc)
local line, str, char1, lines

lines=strutil.TOKENIZER(doc, "\n")
key,value,extra=ICalNextLine(lines)
while key ~= nil
do
	if key=="BEGIN" and value=="VEVENT" then ICalParseEvent(lines, Events) end
	key,value,extra=ICalNextLine(lines)
end

end





-- FUNCTIONS FOR PARSING RSS FILES

function RSSParseEvent(Parser)
local Event

Event=EventCreate()
item=Parser:next()
while item ~=nil
do
if (item:name()=="title") then Event.Title=item:value() end
if (item:name()=="description") then Event.Details=item:value() end
if (item:name()=="xCal:dtstart") then Event.Start=time.tosecs("%Y%m%dT%H%M%S", item:value()) end
if (item:name()=="dtstart") then Event.Start=time.tosecs("%Y%m%dT%H%M%S", item:value()) end
if (item:name()=="xCal:dtend") then Event.End=time.tosecs("%Y%m%dT%H%M%S", item:value()) end
if (item:name()=="dtend") then Event.End=time.tosecs("%Y%m%dT%H%M%S", item:value()) end
if (item:name()=="xCal:location") then Event.Location=item:value() end
if (item:name()=="location") then Event.Location=item:value() end

item=Parser:next()
end

return Event
end




function RSSLoadEvents(Collated, S)
local P, Events, Item, values, doc

doc=S:readdoc()
--print(doc)

P=dataparser.PARSER("rss", doc)
Events=P:open("/")
if Events ~= nil
then
Item=Events:next()
while Item ~= nil
do
values=Item:open("/")
if string.sub(Item:name(), 1,5) =="item:" then table.insert(Collated, RSSParseEvent(values)) end
Item=Events:next()
end
end

end






-- FUNCTIONS RELATING TO GOOGLE CALENDAR
function GCalAddEvent(calendars, NewEvent)
local url, S, text, doc, cal, Tokens

if OA==nil
then
	OA=oauth.OAUTH("auth","gcal",ClientID, ClientSecret,"https://www.googleapis.com/auth/calendar", "https://www.googleapis.com/oauth2/v4/token");
	if OA:load() == 0 then OAuthGet(OA) end
end


Tokens=strutil.TOKENIZER(calendars,",")
cal=Tokens:next()
while cal ~= nil
do
cal=string.sub(cal,3)
if strutil.strlen(cal) > 0
then
url="https://www.googleapis.com/calendar/v3/calendars/".. strutil.httpQuote(cal) .."/events"
text="{\n\"summary\": \"" .. strutil.quoteChars(NewEvent.Title, "\n\"") .. "\",\n"
if strutil.strlen(NewEvent.Location) > 0 then text=text.."\"location\": \"".. strutil.quoteChars(NewEvent.Location, "\n\"") .."\",\n" end
if strutil.strlen(NewEvent.Details) > 0 then text=text.."\"description\": \"".. strutil.quoteChars(NewEvent.Details, "\n\"") .."\",\n" end
if strutil.strlen(NewEvent.Visibility) > 0 then text=text.."\"visibility\": \"".. NewEvent.Visibility .."\",\n" end
text=text.."\"start\": {\n\"dateTime\": \"" .. time.formatsecs("%Y-%m-%dT%H:%M:%SZ", NewEvent.Start,"GMT") .. "\"\n},\n"
text=text.."\"end\": {\n\"dateTime\": \"" .. time.formatsecs("%Y-%m-%dT%H:%M:%SZ", NewEvent.End,"GMT") .. "\"\n}\n"
text=text.. "}"
S=stream.STREAM(url, "w oauth=" .. OA:name() .. " content-type=" .. "application/json " .. "content-length=" .. string.len(text))

S:writeln(text)
doc=S:readdoc()
S:close()
end

cal=Tokens:next()
end

end


function GCalParseEvent(Parser)
local Event
local Start, End


Event=EventCreate()
Event.Title=Parser:value("summary")
Event.Details=Parser:value("description")
LocationParse(Event, Parser:value("location"))
Start=Parser:value("start/dateTime")
if strutil.strlen(Start) == 0 then Start=Parser:value("start/date") .. "T00:00:00" end
End=Parser:value("end/dateTime")
if strutil.strlen(End) == 0 then End=Parser:value("start/date") .. "T00:00:00" end
Event.Attendees=0
Event.Status=Parser:value("status")

--"2012-04-26T21:00:00+01:00",
Event.Start=time.tosecs("%Y-%m-%dT%H:%M:%S", Start)
Event.End=time.tosecs("%Y-%m-%dT%H:%M:%S", End)

return Event
end




function GCalLoadCalendar(Collated, cal)
local S, P, Events, Item, doc, url

if OA==nil
then
	OA=oauth.OAUTH("auth","gcal",ClientID, ClientSecret,"https://www.googleapis.com/auth/calendar", "https://www.googleapis.com/oauth2/v4/token");
	if OA:load() == 0 then OAuthGet(OA) end
end

url="https://www.googleapis.com/calendar/v3/calendars/".. strutil.httpQuote(cal) .."/events?singleEvents=true"
if EventsStart > 0 then url=url.."&timeMin="..strutil.httpQuote(time.formatsecs("%Y-%m-%dT%H:%M:%SZ", EventsStart)) end

S=stream.STREAM(url,"oauth="..OA:name())
doc=S:readdoc()
--print(doc)

P=dataparser.PARSER("json", doc)
Events=P:open("/items")
if Events ~= nil
then
Item=Events:next()
while Item ~= nil
do
if Item:value("kind")=="calendar#event" then table.insert(Collated, GCalParseEvent(Item)) end
Item=Events:next()
end
end

S:close()
end




-- FUNCTIONS RELATING TO MEETUP CALENDARS
function MeetupParseEvent(Parser)
local Event={}

Event=EventCreate()
Event.Title=Parser:value("name")
Event.Details=Parser:value("description")
Event.Location=Parser:value("venue/name");
if Event.Location==nil then Event.Location="" end
Event.Country=Parser:value("venue/country");
Event.City=Parser:value("venue/city");
--Event.Start=Parser:value("local_date").." "..Parser:value("local_time")
Event.Attendees=tonumber(Parser:value("yes_rsvp_count"))
Event.UTCoffset=tonumber(Parser:value("utc_offset"));

-- convert from time in millseconds
Event.Start=tonumber(Parser:value("time")) / 1000.0
if strutil.strlen(Parser:value("duration"))  > 0
then
Event.End=Event.Start + tonumber(Parser:value("duration")) / 1000.0
else Event.End=0
end

return Event
end



function MeetupLoadCalendar(Collated, cal)
local S, P, Events, Item, doc

S=stream.STREAM("https://api.meetup.com/".. strutil.httpQuote(cal) .."/events")
doc=S:readdoc()
--print(doc)

P=dataparser.PARSER("json", doc)
Events=P:open("/")
if Events ~= nil
then
Item=Events:next()
while Item ~= nil
do
table.insert(Collated, MeetupParseEvent(Item))
Item=Events:next()
end
end

S:close()
end

--FUNCTIONS RELATED TO NATIVE ALMANAC CALENDARS

function AlmanacLoadCalendar(Collated, cal)
local S, str, event, toks

str=process.getenv("HOME") .. time.format("/.almanac/%b-%Y.cal")
S=stream.STREAM(str)
if S ~= nil
then
str=S:readln()
while str ~= nil
do
event=EventCreate()
toks=strutil.TOKENIZER(str, "\\S", "Q")
event.Start=time.tosecs("%Y/%m/%d.%H:%M:%S", toks:next())
event.End=time.tosecs("%Y/%m/%d.%H:%M:%S", toks:next())
event.Title=toks:next()
event.Location=toks:next()
table.insert(Collated, event)
str=S:readln()
end
S:close()
end

end


function AlmanacAddEvent(event)
local S, str

str=process.getenv("HOME") .. "/.almanac/"
filesys.mkdir(str)

str=str..time.formatsecs("%b-%Y.cal", event.Start)
S=stream.STREAM(str, "a")
if S ~= nil
then
str=time.formatsecs("%Y/%m/%d.%H:%M:%S ", event.Start)
str=str .. time.formatsecs("%Y/%m/%d.%H:%M:%S ", event.End)
str=str .. "\"" .. event.Title .. "\" \""..event.Location.."\" "
S:writeln(str.."\n")
S:close()
end

end


function DocumentGetType(S)
local Tokens, str, ext
local doctype=""

str=S:getvalue("HTTP:Content-Type")
if strutil.strlen(str) ~= 0
then
	Tokens=strutil.TOKENIZER(str, ";")
	doctype=Tokens:next()
else
	str=S:path()
	if strutil.strlen(str) ~= nil
	then
		ext=filesys.extn(str)
		if ext==".ical" then doctype="application/ical" 
		elseif ext==".rss" then doctype="application/rss" 
		end
	end
end

return doctype
end 



function DocumentLoadEvents(Events, url)
local S, doctype
S=stream.STREAM(url, "r");
if S ~= nil
then
	doctype=DocumentGetType(S)
	if doctype=="text/xml" or doctype=="application/rss" or doctype=="application/rss+xml" 
	then 
		RSSLoadEvents(Events, S)
	else
		ICalLoadEvents(Events, S:readdoc())
	end
else
print(terminal.format("~rerror: cannot open '"..url.."'~0"))
end

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



-- Functions related to extracting ical and other files from emails
function EmailExtractBoundary(header)
local toks, str
local boundary=""


toks=strutil.TOKENIZER(header, "\\S")
str=toks:next()
while str~= nil
do
if string.sub(str, 1,9) == "boundary=" then boundary=strutil.stripQuotes(string.sub(str, 10)) end
str=toks:next()
end

return boundary
end

function EmailHandleContentType(content_type, args)
local boundary=""

if string.sub(content_type, 1, 10)== "multipart/" then boundary=EmailExtractBoundary(args) end

return content_type, boundary
end


function EmailParseHeader(header, mime_info)
local toks
local name=""
local value=""
local args=""

toks=strutil.TOKENIZER(header, ":|;", "m")
name=toks:next()
value=toks:next()
if name ~= nil  and value ~= nil
then
	name=string.lower(name)
	value=string.lower(strutil.stripLeadingWhitespace(value))
	args=toks:remaining()

	if name=="content-type" 
	then 
	mime_info.content_type,mime_info.boundary=EmailHandleContentType(value, args) 
	elseif name=="content-transfer-encoding"
	then
	mime_info.encoding=value
	end
end

end



function EmailReadHeaders(S)
local line, str
local header=""
local mime_info={}

mime_info.content_type=""
mime_info.boundary=""
mime_info.encoding=""

line=S:readln()
while line ~= nil
do
	line=strutil.stripTrailingWhitespace(line);
	char1=string.sub(line, 1, 1)

	if char1 ~= " " and char1 ~= "	"
	then
		EmailParseHeader(header, mime_info)
		header=""
	end
	header=header .. line
	if strutil.strlen(line) < 1 then break end
	line=S:readln()
end

EmailParseHeader(header, mime_info)

return mime_info
end


function EmailReadDocument(S, boundary, encoding)
local line, event, i
local doc=""
local Events={}

line=S:readln()
while line ~= nil
do
	if encoding=="base64" 
	then 
	doc=doc..strutil.decode(line, "base64") 
	else
	doc=doc..line
	end
line=S:readln()
end

ICalLoadEvents(Events, doc)
for i,event in ipairs(Events)
do
	AlmanacAddEvent(event)
end

end

function EmailHandleMimeItem(S, boundary)
local mime_info

mime_info=EmailReadHeaders(S)
print("ct: ".. mime_info.content_type.. " enc: ".. mime_info.encoding)

if mime_info.content_type == "text/calendar"
then
	EmailReadDocument(S, mime_info.boundary, mime_info.encoding)
end

end



function EmailImportCalendarItems(path)
local S, mime_info, boundary, str

S=stream.STREAM(path, "r")
mime_info=EmailReadHeaders(S)

boundary="--" .. mime_info.boundary
str=S:readln()
while str ~= nil
do
	str=strutil.stripTrailingWhitespace(str)
	if str==boundary then EmailHandleMimeItem(S, boundary) end
	str=S:readln()
end

end



function OutputICALHeader()
print("BEGIN:VCALENDAR")
end

function OutputICALTrailer()
print("END:VCALENDAR")
end


function OutputEventICAL(event)
local str, date

print("BEGIN:VEVENT")
print("SUMMARY:"..event.Title)
print("DESCRIPTION:"..event.Details)
print("LOCATION:"..event.Location)
print("DTSTART:"..time.formatsecs("%Y%m%dT%H%M%SZ", event.Start))
if event.End > 0 then print("DTEND:"..time.formatsecs("%Y%m%dT%H%M%SZ", event.End)) end
print("END:VEVENT")
end

function OutputCSVHeader()
print("Start,End,Title,Location,Attendees,Status");
end

function OutputCSVTrailer()
end

function OutputEventCSV(event)
local str, date

str=time.formatsecs("%a,%Y/%m/%d %H:%M,", event.Start) .. " - "  
if event.End > 0 then 
	str=str .. time.formatsecs("%H:%M,", event.End) 
else 
	str=str.. "?,"
end

str="\"" .. event.Title .. "\", \"" .. event.Location .. "\", \""..event.Attendees.."\", \""..event.Status.."\""
print(str)
end



function OutputEventANSI(event)
local str, date

str="~c"..time.formatsecs("%a %Y/%m/%d %H:%M", event.Start) .. " - "  
if event.End > 0 then 
	str=str .. time.formatsecs("%H:%M", event.End) 
else 
	str=str.. "?    "
end

str=str.."~0"
str=strutil.padto(str, ' ', 30)
str=str.. "  ~e~m" .. event.Title .."~0 " .. event.Location

if event.Attendees > 0 then str=str.." ~c" .. event.Attendees.. " attending~0" end
if event.Status=="cancelled" then str=str.." ~rCANCELLED~0" end
if event.Status=="tentative" then str=str.." ~e~y(tentative)~0" end
	
date=time.formatsecs("%Y%m%d",event.Start);
if date==Today then str=str.." ~e~rToday~0" end
if date==Tomorrow then str=str.." ~e~yTomorrow~0" end
print(terminal.format(str))
if ShowDetail 
then 
	if strutil.strlen(event.Details) > 0 then print(terminal.format(event.Details)) end
	print()
end

end

function OutputEventTXT(event)
local str, date

str=time.formatsecs("%a %Y/%m/%d %H:%M", event.Start) .. " - "  
if event.End > 0 then 
	str=str .. time.formatsecs("%H:%M", event.End) 
else 
	str=str.. "?    "
end

str=strutil.padto(str, ' ', 30)
str=str.. "  " .. event.Title .." " .. event.Location

if event.Attendees > 0 then str=str.." " .. event.Attendees.. " attending" end
if event.Status=="cancelled" then str=str.." CANCELLED" end
if event.Status=="tentative" then str=str.." (tentative)" end
	
date=time.formatsecs("%Y%m%d",event.Start);
if date==Today then str=str.." Today" end
if date==Tomorrow then str=str.." Tomorrow" end
print(terminal.format(str))
if ShowDetail 
then 
	print(event.Details) 
	print()
end

end



-- called by 'OutputCalendar' to check if an event has been 'hidden' and should not be displayed
function EventShow(event, Selections) 
local TOK, pattern, invert
local result=false

if strutil.strlen(Selections)==0 then return true end

TOK=strutil.TOKENIZER(Selections,",")
pattern=TOK:next()
while pattern ~= nil
do
	invert=false
	if string.sub(pattern, 1, 1) == "!" then 
		invert=true 
		pattern=string.sub(pattern, 2)
	end

	if strutil.pmatch(pattern, event.Title) > 0 
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




function OutputCalendar(Calendar, Selections)
local i, event

if OutputFormat=="csv" then OutputCSVHeader() 
elseif OutputFormat=="ical" then OutputICALHeader() 
end

for i,event in ipairs(Calendar)
do
	if event.Start >= EventsStart and ( EventsEnd == 0 or event.Start <= EventsEnd) and EventShow(event, Selections) 
	then
		if OutputFormat=="csv" then OutputEventCSV(event) 
		elseif OutputFormat=="ical" then OutputEventICAL(event) 
		elseif OutputFormat=="txt" then OutputEventTXT(event) 
		else OutputEventANSI(event)
		end
	end
end

if OutputFormat=="csv" then OutputCSVTrailer() 
elseif OutputFormat=="ical" then OutputICALTrailer() 
end


end



-- Sort events callback function. Sorts in date order and also finds the most recent event (which is used to decide whether to display events older than today)
function EventsSort(ev1, ev2)

if ev1.Start > EventsNewest then EventsNewest=ev1.Start end
if ev2.Start > EventsNewest then EventsNewest=ev2.Start end

if ev1.Start < ev2.Start then return true end
return false
end


function DisplayCalendarEvents(calendars, selections)
local T, cal
local Collated={}

T=strutil.TOKENIZER(calendars,",")
cal=T:next()
while cal ~= nil
do
if string.len(cal) > 0
then
	if string.sub(cal,1, 2) == "a:" then AlmanacLoadCalendar(Collated, string.sub(cal, 3)) 
	elseif string.sub(cal,1, 2) == "g:" then GCalLoadCalendar(Collated, string.sub(cal, 3)) 
	elseif string.sub(cal,1, 2) == "m:" then MeetupLoadCalendar(Collated, string.sub(cal, 3)) 
	elseif string.sub(cal,1, 7) == "webcal:" then DocumentLoadEvents(Collated, "http://" .. string.sub(cal, 8))
	else DocumentLoadEvents(Collated, cal)
	end
end
cal=T:next()
end

if #Collated > 0
then
	table.sort(Collated, EventsSort)
	if EventsNewest < Now or #Collated < 2 then EventsStart=0 end

	OutputCalendar(Collated, selections)
else
	print("No Events found to display")
end
end


function PrintHelp()
print("almanac - version: "..VERSION)
print("author: Colum Paget (colums.projects@gmail.com)")
print("licence: GPLv3")
print()
print("usage:  almanac [options] [calendar]...")
print()
print("almanac can pull calendar feeds from webcalendars using the google calendar api, meetup api, ical format, or xcal rss format")
print("google and meetup calendars are identified in the following format:")
print("g:calendar@hackercons.org          - a google calendar")
print("m:fizzPOP-Birminghams-Makerspace   - a meetup calendar")
print("the users default calendar can be specified as 'g:primary' and if no calendar is supplied then it will be displayed by default")
print("ical and rss webcalendars are identified by a url as normal.")
print("Currently only .ical or .ics files can be loaded from disk.")
print("Events can also be uploaded to google calendars that the user has permission for.")
print()
print("options:")
print("   -h <n>      show events for the next 'n' hours. The 'n' argument is optional, if missing 1 day will be assumed")
print("   -hour <n>   show events for the next 'n' hours. The 'n' argument is optional, if missing 1 day will be assumed")
print("   -d <n>      show events for the next 'n' days. The 'n' argument is optional, if missing 1 day will be assumed")
print("   -day  <n>   show events for the next 'n' days. The 'n' argument is optional, if missing 1 day will be assumed")
print("   -days <n>   show events for the next 'n' days. The 'n' argument is optional, if missing 1 day will be assumed")
print("   -w <n>      show events for the next 'n' weeks. The 'n' argument is optional, if missing 1 week will be assumed")
print("   -week <n>   show events for the next 'n' weeks. The 'n' argument is optional, if missing 1 week will be assumed")
print("   -m <n>      show events for the next 'n' weeks. The 'n' argument is optional, if missing 1 month will be assumed")
print("   -month <n>  show events for the next 'n' weeks. The 'n' argument is optional, if missing 1 month will be assumed")
print("   -y <n>      show events for the next 'n' weeks. The 'n' argument is optional, if missing 1 year will be assumed")
print("   -year <n>   show events for the next 'n' weeks. The 'n' argument is optional, if missing 1 year will be assumed")
print("   -at <loc>   show events at location 'loc'")
print("   -where <loc>     show events at location 'loc'")
print("   -location <loc>  show events at location 'loc'")
print("   -hide <pattern>  hide events whose title matches fnmatch/shell style pattern 'pattern'")
print("   -show <pattern>  show only events whose title matches fnmatch/shell style pattern 'pattern'")
print("   -detail     print event description/details")
print("   -details    print event description/details")
print("   -old        show events that are in the past")
print("   -import <url>  Import events from specified URL (usually an ical file) into calendar")
print("   -of <fmt>   specify format to output. 'csv' will output comma-seperated-values sutitable for reading into a spreadsheet, 'ical' will output ical/ics format, 'txt' will output plain text format, anything else will output text with ANSI color formatting")
print("   -u         Terminal supports unicode up to code 0x8000")
print("   -unicode   Terminal supports unicode up to code 0x8000")
print("   -u2        Terminal supports unicode up to code 0x8000")
print("   -unicode2  Terminal supports unicode up to code 0x10000")
print("   -?          This help")
print("   -h          This help")
print("   -help       This help")
print("   --help      This help")
print()
print("The following options all relate to inserting an event into a google calendar. if no google calendar is specified then the users primary calendar (g:primary) is assumed")
print("   -add <title>           add an event with specified title using the destination calendars default privacy setting")
print("   -addpub <title>        add a public event with specified title")
print("   -addpriv <title>       add a private event with specified title")
print("   -start <datetime>      start time of event (see 'time formats' below)")
print("   -end <datetime>        end time of event (see 'time formats' below)")
print("   -at <location>         location of event")
print("   -where <location>      location of event")
print("   -location <location>   location of event")
print("   -import <path>         import events from a .ical/.ics file and upload them to a calendar")
end



function ParseArg(args, i)
local val

val=args[i]
args[i]=""
return val

end

-- Parse a numeric command line argument. This will test if the next argument is numeric, if it is it will be consumed, 
-- if not then a value of 1 will be returned
function ParseNumericArg(args, i)
local val

	val=tonumber(args[i+1])
	if val == nil then 
	val=1 
	else args[i+1]=""
	end

	return val
end



-- Parse command line arguments. The 'add event' functionality is called directly from with this function if -add is encounted on the command line
function ParseCommandLine(args)
local i, v, val
local action="none"
local calendars=""
local selections=""
local locations=""
local import_urls={}
local NewEvent={}

NewEvent.Visibility="default"

for i,v in ipairs(args)
do
if v=="-s" or v=="-start"
then
	EventsStart=ParseDate(args[i+1])
	args[i+1]=""
end
end

if EventsStart==0 then EventStart=time.now() end

for i,v in ipairs(args)
do
if v=="-h" or v=="-hour"  then EventsEnd=EventsStart + 3600 * ParseNumericArg(args,i)
elseif v=="-d" or v=="-day" or v=="-days" then EventsEnd=EventsStart + 3600 * 24 * ParseNumericArg(args,i)
elseif v=="-w" or v=="-week" then EventsEnd=EventsStart + 3600 * 24 * 7 * ParseNumericArg(args,i)
elseif v=="-m" or v=="-month" then EventsEnd=EventsStart + 3600 * 24 * 7 * 4 * ParseNumericArg(args,i)
elseif v=="-y" or v=="-year" then EventsEnd=EventsStart + 3600 * 24 * 365 * ParseNumericArg(args,i)
elseif v=="-detail" or v=="-details" or v=="-v" then ShowDetail=true
elseif v=="-add" 
then 
		action="add"
		NewEvent.Title=ParseArg(args, i+1)
elseif v=="-addpub" 
then 
	action="add"
  NewEvent.Title=ParseArg(args, i+1)
	NewEvent.Visibility="public"
elseif v=="-addpriv"
then
	action="add"
  NewEvent.Title=ParseArg(args, i+1)
	NewEvent.Visibility="private"
elseif v=="-end"
then
	EventsEnd=ParseDate(args[i+1])
	args[i+1]=""
elseif v=="-at" or v=="-where" or v=="-location" then NewEvent.Location=ParseArg(args, i+1)
elseif v=="-import"
then
	action="import"
	table.insert(import_urls, args[i+1])
	args[i+1]=""
elseif v=="-email"
then
	action="import-email"
	table.insert(import_urls, args[i+1])
	args[i+1]=""
elseif v=="-hide"
then
	if strutil.strlen(selections) > 0 then selections=selections.. ",!" ..ParseArg(args,i+1) else selections="!"..ParseArg(args, i+1) end
elseif v=="-show"
then
	if strutil.strlen(selections) > 0 then selections=selections..","..ParseArg(args,i+1) else selections=ParseArg(args, i+1) end
elseif v=="-old"
then
	EventsStart=0
elseif v=="-persist" then Persist=true 
elseif v=="-of" then OutputFormat=ParseArg(args, i+1) 
elseif v=="-u" or v=="-unicode" then  terminal.unicodelvl(1)
elseif v=="-u2" or v=="-unicode2" then  terminal.unicodelvl(2)
elseif v=="-?" or v=="-h" or v=="-help" or v=="--help"
then
	action="help"
	os.exit() --othewise we will print default calendar
else
	if strutil.strlen(v) then calendars=calendars..","..v end
end

end

if strutil.strlen(calendars)==0 then calendars="a:default" end

if strutil.strlen(NewEvent.Title) > 0
then
	NewEvent.Start=EventsStart
	if EventsEnd > 0 
	then 
		NewEvent.End=EventsEnd
	else
		NewEvent.End=EventsStart
	end
end


for i,import in ipairs(import_urls)
do
	if action=="import-email"
	then
	EmailImportCalendarItems(import)
	else
	ImportEventsToCalendar(import, calendars)
	end
end

return action, NewEvent, calendars, selections 
end




--Main starts here
action,event,calendars,selections=ParseCommandLine(arg)

if action=="help"
then
	PrintHelp()
elseif action=="add"
then
	AlmanacAddEvent(event)
	--if strutil.strlen(NewEvent.Title) > 0 then GCalAddEvent(calendars, NewEvent) end
elseif Persist==true
then
	while true
	do
	DisplayCalendarEvents(calendars, selections)
	process.sleep(100)
	end
else
	DisplayCalendarEvents(calendars, selections)
end
