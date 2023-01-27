
-- how is it that no one can ever stick one a single mime type for
-- a single type of document?
function AnalyzeContentType(ct)

if ct=="text/calendar" then return "application/ical" end
if ct=="application/ics" then return "application/ical" end

if ct=="text/xml" then return "application/rss" end
if ct=="application/rss+xml" then return "application/rss" end

return ct
end
