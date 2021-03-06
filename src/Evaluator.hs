module Evaluator
(
  evl
) where

import Types
import Subr
import Env
import Control.Monad.State
import Control.Monad.Except

evl :: SObj -> Env -> SError (SObj, Env)
evl exp env = do
   (val, (env, _)) <- runStateT (eval exp) (env, [])
   return (val, env)

eval :: SObj -> StateE SEnv SObj
-- self evaluating
eval (SInt x) = return $ SInt x
eval (SBool x) = return $ SBool x
-- variable
eval (SSymbol x) = do
  env <- get
  let val = lookupEnv x env
  case val of
    Nothing -> throwError $ "Unbound variable -- " ++ x
    Just v  -> return v
-- quotation
eval (SList [SSymbol "quote", exp] _) = return exp
-- assignment
eval (SList (SSymbol "set!" : exps) _) = evalSet exps
-- definition
eval (SList (SSymbol "define" : exps) _) = evalDef exps
---- if
eval (SList (SSymbol "if" : exps) _) = evalIf exps
-- cond
eval (SList (SSymbol "cond" : exps) _) = eval (cond2if $ SList (SSymbol "cond" : exps) Nil)
-- lambda
eval (SList (SSymbol "lambda" : exps) _) = do
  (_, r) <- get
  return $ makeLambda exps r
-- begin
eval (SList (SSymbol "begin" : exps) _) = evalSeq exps
-- application
eval (SList (op:args) _) = do
  op' <- eval op
  args' <- evalArgs args
  apply op' args'
eval exp = throwError $ "Unknown expression type -- " ++ show exp

evalArgs :: [SObj] -> StateE SEnv [SObj]
evalArgs exps = mapM eval exps

apply :: SObj -> [SObj] -> StateE SEnv SObj
apply (Primitive x) args = do
  let result = lookupPrimitive (Primitive x)
  case result of
    Nothing -> return Nil
    Just p  -> return (p args)
apply (SLambda params "" body lr) args = do
  when (length params < length args) $ throwError $ "Too many arguments supplied -- " ++ show params ++ ":" ++ show args
  when (length params > length args) $ throwError $ "Too few arguments supplied -- " ++ show params ++ ":" ++ show args
  (env, r) <- get
  put $ (extendEnv params args env, extendRef env lr)
  val <- evalSeq body
  modify (\(env', _) -> (env', r))
  return val
apply (SLambda params p body lr) args = do
  (env, r) <- get
  let n = length params
  let params' = params ++ [p]
  let args'   = take n args ++ [SList (drop n args) Nil]
  when (length params > length args) $ throwError $ "Too few arguments supplied -- " ++ show params ++ ":" ++ show args
  let newEnv = extendEnv params' args' env
  let newRef = extendRef env lr
  put $ (newEnv, newRef)
  val <- evalSeq body
  modify (\(env', _) -> (env', r))
  return val
apply exp args = throwError $ "Invalid application -- " ++ show exp

evalIf :: [SObj] -> StateE SEnv SObj
evalIf [pred, cnsq] = do
  result <- eval pred
  case result of
    SBool False -> return $ SBool False
    _           -> eval cnsq
evalIf [pred, cnsq, alt] = do
  result <- eval pred
  case result of
    SBool False -> eval alt
    _           -> eval cnsq
evalIf exps = throwError $ "Syntax error: if -- " ++ show exps

cond2if :: SObj -> SObj
cond2if (SList (SSymbol "cond" : clauses) _) = expandClause clauses

expandClause :: [SObj] -> SObj
expandClause [] = SBool False
expandClause (SList (SSymbol "else" : clause) _ : _) = seq2begin clause
expandClause (SList (pred:cnsq) _ : clauses) = SList [SSymbol "if", pred, seq2begin cnsq, expandClause clauses] Nil

seq2begin :: [SObj] -> SObj
seq2begin []   = Nil
seq2begin exps = SList (SSymbol "begin" : exps) Nil

makeLambda :: Body -> [Ref] -> SObj
makeLambda (Nil:body) = SLambda [] "" body
makeLambda (SList exps Nil : body) = SLambda (makeParams exps) "" body
makeLambda (SList exps (SSymbol tail) : body) = SLambda (makeParams exps) tail body

makeParams :: [SObj] -> [String]
makeParams exps = map (\(SSymbol name) -> name) exps

evalSeq :: [SObj] -> StateE SEnv SObj
evalSeq exps = foldM (\x y ->  eval y) Nil exps

evalSet :: [SObj] -> StateE SEnv SObj
evalSet [SSymbol var, val] = do
  val' <- eval val
  env <- get
  put $ setVar var val' env
  return $ SSymbol "ok"

evalDef :: [SObj] -> StateE SEnv SObj
evalDef [SSymbol var, SList (SSymbol "lambda" : body) _] = do
  (env, r) <- get
  put $ defineVar var (makeLambda body r) (env, r)
  return $ SSymbol "ok"
evalDef (SList (SSymbol var : params) Nil : body) = do
  (env, r) <- get
  put $ defineVar var (makeLambda (SList params Nil : body) r) (env, r)
  return $ SSymbol "ok"
evalDef (SList (SSymbol var : params) tail : body) = do
  (env, r) <- get
  put $ defineVar var (makeLambda (SList params tail : body) r) (env, r)
  return $ SSymbol "ok"
evalDef [SSymbol var, val] = do
  val' <- eval val
  env <- get
  put $ defineVar var val' env
  return $ SSymbol "ok"
