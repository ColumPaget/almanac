

function ParseDuration(str)
local pos, multiplier, val, retval

pos=CountDigits(str)
val=string.sub(str, 1, pos)
multiplier=string.sub(str, pos+1)

if multiplier == "m"
then 
retval=tonumber(val) * 60
elseif multiplier == "h"
then
retval=tonumber(val) * 3600
elseif multiplier == "d"
then
retval=tonumber(val) * 3600 * 24
elseif multiplier == "w"
then
retval=tonumber(val) * 3600 * 24 * 7
else
retval=tonumber(val)
end

return retval
end



--Parse a date from a number of different formats
function ParseDate(datestr, Zone)
local len, lead_digits
local str=""
local when=0

len=strutil.strlen(datestr)
lead_digits=CountDigits(datestr)

if len==5 and string.sub(datestr, 3, 3) == ":"
then
	str=time.format("%Y-%m-%dT")..string.sub(datestr,1,2)..":"..string.sub(datestr,4,6)..":00"
elseif len==8
then
	if lead_digits == 8 --if it's ALL digits, then we have to presume YYYYmmdd
	then
	str=string.sub(datestr,1,4).."-"..string.sub(datestr,5,6).."-"..string.sub(datestr,7,8).."T00:00:00"
	elseif string.sub(datestr, 3, 3) == ":"
	then
		str=time.format("%Y-%m-%dT")..string.sub(datestr,1,2)..":"..string.sub(datestr,4,6)..":"..string.sub(datestr,7,8)
	else
	str="20"..string.sub(datestr,1,2).."-"..string.sub(datestr,4,5).."-"..string.sub(datestr,7,8).."T00:00:00"
	end
elseif len==10
then
	if lead_digits == 4
	then
		str=string.sub(datestr,1,4).."-"..string.sub(datestr,6,7).."-"..string.sub(datestr,9,10).."T00:00:00"
	else
		str=string.sub(datestr,7,10).."-"..string.sub(datestr,4,5).."-"..string.sub(datestr,1,2).."T00:00:00"
	end
elseif len==14
then
	str="20"..string.sub(datestr,1,2).."-"..string.sub(datestr,4,5).."-"..string.sub(datestr,7,8).."T"..string.sub(datestr,10,11)..":"..string.sub(datestr,13,14)
elseif len==15
then
	if lead_digits == 8 -- 20200212T140042
	then
	str=string.sub(datestr,1,4).."-"..string.sub(datestr,5,6).."-"..string.sub(datestr,7,8).."T"..string.sub(datestr,10,11)..":"..string.sub(datestr,12,13)..":"..string.sub(datestr,14,15)
	end
elseif len==16
then
	if lead_digits == 8 -- 20200212T140042Z
	then
	str=string.sub(datestr,1,4).."-"..string.sub(datestr,5,6).."-"..string.sub(datestr,7,8).."T"..string.sub(datestr,10,11)..":"..string.sub(datestr,12,13)..":"..string.sub(datestr,14,15)
	elseif lead_digits == 4
	then
		str=string.sub(datestr,1,4).."-"..string.sub(datestr,6,7).."-"..string.sub(datestr,9,10).."T"..string.sub(datestr,12,13)..":"..string.sub(datestr, 15, 16)..":00"
	else
		str=string.sub(datestr,7,10).."-"..string.sub(datestr,4,5).."-"..string.sub(datestr,1,2).."T"..string.sub(datestr,12,13)..":"..string.sub(datestr, 15, 16)..":00"
	end
elseif len==19
then
		str=string.sub(datestr,1,4).."-"..string.sub(datestr,6,7).."-"..string.sub(datestr,9,10).."T"..string.sub(datestr,12,13)..":"..string.sub(datestr, 15, 16)..":"..string.sub(datestr, 18)
end

when=time.tosecs("%Y-%m-%dT%H:%M:%S", str, Zone)
return when
end



-- Parse a location string, 
function LocationParse(Event, str)
local tmpstr=""

if str ~= nil
then
tmpstr=strutil.unQuote(str)
tmpstr=string.gsub(tmpstr, '\n', '')
tmpstr=string.gsub(tmpstr, "United States", "USA")
else
tempstr=""
end

if string.sub(tmpstr, 1, 6) == "https:" then Event.URL=tmpstr
else Event.Location=tmpstr
end

end


