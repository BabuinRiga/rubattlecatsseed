## Stats

* Account surge damage into DPS
* Show surge duration
* Show knockback distance
* Show slow percentage
* Use consistent unit for speed (range per second)
* Figure out how where to find the hard coded values in the game data

## Talents

* Defined in `SkillAcquisition.csv`
* Cat id is (line - 1) (i.e. cat is 0, not 1)
* Which talent is defined by `abilityID_A`, `abilityID_B`, etc, to `abilityID_H`, max 8
* How this is interpreted can be found in `PCoin.java`
* Ability id is defined in `PC_CORRES` in `Data.java`
* If `MAXLv_A` is 0, it means it can only be unlocked. if it's 10, it means max is 10 (when unlocked, it's at lv1 so actual level growth is MAX-1)
* Min and max have 4 pairs. how it's interpreted is probably defined by the ability
* When unlocked at lv1, it starts at min. when it's at max level, it's at max. so growth is `(max - min) / (maxLevel - 1)`
* `limit_A` means if it's a super talent (locked behind lv60)

## Bugs

* If there's a non-existing cat in a gacha, for now we show nothing because
  tracking can't be done due to missing rarity data. However, it'll be useful
  to show the gacha data so we know it's not just an empty gacha but a gacha
  we can't use, and it should be clear what's the missing cat so we have a
  better idea. See:
  https://bc.godfat.org/?seed=1&event=custom&custom=12&details=true
  This should not show empty gacha, but what are there and what's missing.
  Check GachaPool#slots for this.
* Fix guessing 10 rolls link when seeking seed (Can't recall this. Was this for dupe rare?)
* Preserve current queries when swapping language for a non-existing cat when
  showing stats (This is something that it's hard to fix, too. We don't know
  if the user intentionally enter an invalid level, or it's swapping to a cat
  with invalid level. The same goes to Metal Cat. It's capped at level=20,
  and if we swap language or tick some options, we'll send level=20, without
  knowing if it's intentional or not.)
* Can't untick the last owned cat (This is because we can't tell if this is
  visiting the page itself or it's unticking the last cat, because `t` is
  absent in both cases, the URL is the same!)

## Features and utilities

* Localize default customized rate. superfest -> 超極ネコ祭
* Finishing the help page
* Multi-select for finding cats
* Retreat seed
* Client-side seed seeker
* Don't use the hard coded version. Check on the disk and see if there's
  a newer version apk and use that instead.
* Show multiple instances horizontally so we can look at different events
  at the same time! Each can take different seeds.
* Tracking history (by recording rolls we click)
* Use browser timezone offset to calculate local time

## Architecture

* Queue in memcached rather than in-process! Otherwise can't do great
  zero down time restarting. But we might want to find a way to clear
  the queue without clearing the whole memcached.

## Build script, language and APK

* Only show the languages which are built, no need to force all of them

## Seed seeker

* An idea to speed up seeking process. We could pre-process the seeds, and
  create 10 rarity patterns saved in files. Say, starting with seed 1,
  the following rarity will be: R, S, R, R, U, R, and so on, we append the
  seed 1 to the file RSRRUR. We repeat this process for all the seeds, ending
  up with tons of files recoding all the seeds of possible patterns. This
  way, we could use the input rarity pattern to find the corresponding files,
  and only search for those seeds. It could be multiple files because the
  input might not have enough rolls. We should record for 10 rolls pattern,
  say RSRRURSRRU, and RSRRURSRRS (only the last one is different). And the
  input could be just 9 rolls like RSRRURSRR, then we should search for
  both files because they both match the same prefix pattern.
