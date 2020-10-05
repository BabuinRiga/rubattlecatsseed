# frozen_string_literal: true

require_relative 'root'
require_relative 'route'

require 'promise_pool'
require 'digest/sha1'

module BattleCatsRolls
  class SeekSeed < Struct.new(
    :source, :key, :logger, :cache,
    :promise, :seed, :previous_count)
    Pool = PromisePool::ThreadPool.new(1)
    Mutex = Mutex.new

    def self.processed
      @processed ||= 0
    end

    def self.finishing key
      Mutex.synchronize do
        yield
        queue.delete(key)
        @processed += 1
      end
    end

    def self.enqueue source, cache, logger
      key = Digest::SHA1.hexdigest(source)

      cache[key] || queue[key] = new(source, key, logger, cache).start

      key
    end

    def self.queue
      @queue ||= {}
    end

    def start
      Mutex.synchronize do
        enqueue
      end

      self
    end

    def started?
      promise.started?
    end

    def ended?
      promise.resolved?
    end

    def yield
      promise.yield
    end

    def position
      previous_count - self.class.processed + 1
    end

    private

    def enqueue
      self.previous_count = Pool.queue_size + self.class.processed
      self.promise = PromisePool::Promise.new.defer(Pool) do
        self.seed = cache[key] || seek

        self.class.finishing(key) do
          cache[key] = seed if $?.success?
        end
      end
    end

    def seek
      if source.start_with?('8.6 ')
        IO.popen([
          "#{Root}/Seeker/Seeker-8.6",
          *ENV['SEEKER_OPT'].to_s.split(' '), *source.split(' '),
          err: %i[child out]], 'r+') do |io|
          logger.info("Seeking seed with #{source}")
          io.close_write
          io.read.scan(/\d+/).map(&:to_i)
        end
      else
        IO.popen([
          "#{Root}/Seeker/Seeker",
          *ENV['SEEKER_OPT'].to_s.split(' '),
          err: %i[child out]], 'r+') do |io|
          logger.info("Seeking seed with #{source}")
          io.puts source
          io.close_write
          io.read.scan(/\d+/).map(&:to_i)
        end
      end
    end
  end
end
