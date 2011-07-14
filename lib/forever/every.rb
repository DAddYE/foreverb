module Forever
  module Every
    class Job
      attr_accessor :period, :option, :last, :running

      def initialize(period, options, block)
        @period, @options, @last, @running = period, options, 0, false
        @at = options[:at] ? parse_at(*@options[:at]) : []
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
        time_ready = @at.empty? || @at.any? { |at| (at[0].empty? || t.hour == at[0].to_i) && (at[1].empty? || t.min == at[1].to_i) }
        !running && ellapsed_ready && time_ready
      end

      private
        def parse_at(*args)
          args.map do |at|
            raise "#{at} must be a string" unless at.is_a?(String)
            raise "#{at} has not a colon separator" unless at =~ /:/
            hour, min = at.split(":")
            raise "Failed to parse #{at}" if hour.to_i >= 24 || min.to_i >= 60
            [hour, min]
          end
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