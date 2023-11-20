# frozen_string_literal: true

require_relative 'root'
require_relative 'crystal_ball'
require_relative 'gacha_pool'
require_relative 'gacha'
require_relative 'owned'
require_relative 'aws_auth'
require_relative 'find_cat'
require_relative 'cat'

require 'cgi'
require 'date'
require 'forwardable'

module BattleCatsRolls
  class Route < Struct.new(:request)
    def self.load_ball lang
      CrystalBall.load("#{Root}/build", lang)
    end

    def self.reload_balls force=false
      %w[en tw jp kr].each do |lang|
        if public_send("ball_#{lang}").nil? || force
          public_send("ball_#{lang}=", load_ball(lang))
        end
      end
    end

    singleton_class.attr_accessor :ball_en, :ball_tw, :ball_jp, :ball_kr

    extend Forwardable

    def_delegator :request, :path_info

    def gacha
      @gacha ||= Gacha.new(pool, seed, version)
    end

    def ball
      @ball ||= Route.public_send("ball_#{lang}")
    end

    def cats
      ball.cats
    end

    def seek_source
      @seek_source ||=
        [version, gacha.rare, gacha.supa, gacha.uber, gacha.legend,
         gacha.rare_cats.size, gacha.supa_cats.size,
         gacha.uber_cats.size, gacha.legend_cats.size,
         *request.POST['rolls']].join(' ').squeeze(' ')
    end

    def seek_result key
      "/seek/result/#{key}?" \
        "event=#{event}&lang=#{lang}&version=#{version}&name=#{name}"
    end

    def show_tracks?
      event && seed.nonzero? && gacha.pool.exist?
    end

    def prepare_tracks
      gacha.pool.add_future_ubers(ubers) if ubers > 0

      if last.nonzero?
        gacha.last_roll = Cat.new(id: last)
        gacha.last_both = [gacha.last_roll, nil]
      end

      # Human counts from 1
      cats = 1.upto(count).map do |sequence|
        gacha.roll_both!(sequence)
      end

      if version == '8.6'
        gacha.finish_rerolled_links(cats)
      end

      if last.nonzero?
        gacha.finish_last_roll(cats.dig(0, 0))
      end

      if guaranteed_rolls > 0
        gacha.finish_guaranteed(cats, guaranteed_rolls)
      end

      if pick = request.params_coercion_with_nil('pick', :to_s)
        gacha.finish_picking(cats, pick, guaranteed_rolls)
      end

      found_cats =
        FindCat.search(gacha, find,
          cats: cats, guaranteed: !no_guaranteed, max: FindCat::Max)

      [cats, found_cats]
    end

    def cats_uri **args
      uri(path: "//#{web_host}/cats", **args)
    end

    def help_uri
      uri(path: "//#{web_host}/help")
    end

    def logs_uri
      uri(path: "//#{web_host}/logs")
    end

    def seek_uri
      uri(path: "//#{seek_host}/seek")
    end

    def uri path: "//#{web_host}/", query: {}
      query = cleanup_query(default_query(query))

      if query.empty?
        path
      else
        "#{path}?#{query_string(query)}"
      end
    end

    def seek_host
      SeekHost || request.host_with_port
    end

    def web_host
      WebHost || request.host_with_port
    end

    def tsv_expires_in
      600
    end

    def throttle_ip_expires_in
      600
    end

    def lang
      @lang ||=
        case value = request.params_coercion_with_nil('lang', :to_s)
        when 'tw', 'jp', 'kr'
          value
        else
          'en'
        end
    end

    def ui
      @ui ||=
        case value = request.params_coercion_with_nil('ui', :to_s)
        when 'en', 'tw', 'jp', 'kr'
          value
        else
          '' # Default to whatever lang is
        end
    end

    def ui_lang
      @ui_lang = if ui.empty? then lang else ui end
    end

    def version
      @version ||=
        case value = request.params_coercion_with_nil('version', :to_s)
        when '8.6', '8.5', '8.4'
          value
        else
          default_version
        end
    end

    def default_version
      case lang
      when 'jp'
        '8.6'
      else
        '8.6'
      end
    end

    def name
      @name ||=
        case value = request.params_coercion_with_nil('name', :to_i)
        when 1, 2
          value
        else
          0
        end
    end

    def theme
      @theme ||=
        case value = request.params_coercion('theme', :to_s)
        when 'mkweb'
          value
        else
          ''
        end
    end

    MaxSeed = 2 ** 32

    # This is the seed from the seed input field
    def seed
      @seed ||= request.params_coercion('seed', :to_i).abs % MaxSeed
    end

    def event
      @event ||= request.params_coercion_with_nil('event', :to_s) ||
        current_event
    end

    def upcoming_events
      @upcoming_events ||=
        [*grouped_events[:ongoing], *grouped_events[:upcoming]] || []
    end

    def past_events
      @past_events ||= grouped_events[:past] || []
    end

    def custom
      @custom ||= request.params_coercion_with_nil('custom', :to_i) ||
        ball.gacha.each_key.reverse_each.first.to_i
    end

    def rate
      @rate ||= request.params_coercion('rate', :to_s)
    end

    def c_rare
      @c_rare ||= get_rate('c_rare', 0)
    end

    def c_supa
      @c_supa ||= get_rate('c_supa', 1)
    end

    def c_uber
      @c_uber ||= get_rate('c_uber', 2)
    end

    def count
      @count ||=
        [
          1,
          [
            request.params_coercion_with_nil('count', :to_i) || 100,
            FindCat::Max
          ].min
        ].max
    end

    def find
      @find ||= request.params_coercion('find', :to_i)
    end

    def last
      @last ||= request.params_coercion('last', :to_i)
    end

    def no_guaranteed
      return @no_guaranteed if instance_variable_defined?(:@no_guaranteed)

      @no_guaranteed = request.params_coercion_true_or_nil('no_guaranteed')
    end

    def force_guaranteed
      @force_guaranteed ||= request.params_coercion('force_guaranteed', :to_i)
    end

    def guaranteed_rolls
      @guaranteed_rolls ||=
        if force_guaranteed.zero?
          gacha.pool.guaranteed_rolls
        else
          force_guaranteed
        end
    end

    def ubers
      @ubers ||= request.params_coercion('ubers', :to_i)
    end

    def details
      return @details if instance_variable_defined?(:@details)

      @details = request.params_coercion_true_or_nil('details')
    end

    def o
      @o ||=
        if owned.any?
          Owned.encode(owned)
        else
          ''
        end
    end

    def owned
      @owned ||=
        if ticked.any?
          ticked
        elsif (result = Owned.decode(request.params_coercion('o', :to_s))).any?
          result
        else
          Owned.decode_old(request.params_coercion('owned', :to_s))
        end.sort.uniq
    end

    def ticked
      @ticked ||= Array(request.params['t']).map(&:to_i).sort.uniq
    end

    def level
      @level ||= request.params_coercion_with_nil('level', :to_i)&.abs ||
        default_level
    end

    def default_level
      @default_level ||= 30
    end

    def hide_wave
      return @hide_wave if instance_variable_defined?(:@hide_wave)

      @hide_wave = request.params_coercion_true_or_nil('hide_wave')
    end

    def sum_no_wave
      return @sum_no_wave if instance_variable_defined?(:@sum_no_wave)

      @sum_no_wave = request.params_coercion_true_or_nil('sum_no_wave')
    end

    def dps_no_critical
      return @dps_no_critical if instance_variable_defined?(:@dps_no_critical)

      @dps_no_critical = request.params_coercion_true_or_nil('dps_no_critical')
    end

    def uri_to_roll cat
      uri(query: {seed: cat.slot_fruit.seed, last: cat.id})
    end

    def uri_to_cat cat
      uri(path: "//#{web_host}/cats/#{cat.id}")
    end

    def event_url *args, **options
      AwsAuth.event_url(lang, *args, base_uri: event_base_uri, **options)
    end

    private

    def pool
      @pool ||=
        case event
        when 'custom'
          event_data = {
            'id' => custom,
            'rare' => c_rare,
            'supa' => c_supa,
            'uber' => c_uber
          }

          GachaPool.new(ball, event_data: event_data)
        else
          GachaPool.new(ball, event_name: event)
        end
    end

    def current_event
      @current_event ||=
        upcoming_events.find{ |_, info| info['platinum'].nil? }&.first
    end

    def grouped_events
      @grouped_events ||= begin
        today = Date.today

        events = all_events.group_by do |_, value|
          if today <= value['start_on']
            :upcoming
          elsif today <= value['end_on']
            :ongoing
          else
            :past
          end
        end

        if events[:ongoing]
          # keep each types of platinum just once for ongoing events
          # uniq will keep the first occurrence so we reverse and reverse
          events[:ongoing] = events[:ongoing].reverse_each.uniq do |id, event|
            event['platinum'] || id
          end.reverse!
        end

        events
      end
    end

    def all_events
      @all_events ||= ball.events
    end

    def get_rate name, index
      int = request.params_coercion_with_nil(name, :to_i)&.abs ||
        CrystalBall.predefined_rates.dig(rate, :rate, index) ||
        predict_rate(index).to_i

      [int, 10000].min
    end

    def predict_rate index
      # We only want to predict if it's specified, especially because
      # for custom rates we don't want to predict to interfere it.
      # Keep in mind that for custom rates the rate == ''
      if rate == 'predicted'
        CrystalBall.predefined_rates.dig(
          # We also want to give something if no prediction can be made,
          # otherwise we won't be able to switch to custom rates when
          # we can't make prediction. In that case, just guess it with
          # the most common rates, regular. To verify this, check:
          # https://bc.godfat.org/?seed=1&event=custom&custom=2&rate=predicted
          # And switch to "Customize..." under "Predicted".
          ball.gacha.dig(custom, 'rate') || 'regular', :rate, index)
      end
    end

    def event_base_uri
      "#{request.scheme}://#{seek_host}/seek"
    end

    def query_string query
      query.map do |key, value|
        "#{CGI.escape(key.to_s)}=#{CGI.escape(value.to_s)}"
      end.join('&')
    end

    def default_query query={}
      ret = %i[
        seed last event custom rate c_rare c_supa c_uber level lang ui version
        name theme count find no_guaranteed force_guaranteed ubers details
        hide_wave sum_no_wave dps_no_critical
        o
      ].inject({}) do |result, key|
        result[key] = query[key] || __send__(key)
        result
      end

      if ret[:rate] == '' && %i[c_rare c_supa c_uber].all?{ |c| ret[c].zero? }
        # When we first go into customization, all of them are in base values,
        # and we want to use the predicted rates in this case. However,
        # it can also be possible that all rates are zero, yet we have
        # already picked a specific rate. For example, this can happen if
        # we're checking a gacha having non-existing cats. In this case,
        # we don't want to change the rate already picked!
        # Try this and pick a different rate:
        # https://bc.godfat.org/?seed=1&event=custom&custom=2&rate=predicted
        # We want it to be preserved and we should be able to pick freely.
        ret[:rate] = 'predicted'
      end

      ret
    end

    def cleanup_query query
      query.compact.select do |key, value|
        if (key == :seed && value == 0) ||
           (key == :lang && value == 'en') ||
           (key == :ui && value == '') ||
           (key == :version && value == default_version) ||
           (key == :name && value == 0) ||
           (key == :theme && value == '') ||
           (key == :count && value == 100) ||
           (key == :find && value == 0) ||
           (key == :last && value == 0) ||
           (key == :force_guaranteed && value == 0) ||
           (key == :ubers && value == 0) ||
           (key == :level && value == default_level) ||
           (key == :o && value == '') ||
           (key == :event && value == current_event) ||
           (query[:event] != 'custom' &&
              (key == :custom || key == :rate ||
               key == :c_rare || key == :c_supa || key == :c_uber)) ||
           (query[:event] == 'custom' &&
              (
                (key == :rate && value == '') ||
                (query[:rate] != '' &&
                  (key == :c_rare || key == :c_supa || key == :c_uber))
              ))
          false
        else
          true
        end
      end
    end
  end
end
