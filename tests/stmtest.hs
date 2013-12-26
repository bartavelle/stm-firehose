module Main where

import Test.Hspec
import Control.Concurrent.STM
import Control.Concurrent.STM.Firehose
import Control.Monad
import Test.HUnit
import Control.Applicative

intFH :: STM (Firehose Int)
intFH = newFirehose

main :: IO ()
main = hspec $ parallel $ do
    describe "Fire hose with no subscriptions" $ do
        it "must not block" $ do
            fh <- atomically intFH
            mapM_ (atomically . writeEvent fh) [1..10000]
            atomically (mapM_ (writeEvent fh) [1..10000])
    describe "Fire hose with a single subscription" $ do
        it "must give the oldest items in case of overflow" $ do
            out <- atomically $ do
                fh <- intFH
                sub <- subscribe 10 fh
                mapM_ (writeEvent fh) [1..10000]
                replicateM 10 (readEvent sub)
            map Just [1..10] @=? out
        it "must not block or close when unsubscribed" $ do
            out <- atomically $ do
                fh <- intFH
                sub <- subscribe 10 fh
                mapM_ (writeEvent fh) [1..100]
                unsubscribe sub
                mapM_ (writeEvent fh) [101..200]
                sub' <- subscribe 10 fh
                mapM_ (writeEvent fh) [201..300]
                replicateM 10 (readEvent sub')
            map Just [201..210] @=? out
    describe "Fire hose with multiple subscriptions" $ do
        it "must accept multiple subscriptions" $ do
            (o1,o2,o3,o4) <- atomically $ do
                fh <- intFH
                sub1 <- subscribe 10 fh
                writeEvent fh 1
                sub2 <- subscribe 10 fh
                writeEvent fh 2
                sub3 <- subscribe 10 fh
                writeEvent fh 3
                sub4 <- subscribe 10 fh
                mapM_ (writeEvent fh) [201..300]
                (,,,) <$> replicateM 10 (readEvent sub1) <*> replicateM 10 (readEvent sub2) <*> replicateM 10 (readEvent sub3) <*> replicateM 10 (readEvent sub4)
            map Just (take 10 ([1,2,3] ++ [201..])) @=? o1
            map Just (take 10 ([2,3] ++ [201..])) @=? o2
            map Just (take 10 ([3] ++ [201..])) @=? o3
            map Just (take 10 ([201..])) @=? o4

