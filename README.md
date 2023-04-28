# Battle Cats Rolls <https://bc.godfat.org/>

## How to install the Ruby server:

    gem install bundler
    bundle install

And pick one:

* Set up memcached and run `gem install dalli`
* Use LRU cache so run `gem install lru_redux`

## How to build the Haskell seed seeker:

First install [GHC](https://www.haskell.org/ghc/), then:

    ./Seeker/bin/build.sh

This should build the seed seeker at: `Seeker/Seeker`, which will be used
by the Ruby server.

## How to run the server locally:

    ./bin/server

## Production with nginx, systemd and socket activation:

### Setup nginx

Take `config/nginx.conf` as an example to set up nginx, and start it with
systemd:

    sudo systemctl enable nginx
    sudo systemctl start nginx

### Installation for systemd

Tweak the paths in `config/battlecatsrolls@.service` accordingly and run:

    sudo ./bin/install

### Read logs

Read the whole logs:

    ./bin/log

Watch the logs in realtime:

    ./bin/log -f

### Restart with zero down time

This will start a temporary server taking requests while shutting down
the old server. When the old server is properly restarted, the temporary
server will be shut down.

    sudo ./bin/restart-zero-down

### Uninstallation for systemd

    sudo ./bin/uninstall

## How to populate data:

Populate everything:

    env (cat .env) ruby bin/build.rb

Populate BCEN data:

    env (cat .env) ruby bin/build.rb en

Populate BCTW data:

    env (cat .env) ruby bin/build.rb tw

Populate BCJP data:

    env (cat .env) ruby bin/build.rb jp

Populate BCKR data:

    env (cat .env) ruby bin/build.rb kr

## Thanks:

### Tracking discovery for 7.2+

* [Seed Tracking TBC 7.3 Public Release](https://old.reddit.com/r/BattleCatsCheats/comments/9jvdcg/seed_tracking_tbc_73_public_release/)

### The spreadsheet 2.0

* [[Cheating] Rare Ticket Forecasting Spreadsheet v2.0](https://old.reddit.com/r/battlecats/comments/8mhun4/cheating_rare_ticket_forecasting_spreadsheet_v20/)

### Finding my seed and providing information

* [[Cheating] Seed calculation here!](https://old.reddit.com/r/battlecats/comments/8cbs2i/cheating_seed_calculation_here/e0r8l9v/)

### How it works

* [[Tutorial] [Cheating] (Almost) Everything you could possibly want to know about the gacha system in v5.10.](https://old.reddit.com/r/battlecats/comments/64geym/tutorial_cheating_almost_everything_you_could/)

### Decrypting the app data

* [Is there anyone able to access BC files? Your help is needed!](https://old.reddit.com/r/battlecats/comments/41e4l1/is_there_anyone_able_to_access_bc_files_your_help/cz3npr2)
* [Unit upgrade cost spreadsheet?](https://old.reddit.com/r/battlecats/comments/3em0bw/unit_upgrade_cost_spreadsheet/cthqo3f)
* [FX File Explorer](https://play.google.com/store/apps/details?id=nextapp.fx)

### Event data

* [[BCEN] New Event Data - Last Half of October 2017](https://old.reddit.com/r/battlecats/comments/75w399/bcen_new_event_data_last_half_of_october_2017/dostwfb)
* [[BCEN] New Event Data - First Half of July 2018](https://old.reddit.com/r/battlecats/comments/8vikts/bcen_new_event_data_first_half_of_july_2018/e1sc33v/)
* [[Cheating] Rare Ticket Forecasting - Seed Request Thread](https://www.reddit.com/r/battlecats/comments/7t2dlb/cheating_rare_ticket_forecasting_seed_request/dtb3q0w/)
* [How to retrieve and decipher Battle Cats event data](https://old.reddit.com/r/battlecats/comments/3tf03s/how_to_retrieve_and_decipher_battle_cats_event/)

### Other references

* [[Tutorial] [Cheating] (Almost) Rare Ticket draw Forcasting Spreadsheet](https://www.reddit.com/r/battlecats/comments/7llv80/tutorial_cheating_almost_rare_ticket_draw/)
* [[Cheating] Seed finder and draw strategy manager](https://old.reddit.com/r/battlecats/comments/8cbuyw/cheating_seed_finder_and_draw_strategy_manager/)
* [[BCEN] All cat data for Battle Cats 7.2](https://old.reddit.com/r/battlecats/comments/96ogif/bcen_all_cat_data_for_battle_cats_72/)
  * [unit&lt;num&gt;.csv columns](https://pastebin.com/JrCTPnUV)

## CONTRIBUTORS:

* Lin Jen-Shin (@godfat)
* forgothowtoreddid
* MandarinSmell
* clam
* 占庭 盧 (@lzt00275)

## LICENSE:

Apache License 2.0

Copyright (c) 2018-2023, Lin Jen-Shin (godfat)

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

<http://www.apache.org/licenses/LICENSE-2.0>

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
