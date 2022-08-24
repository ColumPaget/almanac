
require("oauth")
require("process")
require("strutil")
require("stream")
require("dataparser")
require("terminal")
require("filesys")
require("time")
require("hash")


VERSION="2.2"
Settings={}
EventsNewest=0
Now=0
Today=""
Tomorrow=""
WarnEvents={}
display_count=0
Out=nil
Term=nil

--GENERIC FUNCTIONS

function UpdateTimes()
Now=time.secs()
Today=time.formatsecs("%Y/%m/%d", Now)
Tomorrow=time.formatsecs("%Y/%m/%d", Now+3600*24)
end

