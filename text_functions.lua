
--this function builds a single line from file formats (email headers and ical) that set limits on line length.
--these formats split long lines and start the continuation lines with a whitespace to indicate it's a
--continuation of the previousline
function UnSplitLine(lines)
local line, tok, char1

line=lines:next()
tok=lines:peek()

while line ~= nil and tok ~= nil
do
	line=strutil.stripCRLF(line)
	char1=string.sub(tok, 1, 1)
	if char1 ~= " " and char1 ~= "  " then break end

	--now really read the peeked token
	tok=strutil.stripCRLF(lines:next())
	line=line .. string.sub(tok, 2)
	tok=lines:peek()
end

return line
end



--count digits at start of a string, mostly used by ParseDate 
function CountDigits(str)
local count=0
local i

--no, we can't just use 'i' for the return values, because once we
--leave the loop i will reset to 0 (weird lua thing) so we then
--wouldn't know if we'd failed to loop at all, or had loops through
--all the characters in the string
for i=1,strutil.strlen(str),1
do
	if tonumber(string.sub(str,i,i)) == nil then return count end
	count=count + 1
end

return count
end

