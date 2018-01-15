require 'health_monitor/providers/base'
require 'sidekiq/api'

module HealthMonitor
  module Providers
    class SidekiqException < StandardError; end

    class Sidekiq < Base
      class Configuration
        DEFAULT_LATENCY_TIMEOUT = 30
        DEFAULT_QUEUES_SIZE = 100
        DEFAULT_QUEUES = []

        attr_accessor :latency, :queue_size, :queues

        def initialize
          @latency = DEFAULT_LATENCY_TIMEOUT
          @queue_size = DEFAULT_QUEUES_SIZE
          @queues = DEFAULT_QUEUES
        end
      end

      def check!
        check_workers!
        check_processes!
        if configuration.queues.length > 0
          configuration.queues.each do |name|
            queue = ::Sidekiq::Queue.new(name)
            check_latency!(queue)
            check_queue_size!(queue)
          end
        else
          check_latency!
          check_queue_size!
        end
        check_redis!

      rescue Exception => e
        raise SidekiqException.new(e.message)
      end

      private

      class << self
        private

        def configuration_class
          ::HealthMonitor::Providers::Sidekiq::Configuration
        end
      end

      def check_workers!
        ::Sidekiq::Workers.new.size
      end

      def check_processes!
        sidekiq_stats = ::Sidekiq::Stats.new
        return unless sidekiq_stats.processes_size.zero?

        raise 'Sidekiq alive processes number is 0!'
      end

      def check_latency!(queue = default_queue)
        latency = queue.latency

        return unless latency > configuration.latency

        raise "latency #{latency} is greater than #{configuration.latency}"
      end

      def check_queue_size!(queue = default_queue)
        size = queue.size

        return unless size > configuration.queue_size

        raise "queue size #{size} is greater than #{configuration.queue_size}"
      end

      def check_redis!
        if ::Sidekiq.respond_to?(:redis_info)
          ::Sidekiq.redis_info
        else
          ::Sidekiq.redis(&:info)
        end
      end

      private def default_queue
        @queue ||= ::Sidekiq::Queue.new
      end
    end
  end
end
