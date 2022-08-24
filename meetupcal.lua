


-- FUNCTIONS RELATING TO MEETUP CALENDARS
function MeetupParseEvent(Parser)
local Event={}

Event=EventCreate()
Event.Title=Parser:value("name")
Event.Details=Parser:value("description")
Event.Location=Parser:value("venue/name");
if Event.Location==nil then Event.Location="" end
Event.Country=Parser:value("venue/country");
Event.City=Parser:value("venue/city");
--Event.Start=Parser:value("local_date").." "..Parser:value("local_time")
Event.Attendees=tonumber(Parser:value("yes_rsvp_count"))
Event.UTCoffset=tonumber(Parser:value("utc_offset"));

-- convert from time in millseconds
Event.Start=tonumber(Parser:value("time")) / 1000.0
if strutil.strlen(Parser:value("duration"))  > 0
then
Event.End=Event.Start + tonumber(Parser:value("duration")) / 1000.0
else Event.End=0
end

return Event
end



function MeetupLoadCalendar(Collated, cal)
local S, P, Events, Item, doc

S=stream.STREAM("https://api.meetup.com/".. strutil.httpQuote(cal) .."/events")
doc=S:readdoc()

P=dataparser.PARSER("json", doc)
Events=P:open("/")
if Events ~= nil
then
Item=Events:next()
while Item ~= nil
do
table.insert(Collated, MeetupParseEvent(Item))
Item=Events:next()
end
end

S:close()
end


