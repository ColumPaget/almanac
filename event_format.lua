
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


