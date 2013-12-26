{-# LANGUAGE OverloadedStrings #-}
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

-- | A firehose application, suitable for use in a wai-compatible server.
firehoseApp :: Int -- ^ Buffer size for the fire hose threads
            -> (Request -> a ->  Bool) -- ^ A filtering function for fire hose messages. Only messages that match this functions will be passed. The request can be used to build the filter.
            -> (a -> Builder) -- ^ The serialization function
            -> Firehose a
            -> Application
firehoseApp buffsize filtering serialize fh req = responseSourceBracket (atomically (subscribe buffsize fh)) (atomically . unsubscribe) runFirehose
    where
        filtering' = filtering req
        -- Subscription a -> IO (Status, ResponseHeaders, Source IO (Flush Builder))
        runFirehose sub = return (status200, [], sourceTBMQueue (getQueue sub) $= CL.filter filtering' $= CL.concatMap (\e -> [Chunk (serialize e), Flush]) )

-- | A fire hose conduit creator, that can be inserted in your conduits as
-- firehose entry points. Will run Warp on the specified port.
firehoseConduit :: (Monad m, MonadIO m)
                => Int -- ^ Port to listen on
                -> Int -- ^ Buffer size for the fire hose threads
                -> (Request -> a ->  Bool) -- ^ A filtering function for fire hose messages. Only messages that match this functions will be passed. The request can be used to build the filter.
                -> (a -> Builder) -- ^ The serialization function
                -> IO (Conduit a m a)
firehoseConduit port buffersize getFilter serialize = do
    fh <- atomically newFirehose
    void $ forkIO (run port (firehoseApp buffersize getFilter serialize fh))
    return (CL.mapM (\m -> liftIO (atomically (writeEvent fh m)) >> return m))
