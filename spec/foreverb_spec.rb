require File.expand_path('../spec_helper', __FILE__)

describe Forever do

  it 'should set a basic config' do
    run_example
    @forever.dir.must_equal File.expand_path("../../", __FILE__)
    @forever.log.must_equal File.join(@forever.dir, 'log', File.basename(example_filename, '.*') + '.log')
    @forever.pid.must_equal File.join(@forever.dir, 'tmp', File.basename(example_filename, '.*') + '.pid')
    @forever.file.must_equal example_filename
    config = YAML.load_file(FOREVER_PATH)
    config[0][:file].must_equal example_filename
    config[0][:log].must_equal @forever.log
    config[0][:pid].must_equal @forever.pid
  end

  it 'should set a custom config' do
    run_example(:dir => Dir.tmpdir)
    @forever.dir.must_equal Dir.tmpdir
    @forever.log.must_equal File.join(@forever.dir, 'log', File.basename(example_filename, '.*') + '.log')
    @forever.pid.must_equal File.join(@forever.dir, 'tmp', File.basename(example_filename, '.*') + '.pid')
    @forever.file.must_equal example_filename
    config = YAML.load_file(FOREVER_PATH)
    config[0][:file].must_equal example_filename
    config[0][:log].must_equal @forever.log
    config[0][:pid].must_equal @forever.pid
  end

  it 'should launch a daemon with threads with soft stop' do
    run_example
    sleep 0.1 while !File.exist?(@forever.pid)
    pid = File.read(@forever.pid).to_i
    sleep 1
    out, err = capture_io { @forever.stop }
    out.must_match(/waiting the daemon's death/i)
    out.must_match(/#{pid}/)
  end

  it 'should launch a daemon with threads with soft stop' do
    run_example(:fork => true)
    sleep 0.1 while !File.exist?(@forever.pid)
    pid = File.read(@forever.pid).to_i
    sleep 1
    out, err = capture_io { @forever.stop }
    out.must_match(/waiting the daemon's death/i)
    out.must_match(/#{pid}/)
  end
end
