-- do initial oauth authentication
function OAuthGet(OA)

OA:set("redirect_uri", "http://127.0.0.1:8989");
OA:stage1("https://accounts.google.com/o/oauth2/v2/auth");

print()
print("GOOGLE CALENDAR REQUIRES OAUTH LOGIN. Goto the url below, grant permission, and then copy the resulting code into this app.");
print()
print("GOTO: ".. OA:auth_url());

OA:listen(8989, "https://www.googleapis.com/oauth2/v2/token");
OA:finalize("https://oauth2.googleapis.com/token");
print()
end

