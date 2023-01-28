# frozen_string_literal: true

require_relative 'cat'
require_relative 'find_cat'
require_relative 'gacha'
require_relative 'owned'

require 'tilt'

require 'cgi'
require 'erb'
require 'forwardable'

module BattleCatsRolls
  class View < Struct.new(:route, :arg)
    extend Forwardable

    def_delegator :route, :gacha

    def render name
      erb(:layout){ erb(name) }
    end

    private

    def each_ball_cat
      arg[:cats].reverse_each do |rarity, data|
        yield(rarity, data.map{ |id, info| Cat.new(id: id, info: info) })
      end
    end

    def each_ab_cat
      arg[:cats].inject(nil) do |prev_b, ab|
        yield(prev_b, ab)

        ab.last
      end
    end

    def color_label cat, type, rerolled
      return unless cat

      if type == :cat || !(rerolled || cat.rerolled)
        picked = cat.picked_label
        cursor = :pick
      else
        cursor = :navigate
      end

      "#{cursor} #{color_rarity(cat)} #{picked}".chomp(' ')
    end

    def color_rarity cat
      case rarity_label = cat.rarity_label
      when :legend
        :legend
      else
        case cat.id
        when route.find
          :found
        when *route.owned
          :owned
        when *FindCat.exclusives
          :exclusive
        else
          rarity_label
        end
      end
    end

    def color_guaranteed cat
      case cat.guaranteed.id
      when route.find
        :found
      when *FindCat.exclusives
        :exclusive
      when Integer
        :rare
      end
    end

    def number_td cat, other_cat
      rowspan = 2 + [cat.rerolled, other_cat&.rerolled].compact.size

      <<~HTML
        <td rowspan="#{rowspan}" id="N#{cat.number}">#{cat.number}</td>
      HTML
    end

    def score_tds cat, other_cat
      rowspan =
        if other_cat&.rerolled
          2
        else
          1
        end

      content =
        if show_details
          "#{cat.score}, #{cat.slot}"
        else
          "\u00A0"
        end

      single = td(cat, :score, rowspan: rowspan, content: content)
      guaranteed = td(cat.guaranteed, :score, rowspan: rowspan,
        rerolled: cat.rerolled&.guaranteed)

      "#{single}\n#{guaranteed}"
    end

    def cat_tds cat, type=:roll
      single = td_to_cat(cat, type)
      guaranteed = td_to_cat(cat.guaranteed, :next)

      "#{single}\n#{guaranteed}"
    end

    def td_to_cat cat, link_type
      td(cat, :cat, content: cat && __send__("link_to_#{link_type}", cat))
    end

    def td cat, type, rowspan: 1, content: nil, rerolled: nil
      <<~HTML
        <td
          rowspan="#{rowspan}"
          class="#{type} #{color_label(cat, type, rerolled)}"
          #{onclick_pick(cat, type)}>
          #{content}
        </td>
      HTML
    end

    def link_to_roll cat
      name = h cat.pick_name(route.name)
      title = h cat.pick_title(route.name)

      if cat.slot_fruit
        %Q{<a href="#{h route.uri_to_roll(cat)}" title="#{title}">#{name}</a>}
      else
        %Q{<span title="#{title}">#{name}</span>}
      end +
        if cat.id > 0
          %Q{<a href="#{h uri_to_cat_db(cat)}">🐾</a>}
        else
          ''
        end
    end

    def link_to_next cat
      cat_link = link_to_roll(cat)
      next_cat = cat.next

      case next_cat&.track
      when 0
        "&lt;- #{next_cat.number} #{cat_link}"
      when 1
        "#{cat_link} -&gt; #{next_cat.number}"
      when nil
        "&lt;?&gt; #{cat_link}"
      else
        raise "Unknown track: #{next_cat.track.inspect}"
      end
    end

    def pick_option cats
      cats.map.with_index do |cat, slot|
        <<~HTML
          <option value="#{cat.rarity} #{slot}">#{slot} #{cat_name(cat)}</option>
        HTML
      end.join
    end

    def selected_lang lang_name
      'selected="selected"' if route.lang == lang_name
    end

    def selected_version version_name
      'selected="selected"' if route.version == version_name
    end

    def selected_name name_name
      'selected="selected"' if route.name == name_name
    end

    def selected_theme theme_name
      'selected="selected"' if route.theme == theme_name
    end

    def selected_current_event event_name
      'selected="selected"' if route.event == event_name
    end

    def selected_custom_gacha gacha_id
      'selected="selected"' if route.custom == gacha_id
    end

    def selected_rate rate
      'selected="selected"' if route.rate == rate
    end

    def selected_find cat
      'selected="selected"' if route.find == cat.id
    end

    def selected_last cat
      'selected="selected"' if route.last == cat.id
    end

    def checked_no_guaranteed
      'checked="checked"' if route.no_guaranteed
    end

    def selected_force_guaranteed n
      'selected="selected"' if route.force_guaranteed == n
    end

    def selected_ubers n
      'selected="selected"' if route.ubers == n
    end

    def checked_details
      'checked="checked"' if route.details
    end

    def checked_cat cat
      ticked = route.ticked

      if ticked.empty?
        'checked="checked"' if route.owned.member?(cat.id)
      elsif ticked.member?(cat.id)
        'checked="checked"'
      end
    end

    def show_details
      arg&.dig(:details) && route.details
    end

    def hidden_inputs *input_names
      input_names.map do |name|
        <<~HTML
          <input type="hidden" name="#{name}" value="#{route.public_send(name)}">
        HTML
      end.join("\n")
    end

    def show_event info
      h "#{info['start_on']} ~ #{info['end_on']}: #{info['name']}"
    end

    def show_gacha_slots cats
      cats.map.with_index do |cat, i|
        %Q{#{i} <a href="#{uri_to_cat_db(cat)}">#{cat_name(cat)}</a>}
      end.join(', ')
    end

    def cat_name cat
      h cat.pick_name(route.name)
    end

    def stat_time frames
      fps = 30.0
      title = "#{frames} frames"
      %Q{<span title="#{title}">#{(frames / fps).round(2)}s</span>}
    end

    def h str
      CGI.escape_html(str)
    end

    def made10rolls? seeds
      gacha = Gacha.new(
        route.gacha.pool, seeds.first, route.version)
      gacha.send(:advance_seed!) # Account offset
      9.times.inject(nil){ |last| gacha.roll! } # Only 9 rolls left

      if gacha.seed == seeds.last
        gacha.send(:advance_seed!) # Account for guaranteed roll
        gacha.seed
      end
    end

    def header n, name
      id = name.to_s.downcase.gsub(/\W+/, '-')

      <<~HTML
        <a href="##{id}">⚓</a> <h#{n} id="#{id}">#{name}</h#{n}>
      HTML
    end

    def seed_tds fruit, cat
      return unless show_details

      rowspan =
        if cat&.rerolled
          2
        else
          1
        end

      value =
        if fruit.seed == fruit.value
          '-'
        else
          fruit.value
        end

      <<~HTML
        <td rowspan="#{rowspan}">#{fruit.seed}</td>
        <td rowspan="#{rowspan}">#{value}</td>
      HTML
    end

    def onclick_pick cat, type
      return unless cat && route.path_info == '/'

      number =
        case type
        when :cat
          cat.number
        else
          "#{cat.number}X"
        end

      %Q{onclick="pick('#{number}')"}
    end

    def uri_to_cat_db cat
      "https://battlecats-db.com/unit/#{sprintf('%03d', cat.id)}.html"
    end

    def uri_to_own_all_cats
      route.cats_uri(query: {o:
        Owned.encode(arg[:cats].values.flat_map{ |data| data.map(&:first) })})
    end

    def uri_to_drop_all_cats
      route.cats_uri(query: {o: ''})
    end

    def erb name, nested_arg=nil, &block
      context =
        if nested_arg
          self.class.new(route, arg&.merge(nested_arg) || nested_arg)
        else
          self
        end

      self.class.template(name).render(context, &block)
    end

    def self.template name
      (@template ||= {})[name.to_s] ||=
        Tilt.new("#{__dir__}/view/#{name}.erb")
    end

    def self.warmup
      prefix = Regexp.escape("#{__dir__}/view/")

      Dir.glob("#{__dir__}/view/**/*") do |name|
        next if File.directory?(name)

        template(name[/\A#{prefix}(.+)\.erb\z/m, 1])
      end
    end
  end
end
