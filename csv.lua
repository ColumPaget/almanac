
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


