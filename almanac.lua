
require("oauth")
require("process")
require("strutil")
require("stream")
require("dataparser")
require("terminal")
require("filesys")
require("time")
require("hash")


VERSION="2.2"
Settings={}
EventsStart=time.secs()
EventsEnd=0
EventsNewest=0
Now=0
Today=""
Tomorrow=""
WarnEvents={}
display_count=0


--GENERIC FUNCTIONS

function UpdateTimes()
Now=time.secs()
Today=time.formatsecs("%Y/%m/%d", Now)
Tomorrow=time.formatsecs("%Y/%m/%d", Now+3600*24)
end



function DocumentGetType(S)
local Tokens, str, ext
local doctype=""

str=S:getvalue("HTTP:Content-Type")
if strutil.strlen(str) ~= 0
then
	Tokens=strutil.TOKENIZER(str, ";")
	doctype=Tokens:next()

	if doctype=="application/ical" then ext=".ical" 
	elseif doctype=="application/rss" then ext=".rss"
	elseif doctype=="text/calendar" 
	then 
		ext=".ical"
		doctype="application/ical"
	end
else
	str=S:path()
	if strutil.strlen(str) ~= nil
	then
		ext=filesys.extn(filesys.basename(str))
		if ext==".ical" then doctype="application/ical" 
		elseif ext==".rss" then doctype="application/rss" 
		end
	end
end

return doctype, ext
end 




function OpenCachedDocument(url)
local str, dochash, doctype, extn, S
local extns={".ical", ".rss"}

dochash=hash.hashstr(url, "md5", "hex")

if filesys.exists(url) == true then return(stream.STREAM(url, "r")) end

for i,extn in ipairs(extns)
do
str=process.getenv("HOME") .. "/.almanac/" .. dochash..extn
if filesys.exists(str) == true and (time.secs() - filesys.mtime(str)) < Settings.CacheTime then return(stream.STREAM(str, "r")) end
end

S=stream.STREAM(url)
if S ~= nil
then
	doctype,extn=DocumentGetType(S)
	S:close()
	str=process.getenv("HOME") .. "/.almanac/" .. dochash..extn
	filesys.copy(url, str)
	return(stream.STREAM(str, "r"))
end

return nil
end




--this function substitutes named values like '$(day)' with their actual data
function SubstituteEventStrings(format, event)
local toks, str, diff 
local values={}
local output=""

if event.Start==nil then return "" end

values["date"]=time.formatsecs("%Y/%m/%d", event.Start)
values["time"]=time.formatsecs("%H:%M:%S", event.Start)
values["day"]=time.formatsecs("%d", event.Start)
values["month"]=time.formatsecs("%m", event.Start)
values["Year"]=time.formatsecs("%Y", event.Start)
values["year"]=time.formatsecs("%y", event.Start)
values["dayname"]=time.formatsecs("%A", event.Start)
values["daynick"]=time.formatsecs("%a", event.Start)
values["monthname"]=time.formatsecs("%B", event.Start)
values["monthnick"]=time.formatsecs("%b", event.Start)
values["location"]=event.Location
values["title"]=event.Title

if values["date"]==Today 
then 
	values["dayid"]="Today"
	values["dayid_color"]="~r~eToday~0"
	values["daynick_color"]=time.formatsecs("~r~e%a~0", event.Start)
elseif values["date"]==Tomorrow
then 
	values["dayid"]="Tomorrow"
	values["dayid_color"]="~y~eTomorrow~0"
	values["daynick_color"]=time.formatsecs("~y~e%a~0", event.Start)
elseif event.Start < Now
then
	values["dayid"]=time.formatsecs("%A", event.Start)
	values["dayid_color"]=time.formatsecs("~R~n%a~0", event.Start)
	values["daynick_color"]=time.formatsecs("~R~n%a~0", event.Start)
else
	values["dayid"]=time.formatsecs("%A", event.Start)
	values["dayid_color"]=time.formatsecs("%a", event.Start)
	values["daynick_color"]=time.formatsecs("%a", event.Start)
end


diff=event.Start - Now
if diff < 0 then str="~R~b"
elseif diff < (10 * 60)  then str="~r"
elseif diff < (30 * 60) then str="~m"
elseif diff < (60 * 60) then str="~g"
else str=""
end

values["time_color"]=str ..time.formatsecs("%H:%M:%S", event.Start).."~0"

diff=event.End - event.Start
if diff < 0
then
	values["duration"]="??????"
elseif diff < 3600
then
	values["duration"]=string.format("%dmins", diff / 60)
else
	values["duration"]=time.formatsecs("%Hh%Mm", diff)
end

toks=strutil.TOKENIZER(format, "$(|)", "ms")
str=toks:next()
while str ~= nil
do
  if str=="$("
  then
    str=toks:next()
    if values[str] ~= nil then output=output .. values[str] end
  elseif strutil.strlen(str) and str ~= ")"
  then
    output=output..str
  end
  str=toks:next()
end

return output
end



--this function builds a single line from file formats (email headers and ical) that set limits on line length.
--these formats split long lines and start the continuation lines with a whitespace to indicate it's a
--continuation of the previousline
function UnSplitLine(lines)
local line, tok, char1

line=lines:next()
tok=lines:peek()

while line ~= nil and tok ~= nil
do
	line=strutil.stripCRLF(line)
	char1=string.sub(tok, 1, 1)
	if char1 ~= " " and char1 ~= "  " then break end

	--now really read the peeked token
	tok=strutil.stripCRLF(lines:next())
	line=line .. string.sub(tok, 2)
	tok=lines:peek()
end

return line
end



--count digits at start of a string, mostly used by ParseDate 
function CountDigits(str)
local count=0
local i

--no, we can't just use 'i' for the return values, because once we
--leave the loop i will reset to 0 (weird lua thing) so we then
--wouldn't know if we'd failed to loop at all, or had loops through
--all the characters in the string
for i=1,strutil.strlen(str),1
do
	if tonumber(string.sub(str,i,i)) == nil then return count end
	count=count + 1
end

return count
end


function ParseDuration(str)
local pos, multiplier

pos=CountDigits(str)
val=string.sub(str, 1, pos)
multiplier=string.sub(str, pos+1)

if multiplier == "m"
then 
retval=tonumber(val) * 60
elseif multiplier == "h"
then
retval=tonumber(val) * 3600
elseif multiplier == "d"
then
retval=tonumber(val) * 3600 * 24
elseif multiplier == "w"
then
retval=tonumber(val) * 3600 * 24 * 7
end

return retval
end



--Parse a date from a number of different formats
function ParseDate(datestr)
local len, lead_digits
local str=""
local when=0

len=strutil.strlen(datestr)
lead_digits=CountDigits(datestr)

if len==5 and string.sub(datestr, 3, 3) == ":"
then
	str=time.format("%Y-%m-%dT")..string.sub(datestr,1,2)..":"..string.sub(datestr,4,6)..":00"
elseif len==8
then
	if lead_digits == 8 --if it's ALL digits, then we have to presume YYYYmmdd
	then
	str=string.sub(datestr,1,4).."-"..string.sub(datestr,5,6).."-"..string.sub(datestr,7,8).."T00:00:00"
	elseif string.sub(datestr, 3, 3) == ":"
	then
		str=time.format("%Y-%m-%dT")..string.sub(datestr,1,2)..":"..string.sub(datestr,4,6)..":"..string.sub(datestr,7,8)
	else
	str="20"..string.sub(datestr,1,2).."-"..string.sub(datestr,4,5).."-"..string.sub(datestr,7,8).."T00:00:00"
	end
elseif len==10
then
	if lead_digits == 4
	then
		str=string.sub(datestr,1,4).."-"..string.sub(datestr,6,7).."-"..string.sub(datestr,9,10).."T00:00:00"
	else
		str=string.sub(datestr,7,10).."-"..string.sub(datestr,4,5).."-"..string.sub(datestr,1,2).."T00:00:00"
	end
elseif len==14
then
	str="20"..string.sub(datestr,1,2).."-"..string.sub(datestr,4,5).."-"..string.sub(datestr,7,8).."T"..string.sub(datestr,10,11)..":"..string.sub(datestr,13,14)
elseif len==15
then
	if lead_digits == 8 -- 20200212T140042
	then
	str=string.sub(datestr,1,4).."-"..string.sub(datestr,5,6).."-"..string.sub(datestr,7,8).."T"..string.sub(datestr,10,11)..":"..string.sub(datestr,12,13)..":"..string.sub(datestr,14,15)
	end
elseif len==16
then
	if lead_digits == 8 -- 20200212T140042Z
	then
	str=string.sub(datestr,1,4).."-"..string.sub(datestr,5,6).."-"..string.sub(datestr,7,8).."T"..string.sub(datestr,10,11)..":"..string.sub(datestr,12,13)..":"..string.sub(datestr,14,15)
	elseif lead_digits == 4
	then
		str=string.sub(datestr,1,4).."-"..string.sub(datestr,6,7).."-"..string.sub(datestr,9,10).."T"..string.sub(datestr,12,13)..":"..string.sub(datestr, 15, 16)..":00"
	else
		str=string.sub(datestr,7,10).."-"..string.sub(datestr,4,5).."-"..string.sub(datestr,1,2).."T"..string.sub(datestr,12,13)..":"..string.sub(datestr, 15, 16)..":00"
	end
elseif len==19
then
		str=string.sub(datestr,1,4).."-"..string.sub(datestr,6,7).."-"..string.sub(datestr,9,10).."T"..string.sub(datestr,12,13)..":"..string.sub(datestr, 15, 16)..":"..string.sub(datestr, 18)
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
tmpstr=string.gsub(tmpstr, '\n', '')
tmpstr=string.gsub(tmpstr, "United States", "USA")
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
Event.UID=string.format("%x",time.secs())
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

toks=strutil.TOKENIZER(line,":|;","ms")
key=toks:next()
tok=toks:next()
while tok==";"
do
	tok=toks:next()
	if tok==nil then break end
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
local Tokens, str, i
local Timezone=""

value=strutil.trim(value);

Tokens=strutil.TOKENIZER(extra,";")
str=Tokens:next()
while str ~= nil
do
if string.sub(str,1,5) =="TZID=" then Timezone=string.sub(str,6) end
str=Tokens:next()
end

--return(time.tosecs("%Y%m%dT%H%M%S", value, Timezone))
return(ParseDate(value))
end



function ICalParseEvent(lines, Events)
local key, value, extra, tmpstr
local Event

Event=EventCreate()
key,value,extra=ICalNextLine(lines)
while key ~= nil
do
	if key=="END" and value=="VEVENT" then break
	elseif key=="UID" then Event.UID=value 
	elseif key=="BEGIN" then ICalReadPastSubItem(lines, value)
	elseif key=="SUMMARY" then 
		tmpstr=string.gsub(strutil.unQuote(value),"\n"," ")
		Event.Title=strutil.stripCRLF(tmpstr)
	elseif key=="DESCRIPTION" 
	then 
		tmpstr=string.gsub(strutil.unQuote(value),"\n\n","\n")
		Event.Details=strutil.stripCRLF(tmpstr)
	elseif key=="LOCATION" then LocationParse(Event, value)
	elseif key=="STATUS" then Event.Status=value
	elseif key=="DTSTART" then 
		Event.Start=ICalParseTime(value, extra)
	elseif key=="DTEND" then Event.End=ICalParseTime(value, extra)
	elseif key=="ATTENDEE" then Event.Attendees=Event.Attendees+1 
	end

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





-- FUNCTIONS FOR PARSING RSS and XCal FILES

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




function RSSLoadEvents(Collated, doc)
local P, Events, Item, values, doc

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
	OA=oauth.OAUTH("auth","gcal",Settings.GCalClientID, Settings.GCalClientSecret,"https://www.googleapis.com/auth/calendar", "https://www.googleapis.com/oauth2/v4/token");
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
S=stream.STREAM(url, "w oauth=" .. OA:name() .. " content-type=" .. "application/json " .. "content-length=" .. strutil.strlen(text))

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
	OA=oauth.OAUTH("auth","gcal",Settings.GCalClientID, Settings.GCalClientSecret,"https://www.googleapis.com/auth/calendar", "https://www.googleapis.com/oauth2/v4/token");
	if OA:load() == false then OAuthGet(OA) end
end

url="https://www.googleapis.com/calendar/v3/calendars/".. strutil.httpQuote(cal) .."/events?singleEvents=true"
if EventsStart > 0
then 
	url=url.."&timeMin="..strutil.httpQuote(time.formatsecs("%Y-%m-%dT%H:%M:%SZ", EventsStart))
end

S=stream.STREAM(url,"oauth="..OA:name())
doc=S:readdoc()

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
local S, str, event, toks, when
local tmpTable={}

str=process.getenv("HOME") .. time.format("/.almanac/%b-%Y.cal")
S=stream.STREAM(str)
if S ~= nil
then
str=S:readln()
while str ~= nil
do
	event=EventCreate()
	toks=strutil.TOKENIZER(str, "\\S", "Q")
	event.Added=time.tosecs("%Y/%m/%d.%H:%M:%S", toks:next())
	event.UID=toks:next()
	event.Start=time.tosecs("%Y/%m/%d.%H:%M:%S", toks:next())
	event.End=time.tosecs("%Y/%m/%d.%H:%M:%S", toks:next())
	event.Title=toks:next()
	event.Location=toks:next()
	event.Details=strutil.unQuote(toks:next())
	tmpTable[event.UID]=event
	str=S:readln()
end
S:close()
end


for key,event in pairs(tmpTable)
do
	when=Settings.WarnTime
	if Settings.WarnRaisedTime > Settings.WarnTime then when=Settings.WarnRaisedTime end
	if when > 0 and (Now - event.Start) < when
	then
		table.insert(WarnEvents, event)
	end

	table.insert(Collated, event)
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
str=time.format("%Y/%m/%d.%H:%M:%S") .. " " .. event.UID .. " "..time.formatsecs("%Y/%m/%d.%H:%M:%S ", event.Start)
str=str .. time.formatsecs("%Y/%m/%d.%H:%M:%S ", event.End)
str=str .. "\"" .. event.Title .. "\" \""..event.Location.."\" \"" .. string.gsub(event.Details, "\n", "\\n") .."\""
S:writeln(str.."\n")
S:close()
end
end





function DocumentLoadEvents(Events, url)
local S, doctype, doc

S=OpenCachedDocument(url);
if S ~= nil
then
	doctype=DocumentGetType(S)
	doc=S:readdoc()
	if doctype=="text/xml" or doctype=="application/rss" or doctype=="application/rss+xml" 
	then 
		RSSLoadEvents(Events, doc)
	else
		ICalLoadEvents(Events, doc)
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



function EmailReadDocument(S, boundary, encoding, EventsFunc)
local line, event, i, len
local doc=""
local Events={}

if config.debug==true then io.stderr:write("extract:  enc="..encoding.." boundary="..boundary.."\n") end
len=strutil.strlen(boundary)
line=S:readln()
while line ~= nil
do
	if len > 0 and string.sub(line, 1, len) == boundary then break end
	if encoding=="base64" then line=strutil.trim(line) end
	doc=doc..line
	line=S:readln()
end

if encoding=="base64"
then
	doc=strutil.decode(doc, "base64") 
elseif encoding=="quoted-printable"
then 
	doc=strutil.decode(doc, "quoted-printable") 
end


if config.debug==true then io.stderr:write("doc:  "..doc.."\n") end
doc=string.gsub(doc, "\r\n", "\n")
ICalLoadEvents(Events, doc)
for i,event in ipairs(Events)
do
	EventsFunc(event)
end

end


function EmailHandleMimeContainer(S, mime_info, EventsFunc)
local str, boundary

boundary="--" .. mime_info.boundary
str=S:readln()
while str ~= nil
do
	str=strutil.stripTrailingWhitespace(str)
	if str==boundary then EmailHandleMimeItem(S, boundary, EventsFunc) end
	str=S:readln()
end
end


function EmailHandleMimeItem(S, boundary, EventsFunc)
local mime_info

mime_info=EmailReadHeaders(S)

if config.debug==true then io.stderr:write("mime item: ".. mime_info.content_type.." enc="..mime_info.encoding.." boundary="..mime_info.boundary.."\n") end
if mime_info.content_type == "text/calendar"
then
	EmailReadDocument(S, boundary, mime_info.encoding, EventsFunc)
	mime_info.content_type=""
elseif mime_info.content_type == "multipart/mixed"
then
	EmailHandleMimeContainer(S, mime_info, EventsFunc)
end

end



function EmailExtractCalendarItems(path, EventsFunc)
local S, mime_info, boundary, str

S=stream.STREAM(path, "r")
if S ~= nil
then
mime_info=EmailReadHeaders(S)
EmailHandleMimeContainer(S, mime_info, EventsFunc)
S:close()
end

end


-- These functions output calendar in standard ICAL calendar format
function OutputICALHeader(Out)
Out:writeln("BEGIN:VCALENDAR\n")
end

function OutputICALTrailer(Out)
Out:writeln("END:VCALENDAR\n")
end


function OutputEventICAL(Out, event)
local str, date

Out:writeln("BEGIN:VEVENT\n")
Out:writeln("SUMMARY:"..event.Title.."\n")
Out:writeln("DESCRIPTION:"..event.Details.."\n")
Out:writeln("LOCATION:"..event.Location.."\n")
Out:writeln("DTSTART:"..time.formatsecs("%Y%m%dT%H%M%SZ", event.Start).."\n")

if event.End > 0
then 
	diff=event.End-Event.Start
	if Settings.MaxEventLength > -1 and diff > Settings.MaxEventLength
	then 
		Out:writeln("DTEND:"..time.formatsecs("%Y%m%dT%H%M%SZ", event.Start + Settings.MaxEventLength).."\n") 
	else
		Out:writeln("DTEND:"..time.formatsecs("%Y%m%dT%H%M%SZ", event.End).."\n") 
	end
end

Out:writeln("END:VEVENT".."\n")
end



-- These functions output calendars in the format for Sanjay Ghemawat's 'ical' program,
-- https://en.wikipedia.org/wiki/Ical_%28Unix%29
-- which is nothing to do with Apple's 'ical' format

function OutputSGIcalHeader(Out)
Out:writeln("Calendar [v2.0]\n")
end

function OutputSGIcalTrailer(Out)
end

function OutputEventSGIcal(Out, event)
local str, date

Out:writeln("Appt [\n")
start_str=time.formatsecs("%Y%m%dT000000", event.Start)
diff=event.Start - time.tosecs("%Y%m%dT%H%M%S", start_str)
Out:writeln(string.format("Start [%d]\n", diff / 60))

diff=(event.End - event.Start)
if Settings.MaxEventLength > -1 and diff > Settings.MaxEventLength then diff=Settings.MaxEventLength end
Out:writeln(string.format("Length [%d]\n", diff / 60))
Out:writeln("Uid ["..event.UID.."]\n")
str="Contents [" .. event.Title
if strutil.strlen(event.Location) > 0 then str=str.. "\nAt: " .. event.Location end
if strutil.strlen(event.Description) > 0 then str=str.. "\n" .. event.Description end
str=str.."]\n"
Out:writeln(str)
Out:writeln("Remind [1]\n");
Out:writeln("Hilite [1]\n");
Out:writeln(time.formatsecs("Dates [Single %d/%m/%Y End ]\n", event.Start));
Out:writeln("]\n");
end



function OutputCSVHeader(Out)
Out:writeln("Start,End,Title,Location,Attendees,Status\n")
end


function OutputCSVTrailer(Out)
end



function OutputEventCSV(Out, event)
local str, date

str=time.formatsecs("%a,%Y/%m/%d %H:%M,", event.Start) .. " - "  
if event.End > 0 
then 
	str=str .. time.formatsecs("%H:%M,", event.End) 
else 
	str=str.. "?,"
end

str="\"" .. event.Title .. "\", \"" .. event.Location .. "\", \""..event.Attendees.."\", \""..event.Status.."\"\n"
Out:writeln(str)
end



function OutputEventANSI(event)
str=SubstituteEventStrings(Settings.DisplayFormat, event)
print(terminal.format(str))
if Settings.ShowDetail 
then 
	if strutil.strlen(event.Details) > 0 then print(terminal.format(event.Details)) end
	print()
end

end


function OutputEventTXT(event)
local str, date

str=time.formatsecs("%a %Y/%m/%d %H:%M", event.Start) .. " - "  
if event.End > 0 
then 
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
if Settings.ShowDetail 
then 
	print(event.Details) 
	print()
end

end



-- called by 'OutputCalendar' to check if an event has been 'hidden' and should not be displayed
function EventShow(event, Selections) 
local TOK, pattern, invert
local result=false

if EventsStart==nil then print("ERROR: Events start==nil") end

if event.Start == nil then return false end
if event.Start < EventsStart then return false end
if EventsEnd > 0 and event.Start > EventsEnd then return false end

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




function OutputCalendar(Out, Events, Selections)
local i, event

if Settings.OutputFormat=="csv" then OutputCSVHeader(Out) 
elseif Settings.OutputFormat=="ical" then OutputICALHeader(Out) 
elseif Settings.OutputFormat=="sgical" then OutputSGIcalHeader(Out) 
end

for i,event in ipairs(Events)
do
	if EventShow(event, Selections) 
	then
		if Settings.OutputFormat=="csv" then OutputEventCSV(Out, event) 
		elseif Settings.OutputFormat=="ical" then OutputEventICAL(Out, event) 
		elseif Settings.OutputFormat=="sgical" then OutputEventSGIcal(Out, event) 
		elseif Settings.OutputFormat=="txt" then OutputEventTXT(event) 
		else OutputEventANSI(event)
		end
	end
end

if Settings.OutputFormat=="csv" then OutputCSVTrailer(Out) 
elseif Settings.OutputFormat=="ical" then OutputICALTrailer(Out) 
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
	if string.sub(cal,1, 2) == "a:" then AlmanacLoadCalendar(Events, string.sub(cal, 3)) 
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
	if EventsNewest < Now or #Events < 2 then EventsStart=0 end
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
print()
print("The default calendar is stored on disk, and is referred to as 'a:default',  and if no calendar is supplied then it will be displayed by default")
print("ical and rss webcalendars are identified by a url as normal.")
print("Events can also be uploaded to google calendars that the user has permission for. If pushing events to a user's google calendar, or displaying events from it, this can be specified as 'g:primary'")
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
print("   -import-email <url>  Import events from ical attachments within an email file at the specified URL into calendar")
print("   -persist    don't exit, but print out events in a loop. This can be used to create an updating window that displays upcoming events.")
print("   -lfmt <format string>          line format for ansi output (see 'display formats' for details of title strings)")
print("   -xt <title string>             when -persist is used, also set the xterm title to be <title string> (see 'display formats' for details of title strings)")
print("   -xtitle <title string>         when -persist is used, also set the xterm title to be <title string> (see 'display formats' for details of title strings)")
print("   -xterm-title <title string>    when -persist is used, also set the xterm title to be <title string> (see 'display formats' for details of title strings)")
print("   -of <fmt>   specify format to output. '<fmt> will be one of 'csv', 'ical', 'sgical', 'txt' or 'ansi'. Default is 'ansi'. See 'Output Formats' below for more details")
print("   -refresh <len>                 when in persist mode, update with this frequency, where 'len' is a number postfixed by 'm' 'h' 'd' or 'w' for 'minutes', 'hours', 'days' or 'weeks'. e.g. '2d' two days, '30m' thiry minutes. Default 2m.")
print("   -maxlen <len>     When importing calendars set the max length of an event to <len> where len is a number postfixed by 'm' 'h' 'd' or 'w' for 'minutes', 'hours', 'days' or 'weeks'. e.g. '2d' two days, '30m' thiry minutes.")
print("   -u         Terminal supports unicode up to code 0x8000")
print("   -unicode   Terminal supports unicode up to code 0x8000")
print("   -u2        Terminal supports unicode up to code 0x8000")
print("   -unicode2  Terminal supports unicode up to code 0x10000")
print("   -?          This help")
print("   -h          This help")
print("   -help       This help")
print("   --help      This help")
print()
print("ADD EVENTS")
print("The following options all relate to inserting an event into an almanac or a google calendar. if calendar is specified then the default almanac calendar (a:default) is assumed. You can instead use the user's primary google calendar by specifiying 'g:primary'")
print("   -add <title>           add an event with specified title using the destination calendars default privacy setting")
print("   -addpub <title>        add a public event to a google calendar with specified title")
print("   -addpriv <title>       add a private event to a google calendar with specified title")
print("   -start <datetime>      start time of event (see 'time formats' below)")
print("   -end <datetime>        end time of event (see 'time formats' below)")
print("   -at <location>         location of event")
print("   -where <location>      location of event")
print("   -location <location>   location of event")
print("   -import <path>         import events from a .ical/.ics file and upload them to a calendar")
print()
print("example: almanac.lua -add \"dental appointment\" -start \"2020/01/23\"")
print()
print("TIME FORMATS")
print("almanac accepts the following date/time formats:")
print("")
print("HH:MM                 -  4 digit time, date is 'today'")
print("HH:MM:SS              -  6 digit time, date is 'today'")
print("YYYYMMDD              -  8 digit date, e.g. 19890101")
print("YY?MM?DD              -  6 digit date with any separator character OTHER THAN ':' (so ? can be anything, e.g. 89/01/01)")
print("YYYY?MM?DD            -  8 digit date with any separator character (so ? can be anything, e.g. 1989:01:01)")
print("YYYYMMDDTHHMM         -  8 digit date with time e.g. 19890101T11:40:00")
print("YYYYMMDDTHHMMSS       -  8 digit date with time e.g. 19890101T11:40:00")
print("YYYYMMDDTHHMMSSZ      -  8 digit date with time e.g. 19890101T11:40:00Z")
print("YYYY?MM?DDTHH?MM?SS   -  8 digit date with time e.g. 1989/01/01T11:40:00")
print("")
print("Currently the following *discouraged* formats are also supported. Almanac doesn't have locale support yet and these support UK/international date format")
print("")
print("DD?MM?YYYY            -  8 digit date with any separator character (so ? can be anything, e.g. 1989:01:01)")
print("DD?MM?YYYYTHH?MM?SS   -  8 digit date with time e.g. 1989/01/01T11:40:00")
print("")
print("OUTPUT FORMATS")
print("the '-of' option can specify one of the following output formats:")
print("csv     output comma-seperated-values suitable for reading into a spreadsheet.")
print("txt     output plain text format.")
print("ical    output ical/ics format.")
print("sgical  output file format sutable for Sanjay Ghemawat's unix ical application.")
print("ansi    output text with ANSI color formatting")
print()
print("DISPLAY FORMATS")
print("In the default mode, ansi display mode, you can specify the line-by-line output format by using a combination of color identifiers and data identifiers.")
print("data identifiers: these are strings that will be replaced by the specified value")
print("$(title)          event title/summary")
print("$(date)           start date in Y/m/d format")
print("$(time)           start time in H:M:S format")
print("$(day)            numeric day of month")
print("$(month)          numeric month of year")
print("$(Year)           year in 4-digit format")
print("$(year)           year in 2-digit format")
print("$(monthname)      Full name of month ('Feburary')")
print("$(monthnick)      Short name of month ('Feb')")
print("$(dayname)        full name of day (Monday, Tuesday, Wednesday...)")
print("$(daynick)        short name of day (Mon, Tues, Wed...)")
print("$(dayid)          like dayname, except including 'today' and 'tomorrow'")
print("$(dayid_color)    like dayid, but today will be in ansi red, tomorrow in ansi yellow")
print("$(daynick_color)  like daynick, but today will be in ansi red, tomorrow in ansi yellow, although they will still have daynick names")
print("$(location)       event location")
print("$(duration)       event duration")
print()
print("color identifiers: format strings that specifier colors")
print("~0      reset colors")
print("~r      red")
print("~g      green")
print("~b      blue")
print("~y      yellow")
print("~m      magenta")
print("~c      cyan")
print("~w      white")
print("~n      noir (black)")
print("~e      bold (emphasis)")
print("default display format is:  ~c$(dayid_color)~0 $(date) $(time_color) $(duration) ~e~m$(title)~0 $(location)")
print()
print("EXAMPLES")
print()
print("display default calendar")
print("	almanac.lua a:default")
print()
print("display user's primary google calendar")
print("	almanac.lua g:primary")
print()
print("display web calendar")
print("	almanac.lua https://launchlibrary.net/1.3/calendar/next/100")
print()
print("output web calendar in format suitable for Sanjay Ghemawat's 'ical' program, and redirect to a file that ical can import") 
print("	almanac.lua -of sgical https://launchlibrary.net/1.3/calendar/next/100 > launches.calendar")
print()
print("output web calendar in CSV format suitable spreadsheet import") 
print("	almanac.lua -of csv https://launchlibrary.net/1.3/calendar/next/100 > launches.csv")
print()
print("add event to almanac calendar")
print("	almanac.lua -add \"dental appointment\" -start \"2020/01/23\"")
print("	almanac.lua a:default -add \"dental appointment\" -start \"2020/01/23\"")
print()
print("add event to google calendar")
print("	almanac.lua g:primary -add \"dental appointment\" -start \"2020/01/23\"")
print("	almanac.lua g:me@mydomain.org -add \"next meeting\" -start \"2020/01/23\"")
print()
print("import an ical url into local calendar") 
print("	almanac.lua a:default -import https://launchlibrary.net/1.3/calendar/next/100")
print()
print("import all ical attachments in an email file into local calendar") 
print("	almanac.lua a:default -import-email mailfile.mail")
print()

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
local NewEvent
local Config={}

Config.action="none"
Config.debug=false
Config.calendars=""
Config.selections=""

NewEvent=EventCreate()
NewEvent.Visibility="default"

--as other values are set relative to EventsStart, so we have to grab any '-start' option before all others
for i,v in ipairs(args)
do
if v=="-s" or v=="-start" then EventsStart=ParseDate(ParseArg(args, i+1)) end
end

if EventsStart==0 then EventsStart=time.secs() end

for i,v in ipairs(args)
do

if v=="-debug" then Config.debug=true
elseif v=="-h" or v=="-hour"  then EventsEnd=EventsStart + 3600 * ParseNumericArg(args,i)
elseif v=="-d" or v=="-day" or v=="-days" then EventsEnd=EventsStart + 3600 * 24 * ParseNumericArg(args,i)
elseif v=="-w" or v=="-week" then EventsEnd=EventsStart + 3600 * 24 * 7 * ParseNumericArg(args,i)
elseif v=="-m" or v=="-month" then EventsEnd=EventsStart + 3600 * 24 * 7 * 4 * ParseNumericArg(args,i)
elseif v=="-y" or v=="-year" then EventsEnd=EventsStart + 3600 * 24 * 365 * ParseNumericArg(args,i)
elseif v=="-detail" or v=="-details" or v=="-v" then Settings.ShowDetail=true
elseif v=="-add" 
then 
	Config.action="add"
	NewEvent.Title=ParseArg(args, i+1)
elseif v=="-addpub" 
then 
	Config.action="add"
	NewEvent.Title=ParseArg(args, i+1)
	NewEvent.Visibility="public"
elseif v=="-addpriv"
then
	Config.action="add"
	NewEvent.Title=ParseArg(args, i+1)
	NewEvent.Visibility="private"
elseif v=="-start" or v=="-s"
then
	--do nothing! this is handled by the earlier loop
elseif v=="-end"
then
	EventsEnd=ParseDate(ParseArg(args, i+1))
elseif v=="-maxlen"
then
	Settings.EventMaxLength=ParseDuration(ParseArg(args, i+1))
elseif v=="-at" or v=="-where" or v=="-location" then NewEvent.Location=ParseArg(args, i+1)
elseif v=="-import"
then
	Config.action="import"
	Config.selections=Config.selections..ParseArg(args, i+1).."\n"
elseif v=="-email" or v=="-import-email"
then
	Config.action="import-email"
	Config.selections=Config.selections..ParseArg(args, i+1).."\n"
elseif v=="-xt" or v=="-xterm-title" or v=="-xtitle" then Settings.XtermTitle=ParseArg(args, i+1)
elseif v=="-refresh" then Settings.RefreshTime=ParseDuration(ParseArg(args, i+1))
elseif v=="-lfmt" then Settings.DisplayFormat=ParseArg(args, i+1)
elseif v=="-hide"
then
	if strutil.strlen(Config.selections) > 0 then Config.selections=Config.selections.. ",!" ..ParseArg(args,i+1) else Config.selections="!"..ParseArg(args, i+1) end
elseif v=="-show"
then
	if strutil.strlen(Config.selections) > 0 then Config.selections=Config.selections..","..ParseArg(args,i+1) else Config.selections=ParseArg(args, i+1) end
elseif v=="-old" then EventsStart=0
elseif v=="-persist" then Settings.Persist=true 
elseif v=="-warn" then Settings.WarnTime=ParseDuration(ParseArg(args, i+1))
elseif v=="-warn-raise" then Settings.WarnRaisedTime=ParseDuration(ParseArg(args, i+1))
elseif v=="-of" then Settings.OutputFormat=ParseArg(args, i+1) 
elseif v=="-u" or v=="-unicode" then  terminal.unicodelvl(1)
elseif v=="-u2" or v=="-unicode2" then  terminal.unicodelvl(2)
elseif v=="-u3" or v=="-unicode3" then  terminal.unicodelvl(3)
elseif v=="-?" or v=="-h" or v=="-help" or v=="--help"
then
	Config.action="help"
else
	if strutil.strlen(v) > 0 then Config.calendars=Config.calendars..","..v end
end

end

if strutil.strlen(Config.calendars)==0 then Config.calendars="a:default" end

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

return Config, NewEvent
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




function SetupTerminal()
local S
local Out=nil

S=stream.STREAM("stdout")
if S:isatty() == true
then
Out=terminal.TERM(S)
end

return Out
end



--this function sets up initial values of some settings
function Init()

-- output format can be 'csv', 'ical', 'sgical', 'txt' and 'ansi'. default is ansi
Settings.OutputFormat=""

-- persist means instead of just print out a list of events, print out the list, sleep for a bit,
-- clear screen and print out again in an eternal loop
Settings.Persist=false

-- if 'ShowDetail' is true then display event descriptions as well as summary/title
Settings.ShowDetail=false

-- xterm title line to display when in persist mode
Settings.XtermTitle="$(dayname) $(day) $(monthname)"

Settings.RefreshTime=ParseDuration("2m")

-- 'DisplayFormat' is used in 'ansi' output (the default display type) 
Settings.DisplayFormat="~c$(daynick_color)~0 $(date) $(time_color) $(duration) ~e~m$(title)~0 $(location)"

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



function XtermTitle(Out, title)
local str
local ev={}

if strutil.strlen(title) > 0
then
	ev.Start=Now;
	ev.End=Now;
	str=string.format("\x1b]2;%s\x07", SubstituteEventStrings(title, ev))
	Out:puts(str)			
end
end



function LoadAndOutputCalendar(calendars, selections)
local Out
local Events={}

Out=stream.STREAM("-")
LoadCalendarEvents(calendars, selections, Events)
OutputCalendar(Out, Events, selections)

end


function EventSoonest(WarnEvents)
local i, event, soonest

for i,event in ipairs(WarnEvents)
do
if soonest==nil or event.Start < soonest.Start then soonest=event end
end

return soonest
end


function WaitEvents(Out)
local event, action="", ch, title

	title=Settings.XtermTitle

	if #WarnEvents > 0
	then
		event=EventSoonest(WarnEvents)
		if event.Start < Settings.WarnRaisedTime then Out:puts("\x1b[5t") end

		if display_count % 2 == 0
		then
		title=string.format("* * *   %s in %d mins", event.Title, math.floor((event.Start - Now) / 60))
		else
		title=string.format("_ _ _   %s in %d mins", event.Title, math.floor((event.Start - Now) / 60))
		end

		next_update=Now + 1	
		Out:timeout(100) --one sec
	else
		Out:timeout(1000) --ten secs
	end


	XtermTitle(Out, title)
	ch=Out:getc()

	if ch=="m" then
		action="menu"
	elseif ch=="LEFT" then 
		EventsStart=EventsStart - (3600 * 24 *7)
		action="refresh"
	elseif ch=="RIGHT" then 
		EventsStart=EventsStart + (3600 * 24 *7)
		action="refresh"
	end

	display_count=display_count + 1

return action
end


function DisplayCalendarMenu(Out, calendars) 
local menu, str
local cal_list

Out:clear()
menu=terminal.TERMMENU(Out, 1, 1, Out:width() -1, Out:height() -1)
menu:add("all")
menu:add("Recently Added", "recent")

toks=strutil.TOKENIZER(calendars,",")
str=toks:next()
while str ~= nil
do
	menu:add(str)	
	str=toks:next()
end

str=menu:run()
if str=="all"
then
	cal_list=calendars
else
	cal_list=str
end

return cal_list
end


-- This function loops around outputing a list of events
function PersistentScheduleDisplay(calendars, selections)
local Out, Events, action, next_update, display_calendars

Out=terminal.TERM()
next_update=Now

display_calendars=calendars
while true
do
	Events={}
	WarnEvents={}
	LoadCalendarEvents(display_calendars, selections, Events)

	if Out ~= nil
	then
		XtermTitle()
		print("\x1b[3J") -- clear scrollback buffer
		Out:clear()
		Out:move(0,0)
	end

	OutputCalendar(Out, Events, selections)
	next_update=Now + Settings.RefreshTime

	while Now < next_update
	do
		action=WaitEvents(Out) 
		if action == "refresh" 
		then 
			break 
		elseif action == "menu"
		then
			display_calendars=DisplayCalendarMenu(Out, calendars)
			Out:clear()
			break
		end
		UpdateTimes()
	end

end
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
elseif Settings.Persist==true
then
	PersistentScheduleDisplay(config.calendars, config.selections)
else
	LoadAndOutputCalendar(config.calendars, config.selections)
end
