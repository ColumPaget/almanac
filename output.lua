
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


