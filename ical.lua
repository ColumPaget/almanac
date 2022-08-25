
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


function ICalPostProcessLoopUp(Event)
local toks, tok

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
	elseif key=="X-MICROSOFT-SKYPETEAMSMEETINGURL" then Event.URL=value
	end

	key,value,extra=ICalNextLine(lines)
end

ICalPostProcess(Event)
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

