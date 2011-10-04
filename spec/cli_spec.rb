require File.expand_path('../spec_helper', __FILE__)

describe 'CLI' do
  def cli(task)
    `#{Gem.ruby} #{File.expand_path('../../bin/foreverb', __FILE__)} #{task}`
  end

  it 'should list daemons' do
    cli('list').must_match(/Your config is empty/)
    cli('list').must_match(FOREVER_PATH)
    cli('list -m').must_match(/PID  RSS  CPU  CMD/)
    run_example
    cli('list').must_match(/RUNNING/)
    cli('list -m').must_match(/Forever:\s/)
  end

  it "should stop daemons" do
    run_example
    cli('list').must_match(/RUNNING/)
    result = cli('stop -a -y')
    result.must_match(/STOPPING/)
    result.wont_match(/ERROR/)
    cli('list').must_match(/NOT RUNNING/)
  end

  it 'should kill daemons' do
    run_example
    cli('list').must_match(/RUNNING/)
    result = cli('kill -a -y')
    result.must_match(/KILLING/)
    result.wont_match(/ERROR/)
    cli('list').must_match(/NOT RUNNING/)
  end
end
