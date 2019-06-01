# frozen_string_literal: true

require_relative 'cat'
require_relative 'find_cat'
require_relative 'aws_auth'

require 'cgi'
require 'erb'
require 'tilt'

require 'forwardable'

module BattleCatsRolls
  class View < Struct.new(:controller, :arg)
    extend Forwardable

    def_delegators :controller, *%w[request gacha]

    def render name
      erb(:layout){ erb(name) }
    end

    def each_ball_cat
      arg[:cats].each do |rarity, data|
        yield(rarity, data.map{ |id, info| Cat.new(id, info) })
      end
    end

    def each_ab_cat
      arg[:cats].inject(nil) do |prev_b, ab|
        yield(prev_b, ab)

        ab.last
      end
    end

    def guaranteed_cat cat, offset
      if guaranteed = cat.guaranteed
        link = link_to_roll(guaranteed)
        next_sequence = cat.sequence + controller.guaranteed_rolls + offset

        if offset < 0
          "#{link}<br>-&gt; #{next_sequence}B"
        else
          "#{link}<br>&lt;- #{next_sequence}A"
        end
      end
    end

    def color_label cat
      "pick #{color_rarity(cat)} #{color_picked(cat)}"
    end

    def color_label_guaranteed cat
      if cat.guaranteed
        "pick #{color_guaranteed(cat)} #{color_picked_guaranteed(cat)}"
      end
    end

    def color_picked cat
      sequence = cat.sequence
      guaranteed_position = pick_position + guaranteed_rolls

      if pick_position > 0
        if cat.track == pick_track
          if pick_guaranteed
            if sequence < pick_position
              :picked
            elsif sequence < guaranteed_position - 1
              :picked_cumulatively
            end
          elsif sequence <= pick_position
            :picked
          elsif sequence == pick_position + 1
            :next_position
          end
        elsif pick_guaranteed &&
              sequence == guaranteed_position - (cat.track.ord - 'A'.ord)
          :next_position
        end
      end
    end

    def color_picked_guaranteed cat
      :picked_cumulatively if pick == cat.guaranteed.sequence_track
    end

    def color_rarity cat
      case rarity_label = cat.rarity_label
      when :legend
        :legend
      else
        case cat.id
        when controller.find
          :found
        when *FindCat.exclusives
          :exclusive
        else
          rarity_label
        end
      end
    end

    def color_guaranteed cat
      case cat.guaranteed.id
      when controller.find
        :found
      when *FindCat.exclusives
        :exclusive
      when Integer
        :rare
      end
    end

    def link_to_roll cat
      name = h cat.pick_name(controller.name)
      title = h cat.pick_title(controller.name)

      if cat.slot_fruit
        %Q{<a href="#{h uri_to_roll(cat)}" title="#{title}">#{name}</a>}
      else
        %Q{<span title="#{title}">#{name}</span>}
      end +
        if cat.id > 0
          %Q{<a href="#{h uri_to_cat_db(cat)}">🐾</a>}
        else
          ''
        end
    end

    def guaranteed_rolls
      @guaranteed_rolls ||=
        arg[:guaranteed_rolls] || controller.guaranteed_rolls
    end

    def pick
      @pick ||= arg[:pick] || controller.pick
    end

    def pick_position
      @pick_pos ||= pick.to_i
    end

    def pick_track
      @pick_track ||= pick[/\A\d+(\w)/, 1]
    end

    def pick_guaranteed
      return @pick_guaranteed if
        instance_variable_defined?(:@pick_guaranteed)

      @pick_guaranteed = pick.end_with?('G')
    end

    def pick_option cats
      cats.map.with_index do |cat, slot|
        <<~HTML
          <option value="#{cat.rarity} #{slot}">#{slot} #{cat_name(cat)}</option>
        HTML
      end.join
    end

    def selected_lang lang_name
      'selected="selected"' if controller.lang == lang_name
    end

    def selected_version version_name
      'selected="selected"' if controller.version == version_name
    end

    def selected_name name_name
      'selected="selected"' if controller.name == name_name
    end

    def selected_current_event event_name
      'selected="selected"' if controller.event == event_name
    end

    def selected_find cat
      'selected="selected"' if controller.find == cat.id
    end

    def checked_no_guaranteed
      'checked="checked"' if controller.no_guaranteed
    end

    def selected_force_guaranteed n
      'selected="selected"' if controller.force_guaranteed == n
    end

    def selected_ubers n
      'selected="selected"' if controller.ubers == n
    end

    def checked_details
      'checked="checked"' if controller.details
    end

    def show_details
      arg&.dig(:details) && controller.details
    end

    def hidden_inputs *input_names
      input_names.map do |name|
        <<~HTML
          <input type="hidden" name="#{name}" value="#{controller.public_send(name)}">
        HTML
      end.join("\n")
    end

    def show_event info
      h "#{info['start_on']} ~ #{info['end_on']}: #{info['name']}"
    end

    def show_gacha_slots cats
      cats.map.with_index do |cat, i|
        "#{i} #{cat_name(cat)}"
      end.join(', ')
    end

    def cat_name cat
      h cat.pick_name(controller.name)
    end

    def event_url *args, **options
      AwsAuth.event_url(*args, base_uri: event_base_uri, **options)
    end

    def h str
      CGI.escape_html(str)
    end

    def u str
      CGI.escape(str)
    end

    def made10rolls? seeds
      gacha = Gacha.new(
        controller.ball, controller.event, seeds.first, controller.version)
      gacha.send(:advance_seed!) # Account offset for next_seed
      9.times.inject(nil){ |last| gacha.roll!(last) } # Only 9 rolls left

      if gacha.seed == seeds.last
        gacha.send(:advance_seed!) # Account for guaranteed roll
        gacha.seed
      end
    end

    private

    def header n, name
      id = name.to_s.downcase.gsub(/\W+/, '-')

      <<~HTML
        <a href="##{id}">⚓</a> <h#{n} id="#{id}">#{name}</h#{n}>
      HTML
    end

    def seed_column fruit
      return unless show_details

      <<~HTML
        <td>#{fruit.seed}</td>
        <td>#{if fruit.seed == fruit.value then '-' else fruit.value end}</td>
      HTML
    end

    def onclick_pick cat
      return unless cat && controller.path_info == '/'

      %Q{onclick="pick('#{cat.sequence_track}')"}
    end

    def uri_to_roll cat
      uri(query: {seed: cat.slot_fruit.seed})
    end

    def uri_to_cat_db cat
      "https://battlecats-db.com/unit/#{sprintf('%03d', cat.id)}.html"
    end

    def uri path: "//#{web_host}/", query: {}
      # keep query hash order
      query = cleanup_query(query.merge(default_query).merge(query))

      if query.empty?
        path
      else
        "#{path}?#{query_string(query)}"
      end
    end

    def default_query
      {
        next_seed: controller.next_seed,
        seed: controller.seed,
        event: controller.event,
        lang: controller.lang,
        version: controller.version,
        name: controller.name,
        count: controller.count,
        find: controller.find,
        no_guaranteed: controller.no_guaranteed,
        force_guaranteed: controller.force_guaranteed,
        ubers: controller.ubers,
        details: controller.details
      }
    end

    def cleanup_query query
      query.compact.select do |key, value|
        if (key == :next_seed && (value == 0 || query[:seed].nonzero?)) ||
           (key == :seed && value == 0) ||
           (key == :lang && value == 'en') ||
           (key == :version && value == controller.default_version) ||
           (key == :name && value == 0) ||
           (key == :count && value == 100) ||
           (key == :find && value == 0) ||
           (key == :no_guaranteed && value == 0) ||
           (key == :force_guaranteed && value == 0) ||
           (key == :ubers && value == 0)
          false
        else
          true
        end
      end
    end

    def query_string query
      query.map do |key, value|
        "#{u key.to_s}=#{u value.to_s}"
      end.join('&')
    end

    def seek_host
      ENV['SEEK_HOST'] || request.host_with_port
    end

    def web_host
      ENV['WEB_HOST'] || request.host_with_port
    end

    def event_base_uri
      "#{request.scheme}://#{seek_host}/seek"
    end

    def cats_uri
      uri(path: "//#{web_host}/cats")
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

    def erb name, nested_arg=nil, &block
      context =
        if nested_arg
          self.class.new(controller, arg&.merge(nested_arg) || nested_arg)
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
