# frozen_string_literal: true

require 'stringio'

module BattleCatsRolls
  class CatsBuilder < Struct.new(:provider)
    def cats
      @cats ||= Hash[build_cats.sort]
    end

    def gacha
      @gacha ||= store_gacha(provider.gacha)
    end

    def cat_data
      @cat_data ||= store_cat_data(provider.res)
    end

    def cat_stats
      @cat_stats ||= store_cat_stats(provider.units)
    end

    def attack_animation
      @attack_animation ||= store_attack_animation(provider.attack_maanims)
    end

    def unitbuy
      @unitbuy ||= store_unitbuy(provider.unitbuy)
    end

    def unitlevel
      @unitlevel ||= store_unitlevel(provider.unitlevel)
    end

    def == rhs
      cats == rhs.cats && gacha == rhs.gacha
    end

    private

    def build_cats
      ids = cat_data.keys
      cat_data.merge(unitbuy.slice(*ids)) do |id, data, buy|
        data.merge(buy)
      end.merge(unitlevel.slice(*ids)) do |id, data, level|
        growth = level.take((data['max_level'] / 10.0).ceil).map(&:to_i)
        data['growth'] = growth
        data
      end
    end

    def store_gacha data
      data.each_line.with_index.inject({}) do |result, (line, index)|
        next result unless line =~ /\A\d+/

        slots = line.split(',')
        id = slots.pop until slots.empty? || id&.start_with?('-1')
        result[index] = {'cats' => slots.map { |s| Integer(s) + 1 }}
        result
      end
    end

    def store_unitbuy data
      data.each_line.with_index.inject({}) do |result, (line, index)|
        id = index + 1
        row = line.split(',')
        result[id] = {
          'rarity' => Integer(row[13]),
          'max_level' => Integer(row[50]) + Integer(row[51])
        }
        result
      end
    end

    def store_unitlevel data
      data.each_line.with_index.inject({}) do |result, (line, index)|
        id = index + 1
        result[id] = line.split(',')
        result
      end
    end

    def store_cat_data res_local
      res_local.inject({}) do |result, (filename, data)|
        separator_char =
          if filename.end_with?('_ja.csv')
            ','
          else
            '|'
          end
        separator = Regexp.escape(separator_char)
        # String#strip doesn't remove \u00a0
        strip = lambda do |str|
          str.sub(/\A\p{whitespace}+/, '').sub(/\p{whitespace}+\z/, '')
        end

        names = data.scan(/^(?:[^#{separator}]+)/).uniq.
          map(&strip).delete_if(&:empty?)
        descs = data.scan(/(?=#{separator}).+$/).
          map{ |s| strip[s.tr(separator_char, "\n").squeeze(' ')] }.
          delete_if(&:empty?)

        if names.any?
          id = Integer(filename[/\d+/])

          result[id] = {
            'name' => names,
            'desc' => descs.first(names.size),
            'stat' => cat_stats[id].first(names.size)
          }
        end

        result
      end.compact
    end

    def store_cat_stats units
      result = units.transform_values do |csv|
        csv.each_line.filter_map do |line|
          fields = stat_fields
          values = line.split(',').values_at(*fields.values)

          if values.any?
            stat = Hash[fields.each_key.map(&:to_s).zip(values)].
              delete_if do |name, value|
                !/\A\-?\d+/.match?(value) || value.start_with?('0')
              end.transform_values(&:to_i)

            if stat['conjure']
              stat['conjure'] += 1
              stat.delete('conjure') if stat['conjure'] == 0
            end

            stat
          end
        end
      end

      attach_attack_duration(result)
    end

    def attach_attack_duration(result)
      result.each do |id, cat_stats|
        cat_stats.each.with_index do |stat, index|
          if attack_duration = attack_animation.dig(id, index)
            stat.merge!('attack_duration' => attack_duration)
          end
        end
      end
    end

    def stat_fields
      @stat_fields ||= {
        health: 0, knockbacks: 1, speed: 2, cost: 6, production_cooldown: 7,
        attack_cooldown: 4, range: 5, width: 9, area_effect: 12,
        damage_0: 3, long_range_0: 44, long_range_offset_0: 45,
        attack_time_0: 13, trigger_effects_0: 63,
        damage_1: 59, long_range_1: 100, long_range_offset_1: 101,
        attack_time_1: 61, trigger_effects_1: 64,
        damage_2: 60, long_range_2: 103, long_range_offset_2: 104,
        attack_time_2: 62, trigger_effects_2: 65,
        against_only: 32, against_red: 10,
        against_float: 16, against_black: 17, against_metal: 18,
        against_white: 19, against_angel: 20, against_alien: 21,
        against_relic: 78, against_aku: 96,
        against_zombie: 22, zombie_killer: 52, soul_strike: 98,
        break_barrier_chance: 70, break_shield_chance: 95,
        colossus_killer: 97, behemoth_killer: 105, sage_killer: 111,
        behemoth_dodge_chance: 106, behemoth_dodge_duration: 107,
        witch_killer: 53, eva_angel_killer: 77,
        strong: 23, resistant: 29, massive_damage: 30,
        insane_resistant: 80, insane_damage: 81,
        knockback_chance: 24, freeze_chance: 25, freeze_duration: 26,
        slow_chance: 27, slow_duration: 28,
        weaken_chance: 37, weaken_duration: 38, weaken_multiplier: 39,
        curse_chance: 92, curse_duration: 93,
        critical_chance: 31,
        savage_blow_chance: 82, savage_blow_modifier: 83,
        wave_chance: 35, wave_level: 36, wave_mini: 94,
        surge_chance: 86, surge_level: 89, surge_mini: 108,
        surge_range: 87, surge_range_offset: 88, counter_surge: 109,
        survive_chance: 42, dodge_chance: 84, dodge_duration: 85,
        loot_money: 33, base_destroyer: 34, metal: 43, suicide: 58,
        strengthen_threshold: 40, strengthen_modifier: 41,
        conjure: 110,
        immune_bosswave: 56,
        immune_wave: 46, block_wave: 47, immune_surge: 91,
        immune_knockback: 48, immune_freeze: 49, immune_slow: 50,
        immune_weaken: 51, immune_warp: 75, immune_curse: 79,
        immune_toxic: 90,
        # unused
        warp_chance: 71, warp_duration: 72,
        warp_range: 73, warp_range_offset: 74,
      }
    end

    def store_attack_animation attack_maanims
      attack_maanims.transform_values do |maanims|
        maanims.map(&method(:calculate_duration))
      end
    end

    def calculate_duration maanim
      return unless maanim

      stream = StringIO.new(maanim)
      stream.readline
      stream.readline
      stream.readline.to_i.times.filter_map do
        times = read_int(stream, 2).abs
        size = stream.readline.to_i

        next if size <= 0

        first_frame = read_int(stream)
        (size - 2).times{ stream.readline }
        last_frame = read_int(stream) if size > 1

        min, max = [first_frame, last_frame || first_frame].sort

        [max - min, times, min]
      end.inject(0) do |result, (delta, times, offset)|
        value = delta * times

        if offset < 0
          [result, value]
        else
          [result, value + offset]
        end.max
      end
    end

    def read_int stream, index=0
      stream.readline.split(',')[index].to_i
    end
  end
end
