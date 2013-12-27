{-# LANGUAGE OverloadedStrings #-}
{-| This module is here to let you easily build firehose systems. The
'firehoseApp' application is a standard 'Application' that will stream the events to clients. The 'firehoseConduit' function will spawn a web server on the given port, and let
the data-flow in a conduit be examined this way.

For an example implementation, with a JSON encodable data type, see <http://hackage.haskell.org/package/hslogstash/docs/src/Data-Conduit-FireHose.html#fireHose>.

-}
module Data.Conduit.Network.Firehose (firehoseApp, firehoseConduit) where

import Control.Concurrent (forkIO)
import Control.Concurrent.STM
import Control.Concurrent.STM.Firehose
import Data.Conduit.TQueue
import qualified Data.Conduit.List as CL

import Network.HTTP.Types
import Network.Wai
import Data.Conduit
import Blaze.ByteString.Builder
import Network.Wai.Handler.Warp

import Control.Monad (void)
import Control.Monad.IO.Class

{-| A firehose application, suitable for use in a wai-compatible server.
A typical usage is with JSON encodable data, where the serialization function can be :

> -- encode to JSON, turn into a Builder, then append a newline.
> (<> fromByteString "\n") . fromLazyByteString . encode

The filtering function has a type that let you create it based on the 'Request'. That means you can use the query string to build the proper filters.
-}
firehoseApp :: Int -- ^ Buffer size for the fire hose threads
            -> (Request -> a ->  Bool) -- ^ A filtering function for fire hose messages. Only messages that match this function will be passed. The request can be used to build the filter.
            -> (a -> Builder) -- ^ The serialization function
            -> Firehose a
            -> Application
firehoseApp buffsize filtering serialize fh req = responseSourceBracket (atomically (subscribe buffsize fh)) (atomically . unsubscribe) runFirehose
    where
        filtering' = filtering req
        -- Subscription a -> IO (Status, ResponseHeaders, Source IO (Flush Builder))
        runFirehose sub = return (status200, [], sourceTBMQueue (getQueue sub) $= CL.filter filtering' $= CL.concatMap (\e -> [Chunk (serialize e), Flush]) )

{-| A fire hose conduit creator, that can be inserted in your conduits as
firehose entry points. Will run Warp on the specified port. Please not
that the connection will timeout after an hour.
-}
firehoseConduit :: (Monad m, MonadIO m)
                => Int -- ^ Port to listen on
                -> Int -- ^ Buffer size for the fire hose threads
                -> (Request -> a ->  Bool) -- ^ A filtering function for fire hose messages. Only messages that match this functions will be passed. The request can be used to build the filter.
                -> (a -> Builder) -- ^ The serialization function
                -> IO (Conduit a m a)
firehoseConduit port buffersize getFilter serialize = do
    fh <- atomically newFirehose
    let settings = defaultSettings { settingsPort = port, settingsTimeout = 3600 }
    void $ forkIO (runSettings settings (firehoseApp buffersize getFilter serialize fh))
    return (CL.mapM (\m -> liftIO (atomically (writeEvent fh m)) >> return m))
