{-|
A subscription based messaging system, with non-blocking bounded write.

> fh <- atomically newFirehose
> -- the following line will not block, even though nobody subscribed
> atomically (mapM_ (writeEvent fh) [1..100])
> -- let's subscribe a single client
> sub <- atomically (subscribe 10 fh)
> forkIO (forever (atomically (readEvent fh) >>= print))
> writeEvent fh 1
-}
module Control.Concurrent.STM.Firehose (Firehose, Subscription, newFirehose, writeEvent, subscribe, unsubscribe, readEvent, getQueue) where

import Control.Concurrent.STM
import Control.Concurrent.STM.TBMQueue
import Control.Monad (filterM)

newtype Firehose a = Firehose (TVar [TBMQueue a])

data Subscription a = Subscription (TBMQueue a) (Firehose a)

-- | Creates a new 'Firehose' item.
newFirehose :: STM (Firehose a)
newFirehose = Firehose `fmap` newTVar []

-- | Sends a piece of data in the fire hose.
writeEvent :: Firehose a -> a -> STM ()
writeEvent (Firehose lst) element = readTVar lst >>= mapM_ (flip tryWriteTBMQueue element)

-- | Get a subscription from the fire hose, that will be used to
-- read events.
subscribe :: Int -- ^ Number of elements buffered. If set too high, it will increase memory usage. If set too low, activity spikes will result in message loss.
          -> Firehose a -> STM (Subscription a)
subscribe len f@(Firehose lst) = do
    nq <- newTBMQueue len
    modifyTVar' lst (nq:)
    return (Subscription nq f)

-- | Unsubscribe from the fire hose. Subsequent calls to 'readEvent' will
-- return 'Nothing'. This runs in O(n), where n is the current number of
-- subscriptions. Please contact the maintainer if you need better
-- performance.
unsubscribe :: Subscription a -> STM ()
unsubscribe (Subscription q (Firehose lst)) = do
    closeTBMQueue q
    queues <- readTVar lst
    nqueues <- filterM (fmap not . isClosedTBMQueue) queues
    writeTVar lst nqueues

-- | Read an event from a 'Subscription'. This will return 'Nothing' if the
-- firehose is shut, or the subscription removed.
readEvent :: Subscription a -> STM (Maybe a)
readEvent (Subscription q _) = readTBMQueue q

-- | Gets the underlying queue from a subscription.
getQueue :: Subscription a -> TBMQueue a
getQueue (Subscription q _) = q
