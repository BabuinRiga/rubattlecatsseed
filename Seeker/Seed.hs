
module Seed(Seed(Seed), fromSeed, advanceSeed, matchRoll) where

import Data.Bits (xor, shiftL, shiftR)
import Data.Word (Word32)

import Roll

newtype Seed = Seed { fromSeed :: Word32 } deriving (Show, Eq)

advanceSeed :: Seed -> Seed
advanceSeed =
  Seed .
  (step (`shiftL` 15)) .
  (step (`shiftR` 17)) .
  (step (`shiftL` 13)) .
  fromSeed

matchRoll :: Seed -> Roll -> Bool
matchRoll seed (Roll rarity@(Rarity _ _ count) slot) =
  matchRarity seed rarity && matchSlot (advanceSeed seed) count slot

matchRarity :: Seed -> Rarity -> Bool
matchRarity seed (Rarity begin end _) =
  score >= begin && score < end where
  score = (seedValue seed) `mod` scoreBase

matchSlot :: Seed -> Word32 -> Slot -> Bool
matchSlot seed count (Slot n) =
  slot == n where
  slot = (seedValue seed) `mod` count

step :: (Word32 -> Word32) -> Word32 -> Word32
step direction seed = seed `xor` (direction seed)

seedValue :: Seed -> Word32
seedValue (Seed seed) = min seed (alternativeSeed seed)

alternativeSeed :: Word32 -> Word32
alternativeSeed seed = 0xffffffff - alt + 1 where
  alt = if seed < 0x80000000 then 0x80000000 - seed else seed

------------------------------------------------

-- seed = Seed 1745107336
-- tests =
--   [ advanceSeed seed == Seed 2009320978
--   , matchRarity seed (Rarity 7000 9000 1)
--   , not $ matchRarity seed (Rarity 0 7000 1)
--   , matchSlot seed 10 (Slot 6)
--   , not $ matchSlot seed 10 (Slot 7)
--   , matchRoll seed (Roll (Rarity 7000 9000 100) (Slot 78))
--   ]

-- test = foldr (&&) True tests
