require 'tmpdir'

module Forever
  module Every
    class Job

      def initialize(period, options, block)
        @period   = period
        @at_start = options[:at] == :start && options.delete(:at) ? true : false
        @at       = options[:at] ? parse_at(*options[:at]) : []
        @tmp      = File.join(Dir.tmpdir, '%x' % rand(255**10))
        @block    = block
      end

      def call
        File.open(@tmp, 'w') { |f| f.write('running') }
        FileUtils.touch(@tmp)
        @block.call
      ensure
        File.open(@tmp, 'w') { |f| f.write('idle') }
      end

      def running?
        File.exist?(@tmp) && File.read(@tmp) == 'running'
      end

      def last
        File.mtime(@tmp)
      rescue Errno::ENOENT
        0
      end

      def time?(t)
        elapsed_ready = (t - last).to_i >= @period
        time_ready = @at.empty? || @at.any? { |at| (at[0].empty? || t.hour == at[0].to_i) && (at[1].empty? || t.min == at[1].to_i) }
        !running? && elapsed_ready && time_ready
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
