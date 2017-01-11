{-# LANGUAGE OverloadedStrings #-}

module Comp where

import Control.Applicative
import Data.Functor
import Data.Either
import Control.Monad
import qualified Data.Map as M
import qualified Data.Set as S

import System.IO
import Parser
import Eval
import Printer
import Debug.Trace
import CompExec

translateLang :: [Char] -> [Char] -> IO ()
translateLang input_path output_path = do
  inh <- openFile input_path ReadMode
  ouh <- openFile output_path WriteMode
  executeLoop (M.empty, M.empty, S.empty) "" 0 inh ouh
  hClose inh
  hClose ouh

executeLoop :: CompTable -> [Char] -> Int -> Handle -> Handle -> IO ()
executeLoop cpt hist cnt inh ouh = do
    isEof <- hIsEOF inh
    if isEof
        then return ()
    else do
        line <- hGetLine inh
        if (newCount cnt line) /= 0
            then executeLoop cpt (hist ++ " " ++ line) (newCount cnt line) inh ouh
        else
            case trace (hist ++ " " ++ line) (hist ++ " " ++ line) of
                _ -> case out of
                    "" -> executeLoop cpt' "" 0 inh ouh
                    _ -> do
                        putStrLn line'
                        hPutStr ouh out
                        executeLoop cpt' "" 0 inh ouh
                    where
                        line' = hist ++ " " ++ line
                        (cpt', out) = comp cpt line'