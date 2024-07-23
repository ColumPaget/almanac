email_bounds={}
email_bounds.boundary=1
email_bounds.final_boundary=2
email_bounds.mbox=3


function EmailCheckBoundary(S, line, boundary, mailfile_type)
local cleaned, final
local RetVal=0

	cleaned=strutil.trim(line)

	if strutil.strlen(boundary) > 0  
	then 
	   if cleaned == ("--"..boundary.."--") then RetVal=email_bounds.final_boundary
	   elseif cleaned == ("--" .. boundary) then RetVal=email_bounds.boundary
	   end
	elseif mailfile_type=="mbox"
	then
		while line == "\r\n" or line == "\n"
		do
			line=S:readln()
		end
		if line==nil then return email_bounds.final_boundary,nil end
		if string.sub(line, 1, 5)=="From " then RetVal=email_bounds.mbox end
	end

return RetVal, line
end


-- Functions related to extracting ical and other files from emails
function EmailExtractBoundary(header)
local toks, str
local boundary=""

toks=strutil.TOKENIZER(header, "\\S|;", "m")
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
content_type=AnalyzeContentType(content_type)

return content_type, boundary
end



function EmailParseHeader(header, mime_info)
local toks
local name=""
local value=""
local args=""

if config.debug==true then io.stderr:write("EMAIL HEADER: "..header.."\n") end
toks=strutil.TOKENIZER(header, ":|;", "m")
name=toks:next()
value=toks:next()
if name ~= nil  and value ~= nil
then
	name=string.lower(name)
	value=string.lower(strutil.stripLeadingWhitespace(value))
	args=toks:remaining()

	if name == "content-type" 
	then 
	mime_info.content_type,mime_info.boundary=EmailHandleContentType(value, args) 
	elseif name == "content-transfer-encoding"
	then
	mime_info.encoding=value
	elseif name == "subject"
	then
	--print("SUBJECT: " .. args)
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
if line == nil then return nil end
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



function EmailReadDocument(S, boundary, encoding, mailfile_type, EventsFunc)
local line, event, i, len, cleaned
local doc=""
local Events={}
local Done=false

if config.debug==true then io.stderr:write("extract:  enc="..encoding.." boundary="..boundary.."\n") end

len=strutil.strlen(boundary)
line=S:readln()
while line ~= nil
do
 bound_found=EmailCheckBoundary(S, line, boundary, mailfile_type)
 if bound_found==email_bounds.boundary and strutil.strlen(doc) > 0 then break
 elseif bound_found==email_bounds.final_boundary then Done=true; break
 elseif bound_found==email_bounds.mbox then Done=true; break
 end

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

return Done
end


function EmailHandleMimeContainer(S, mime_info, mailfile_type, EventsFunc)
local str

str=S:readln()
while str ~= nil
do

	bound_found,str=EmailCheckBoundary(S, str, mime_info.boundary, mailfile_type)
	str=strutil.stripTrailingWhitespace(str)

	if bound_found > email_bounds.boundary then break end
	if bound_found > 0 then Done=EmailHandleMimeItem(S, mime_info.boundary, mailfile_type, EventsFunc) end

	if Done==true then break end
	str=S:readln()
end

end


function EmailHandleMimeItem(S, boundary, mailfile_type, EventsFunc)
local mime_info
local Done=false

mime_info=EmailReadHeaders(S)

if config.debug==true then io.stderr:write("mime item: ".. mime_info.content_type.." enc="..mime_info.encoding.." boundary="..mime_info.boundary.."\n") end

if  strutil.strlen(mime_info.boundary) == 0 then mime_info.boundary=boundary end


if mime_info.content_type == "application/ical"
then
	Done=EmailReadDocument(S, mime_info.boundary, mime_info.encoding, mailfile_type, EventsFunc)
	mime_info.content_type=""
elseif string.sub(mime_info.content_type, 1, 10) == "multipart/"
then
	EmailHandleMimeContainer(S, mime_info, mailfile_type, EventsFunc)
else
	--Done=EmailReadDocument(S, mime_info.boundary, mime_info.encoding, mailfile_type, EventsFunc)
end

return Done
end



function EmailExtractCalendarItems(path, mailfile_type, EventsFunc)
local S, mime_info, boundary, str

S=stream.STREAM(path, "r")
if S ~= nil
then
if config.debug==true then io.stderr:write("open email '"..path.."\n") end

mime_info=EmailReadHeaders(S)
while mime_info ~= nil
do
EmailHandleMimeContainer(S, mime_info, mailfile_type, EventsFunc)
mime_info=EmailReadHeaders(S)
end


S:close()
end

end

