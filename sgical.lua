
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
Out:writeln("Uid ["..event.EID.."]\n")
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


