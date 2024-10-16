# frozen_string_literal: true

module BattleCatsRolls
  module Cache
    EXPIRES_IN = 86400
    LRU_SIZE = 8192

    module DalliExtension
      def [] *args
        get(*args)
      end

      def []= *args
        set(*args)
      end

      def store key, value, expires_in: nil
        set(key, value, expires_in)
        value
      end
    end

    module_function
    def default logger
      @cache ||= Cache.pick(logger)
    end

    def pick logger
      memcache(logger) || lru_cache(logger) || persistent_hash(logger)
    end

    def memcache logger
      require 'dalli'
      client = Dalli::Client.new(nil, :expires_in => EXPIRES_IN)
      File.open(IO::NULL, 'w') do |null|
        Dalli.logger = Logger.new(null)
        client.alive!
        Dalli.logger = logger
      end
      logger.info("Memcached connected to #{client.version.keys.join(', ')}")
      client.extend(DalliExtension)
      client
    rescue LoadError, Dalli::RingError => e
      logger.debug("Skip memcached because: #{e}")
      nil
    end

    def lru_cache logger
      require 'lru_redux'
      logger.info("LRU cache size: #{LRU_SIZE}")
      cache = LruRedux::ThreadSafeCache.new(LRU_SIZE)
      cache.extend(Module.new{
        def fetch key # original fetch could deadlock
          self[key] || self[key] = yield
        end

        def store key, value, expires_in: nil
          self[key] = value
        end
      })
      cache
    rescue LoadError => e
      logger.debug("Skip LRU cache because: #{e}")
      nil
    end

    def persistent_hash logger
      logger.info("Last resort persistent in-memory hash used")
      cache = {}
      cache.extend(Module.new{
        def store key, value, expires_in: nil
          super(key, value)
        end
      })
      cache
    end
  end
end
