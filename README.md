# lucos Media Weighting
A haskell script for deciding the relative likelihood of playing each track.

This script dosen't make a great deal of sense on its own - it  should be used alongside other lucos_media* modules

## Dependencies
* ghc
* libghc-hdbc-sqlite3-dev
* libghc-configfile-dev

## Compiling
Run ```ghc weighting.hs -o weighting``` from the root of the project.

## Configuration
Create a ```config.txt``` file in the root of the project.  This should use a syntax similar to that of windows *.ini files (colon separated key/value pairs, each on a new line).  The following keys are supported:
* **baseurl**: The part of the url which is common to all tracks.
* **readdb**: The path on the filesystem of the sqlite database to make read queries against (relative to the root of the project)
* **writedb**: The path on the filesystem of the sqlite database to make write queries against (relative to the root of the project)

## Running
* Run ```./weighting```

## Supersceded
This script interacts directly with the database, which isn't ideal.  It's been supersceded by (lucos_media_weightings)[https://github.com/lucas42/lucos_media_weightings] which interacts via a HTTP API
