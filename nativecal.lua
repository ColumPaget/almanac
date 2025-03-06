--FUNCTIONS RELATED TO NATIVE ALMANAC CALENDARS

function AlmanacParseItem(event, toks, field)
local str

str=toks:next()
str=strutil.unQuote(str);
if str==nil then str="" end

if str ~= ""
then
if string.sub(str, 1, 4) == "url=" then event.URL=strutil.stripQuotes(string.sub(str, 5)) 
elseif string.sub(str, 1, 6) == "title=" then event.Title=strutil.stripQuotes(string.sub(str, 7)) 
elseif string.sub(str, 1, 6) == "recur=" then event.Recurs=strutil.stripQuotes(string.sub(str, 7)) 
elseif string.sub(str, 1, 7) == "status=" then event.Status=strutil.stripQuotes(string.sub(str, 8)) 
elseif string.sub(str, 1, 9) == "location=" then event.Location=strutil.stripQuotes(string.sub(str, 10)) 
else event[field]=str
end
end

return str
end





function AlmanacParseCalendarLine(line)
local event, toks, str

if config.debug==true then io.stderr:write("nativefile parse: ".. tostring(line) .."\n") end
event=EventCreate()
toks=strutil.TOKENIZER(line, "\\S", "Q")
event.Added=time.tosecs("%Y/%m/%d.%H:%M:%S", toks:next())
event.EID=toks:next()
event.Start=time.tosecs("%Y/%m/%d.%H:%M:%S", toks:next())
event.End=time.tosecs("%Y/%m/%d.%H:%M:%S", toks:next())
AlmanacParseItem(event, toks, "Title")
AlmanacParseItem(event, toks, "Location")
AlmanacParseItem(event, toks, "Details")
AlmanacParseItem(event, toks, "URL")
AlmanacParseItem(event, toks, "Recurs")
AlmanacParseItem(event, toks, "Status")

return event
end


function AlmanacEventsMatch(Event1, Event2)
if Event1 == nil and Event2 == nil then return true end
if Event1 == nil or Event2 == nil then return false end

if Event1.EID ~= Event2.EID then return false end
if Event1.Start ~= Event2.Start then return false end
if Event1.End ~= Event2.End then return false end
if Event1.Title ~= Event2.Title then return false end
if Event1.Location ~= Event2.Location then return false end

--if Event1.Details ~= Event2.Details then return false end
if Event1.URL ~= Event2.URL then return false end
return true
end


function AlmanacAddCalendarItem(events, new_event)
local old_event

	new_event.UID=EventGenerateUID(new_event)

	old_event=events[new_event.UID]
	if old_event ~= nil
	then
	   -- don't re-add event if this new one is identical
	   if AlmanacEventsMatch(old_event, new_event) 
	   then
        	if config.debug==true then io.stderr:write("nativefile duplicate event: ".. tostring(new_event.Title) .."\n") end
	   	return 
	   end

	   --if not identical, then mark the event as moved
	   --this probably can't happen since switching to internal
	   --UIDs
	   old_event.Status="moved"
	end

	--add new event
  if config.debug==true then io.stderr:write("nativefile load event: ".. tostring(new_event.Title) .."\n") end

	events[new_event.UID]=new_event
end


function AlmanacReadCalendarFile(Path)
local S, str, event
local events={}

S=stream.STREAM(Path)
if S ~= nil
then
str=S:readln()
while str ~= nil
do
	event=AlmanacParseCalendarLine(str)

  if config.debug==true then io.stderr:write("nativefile read event: ".. tostring(event.Title) .."\n") end
	AlmanacAddCalendarItem(events, event)
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

event.UID=EventGenerateUID(event)

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
  str=time.format("%Y/%m/%d.%H:%M:%S") .. " " .. event.EID .. " "..time.formatsecs("%Y/%m/%d.%H:%M:%S ", event.Start)
  str=str .. time.formatsecs("%Y/%m/%d.%H:%M:%S ", event.End)
  str=str .. "\"" .. event.Title .. "\" \""..event.Location.."\" \"" .. strutil.quoteChars(event.Details, "\n\\\"") .."\""
  if strutil.strlen(event.URL) > 0 then str=str.. " url=\""..event.URL.."\"" end
  if strutil.strlen(event.Recur) > 0 then str=str.." recur=\""..event.Recur.."\"" end
  str=str.." status=\""..event.Status .. "\""

  S:writeln(str.."\n")
  S:close()
end
end


end


