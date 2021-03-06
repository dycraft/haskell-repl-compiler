{-# LANGUAGE OverloadedStrings #-}

module Exec where

import Prelude hiding (count, getLine, concat, putStrLn, drop, readFile, writeFile, appendFile)
import Control.Applicative
import Data.Functor
import Data.Either
import Data.Text
import Data.Text.IO (getLine, putStrLn, readFile, writeFile, appendFile)
import Control.Monad
import qualified Data.Map as M
import System.IO hiding (getLine, putStrLn, readFile, writeFile, appendFile)
-- import System.Console.Readline
import Control.Monad.State
import Control.Monad.Trans
import Parser
import Eval
import Printer
import Debug.Trace

newCount :: Int -> Text -> Int
newCount i s = i + Data.Text.count "(" s - Data.Text.count ")" s

io :: IO a -> StateT (Env, Text, Text, Int) IO a
io = liftIO

(=|) :: Text -> Text -> Bool
(=|) text starts = Data.Text.take (Data.Text.length starts) (strip text) == starts

type Repl a = StateT (Env, Text, Text, Int) IO a

appendLine :: Text -> (Env, Text, Text, Int) -> (Env, Text, Text, Int)
appendLine line (env, last, hist, cnt) = (env, last `append` line, hist, newCount cnt line)

prettyPrinterLoop :: [Text] -> IO ()
prettyPrinterLoop ts = case ts of
    [] -> return ()
    (x:xs) -> do
        putStrLn x
        prettyPrinterLoop xs

prettyPrinter :: Text -> IO ()
prettyPrinter s = prettyPrinterLoop $ splitOn "\r\n" $ prettyPrint s


genASTLoop :: String -> [Text] -> IO ()
genASTLoop path ts = case ts of
    [] -> return ()
    (x:xs) -> do
        appendFile path x
        appendFile path "\n"
        genASTLoop path xs

genAST :: String -> String -> IO ()
genAST fin fout = do
    content <- readFile fin
    let lines = splitOn "\r\n" $ prettyPrint content
    writeFile fout ""
    genASTLoop fout lines

genRstLoop :: String -> [Text] -> IO ()
genRstLoop path ts = case ts of
    [] -> return ()
    (x:xs) -> do
        appendFile path x
        appendFile path "\n"
        genRstLoop path xs

genRst :: String -> String -> IO ()
genRst fin fout = do
    content <- readFile fin
    let out = runResult content M.empty
    case out of
        (Right "", _) -> return ()
        (Right s, _) -> writeFile fout $ pack s
        (Left err, _) -> writeFile fout $ pack $ show err        

-------------------------------------------------------------------------------
--- REPL loop
--- REPL commands:
---   [Expr/Statement/Function]
---   Show [Variable]
---   Pretty [Expr/Statement/Function]
---   Exec [Expr]
---   Define [Function]
------------------------------------------------------------------------------- 

replT :: Repl ()
replT = do
    io $ putStr ">>> "
    io $ hFlush stdout
    line <- io getLine
    (env, last, hist, cnt) <- get
    case newCount cnt line of
        0 -> unless (line == ":q") $
                if line =| ":i" then do
                    content <- io $ readFile $ unpack $ drop 3 line
                    let out = runResult content env
                    case out of
                        (Right "", env') -> do
                            put (env', "", content, 0)
                            replT
                        (Right s, env') -> do
                            io $ putStrLn $ pack s
                            put (env', "", content, 0)
                            replT
                        (Left err, _) -> do
                            io $ putStrLn $ pack $ show (err::Errors)
                            put (env, "", "", 0)
                            replT
                else
                    if line =| ":t" then do
                        io $ prettyPrinter hist
                        put (env, "", hist, 0)
                        replT
                    else case out of
                        (Right "", env') -> do
                            put (env', "", line', 0)
                            replT
                        (Right s, env') -> do
                            io $ putStrLn $ pack s
                            put (env', "", line', 0)
                            replT
                        (Left err, _) -> do
                            io $ putStrLn $ pack $ show (err::Errors)
                            put (env, "", "", 0)
                            replT
                        where
                            line' = concat [last,  " ", line]
                            out = runResult line' env
        _ -> do 
            modify $ appendLine line
            replT

runReplT :: IO ()
runReplT = void $ runStateT replT (M.empty, "", "", 0)
