-- event uids (now called EID) are not truely unique
-- if an event is modified it keeps the same EID
-- this function generates a truely unique ID for
-- an event
function EventGenerateUID(Event)
local str=""
local uid

str=Event.EID 
if Event.Title ~= nil then str=str .. Event.Title end
if Event.Details ~= nil then str=str .. Event.Details end
if Event.Status ~= nil then str=str .. Event.Status end
if Event.Location ~= nil then str=str .. Event.Location end
if Event.Start ~= nil then str=str .. tostring(Event.Start) end
if Event.End ~= nil then str=str .. tostring(Event.End) end
if Event.URL ~= nil then str=str .. tostring(Event.URL) end

uid=hash.hashstr(str, "sha256", "base64")

return uid
end


-- create a blank event object
function EventCreate()
local Event={}

Event.Attendees=0
Event.UTCoffset=0;
Event.EID=string.format("%x",time.secs())
Event.Title=""
Event.Details=""
Event.Status=""
Event.Location=""
Event.Details=""
Event.Visibility=""
Event.Start=0
Event.End=0
Event.URL=""
Event.src=""

return Event
end


-- create a copy of an event object
function EventClone(parent)
local Event={}

Event.Attendees=parent.Attendees
Event.UTCoffset=parent.UTCoffset;
Event.EID=parent.EID
Event.Title=parent.Title
Event.Details=parent.Details
Event.Status=parent.Status
Event.Location=parent.Location
Event.Details=parent.Details
Event.Visibility=parent.Visiblity
Event.Start=parent.Start
Event.End=parent.End
Event.URL=parent.URL
Event.src=parent.src

return Event
end


