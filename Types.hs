module Types
(
  SObj(..),
  Env,
  Frame
) where

import Data.List

data SObj = SInt Int |
            SSymbol String |
            SList [SObj] SObj |
            SBool Bool |
            SLambda [String] String [SObj] Env |
            Nil |
            Primitive String
            deriving Eq

type Env = [Frame]
type Frame = ([String], [SObj])

instance Show SObj where
  show Nil = "nil"
  show (SSymbol x) = x
  show (SInt x) = show x
  show (SBool True) = "#t"
  show (SBool False) = "#f"
  show (SLambda ps p _ _) = "<closure " ++ show (ps ++ [p]) ++ ">"
  show (Primitive x) = "<subr " ++ x ++ " >"
  show (SList ((SSymbol "quote"):xs) Nil) = showElements xs
  show (SList xs Nil) = "(" ++ (showElements xs) ++ ")"
  show (SList xs obj) = "(" ++ (showElements xs) ++ " . " ++ show obj ++ ")"

showElements :: [SObj] -> String
showElements = (intercalate " ") . (map show)
