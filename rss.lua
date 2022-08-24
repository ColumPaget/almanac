
-- FUNCTIONS FOR PARSING RSS and XCal FILES

function RSSParseEvent(Parser)
local Event

Event=EventCreate()
item=Parser:next()
while item ~=nil
do
if (item:name()=="title") then Event.Title=item:value() end
if (item:name()=="description") then Event.Details=item:value() end
if (item:name()=="xCal:dtstart") then Event.Start=time.tosecs("%Y%m%dT%H%M%S", item:value()) end
if (item:name()=="dtstart") then Event.Start=time.tosecs("%Y%m%dT%H%M%S", item:value()) end
if (item:name()=="xCal:dtend") then Event.End=time.tosecs("%Y%m%dT%H%M%S", item:value()) end
if (item:name()=="dtend") then Event.End=time.tosecs("%Y%m%dT%H%M%S", item:value()) end
if (item:name()=="xCal:location") then Event.Location=item:value() end
if (item:name()=="location") then Event.Location=item:value() end

item=Parser:next()
end

return Event
end




function RSSLoadEvents(Collated, doc)
local P, Events, Item, values, doc

P=dataparser.PARSER("rss", doc)
Events=P:open("/")
if Events ~= nil
then
Item=Events:next()
while Item ~= nil
do
values=Item:open("/")
if string.sub(Item:name(), 1,5) =="item:" then table.insert(Collated, RSSParseEvent(values)) end
Item=Events:next()
end
end

end




