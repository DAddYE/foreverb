module Forever
  module Every
    class Job
      attr_accessor :period, :option, :last, :running

      def initialize(period, options, block)
        @period, @options, @last, @running = period, options, 0, false
        @at = parse_at(@options[:at])
        @block = block
      end

      def call
        @last, @running = Time.now, true
        @block.call
      ensure
        @running = false
      end

      def time?(t)
        ellapsed_ready = (t - @last).to_i >= @period
        time_ready     = @at.nil? || (t.hour == @at[0] && t.min == @at[1])
        !running && ellapsed_ready && time_ready
      end

      private
        def parse_at(at)
          return unless at.is_a?(String)
          m = at.match(/^(\d{1,2}):(\d{1,2})$/)
          raise "Failed to parse #{at}" unless m
          hour, min = m[1].to_i, m[2].to_i
          raise "Failed to parse #{at}" if hour >= 24 || min >= 60
          [hour, min]
        end
    end # Job

    def every(period, options={}, &block)
      jobs << Job.new(period, options, block)
    end

    def jobs
      @_jobs ||= []
    end
  end # Every
end # Forever