
require("oauth")
require("process")
require("strutil")
require("stream")
require("dataparser")
require("terminal")
require("filesys")
require("time")
require("hash")


VERSION="5.0"
Settings={}
EventsNewest=0
Now=0
Today=""
Tomorrow=""
WarnEvents={}
display_count=0
Out=nil
Term=nil

--GENERIC FUNCTIONS

function UpdateTimes()
Now=time.secs()
Today=time.formatsecs("%Y/%m/%d", Now)
Tomorrow=time.formatsecs("%Y/%m/%d", Now+3600*24)
end


-- how is it that no one can ever stick one a single mime type for
-- a single type of document?
function AnalyzeContentType(ct)

if ct=="text/calendar" then return "application/ical" end
if ct=="application/ics" then return "application/ical" end

if ct=="text/xml" then return "application/rss" end
if ct=="application/rss+xml" then return "application/rss" end

return ct
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
Event.URL=""
Event.src=""

return Event
end


-- create a blank event object
function EventClone(parent)
local Event={}

Event.Attendees=parent.Attendees
Event.UTCoffset=parent.UTCoffset;
Event.UID=parent.UID
Event.Title=parent.Title
Event.Details=parent.Details
Event.Status=parent.Status
Event.Location=parent.Location
Event.Details=parent.Details
Event.Visibility=parent.Visiblity
Event.Start=parent.Start
Event.End=parent.End
Event.URL=parent.URL
Event.src=parent.src

return Event
end


function EventRecurParse(event)
local i, char, str
local recur_suffix=""
local recur_val=0

str=""
for i=1,strutil.strlen(event.Recurs),1
do
	char=string.sub(event.Recurs, i, i)
	if tonumber(char) ~= nil then str=str .. char
	else recur_suffix=recur_suffix..char
	end
end

recur_val=tonumber(str)

if recur_suffix=="y" then recur_val=recur_val * 3600 * 24 * 365
elseif recur_suffix=="m" then recur_val=recur_val * 3600 * 24 * 31
elseif recur_suffix=="w" then recur_val=recur_val * 3600 * 24 * 7
elseif recur_suffix=="d" then recur_val=recur_val * 3600 * 24 
elseif recur_suffix=="h" then recur_val=recur_val * 3600 
end


return recur_val
end


function EventRecurringCheckDST(when, start_hour)
local recur_hour

recur_hour=tonumber(time.formatsecs("%H", when)) 
if recur_hour ~= start_hour
then 
if recur_hour > start_hour then diff = (recur_hour - start_hour) * 3600
when= when + ((start_hour - recur_hour) * 3600) 
end
end

return when
end


function EventRecurring(EventsList, event, start_time, end_time)
local recur_val, when, start_hour, gmt_event, str, local_time
local dst=false

start_hour=tonumber(time.formatsecs("%H", event.Start, "GMT"))
recur_val=EventRecurParse(event)

-- convert to GMT so we don't have to deal with Daylight savings time
str=time.formatsecs("%Y/%m/%d:%H:%M:%S", event.Start)
when=time.tosecs("%Y/%m/%d:%H:%M:%S", str, "GMT")
while when < end_time
do

when=EventRecurringCheckDST(when, start_hour)

if when >= start_time and when <= end_time 
then 
	new_event=EventClone(event)
	-- convert back from GMT, so that midnight is always midnight, not an hour adrift
	str=time.formatsecs("%Y/%m/%d:%H:%M:%S", when, "GMT")
	new_event.Start=time.tosecs("%Y/%m/%d:%H:%M:%S", str)
	new_event.End=time.tosecs("%Y/%m/%d:%H:%M:%S", str)
	table.insert(EventsList, new_event)
end

when=when + recur_val
end

return when
end


function EventRecursInPeriod(event, start_time, end_time)
local recur_val, when

recur_val=EventRecurParse(event)
when=event.Start
while when < end_time
do
if when >= start_time and when <= end_time then  return when end
when=when + recur_val
end

return nil
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
local pos, multiplier, val, retval

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
else
retval=tonumber(val)
end

return retval
end



--Parse a date from a number of different formats
function ParseDate(datestr, Zone)
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

when=time.tosecs("%Y-%m-%dT%H:%M:%S", str, Zone)
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

if string.sub(tmpstr, 1, 6) == "https:" then Event.URL=tmpstr
else Event.Location=tmpstr
end

end


-- do initial oauth authentication
function OAuthGet(OA)

OA:set("redirect_uri", "http://127.0.0.1:8989");
OA:stage1("https://accounts.google.com/o/oauth2/v2/auth");

print()
print("GOOGLE CALENDAR REQUIRES OAUTH LOGIN. Goto the url below, grant permission, and then copy the resulting code into this app.");
print()
print("GOTO: ".. OA:auth_url());

OA:listen(8989, "https://www.googleapis.com/oauth2/v2/token");
OA:finalize("https://oauth2.googleapis.com/token");
print()
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


function ICalParseTime(value, extra, TZID)
local Tokens, str, i
local Timezone=""

if strutil.strlen(TZID) > 0 then Timezone=TZID end
value=strutil.trim(value);

Tokens=strutil.TOKENIZER(extra,";")
str=Tokens:next()
while str ~= nil
do
if string.sub(str,1,5) =="TZID=" then Timezone=string.sub(str,6) end
str=Tokens:next()
end

return(ParseDate(value, Timezone))
end


function ICalPostProcessLoopUp(Event)
local toks, tok, when

toks=strutil.TOKENIZER(Event.Details, "\n")
str=toks:next()
while str~=nil
do
	if str=="LoopUp details:" then Event.URL=toks:next() .. " "..toks:next() .. " ".. toks:next() end
	str=toks:next()
end
end


function ICalPostProcessMSTeams(Event)
local toks, tok

toks=strutil.TOKENIZER(Event.Details, "\n")
str=toks:next()
while str~=nil
do
	str=strutil.trim(str)
	if str=="Or call in (audio only)" 
	then 
		Event.URL=Event.URL.."  DialIn:["..strutil.trim(toks:next()).."]"
		break
	end 

	str=toks:next()
end

--[[
 Microsoft Teams meeting \nJoin on your computer or mobile app \nClick here to
  join the meeting \nOr call in (audio only) \n+44 20 3321 5273\,\,13589282
 3#   United Kingdom\, London \nPhone Conference ID: 135 892 823# \nFind a
  local number | Reset PIN \nLearn More | Meeting options 
]]--
end

function ICalPostProcess(Event)

if Event.Location=="LoopUp" then ICalPostProcessLoopUp(Event)
elseif string.find(Event.Details, "Microsoft Teams meeting") ~= nil then ICalPostProcessMSTeams(Event)
end

end


function ICalParseEvent(lines, Events)
local key, value, extra, tmpstr
local Event

Event=EventCreate()
key,value,extra=ICalNextLine(lines)
while key ~= nil
do
if config.debug==true then io.stderr:write("ical parse:  '"..key.."'='"..value.."\n") end

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
	elseif key=="STATUS" then Event.Status=string.lower(value)
	elseif key=="TZID" then Event.TZID=value
	elseif key=="DTSTART" then 
		Event.Start=ICalParseTime(value, extra, Event.TZID)
	elseif key=="DTEND" then Event.End=ICalParseTime(value, extra, Event.TZID)
	elseif key=="ATTENDEE" then Event.Attendees=Event.Attendees+1 
	elseif key=="X-MICROSOFT-SKYPETEAMSMEETINGURL" then Event.URL=value
	elseif key=="X-GOOGLE-CONFERENCE" then Event.URL=value
	end

	key,value,extra=ICalNextLine(lines)
end

ICalPostProcess(Event)
if config.debug==true then io.stderr:write("ical event:  '"..Event.Title.."' " .. time.formatsecs("%Y/%m/%d", Event.Start).."\n") end
table.insert(Events, Event)

return Event
end


function ICalLoadEvents(Events, doc, docname)
local line, str, char1, lines, event

lines=strutil.TOKENIZER(doc, "\n")
key,value,extra=ICalNextLine(lines)
while key ~= nil
do
	if key=="BEGIN" and value=="VEVENT" 
	then 
		event=ICalParseEvent(lines, Events) 
		event.src=docname
	end
	key,value,extra=ICalNextLine(lines)
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
	diff=event.End-event.Start
	if Settings.MaxEventLength > -1 and diff > Settings.MaxEventLength
	then 
		Out:writeln("DTEND:"..time.formatsecs("%Y%m%dT%H%M%SZ", event.Start + Settings.MaxEventLength).."\n") 
	else
		Out:writeln("DTEND:"..time.formatsecs("%Y%m%dT%H%M%SZ", event.End).."\n") 
	end
end

Out:writeln("END:VEVENT".."\n")
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




email_bounds={}
email_bounds.boundary=1
email_bounds.final_boundary=2
email_bounds.mbox=3


function EmailCheckBoundary(S, line, boundary, mailfile_type)
local cleaned, final
local RetVal=0

	cleaned=strutil.trim(line)

	if strutil.strlen(boundary) > 0  
	then 
	   if cleaned == ("--"..boundary.."--") then RetVal=email_bounds.final_boundary
	   elseif cleaned == ("--" .. boundary) then RetVal=email_bounds.boundary
	   end
	elseif mailfile_type=="mbox"
	then
		while line == "\r\n" or line == "\n"
		do
			line=S:readln()
		end
		if line==nil then return email_bounds.final_boundary,nil end
		if string.sub(line, 1, 5)=="From " then RetVal=email_bounds.mbox end
	end

return RetVal, line
end


-- Functions related to extracting ical and other files from emails
function EmailExtractBoundary(header)
local toks, str
local boundary=""

toks=strutil.TOKENIZER(header, "\\S|;", "m")
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
content_type=AnalyzeContentType(content_type)

return content_type, boundary
end



function EmailParseHeader(header, mime_info)
local toks
local name=""
local value=""
local args=""

if config.debug==true then io.stderr:write("EMAIL HEADER: "..header.."\n") end
toks=strutil.TOKENIZER(header, ":|;", "m")
name=toks:next()
value=toks:next()
if name ~= nil  and value ~= nil
then
	name=string.lower(name)
	value=string.lower(strutil.stripLeadingWhitespace(value))
	args=toks:remaining()

	if name == "content-type" 
	then 
	mime_info.content_type,mime_info.boundary=EmailHandleContentType(value, args) 
	elseif name == "content-transfer-encoding"
	then
	mime_info.encoding=value
	elseif name == "subject"
	then
	--print("SUBJECT: " .. args)
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
if line == nil then return nil end
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



function EmailReadDocument(S, boundary, encoding, mailfile_type, EventsFunc)
local line, event, i, len, cleaned
local doc=""
local Events={}
local Done=false

if config.debug==true then io.stderr:write("extract:  enc="..encoding.." boundary="..boundary.."\n") end

len=strutil.strlen(boundary)
line=S:readln()
while line ~= nil
do
 bound_found=EmailCheckBoundary(S, line, boundary, mailfile_type)
 if bound_found==email_bounds.boundary and strutil.strlen(doc) > 0 then break
 elseif bound_found==email_bounds.final_boundary then Done=true; break
 elseif bound_found==email_bounds.mbox then Done=true; break
 end

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

return Done
end


function EmailHandleMimeContainer(S, mime_info, mailfile_type, EventsFunc)
local str

str=S:readln()
while str ~= nil
do

	bound_found,str=EmailCheckBoundary(S, str, mime_info.boundary, mailfile_type)
	str=strutil.stripTrailingWhitespace(str)

	if bound_found > email_bounds.boundary then break end
	if bound_found > 0 then Done=EmailHandleMimeItem(S, mime_info.boundary, mailfile_type, EventsFunc) end

	if Done==true then break end
	str=S:readln()
end

end


function EmailHandleMimeItem(S, boundary, mailfile_type, EventsFunc)
local mime_info
local Done=false

mime_info=EmailReadHeaders(S)

if config.debug==true then io.stderr:write("mime item: ".. mime_info.content_type.." enc="..mime_info.encoding.." boundary="..mime_info.boundary.."\n") end

if  strutil.strlen(mime_info.boundary) == 0 then mime_info.boundary=boundary end


if mime_info.content_type == "application/ical"
then
	Done=EmailReadDocument(S, mime_info.boundary, mime_info.encoding, mailfile_type, EventsFunc)
	mime_info.content_type=""
elseif string.sub(mime_info.content_type, 1, 10) == "multipart/"
then
	EmailHandleMimeContainer(S, mime_info, mailfile_type, EventsFunc)
else
	--Done=EmailReadDocument(S, mime_info.boundary, mime_info.encoding, mailfile_type, EventsFunc)
end

return Done
end



function EmailExtractCalendarItems(path, mailfile_type, EventsFunc)
local S, mime_info, boundary, str

S=stream.STREAM(path, "r")
if S ~= nil
then
if config.debug==true then io.stderr:write("open email '"..path.."\n") end

mime_info=EmailReadHeaders(S)
while mime_info ~= nil
do
EmailHandleMimeContainer(S, mime_info, mailfile_type, EventsFunc)
mime_info=EmailReadHeaders(S)
end


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
	doctype=AnalyzeContentType(Tokens:next())

	if doctype=="application/ical" then ext=".ical" 
	elseif doctype=="application/rss" then ext=".rss"
        end
else
	str=S:path()
	if strutil.strlen(str) ~= nil
	then
		ext=filesys.extn(filesys.basename(str))
		if ext==".ical" then doctype="application/ical" 
		elseif ext==".ics" then doctype="application/ical" 
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
filesys.mkdirPath(str)
if filesys.exists(str) == true and (time.secs() - filesys.mtime(str)) < Settings.CacheTime then return(stream.STREAM(str, "r")) end
end

S=stream.STREAM(url)
if S ~= nil
then
	doctype,extn=DocumentGetType(S)
	S:close()
	if extn==nil then extn="" end
	str=process.getenv("HOME") .. "/.almanac/" .. dochash..extn
	filesys.copy(url, str)
	return(stream.STREAM(str, "r"))
end

return nil
end


function DocumentLoadEvents(Events, url, DocName)
local S, doctype, doc

S=OpenCachedDocument(url);
if S ~= nil
then
        doctype=DocumentGetType(S)
        doc=S:readdoc()
        if doctype=="application/rss" 
        then
                RSSLoadEvents(Events, doc)
        else
                ICalLoadEvents(Events, doc, DocName)
        end
else
print(terminal.format("~rerror: cannot open '"..url.."'~0"))
end

end

-- document with a tag or name on the front in the form
---  <name>:<url>
function NamedDocumentLoadEvents(Events, url)
local toks, name

toks=strutil.TOKENIZER(url, ":")
name=toks:next()
DocumentLoadEvents(Events, toks:remaining(), name)
end


-- FUNCTIONS RELATING TO GOOGLE CALENDAR
function GCalAddEvent(calendars, NewEvent)
local url, S, text, doc, cal, Tokens

if OA==nil
then
	OA=oauth.OAUTH("pkce","gcal",Settings.GCalClientID, Settings.GCalClientSecret,"https://www.googleapis.com/auth/calendar", "https://www.googleapis.com/oauth2/v2/token");
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

process.lu_set("HTTP:Debug", "Y")

if OA==nil
then
	OA=oauth.OAUTH("pkce","gcal",Settings.GCalClientID, Settings.GCalClientSecret,"https://www.googleapis.com/auth/calendar", "https://www.googleapis.com/oauth2/v4/token");
	if OA:load() == false then OAuthGet(OA) end
end

url="https://www.googleapis.com/calendar/v3/calendars/".. strutil.httpQuote(cal) .."/events?singleEvents=true"
if config.EventsStart > 0
then 
	url=url.."&timeMin="..strutil.httpQuote(time.formatsecs("%Y-%m-%dT%H:%M:%SZ", config.EventsStart))
end

S=stream.STREAM(url, "r oauth="..OA:name())
doc=S:readdoc()

if config.debug==true then io.stderr:write("googlecalendar: "..doc.."\n") end


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

function AlmanacParseItem(toks)
local str

str=toks:next()
if str == nil then return "" end
str=strutil.unQuote(str);
if str == nil then return "" end
return str
end

function AlmanacParseCalendarLine(line)
local event, toks, str

event=EventCreate()
toks=strutil.TOKENIZER(line, "\\S", "Q")
event.Added=time.tosecs("%Y/%m/%d.%H:%M:%S", toks:next())
event.UID=toks:next()
event.Start=time.tosecs("%Y/%m/%d.%H:%M:%S", toks:next())
event.End=time.tosecs("%Y/%m/%d.%H:%M:%S", toks:next())
event.Title=AlmanacParseItem(toks)
event.Location=AlmanacParseItem(toks)
event.Details=AlmanacParseItem(toks)
event.URL=AlmanacParseItem(toks)
event.Recurs=AlmanacParseItem(toks)
event.Status=""

return event
end


function AlmanacEventsMatch(Event1, Event2)
if Event1 == nil and Event2 == nil then return true end
if Event1 == nil or Event2 == nil then return false end
if Event1.UID ~= Event2.UID then return false end
if Event1.Start ~= Event2.Start then return false end
if Event1.End ~= Event2.End then return false end
if Event1.Title ~= Event2.Title then return false end
if Event1.Location ~= Event2.Location then return false end
if Event1.Details ~= Event2.Details then return false end
if Event1.URL ~= Event2.URL then return false end
return true
end



function AlmanacReadCalendarFile(Path)
local S, str, event, old_event
local events={}

S=stream.STREAM(Path)
if S ~= nil
then
str=S:readln()
while str ~= nil
do
	event=AlmanacParseCalendarLine(str)
	old_event=events[event.UID]
	if old_event ~= nil
	then
	-- don't re-add event if this new one is identical
	if AlmanacEventsMatch(old_event, event) then break end

	--if not identical, then mark the event as moved
	old_event.Status="moved"
	events[old_event.UID.."-moved"]=old_event
	end

	--add new event
	events[event.UID]=event
	str=S:readln()
end
S:close()
end

return events
end



function AlmanacLoadCalendarFile(Collated, cal, Path)
local str, key, event, when
local tmpTable={}
local count=0


tmpTable=AlmanacReadCalendarFile(Path)
for key,event in pairs(tmpTable)
do
	when=Settings.WarnTime
	if Settings.WarnRaisedTime > Settings.WarnTime then when=Settings.WarnRaisedTime end
	if when > 0 and (Now - event.Start) < when
	then
		table.insert(WarnEvents, event)
	end

	table.insert(Collated, event)
	count=count+1
end

return count
end


function AlmanacLoadRecurring(Collated, cal, start_time, end_time)
local Recurring={}
local i, event, new_event

AlmanacLoadCalendarFile(Recurring, cal, process.getenv("HOME") .. "/.almanac/recurrent.cal")
for i,event in ipairs(Recurring)
do
	when=EventRecurring(Collated, event, start_time, end_time)
end

end


function AlmanacLoadCalendar(Collated, cal, start_time, end_time)
local str, prev, when

if start_time == nil then start_time=time.secs() end
if end_time == nil then end_time=time.secs() end

AlmanacLoadRecurring(Collated, cal, start_time, end_time)

when=start_time
while when <= end_time
do
str=process.getenv("HOME") .. time.formatsecs("/.almanac/%b-%Y.cal", when)
if str ~= prev then AlmanacLoadCalendarFile(Collated, cal, str) end
prev=str
when=when+3600
end

end




function AlmanacAddEvent(event)
local S, str, path, events, exising

if strutil.strlen(event.Recur) > 0 then str="recurrent.cal"
elseif event.Start ~= nil then str=time.formatsecs("%b-%Y.cal", event.Start)
end

if strutil.strlen(str) == 0 then return end

path=process.getenv("HOME") .. "/.almanac/" .. str
filesys.mkdirPath(path)

events=AlmanacReadCalendarFile(path)
old_event=events[event.UID]
if AlmanacEventsMatch(old_event, event) ~= true
then
S=stream.STREAM(path, "a")
if S ~= nil
then
  str=time.format("%Y/%m/%d.%H:%M:%S") .. " " .. event.UID .. " "..time.formatsecs("%Y/%m/%d.%H:%M:%S ", event.Start)
  str=str .. time.formatsecs("%Y/%m/%d.%H:%M:%S ", event.End)
  str=str .. "\"" .. event.Title .. "\" \""..event.Location.."\" \"" .. strutil.quoteChars(event.Details, "\n\\\"") .."\""
  if strutil.strlen(event.URL) > 0 then str=str.. " \""..event.URL.."\"" end
  if strutil.strlen(event.Recur) > 0 then str=str.." "..event.Recur end
  S:writeln(str.."\n")
  S:close()
end
end


end



function FormatEventStatus(status, format)
local str=""

str=status
if status == "confirmed"
then
	if format == "color" then str="~g"..status.."~0"
	elseif format == "short" then str="c"
	elseif format == "short_color" then str="~gc~0"
	end
elseif status == "cancelled"
then
	if format == "color" then str="~r"..status.."~0"
	elseif format == "short" then str="X"
	elseif format == "short_color" then str="~rX~0"
	end
elseif status == "moved"
then
	if format == "color" then str="~r"..status.."~0"
	elseif format == "short" then str="M"
	elseif format == "short_color" then str="~rM~0"
	end
elseif status == "tentative"
then
	if format == "color" then str="~y"..status.."~0"
	elseif format == "short" then str="T"
	elseif format == "short_color" then str="~yT~0"
	end

end

return str
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
values["status"]=event.Status
values["status_color"]=FormatEventStatus(event.Status, "color")
values["status_short"]=FormatEventStatus(event.Status, "short")
values["status_short_color"]=FormatEventStatus(event.Status, "short_color")

values["src"]=event.src
values["version"]=VERSION

values["todaynick"]=time.formatsecs("%a", Now)
values["todayname"]=time.formatsecs("%A", Now)
values["nowdate"]=time.formatsecs("%Y/%m/%d", Now)
values["nowtime"]=time.formatsecs("%H:%M:%S", Now)
values["nowday"]=time.formatsecs("%d", Now)
values["nowmonth"]=time.formatsecs("%m", Now)
values["nowyear"]=time.formatsecs("%Y", Now)
values["nowhour"]=time.formatsecs("%H", Now)
values["nowmin"]=time.formatsecs("%M", Now)
values["nowsec"]=time.formatsecs("%S", Now)


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
elseif dif ~= nil and diff < 3600
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
  elseif strutil.strlen(str) > 0 and str ~= ")"
  then
    output=output..str
  end
  str=toks:next()
end

return output
end



function OutputEventANSI(event)
str=SubstituteEventStrings(Settings.DisplayFormat, event)
print(terminal.format(str))
if (Settings.ShowURL or Settings.ShowDetail) and (strutil.strlen(event.URL) > 0)
then
	print("  " .. event.URL)
end

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

if (Settings.ShowURL or Settings.ShowDetail) and (strutil.strlen(event.URL) > 0)
then
	print("  " .. event.URL)
end


if Settings.ShowDetail 
then 
	print(event.Details) 
	print()
end

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




function XtermTitle(Term, title, when)
local str
local ev={}

if when ~= nil
then
	ev.Start=when.Start
	ev.End=when.End
else
	ev.Start=Now;
	ev.End=Now;
end

if strutil.strlen(title) > 0
then
	str=string.format("\x1b]2;%s\x07", SubstituteEventStrings(title, ev))
	Term:puts(str)			
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
print("   -h <n>                show events for the next 'n' hours. The 'n' argument is optional, if missing 1 day will be assumed")
print("   -hour <n>             show events for the next 'n' hours. The 'n' argument is optional, if missing 1 day will be assumed")
print("   -d <n>                show events for the next 'n' days.  The 'n' argument is optional, if missing 1 day will be assumed")
print("   -day  <n>             show events for the next 'n' days.  The 'n' argument is optional, if missing 1 day will be assumed")
print("   -days <n>             show events for the next 'n' days.  The 'n' argument is optional, if missing 1 day will be assumed")
print("   -w <n>                show events for the next 'n' weeks. The 'n' argument is optional, if missing 1 week will be assumed")
print("   -week <n>             show events for the next 'n' weeks. The 'n' argument is optional, if missing 1 week will be assumed")
print("   -m <n>                show events for the next 'n' months. The 'n' argument is optional, if missing 1 month will be assumed")
print("   -month <n>            show events for the next 'n' months. The 'n' argument is optional, if missing 1 month will be assumed")
print("   -y <n>                show events for the next 'n' years. The 'n' argument is optional, if missing 1 year will be assumed")
print("   -year <n>             show events for the next 'n' years. The 'n' argument is optional, if missing 1 year will be assumed")
print("   -at <loc>             show events at location 'loc'")
print("   -where <loc>          show events at location 'loc'")
print("   -location <loc>       show events at location 'loc'")
print("   -hide <pattern>       hide events whose title matches fnmatch/shell style pattern 'pattern'")
print("   -show <pattern>       show only events whose title matches fnmatch/shell style pattern 'pattern'")
print("   -detail               print event description/details")
print("   -details              print event description/details")
print("   -show-url             print event with event connect url (for Zoom or Teams meetings) on a line below")
print("   -old                  show events that are in the past")
print("   -import <url>         Import events from specified URL (usually an ical file) into calendar")
print("   -email <url>          Import events from ical attachments within an email file at the specified URL into calendar")
print("   -import-email <url>   Import events from ical attachments within an email file at the specified URL into calendar")
print("   -mbox  <url>          Import events from ical attachments within an mbox file full of emails")
print("   -import-mbox  <url>   Import events from ical attachments within an mbox file full of emails")
print("   -persist              don't exit, but print out events in a loop. This can be used to create an updating window that displays upcoming events.")
print("   -convert <url>        Output events from specified URL (usually an ical file) in output format set with '-of'")
print("   -convert-email <url>  Output events from ical attachments within an email file at the specified URL in format set with '-of'")
print("   -lfmt <format string>          line format for ansi output (see 'display formats' for details of title strings)")
print("   -xt <title string>             when -persist is used, also set the xterm title to be <title string> (see 'display formats' for details of title strings)")
print("   -xtitle <title string>         when -persist is used, also set the xterm title to be <title string> (see 'display formats' for details of title strings)")
print("   -xterm-title <title string>    when -persist is used, also set the xterm title to be <title string> (see 'display formats' for details of title strings)")
print("   -of <fmt>             specify format to output. '<fmt> will be one of 'csv', 'ical', 'sgical', 'txt' or 'ansi'. Default is 'ansi'. See 'Output Formats' below for more details")
print("   -refresh <len>        When in persist mode, update with this frequency, where 'len' is a number postfixed by 'm' 'h' 'd' or 'w' for 'minutes', 'hours', 'days' or 'weeks'. e.g. '2d' two days, '30m' thiry minutes. Default 2m.")
print("   -maxlen <len>         When importing calendars set the max length of an event to <len> where len is a number postfixed by 'm' 'h' 'd' or 'w' for 'minutes', 'hours', 'days' or 'weeks'. e.g. '2d' two days, '30m' thiry minutes.")
print("   -u                    Terminal supports unicode up to code 0x8000")
print("   -unicode              Terminal supports unicode up to code 0x8000")
print("   -u2                   Terminal supports unicode up to code 0x8000")
print("   -unicode2             Terminal supports unicode up to code 0x10000")
print("   -debug                Print debug output")
print("   -?                    This help")
print("   -h                    This help")
print("   -help                 This help")
print("   --help                This help")
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
print("   -recur <duration>      event recurrs every '<duration>'. Duration has the format <number><suffix> where suffix can be y=year,m=month,w=week,d=day,h=hour,m=minute. e.g. '-recur 2w' to recur every two weeks.")
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


function ParseCommandLineArg(arg, i,  args, NewEvent, Config)
local val

if arg=="-debug" then Config.debug=true
elseif arg=="-h" or arg=="-hour"  then Config.EventsEnd=Config.EventsStart + 3600 * ParseNumericArg(args,i)
elseif arg=="-d" or arg=="-day" or arg=="-days" then Config.EventsEnd=Config.EventsStart + 3600 * 24 * ParseNumericArg(args, i)
elseif arg=="-w" or arg=="-week" then Config.EventsEnd=Config.EventsStart + 3600 * 24 * 7 * ParseNumericArg(args,i)
elseif arg=="-m" or arg=="-month" then Config.EventsEnd=Config.EventsStart + 3600 * 24 * 7 * 4 * ParseNumericArg(args,i)
elseif arg=="-y" or arg=="-year" then Config.EventsEnd=Config.EventsStart + 3600 * 24 * 365 * ParseNumericArg(args,i)
elseif arg=="-detail" or arg=="-details" or arg=="-v" then Settings.ShowDetail=true
elseif arg=="-show-url" then Settings.ShowURL=true
elseif arg=="-add" 
then 
	Config.action="add"
	NewEvent.Title=ParseArg(args, i+1)
elseif arg=="-addpub" 
then 
	Config.action="add"
	NewEvent.Title=ParseArg(args, i+1)
	NewEvent.Visibility="public"
elseif arg=="-addpriv"
then
	Config.action="add"
	NewEvent.Title=ParseArg(args, i+1)
	NewEvent.Visibility="private"
elseif arg=="-recur"
then
	NewEvent.Recur=ParseArg(args, i+1)
elseif arg=="-start" or arg=="-s"
then
	--do nothing! this is handled by the earlier loop in 'ParseCommandLine'
elseif arg=="-end"
then
	Config.EventsEnd=ParseDate(ParseArg(args, i+1))
elseif arg=="-maxlen"
then
	Settings.EventMaxLength=ParseDuration(ParseArg(args, i+1))
elseif arg=="-at" or arg=="-where" or arg=="-location" then NewEvent.Location=ParseArg(args, i+1)
elseif arg=="-import"
then
	Config.action="import"
	Config.selections=Config.selections..ParseArg(args, i+1).."\n"
elseif arg=="-email" or arg=="-import-email"
then
	Config.action="import-email"
	Config.selections=Config.selections..ParseArg(args, i+1).."\n"
elseif arg=="-mbox" or arg=="-import-mbox"
then
	Config.action="import-mbox"
	Config.selections=Config.selections..ParseArg(args, i+1).."\n"
elseif arg=="-convert"
then
	Config.action="convert"
	Config.selections=Config.selections..ParseArg(args, i+1).."\n"
elseif arg=="-email" or arg=="-convert-email"
then
	Config.action="convert-email"
	Config.selections=Config.selections..ParseArg(args, i+1).."\n"
elseif arg=="-sync"
then
	Config.action="sync"
	Config.SyncURL=ParseArg(args, i+1)
elseif arg=="-xt" or arg=="-xterm-title" or arg=="-xtitle" then Settings.XtermTitle=ParseArg(args, i+1)
elseif arg=="-refresh" then Settings.RefreshTime=ParseDuration(ParseArg(args, i+1))
elseif arg=="-lfmt" then Settings.DisplayFormat=ParseArg(args, i+1)
elseif arg=="-hide"
then
	if strutil.strlen(Config.selections) > 0 then Config.selections=Config.selections.. ",!" ..ParseArg(args,i+1) else Config.selections="!"..ParseArg(args, i+1) end
elseif arg=="-show"
then
	if strutil.strlen(Config.selections) > 0 then Config.selections=Config.selections..","..ParseArg(args,i+1) else Config.selections=ParseArg(args, i+1) end
elseif arg=="-old" then Config.EventsStart=0
elseif arg=="-persist" then Settings.Persist=true 
elseif arg=="-warn" then Settings.WarnTime=ParseDuration(ParseArg(args, i+1))
elseif arg=="-warn-raise" then Settings.WarnRaisedTime=ParseDuration(ParseArg(args, i+1))
elseif arg=="-of" then Settings.OutputFormat=ParseArg(args, i+1) 
elseif arg=="-u" or arg=="-unicode" then  terminal.unicodelvl(1)
elseif arg=="-u2" or arg=="-unicode2" then  terminal.unicodelvl(2)
elseif arg=="-u3" or arg=="-unicode3" then  terminal.unicodelvl(3)
elseif arg=="-?" or arg=="-h" or arg=="-help" or arg=="--help"
then
	Config.action="help"
else
	if strutil.strlen(arg) > 0 then Config.calendars=Config.calendars.."," .. arg end
end

end


-- Parse command line arguments. The 'add event' functionality is called directly from with this function if -add is encounted on the command line
function ParseCommandLine(args)
local i, arg, val
local action="none"
local calendars=""
local selections=""
local NewEvent
local Config={}

Config.action="none"
Config.debug=false
Config.calendars=""
Config.selections=""
Config.EventsStart=time.secs()
Config.EventsEnd=0

NewEvent=EventCreate()
NewEvent.Visibility="default"

--as other values are set relative to Config.EventsStart, so we have to grab any '-start' option before all others
for i,arg in ipairs(args)
do
if arg=="-s" or arg=="-start" then Config.EventsStart=ParseDate(ParseArg(args, i+1)) end
end

if Config.EventsStart==0 then Config.EventsStart=time.secs() end


for i,arg in ipairs(args)
do
 ParseCommandLineArg(arg, i, args, NewEvent, Config)
end

if strutil.strlen(Config.calendars)==0 then Config.calendars="a:default" end


if Config.EventsEnd > 0
then
	if Config.EventsStart > Config.EventsEnd
	then
	val=Config.EventsStart
	Config.EventsStart=Config.EventsEnd
	Config.EventsEnd=val
	end
else
	Config.EventsEnd=Config.EventsStart + 3600
end

NewEvent.Start=Config.EventsStart
NewEvent.End=Config.EventsEnd

return Config, NewEvent
end



function DisplayCalendarMenu(Out, calendars) 
local menu, str
local cal_list
local Term

Term=terminal.TERM(Out)
Term:clear()
menu=terminal.TERMMENU(Term, 1, 1, Term:width() -1, Term:height() -1)
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




function EventSoonest(WarnEvents)
local i, event, soonest

for i,event in ipairs(WarnEvents)
do
if soonest==nil or event.Start < soonest.Start then soonest=event end
end

return soonest
end


function InteractiveDisplayTitle(Term)
local ev={}
local title

title=Settings.XtermTitle

-- if there are events that are marked to raise a warning, then format the warning title
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


if strutil.strlen(title) > 0
then
	 ev.Start=config.EventsStart
	 ev.End=config.EventsEnd
	 XtermTitle(Term, title, ev)
end

end


function WaitEvents(Term)
local event, action="", ch
local pagesize

pagesize=config.EventsEnd - config.EventsStart

	InteractiveDisplayTitle(Term)
	ch=Term:getc()

	if ch=="m" then
		action="menu"
	elseif ch=="LEFT" or ch=="." then 
		config.EventsStart=config.EventsStart - pagesize
		config.EventsEnd=config.EventsEnd - pagesize
		action="refresh"
	elseif ch=="RIGHT" or ch=="," then 
		config.EventsStart=config.EventsStart + pagesize
		config.EventsEnd=config.EventsEnd + pagesize
		action="refresh"
	elseif ch==" " then
		config.EventsStart=Now
		config.EventsEnd=Now + pagesize
		action="refresh"
	elseif ch=="ESC" then
		action="quit"
	end

	display_count=display_count + 1

return action
end



-- This function loops around outputing a list of events
function PersistentScheduleDisplay(config)
local Events, action, next_update, display_calendars
local Term

Term=terminal.TERM(Out)

next_update=Now

display_calendars=config.calendars
while action ~= "quit"
do
	Events={}
	WarnEvents={}
	LoadCalendarEvents(display_calendars, config.selections, Events)
	InteractiveDisplayTitle(Term)

	if Term ~= nil
	then

		Term:puts("\x1b[3J") -- clear scrollback buffer
		Term:clear()
		Term:move(0,0)
	end

	OutputCalendar(Events, config)
	next_update=Now + Settings.RefreshTime

	while Now < next_update
	do
		action=WaitEvents(Term) 
		if action == "refresh" 
		then 
			break 
		elseif action == "menu"
		then
			display_calendars=DisplayCalendarMenu(Term, config.calendars)
			Term:clear()
			break
		elseif action == "quit" then break
		end
		UpdateTimes()
	end

end
end








function PigeonholedAddItem(str, Key, Value)

str=str .. Key .. "=\"" ..strutil.quoteChars(Value, "\n\"") .. "\" "
return str
end


function PigeonholedSendEvents(Events, S)
local i, event, str

	for i,event in ipairs(Events)
	do
	str="object calendar "..event.UID.." "
	str=PigeonholedAddItem(str, "uid", event.UID)
	str=PigeonholedAddItem(str, "title", event.Title)
	str=PigeonholedAddItem(str, "location", event.Location)
	str=PigeonholedAddItem(str, "details", event.Details)
	str=PigeonholedAddItem(str, "url", event.URL)
	str=PigeonholedAddItem(str, "start", time.formatsecs("%Y/%m/%dT%H:%M:%S", event.Start))
	str=PigeonholedAddItem(str, "end", time.formatsecs("%Y/%m/%dT%H:%M:%S", event.End))
	str=str.."\n"
	S:writeln(str)

	str=S:readln()
	end
end

function PigeonholedParseEventProperty(event, str)
local toks, key

toks=strutil.TOKENIZER(str, "=", "Q")
key=toks:next()

if key=="uid" then event.UID=toks:next()
elseif key=="title" then event.Title=toks:next()
elseif key=="location" then event.Location=toks:next()
elseif key=="details" then event.Details=toks:next()
elseif key=="url" then event.URL=toks:next()
elseif key=="start" then event.Start=time.tosecs("%Y/%m/%dT%H:%M:%S", toks:next())
elseif key=="end" then event.End=time.tosecs("%Y/%m/%dT%H:%M:%S", toks:next())
end

end

function PigeonholedEventExists(Events, event) 
local i, item

for i,item in ipairs(Events)
do
	if item.uid==event.uid then return true end
end

return false
end


function PigeonholedReadEventItem(Events, uid, S)
local str, toks
local event={}

S:writeln("read calendar ".. uid .. "\n")
str=S:readln()
toks=strutil.TOKENIZER(str, "\\S", "q")
str=toks:next()
while str ~= nil
do
PigeonholedParseEventProperty(event, str)
str=toks:next()
end

if PigeonholedEventExists(Events, event) ~= true then AlmanacAddEvent(event) end

end


function PigeonholedReadEvents(Events, S)
local i, event, str

	S:writeln("list calendar\n")
	str=S:readln()
	toks=strutil.TOKENIZER(str, "\\S", "Q")
	if toks:next() == "+OK"
	then
		str=toks:next()
		while str ~= nil
		do
		PigeonholedReadEventItem(Events, str, S)
		str=toks:next()
		end
	end

end



function PigeonholedSync(Events, config)
local S

S=stream.STREAM(config.SyncURL)
if S ~= nil
then
PigeonholedSendEvents(Events, S)
PigeonholedReadEvents(Events, S)
S:close()
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
	elseif string.sub(cal,1, 4) == "src:" then NamedDocumentLoadEvents(Events, string.sub(cal, 5))
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
	if action=="import-mbox"
	then
	EmailExtractCalendarItems(url, AlmanacAddEvent, "mbox")
	elseif action=="import-email"
	then
	EmailExtractCalendarItems(url, AlmanacAddEvent, "email")
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
	EmailExtractCalendarItems(url, OutputEvent, "email")
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


function LoadAndSendCalendar(config)

local Events={}

LoadCalendarEvents(config.calendars, config.selections, Events)
PigeonholedSync(Events, config)

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
Settings.DisplayFormat="~c$(daynick_color)~0 $(date) $(time_color) $(duration) ~c$(src)~0 ~r$(status_short_color)~0 ~m$(title)~0 $(location)"

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
elseif config.action=="import" or config.action=="import-email" or config.action=="import-mbox"
then
	ImportItems(config.action, config.selections)
elseif config.action=="convert" or config.action=="convert-email"
then
	ConvertItems(config.action, config.selections)
elseif config.action=="sync"
then
	LoadAndSendCalendar(config)
elseif Settings.Persist==true
then
	PersistentScheduleDisplay(config)
else
	LoadAndOutputCalendar(config)
end
