

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

