
function DocumentGetType(S)
local Tokens, str, ext
local doctype=""

str=S:getvalue("HTTP:Content-Type")
if strutil.strlen(str) ~= 0
then
	Tokens=strutil.TOKENIZER(str, ";")
	doctype=Tokens:next()

	if doctype=="application/ical" then ext=".ical" 
	elseif doctype=="application/rss" then ext=".rss"
	elseif doctype=="text/calendar" 
	then 
		ext=".ical"
		doctype="application/ical"
	end
else
	str=S:path()
	if strutil.strlen(str) ~= nil
	then
		ext=filesys.extn(filesys.basename(str))
		if ext==".ical" then doctype="application/ical" 
		elseif ext==".rss" then doctype="application/rss" 
		end
	end
end

return doctype, ext
end 




function OpenCachedDocument(url)
local str, dochash, doctype, extn, S
local extns={".ical", ".rss"}

dochash=hash.hashstr(url, "md5", "hex")

if filesys.exists(url) == true then return(stream.STREAM(url, "r")) end

for i,extn in ipairs(extns)
do
str=process.getenv("HOME") .. "/.almanac/" .. dochash..extn
if filesys.exists(str) == true and (time.secs() - filesys.mtime(str)) < Settings.CacheTime then return(stream.STREAM(str, "r")) end
end

S=stream.STREAM(url)
if S ~= nil
then
	doctype,extn=DocumentGetType(S)
	S:close()
	if extn==nil then extn="" end
	str=process.getenv("HOME") .. "/.almanac/" .. dochash..extn
	filesys.copy(url, str)
	return(stream.STREAM(str, "r"))
end

return nil
end


function DocumentLoadEvents(Events, url)
local S, doctype, doc

S=OpenCachedDocument(url);
if S ~= nil
then
        doctype=DocumentGetType(S)
        doc=S:readdoc()
        if doctype=="text/xml" or doctype=="application/rss" or doctype=="application/rss+xml"
        then
                RSSLoadEvents(Events, doc)
        else
                ICalLoadEvents(Events, doc)
        end
else
print(terminal.format("~rerror: cannot open '"..url.."'~0"))
end

end
