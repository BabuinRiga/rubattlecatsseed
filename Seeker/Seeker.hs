
module Seeker
  ( SeekResult
  , SeekStep
  , buildSeekStep
  , seekRange
  , minSeed
  , maxSeed) where

import Seed
import Roll
import Control.Applicative ((<|>))

type SeekResult = (Seed, Seed)
type SeekStep = (SeedValue, [Pick])

buildSeekStep :: Source -> SeekStep
buildSeekStep source = (seedValue, picks) where
  picks = sourcePicks source
  seedValue = case sourceVersion source of
    "8.4" -> minSeedValue
    "8.5" -> fromSeed

seekRange :: SeekStep -> Seed -> Seed -> Maybe SeekResult
seekRange step startSeed@(Seed value) endSeed =
  if value == 0 then
    seekNext
  else if startSeed == endSeed then
    found seek
  else
    found seek <|> seekNext
  where
    seek = matchSeed step (advanceSeed startSeed)
    nextSeed = Seed (succ value)
    seekNext = seekRange step nextSeed endSeed

    found Nothing = Nothing
    found (Just currentSeed) = Just (startSeed, currentSeed)

matchSeed :: SeekStep -> Seed -> Maybe Seed
matchSeed (seedValue, []) seed = Nothing
-- We want the seed from last roll, not the advanced one
matchSeed (seedValue, [lastPick]) seed = matchPick seed seedValue lastPick
matchSeed (seedValue, pick:nextPicks) seed = do
  lastSeed <- matchPick seed seedValue pick
  matchSeed (seedValue, nextPicks) (advanceSeed lastSeed)

matchPick :: Seed -> SeedValue -> Pick -> Maybe Seed
matchPick = matchRoll

minSeed :: Seed
minSeed = Seed minBound

maxSeed :: Seed
maxSeed = Seed maxBound

------------------------------------------------

-- seedA = Seed (-448772753)
-- seedB = Seed 1004458905
-- rare = Rarity { begin = 0, end = 7000, count = 23 }
-- sr = Rarity { begin = 7000, end = 9500, count = 16 }
-- uber = Rarity { begin = 9500, end = 10000, count = 4 }
-- rollsA =
--   [ Roll rare (Slot 7) -- Tin Cat
--   , Roll rare (Slot 10) -- Swordsman Cat
--   , Roll rare (Slot 18) -- Viking Cat
--   , Roll rare (Slot 7)
--   , Roll rare (Slot 3) -- Onmyoji Cat
--   , Roll rare (Slot 17) -- Pirate Cat
--   , Roll rare (Slot 0) -- Rover Cat
--   , Roll rare (Slot 12) -- Witch Cat
--   , Roll rare (Slot 17)
--   , Roll sr (Slot 2) -- Surfer Cat
--   ]
-- rollsB =
--   [ Roll sr (Slot 15) -- Bodhisattva Cat
--   , Roll rare (Slot 10) -- Swordsman Cat
--   , Roll rare (Slot 20) -- Salon Cat
--   , Roll rare (Slot 22) -- Pogo Cat
--   , Roll sr (Slot 1) -- Vaulter Cat
--   , Roll rare (Slot 5) -- Mer-Cat
--   , Roll sr (Slot 2) -- Surfer Cat
--   , Roll rare (Slot 16) -- Thief Cat
--   , Roll uber (Slot 2) -- Mizli
--   , Roll sr (Slot 10) -- Swimmer Cat
--   ]

-- tests = -- Event 2018-07-12_276
--   [ matchSeed (Just seedA) rollsA -- -448772753 -> -811982442
--   , matchSeed (Just seedB) rollsB -- 1004458905 -> -428465086
--   ]
