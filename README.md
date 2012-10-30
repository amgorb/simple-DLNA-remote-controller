Simple DLNA perl controller. Used to mass start movie play at office TVs at once.

Requires Net::UPnP

usage: edit first lines of config, script will search local net for DLNA server, then it will search this server
for specified file, then search for all availalable renderes (TVs,players).
Then program goes for infinite loop: each device issued stop-start command sequence (first run), then each device is
maintened in PLAY state by checking its status.


2DO: playlist support.
