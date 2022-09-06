

-- FUNCTIONS RELATING TO GOOGLE CALENDAR
function GCalAddEvent(calendars, NewEvent)
local url, S, text, doc, cal, Tokens

if OA==nil
then
	OA=oauth.OAUTH("pkce","gcal",Settings.GCalClientID, Settings.GCalClientSecret,"https://www.googleapis.com/auth/calendar", "https://www.googleapis.com/oauth2/v2/token");
	if OA:load() == 0 then OAuthGet(OA) end

end


Tokens=strutil.TOKENIZER(calendars,",")
cal=Tokens:next()
while cal ~= nil
do
cal=string.sub(cal,3)
if strutil.strlen(cal) > 0
then
url="https://www.googleapis.com/calendar/v3/calendars/".. strutil.httpQuote(cal) .."/events"
text="{\n\"summary\": \"" .. strutil.quoteChars(NewEvent.Title, "\n\"") .. "\",\n"
if strutil.strlen(NewEvent.Location) > 0 then text=text.."\"location\": \"".. strutil.quoteChars(NewEvent.Location, "\n\"") .."\",\n" end
if strutil.strlen(NewEvent.Details) > 0 then text=text.."\"description\": \"".. strutil.quoteChars(NewEvent.Details, "\n\"") .."\",\n" end
if strutil.strlen(NewEvent.Visibility) > 0 then text=text.."\"visibility\": \"".. NewEvent.Visibility .."\",\n" end
text=text.."\"start\": {\n\"dateTime\": \"" .. time.formatsecs("%Y-%m-%dT%H:%M:%SZ", NewEvent.Start,"GMT") .. "\"\n},\n"
text=text.."\"end\": {\n\"dateTime\": \"" .. time.formatsecs("%Y-%m-%dT%H:%M:%SZ", NewEvent.End,"GMT") .. "\"\n}\n"
text=text.. "}"

S=stream.STREAM(url, "w oauth=" .. OA:name() .. " content-type=" .. "application/json " .. "content-length=" .. strutil.strlen(text))

S:writeln(text)
doc=S:readdoc()
S:close()
end

cal=Tokens:next()
end

end




function GCalParseEvent(Parser)
local Event
local Start, End

Event=EventCreate()
Event.Title=Parser:value("summary")
Event.Details=Parser:value("description")
LocationParse(Event, Parser:value("location"))
Start=Parser:value("start/dateTime")
if strutil.strlen(Start) == 0 then Start=Parser:value("start/date") .. "T00:00:00" end
End=Parser:value("end/dateTime")
if strutil.strlen(End) == 0 then End=Parser:value("start/date") .. "T00:00:00" end
Event.Attendees=0
Event.Status=Parser:value("status")

--"2012-04-26T21:00:00+01:00",
Event.Start=time.tosecs("%Y-%m-%dT%H:%M:%S", Start)
Event.End=time.tosecs("%Y-%m-%dT%H:%M:%S", End)

return Event
end




function GCalLoadCalendar(Collated, cal)
local S, P, Events, Item, doc, url

process.lu_set("HTTP:Debug", "Y")

if OA==nil
then
	OA=oauth.OAUTH("pkce","gcal",Settings.GCalClientID, Settings.GCalClientSecret,"https://www.googleapis.com/auth/calendar", "https://www.googleapis.com/oauth2/v4/token");
	if OA:load() == false then OAuthGet(OA) end
end

url="https://www.googleapis.com/calendar/v3/calendars/".. strutil.httpQuote(cal) .."/events?singleEvents=true"
if config.EventsStart > 0
then 
	url=url.."&timeMin="..strutil.httpQuote(time.formatsecs("%Y-%m-%dT%H:%M:%SZ", config.EventsStart))
end

S=stream.STREAM(url, "r oauth="..OA:name())
doc=S:readdoc()

if config.debug==true then io.stderr:write("googlecalendar: "..doc.."\n") end


P=dataparser.PARSER("json", doc)
Events=P:open("/items")
if Events ~= nil
then
Item=Events:next()
while Item ~= nil
do
	if Item:value("kind")=="calendar#event" then table.insert(Collated, GCalParseEvent(Item)) end
	Item=Events:next()
end
end

S:close()
end


