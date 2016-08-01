module Parser
(
  parse
) where

import Types
import Text.Read

tokenize :: String -> [String]
tokenize = concat . (map separate) . words

separate :: String -> [String]
separate ts =
  t $ span (not . (`elem` ".()'")) ts
    where
      t ("", "") = []
      t (xs, "") = [xs]
      t ("", ys) = [[head ys]] ++ separate (tail ys)
      t (xs, ys) = [xs, [head ys]] ++ separate (tail ys)

parse :: String -> (SObj, [String])
parse str = let tokens = tokenize str in
  case tokens of ("(":ts) -> parseList (SList [] Nil, ts)
                 (t:ts) -> (parseAtom t, ts)

parseList :: (SObj, [String]) -> (SObj, [String])
parseList (exps, ")":ts) = (exps, ts)
parseList (exps, ".":ts) = parseDotList (exps, ts)
parseList (exps, "(":ts) =
  let (sls, restTokens) = parseList (SList [] Nil, ts)
      (SList ls tail, restRestTokens) = parseList (exps, restTokens) in
  (SList (sls : ls) tail, restRestTokens)
parseList (exps, t:ts) =
  let (SList ls tail, restTokens) = parseList (exps, ts) in
  (SList (parseAtom t : ls) tail, restTokens)

parseDotList :: (SObj, [String]) -> (SObj, [String])
parseDotList (SList ls _, "(":ts) =
  let (sls, ")":restTokens) = parseList (SList [] Nil, ts) in
  (SList ls sls, restTokens)
parseDotList (SList ls _, t:")":ts) = (SList ls (parseAtom t), ts)

parseAtom :: String -> SObj
parseAtom token
  | not . (Nothing ==) $ mval = let (Just val) = mval in (SInt val)
  | otherwise = SSymbol token
    where mval = (readMaybe token :: Maybe Int)
