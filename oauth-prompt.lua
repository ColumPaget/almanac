-- do initial oauth authentication
function OAuthGet(OA)

str=strutil.httpQuote("urn:ietf:wg:oauth:2.0:oob");
OA:set("redirect_uri", str);
OA:stage1("https://accounts.google.com/o/oauth2/v2/auth");

print()
print("GOOGLE CALENDAR REQUIRES OAUTH LOGIN. Goto the url below, grant permission, and then copy the resulting code into this app.");
print()
print("GOTO: ".. OA:auth_url());

OA:listen(8989, "https://www.googleapis.com/oauth2/v4/token");
OA:save("");
print()
end

