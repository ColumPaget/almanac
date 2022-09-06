-- Functions related to extracting ical and other files from emails
function EmailExtractBoundary(header)
local toks, str
local boundary=""

toks=strutil.TOKENIZER(header, "\\S")
str=toks:next()
while str~= nil
do
if string.sub(str, 1,9) == "boundary=" then boundary=strutil.stripQuotes(string.sub(str, 10)) end
str=toks:next()
end

return boundary
end



function EmailHandleContentType(content_type, args)
local boundary=""

if string.sub(content_type, 1, 10)== "multipart/" then boundary=EmailExtractBoundary(args) end

return content_type, boundary
end



function EmailParseHeader(header, mime_info)
local toks
local name=""
local value=""
local args=""

toks=strutil.TOKENIZER(header, ":|;", "m")
name=toks:next()
value=toks:next()
if name ~= nil  and value ~= nil
then
	name=string.lower(name)
	value=string.lower(strutil.stripLeadingWhitespace(value))
	args=toks:remaining()

	if name=="content-type" 
	then 
	mime_info.content_type,mime_info.boundary=EmailHandleContentType(value, args) 
	elseif name=="content-transfer-encoding"
	then
	mime_info.encoding=value
	end
end

end



function EmailReadHeaders(S)
local line, str
local header=""
local mime_info={}

mime_info.content_type=""
mime_info.boundary=""
mime_info.encoding=""

line=S:readln()
while line ~= nil
do
	line=strutil.stripTrailingWhitespace(line);
	char1=string.sub(line, 1, 1)

	if char1 ~= " " and char1 ~= "	"
	then
		EmailParseHeader(header, mime_info)
		header=""
	end
	header=header .. line
	if strutil.strlen(line) < 1 then break end
	line=S:readln()
end

EmailParseHeader(header, mime_info)

return mime_info
end



function EmailReadDocument(S, boundary, encoding, EventsFunc)
local line, event, i, len
local doc=""
local Events={}

if config.debug==true then io.stderr:write("extract:  enc="..encoding.." boundary="..boundary.."\n") end
len=strutil.strlen(boundary)
line=S:readln()
while line ~= nil
do
	if len > 0 and string.sub(line, 1, len) == boundary then break end
	if encoding=="base64" then line=strutil.trim(line) end
	doc=doc..line
	line=S:readln()
end

if encoding=="base64"
then
	doc=strutil.decode(doc, "base64") 
elseif encoding=="quoted-printable"
then 
	doc=strutil.decode(doc, "quoted-printable") 
end


if config.debug==true then io.stderr:write("doc:  "..doc.."\n") end
doc=string.gsub(doc, "\r\n", "\n")
ICalLoadEvents(Events, doc)
for i,event in ipairs(Events)
do
	EventsFunc(event)
end

end


function EmailHandleMimeContainer(S, mime_info, EventsFunc)
local str, boundary

boundary="--" .. mime_info.boundary
str=S:readln()
while str ~= nil
do
	str=strutil.stripTrailingWhitespace(str)
	if str==boundary then EmailHandleMimeItem(S, boundary, EventsFunc) end
	str=S:readln()
end
end


function EmailHandleMimeItem(S, boundary, EventsFunc)
local mime_info

mime_info=EmailReadHeaders(S)

if config.debug==true then io.stderr:write("mime item: ".. mime_info.content_type.." enc="..mime_info.encoding.." boundary="..mime_info.boundary.."\n") end
if mime_info.content_type == "text/calendar"
then
	EmailReadDocument(S, boundary, mime_info.encoding, EventsFunc)
	mime_info.content_type=""
elseif mime_info.content_type == "multipart/mixed"
then
	EmailHandleMimeContainer(S, mime_info, EventsFunc)
end

end



function EmailExtractCalendarItems(path, EventsFunc)
local S, mime_info, boundary, str

S=stream.STREAM(path, "r")
if S ~= nil
then
if config.debug==true then io.stderr:write("open email '"..path.."\n") end
mime_info=EmailReadHeaders(S)
EmailHandleMimeContainer(S, mime_info, EventsFunc)
S:close()
end

end

