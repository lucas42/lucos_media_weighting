import Database.HDBC
import Database.HDBC.Sqlite3
import Data.ConfigFile
import Data.Either.Utils
import Control.Monad.Error

main = do
    config <- readConfig "config.txt"
    conn <- connectSqlite3 (readdb config)
    r <- quickQuery' conn "SELECT id, path FROM track LEFT JOIN track_path_fingerprint ON track.fingerprint = track_path_fingerprint.fingerprint WHERE PATH IS NOT NULL" []
    disconnect conn
    parseTrack config r
    
-- Based on http://cogsandlevers.blogspot.co.uk/2013/07/configfile-basics-in-haskell.html
data ConfigInfo = ConfigInfo { baseurl :: String
                             , readdb :: String
                             , writedb :: String
                             }    
readConfig :: String -> IO ConfigInfo
readConfig f = do
   rv <- runErrorT $ do
 
      -- open the configuration file
      cp <- join $ liftIO $ readfile emptyCP f
      let x = cp
 
      -- read out the attributes
      buv <- get x "" "baseurl"
      rdv <- get x "" "readdb"
      wdv <- get x "" "writedb"
 
      -- build the config value
      return (ConfigInfo { baseurl = buv
                         , readdb = rdv
                         , writedb = wdv
                         })
 
   -- in the instance that configuration reading failed we'll
   -- fail the application here, otherwise send out the config
   -- value that we've built
   either (\x -> error (snd x)) (\x -> return x) rv


parseTrack :: ConfigInfo -> [[SqlValue]] -> IO Float
parseTrack _ [] = do
    putStrLn $ "done"
    return 0
    
parseTrack config ([sqltrackid, sqlpath]:xs) = do
    url <- (getUrl config sqlpath)
    (weighting, json) <- (getWeighting config sqltrackid)
    cum_weighting <- getCumWeighting config xs weighting
    print cum_weighting
    conn <- connectSqlite3 (writedb config)
    run conn "INSERT OR IGNORE INTO cache (track_id, url) VALUES (?, ?)" [sqltrackid, toSql url]
    run conn ("UPDATE cache SET weighting = ?, data = ?, url = ?, cum_weighting = ? WHERE track_id = ?;") [toSql (show weighting), (toSql json), toSql url, toSql (show cum_weighting), sqltrackid]
    commit conn
    disconnect conn
    return (cum_weighting)

getUrl :: ConfigInfo -> SqlValue -> IO String
getUrl config sqlpath = do
    return (baseurl config ++ (fromSql sqlpath))
    
getCumWeighting :: ConfigInfo -> [[SqlValue]] -> Float -> IO Float
getCumWeighting config results weighting = do
    other_weightings <- parseTrack config results
    return (other_weightings + weighting)
    
getWeighting :: ConfigInfo -> SqlValue -> IO (Float, String)
getWeighting config trackid = do
    conn <- connectSqlite3 (readdb config)
    tags <- quickQuery' conn "SELECT label, function, value FROM tag JOIN track_tags ON id = tag_id WHERE track_id = ?" [trackid]
    disconnect conn
    weighting <- getTagWeightings config tags
    return (weighting, "{" ++ jsonEncodeTags tags ++ "}")
    
getTagWeightings :: ConfigInfo -> [[SqlValue]] -> IO Float
getTagWeightings config [] = return (5)
getTagWeightings config ([label, tagfunction, value]:xs) = do
    weighting <- getTagWeightings config xs
    getTagWeight config (convertString tagfunction) (convertString label) (convertString value) weighting

getTagWeight :: ConfigInfo -> String -> String -> String -> Float -> IO Float

getTagWeight config "multiply" _ value weight = do
    return (weight * ( float_value / 5 ))
    where float_value = read value :: Float

getTagWeight config "global_match" label tag_value weight = do
    global_value <- getGlobalVal config label
    if tag_value == global_value
        then return (weight * 10)
        else return (weight / 10)

getTagWeight _ "ignore" _ _ _ = return 0

-- Unknown weight, don't change
getTagWeight _ _ _ _ weight = return (weight);

getGlobalVal :: ConfigInfo -> String -> IO String
getGlobalVal config label = do
    conn <- connectSqlite3 (readdb config)
    val <- (quickQuery' conn "SELECT val FROM global_val WHERE key = ?" [toSql label])
    disconnect conn
    return (getVal val)
    
jsonEncodeTags :: [[SqlValue]] -> String

jsonEncodeTags [] = ""
jsonEncodeTags ([sqllabel, _, sqlvalue]:[]) = "\"" ++ escapeJson label ++ "\": \"" ++ escapeJson value ++ "\""
    where label = fromSql sqllabel
          value = fromSql sqlvalue
jsonEncodeTags ([sqllabel, _, sqlvalue]:xs) = "\"" ++ escapeJson label ++ "\": \"" ++ escapeJson value ++ "\", " ++ (jsonEncodeTags xs)
    where label = fromSql sqllabel
          value = fromSql sqlvalue

escapeJson :: String -> String
escapeJson [] = []
escapeJson ('\\': xs) = "\\\\" ++ escapeJson xs
escapeJson ('"': xs) = "\\\"" ++ escapeJson xs
escapeJson (a : xs) = [a] ++ escapeJson xs

convertString :: SqlValue -> String
convertString string = case fromSql string of
    Just x -> x
    Nothing -> "NULL"

getVal :: [[SqlValue]] -> String
getVal [[val]] = convertString val
getVal [] = "NULL"
