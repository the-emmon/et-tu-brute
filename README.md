# et-tu-brute
### It's March 15th, Julius CSRF.
Unhappy with the slowness of available Python token-fetching bruteforcers, I created et-tu-brute to allow for easy, ultrafast multithreaded attacks on CSRF-protected login portals.

Tested against a Proving Grounds machine with a CSRF-protected web portal, et-tu-brute clocked ~120,000 password attempts in 9 minutes. Add it to your toolkit to directly attack CSRF logins at a rapidfire rate, no proxy or long wait required. 

It also handles huge wordlists well, loading 1gb+ password lists with no slowdown or long initial wait.
## Usage
```
./ettubrute <login_url> <csrf_htmlname> <wordlist> <postdata_nocsrf> <username> <errormsg>
```
Here's an example with the values filled in:
```
./ettubrute http://10.10.11.77/login csrf_token /usr/share/wordlists/rockyou.txt 'user=^USER^&password=^PASS^&submit=Login' admin 'Your username and password mismatch.'
```
The tool will automatically try to grab cookies from the login page as well. It was developed for a single PHPSESSID cookie, so multiple cookies set on the token grab might break that functionality; I'll need to test it against login pages that set multiple cookies to see how it performs.
## Compiling
I've provided a compiled amd64 binary. If you'd like to compile the tool yourself, run the following:
```
git clone https://github.com/the-emmon/et-tu-brute
cd et-tu-brute
nim c --threads:on --opt:speed --app:console --gc:boehm -d:release ettubrute.nim
```
Be sure to compile with the options listed to avoid glitches and "illegal filesystem access" crashes.

If you'd like to directly mirror the release builds, strip the executable like this:
```
strip ettubrute && upx --best --strip-relocs=0 ettubrute
``` 
## Ideas?
Open an issue or a pull request if you'd like a feature implemented!
