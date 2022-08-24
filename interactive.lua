
function DisplayCalendarMenu(Out, calendars) 
local menu, str
local cal_list
local Term

Term=terminal.TERM(Out)
Term:clear()
menu=terminal.TERMMENU(Term, 1, 1, Term:width() -1, Term:height() -1)
menu:add("all")
menu:add("Recently Added", "recent")

toks=strutil.TOKENIZER(calendars,",")
str=toks:next()
while str ~= nil
do
	menu:add(str)	
	str=toks:next()
end

str=menu:run()
if str=="all"
then
	cal_list=calendars
else
	cal_list=str
end

return cal_list
end




function EventSoonest(WarnEvents)
local i, event, soonest

for i,event in ipairs(WarnEvents)
do
if soonest==nil or event.Start < soonest.Start then soonest=event end
end

return soonest
end


function WaitEvents(Out)
local event, action="", ch, title

	title=Settings.XtermTitle

	if #WarnEvents > 0
	then
		event=EventSoonest(WarnEvents)
		if event.Start < Settings.WarnRaisedTime then Out:puts("\x1b[5t") end

		if display_count % 2 == 0
		then
		title=string.format("* * *   %s in %d mins", event.Title, math.floor((event.Start - Now) / 60))
		else
		title=string.format("_ _ _   %s in %d mins", event.Title, math.floor((event.Start - Now) / 60))
		end

		next_update=Now + 1	
		Out:timeout(100) --one sec
	else
		Out:timeout(1000) --ten secs
	end


	XtermTitle(Out, title)
	ch=Out:getc()

	if ch=="m" then
		action="menu"
	elseif ch=="LEFT" then 
		config.EventsStart=config.EventsStart - (3600 * 24 *7)
		action="refresh"
	elseif ch=="RIGHT" then 
		config.EventsStart=config.EventsStart + (3600 * 24 *7)
		action="refresh"
	end

	display_count=display_count + 1

return action
end



-- This function loops around outputing a list of events
function PersistentScheduleDisplay(config)
local Events, action, next_update, display_calendars
local Term

Term=terminal.TERM(Out)

next_update=Now

display_calendars=config.calendars
while true
do
	Events={}
	WarnEvents={}
	LoadCalendarEvents(display_calendars, config.selections, Events)

	if Term ~= nil
	then
		XtermTitle(Term, Settings.XtermTitle)
		Term:puts("\x1b[3J") -- clear scrollback buffer
		Term:clear()
		Term:move(0,0)
	end

	OutputCalendar(Events, config)
	next_update=Now + Settings.RefreshTime

	while Now < next_update
	do
		action=WaitEvents(Term) 
		if action == "refresh" 
		then 
			break 
		elseif action == "menu"
		then
			display_calendars=DisplayCalendarMenu(Term, config.calendars)
			Term:clear()
			break
		end
		UpdateTimes()
	end

end
end







