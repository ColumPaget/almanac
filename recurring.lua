
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


