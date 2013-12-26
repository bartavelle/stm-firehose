{-# LANGUAGE OverloadedStrings #-}
module Data.Conduit.Network.Firehose (firehoseApp) where

import Control.Concurrent.STM
import Control.Concurrent.STM.Firehose
import Data.Conduit.TQueue
import qualified Data.Conduit.List as CL

import Network.HTTP.Types
import Network.Wai
import Data.Conduit
import Blaze.ByteString.Builder

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

