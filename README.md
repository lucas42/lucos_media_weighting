#lucos Media Weighting
A haskell script for working out the relevant weightings of tracks for deciding what should be played.

## Dependencies
* ghc
* libghc-hdbc-sqlite3-dev
* libghc-configfile-dev

## Setup
* Create a ```config.txt``` file in the root of the project using a window *.ini style of config.  Include the following keys: ```baseurl```, ```readdb```, ```writedb```
* Run ```ghc weighting.hs -o weighting```

## Running
* Run ```./weighting```