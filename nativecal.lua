--FUNCTIONS RELATED TO NATIVE ALMANAC CALENDARS

function AlmanacParseCalendarLine(line)
local event, toks

event=EventCreate()
toks=strutil.TOKENIZER(line, "\\S", "Q")
event.Added=time.tosecs("%Y/%m/%d.%H:%M:%S", toks:next())
event.UID=toks:next()
event.Start=time.tosecs("%Y/%m/%d.%H:%M:%S", toks:next())
event.End=time.tosecs("%Y/%m/%d.%H:%M:%S", toks:next())
event.Title=toks:next()
event.Location=toks:next()
event.Details=strutil.unQuote(toks:next())
event.URL=strutil.unQuote(toks:next())
event.Recurs=strutil.unQuote(toks:next())
event.Status=""

return event
end


function AlmanacLoadCalendarFile(Collated, cal, Path)
local S, str, event, old_event, toks, when
local tmpTable={}
local count=0

S=stream.STREAM(Path)
if S ~= nil
then
str=S:readln()
while str ~= nil
do
	event=AlmanacParseCalendarLine(str)
	old_event=tmpTable[event.UID]
	if old_event ~= nil
	then
	old_event.Status="moved"
	tmpTable[old_event.UID.."-moved"]=old_event
	end

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
local S, str

str=process.getenv("HOME") .. "/.almanac/"
filesys.mkdir(str)

if strutil.strlen(event.Recur) > 0 then str=str.."recurrent.cal"
else str=str..time.formatsecs("%b-%Y.cal", event.Start)
end

S=stream.STREAM(str, "a")
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



