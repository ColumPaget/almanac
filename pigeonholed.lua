
function PigeonholedAddItem(str, Key, Value)

str=str .. Key .. "=\"" ..strutil.quoteChars(Value, "\n\"") .. "\" "
return str
end


function PigeonholedSendEvents(Events, S)
local i, event, str

	for i,event in ipairs(Events)
	do
	str="object calendar "..event.EID.." "
	str=PigeonholedAddItem(str, "uid", event.EID)
	str=PigeonholedAddItem(str, "title", event.Title)
	str=PigeonholedAddItem(str, "location", event.Location)
	str=PigeonholedAddItem(str, "details", event.Details)
	str=PigeonholedAddItem(str, "url", event.URL)
	str=PigeonholedAddItem(str, "start", time.formatsecs("%Y/%m/%dT%H:%M:%S", event.Start))
	str=PigeonholedAddItem(str, "end", time.formatsecs("%Y/%m/%dT%H:%M:%S", event.End))
	str=str.."\n"
	S:writeln(str)

	str=S:readln()
	end
end

function PigeonholedParseEventProperty(event, str)
local toks, key

toks=strutil.TOKENIZER(str, "=", "Q")
key=toks:next()

if key=="uid" then event.EID=toks:next()
elseif key=="title" then event.Title=toks:next()
elseif key=="location" then event.Location=toks:next()
elseif key=="details" then event.Details=toks:next()
elseif key=="url" then event.URL=toks:next()
elseif key=="start" then event.Start=time.tosecs("%Y/%m/%dT%H:%M:%S", toks:next())
elseif key=="end" then event.End=time.tosecs("%Y/%m/%dT%H:%M:%S", toks:next())
end

end

function PigeonholedEventExists(Events, event) 
local i, item

for i,item in ipairs(Events)
do
	if item.uid==event.uid then return true end
end

return false
end


function PigeonholedReadEventItem(Events, uid, S)
local str, toks
local event={}

S:writeln("read calendar ".. uid .. "\n")
str=S:readln()
toks=strutil.TOKENIZER(str, "\\S", "q")
str=toks:next()
while str ~= nil
do
PigeonholedParseEventProperty(event, str)
str=toks:next()
end

if PigeonholedEventExists(Events, event) ~= true then AlmanacAddEvent(event) end

end


function PigeonholedReadEvents(Events, S)
local i, event, str

	S:writeln("list calendar\n")
	str=S:readln()
	toks=strutil.TOKENIZER(str, "\\S", "Q")
	if toks:next() == "+OK"
	then
		str=toks:next()
		while str ~= nil
		do
		PigeonholedReadEventItem(Events, str, S)
		str=toks:next()
		end
	end

end



function PigeonholedSync(Events, config)
local S

S=stream.STREAM(config.SyncURL)
if S ~= nil
then
PigeonholedSendEvents(Events, S)
PigeonholedReadEvents(Events, S)
S:close()
end

end
