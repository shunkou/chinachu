enc
===

requirements
------------

### Ruby ###
ruby-2.2.0 or later

### ffmpeg ###
libfdk_aac and libx264 are required

installartion
-------------
add crontab
```
5,35 *  *  *  * chinachu   bash -lc "/home/chinachu/enc/bin/encode.rb > /dev/null 2>&1"
```

TODO
----
- use https://github.com/streamio/streamio-ffmpeg
