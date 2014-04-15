module Succinct.Internal.Delta
  ( Delta(..)
  , minima
  , bool
  , bits
  , byte
  , e8, d8, n8
  ) where

import Data.Bits
import Data.Int
import Data.Semigroup
import Data.Vector.Unboxed.Base as UB
import Data.Vector.Unboxed as U
import Data.Vector.Primitive as P
import Data.Word

-- | Δ-Range-Min
--
-- This provides a semigroup-based variant of the basic aggregation used
-- in <http://arxiv.org/pdf/1111.5220.pdf Grossi and Ottaviano's Range-Min tree>,
-- which is in turn a simplification of a
-- <https://www.siam.org/proceedings/alenex/2010/alx10_009_arroyuelod.pdf Range Min-Max> tree
data Delta = Delta
  { excess  :: {-# UNPACK #-} !Int -- even when # bits is even, odd when it is odd
  , delta   :: {-# UNPACK #-} !Int -- minima = excess - delta
  , nminima :: {-# UNPACK #-} !Int -- # of minima
  } deriving Show

instance Semigroup Delta where
  -- Delta e d n <> Delta e' d' n' = case compare d (d' - e') of
  Delta e d n <> Delta e' d' n' = case compare d' (d + e) of
    LT -> Delta (e + e') d'      n'
    EQ -> Delta (e + e') (d + e) (n + n')
    GT -> Delta (e + e') (d + e) n

minima :: Delta -> Int
minima (Delta e d _) = e - d

bool :: Bool -> Delta
bool True  = Delta 1 1 1
bool False = Delta (-1) 0 1

bits :: FiniteBits a => a -> Delta
bits w = Prelude.foldr1 (<>) $ fmap (bool . testBit w) [0..finiteBitSize w - 1]

e8s, d8s, n8s :: P.Vector Int8
(e8s, d8s, n8s) = case U.fromListN 256 $ fmap go [0..255 :: Word8] of
  V_3 _ (V_Int8 es) (V_Int8 ds) (V_Int8 ns) -> (es, ds, ns)
 where
  go i = case bits i of
    Delta e m n -> (fromIntegral e, fromIntegral m, fromIntegral n)

-- | Look up the 'Delta' for a Word8 via LUTs
byte :: Word8 -> Delta
byte w = Delta (e8 w) (d8 w) (n8 w)

e8 :: Word8 -> Int
e8 w = fromIntegral $ P.unsafeIndex e8s (fromIntegral w)

d8 :: Word8 -> Int
d8 w = fromIntegral $ P.unsafeIndex d8s (fromIntegral w)

n8 :: Word8 -> Int
n8 w = fromIntegral $ P.unsafeIndex n8s (fromIntegral w)