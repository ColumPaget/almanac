

function XtermTitle(Term, title)
local str
local ev={}

if strutil.strlen(title) > 0
then
	ev.Start=Now;
	ev.End=Now;
	str=string.format("\x1b]2;%s\x07", SubstituteEventStrings(title, ev))
	Term:puts(str)			
end
end

