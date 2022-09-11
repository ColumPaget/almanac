
function ParseArg(args, i)
local val

val=args[i]
args[i]=""
return val

end



-- Parse a numeric command line argument. This will test if the next argument is numeric, if it is it will be consumed, 
-- if not then a value of 1 will be returned
function ParseNumericArg(args, i)
local val

	val=tonumber(args[i+1])

	if val == nil then 
	val=1 
	else args[i+1]=""
	end

	return val
end


function ParseCommandLineArg(arg, i,  args, NewEvent, Config)
local val

if arg=="-debug" then Config.debug=true
elseif arg=="-h" or arg=="-hour"  then Config.EventsEnd=Config.EventsStart + 3600 * ParseNumericArg(args,i)
elseif arg=="-d" or arg=="-day" or arg=="-days" then Config.EventsEnd=Config.EventsStart + 3600 * 24 * ParseNumericArg(args, i)
elseif arg=="-w" or arg=="-week" then Config.EventsEnd=Config.EventsStart + 3600 * 24 * 7 * ParseNumericArg(args,i)
elseif arg=="-m" or arg=="-month" then Config.EventsEnd=Config.EventsStart + 3600 * 24 * 7 * 4 * ParseNumericArg(args,i)
elseif arg=="-y" or arg=="-year" then Config.EventsEnd=Config.EventsStart + 3600 * 24 * 365 * ParseNumericArg(args,i)
elseif arg=="-detail" or arg=="-details" or arg=="-v" then Settings.ShowDetail=true
elseif arg=="-show-url" then Settings.ShowURL=true
elseif arg=="-add" 
then 
	Config.action="add"
	NewEvent.Title=ParseArg(args, i+1)
elseif arg=="-addpub" 
then 
	Config.action="add"
	NewEvent.Title=ParseArg(args, i+1)
	NewEvent.Visibility="public"
elseif arg=="-addpriv"
then
	Config.action="add"
	NewEvent.Title=ParseArg(args, i+1)
	NewEvent.Visibility="private"
elseif arg=="-recur"
then
	NewEvent.Recur=ParseArg(args, i+1)
elseif arg=="-start" or arg=="-s"
then
	--do nothing! this is handled by the earlier loop in 'ParseCommandLine'
elseif arg=="-end"
then
	Config.EventsEnd=ParseDate(ParseArg(args, i+1))
elseif arg=="-maxlen"
then
	Settings.EventMaxLength=ParseDuration(ParseArg(args, i+1))
elseif arg=="-at" or arg=="-where" or arg=="-location" then NewEvent.Location=ParseArg(args, i+1)
elseif arg=="-import"
then
	Config.action="import"
	Config.selections=Config.selections..ParseArg(args, i+1).."\n"
elseif arg=="-email" or arg=="-import-email"
then
	Config.action="import-email"
	Config.selections=Config.selections..ParseArg(args, i+1).."\n"
elseif arg=="-convert"
then
	Config.action="convert"
	Config.selections=Config.selections..ParseArg(args, i+1).."\n"
elseif arg=="-email" or arg=="-convert-email"
then
	Config.action="convert-email"
	Config.selections=Config.selections..ParseArg(args, i+1).."\n"
elseif arg=="-xt" or arg=="-xterm-title" or arg=="-xtitle" then Settings.XtermTitle=ParseArg(args, i+1)
elseif arg=="-refresh" then Settings.RefreshTime=ParseDuration(ParseArg(args, i+1))
elseif arg=="-lfmt" then Settings.DisplayFormat=ParseArg(args, i+1)
elseif arg=="-hide"
then
	if strutil.strlen(Config.selections) > 0 then Config.selections=Config.selections.. ",!" ..ParseArg(args,i+1) else Config.selections="!"..ParseArg(args, i+1) end
elseif arg=="-show"
then
	if strutil.strlen(Config.selections) > 0 then Config.selections=Config.selections..","..ParseArg(args,i+1) else Config.selections=ParseArg(args, i+1) end
elseif arg=="-old" then Config.EventsStart=0
elseif arg=="-persist" then Settings.Persist=true 
elseif arg=="-warn" then Settings.WarnTime=ParseDuration(ParseArg(args, i+1))
elseif arg=="-warn-raise" then Settings.WarnRaisedTime=ParseDuration(ParseArg(args, i+1))
elseif arg=="-of" then Settings.OutputFormat=ParseArg(args, i+1) 
elseif arg=="-u" or arg=="-unicode" then  terminal.unicodelvl(1)
elseif arg=="-u2" or arg=="-unicode2" then  terminal.unicodelvl(2)
elseif arg=="-u3" or arg=="-unicode3" then  terminal.unicodelvl(3)
elseif arg=="-?" or arg=="-h" or arg=="-help" or arg=="--help"
then
	Config.action="help"
else
	if strutil.strlen(arg) > 0 then Config.calendars=Config.calendars..","..arg end
end

end


-- Parse command line arguments. The 'add event' functionality is called directly from with this function if -add is encounted on the command line
function ParseCommandLine(args)
local i, arg, val
local action="none"
local calendars=""
local selections=""
local NewEvent
local Config={}

Config.action="none"
Config.debug=false
Config.calendars=""
Config.selections=""
Config.EventsStart=time.secs()
Config.EventsEnd=0

NewEvent=EventCreate()
NewEvent.Visibility="default"

--as other values are set relative to Config.EventsStart, so we have to grab any '-start' option before all others
for i,arg in ipairs(args)
do
if arg=="-s" or arg=="-start" then Config.EventsStart=ParseDate(ParseArg(args, i+1)) end
end

if Config.EventsStart==0 then Config.EventsStart=time.secs() end


for i,arg in ipairs(args)
do
 ParseCommandLineArg(arg, i, args, NewEvent, Config)
end

if strutil.strlen(Config.calendars)==0 then Config.calendars="a:default" end


if Config.EventsEnd > 0
then
	if Config.EventsStart > Config.EventsEnd
	then
	val=Config.EventsStart
	Config.EventsStart=Config.EventsEnd
	Config.EventsEnd=val
	end
else
	Config.EventsEnd=Config.EventsStart + 3600
end

NewEvent.Start=Config.EventsStart
NewEvent.End=Config.EventsEnd

return Config, NewEvent
end


