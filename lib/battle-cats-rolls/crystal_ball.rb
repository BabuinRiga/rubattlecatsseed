# frozen_string_literal: true

require_relative 'cat'

module BattleCatsRolls
  class CrystalBall < Struct.new(:data)
    def self.from_pack_and_events pack, events
      new(
        'cats' => pack.cats,
        'gacha' => pack.gacha,
        'events' => events.gacha)
    end

    def self.load dir, lang
      require 'yaml'

      new(YAML.load_file("#{dir}/bc-#{lang}.yaml"))
    end

    def cats
      data['cats']
    end

    def gacha
      data['gacha']
    end

    def events
      data['events']
    end

    def each_custom_gacha name_index
      cat_data = cats.values.inject(&:merge)

      ubers = cats[Cat::Uber].keys
      legends = cats[Cat::Legend].keys

      gacha.reverse_each do |gacha_id, cat_ids|
        prefix_id =
          cat_ids.find(&legends.method(:member?)) ||
          cat_ids.find(&ubers.method(:member?))

        suffix_id =
          cat_ids.reverse_each.find(&ubers.method(:member?))

        prefix_cat = cat_data[prefix_id]
        suffix_cat = cat_data[suffix_id]

        prefix = Cat.new(info: prefix_cat).pick_name(name_index) if prefix_cat
        suffix = Cat.new(info: suffix_cat).pick_name(name_index) if suffix_cat

        title =
          if prefix || suffix
            [*prefix, *suffix].join(', ')
          else
            '?'
          end

        yield(gacha_id, "#{gacha_id}: #{title}")
      end
    end

    def dump dir, lang
      require 'fileutils'
      require 'yaml'

      FileUtils.mkdir_p(dir)
      File.write("#{dir}/bc-#{lang}.yaml", dump_yaml)
    end

    def dump_yaml
      visitor = Psych::Visitors::YAMLTree.create
      visitor << data
      visitor.tree.grep(Psych::Nodes::Sequence).each do |seq|
        seq.style = Psych::Nodes::Sequence::FLOW
      end

      visitor.tree.yaml(nil, line_width: -1)
    end
  end
end
