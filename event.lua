-- create a blank event object
function EventCreate()
local Event={}

Event.Attendees=0
Event.UTCoffset=0;
Event.UID=string.format("%x",time.secs())
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


-- create a blank event object
function EventClone(parent)
local Event={}

Event.Attendees=parent.Attendees
Event.UTCoffset=parent.UTCoffset;
Event.UID=parent.UID
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

