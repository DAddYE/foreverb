require 'spec_helper'

describe Forever do

  before :each do
    ARGV << 'up'
  end

  it 'should set a basic config' do
    @forever = Forever.run {}
    @forever.dir.should == File.expand_path("../../", __FILE__)
    @forever.log.should == File.join(@forever.dir, 'log', File.basename(__FILE__) + '.log')
    @forever.pid.should == File.join(@forever.dir, 'tmp', File.basename(__FILE__) + '.pid')
    @forever.file.should == __FILE__
    config = YAML.load_file(FOREVER_PATH)
    config[0][:file].should == __FILE__
    config[0][:log].should == @forever.log
    config[0][:pid].should == @forever.pid
  end

  it 'should set a custom config' do
    @forever = Forever.run do
      dir File.expand_path('../', __FILE__)
    end
    @forever.dir.should == File.expand_path('../', __FILE__)
    @forever.log.should == File.join(@forever.dir, 'log', File.basename(__FILE__) + '.log')
    @forever.pid.should == File.join(@forever.dir, 'tmp', File.basename(__FILE__) + '.pid')
    @forever.file.should == __FILE__
    config = YAML.load_file(FOREVER_PATH)
    config[0][:file].should == __FILE__
    config[0][:log].should == @forever.log
    config[0][:pid].should == @forever.pid
  end

  it 'should launch a daemon' do
    ARGV.clear
    stdout_was, $stdout = $stdout, StringIO.new
    @forever = Forever.run do
      on_ready { sleep 2 }
    end
    sleep 0.1 while !File.exist?(@forever.pid)
    pid = File.read(@forever.pid).to_i
    Process.waitpid(pid)
    $stdout.string.should match(/pid not found/i)
    $stdout = stdout_was
  end
end