require 'spec_helper'

describe "CLI" do

  it "should list no daemons" do
    cli('list').should match(/Your config is empty/)
    cli('list').should match(FOREVER_PATH)
    cli('list -m').should match(/PID  RSS  CPU  CMD/)
  end

  it "should list a daemon" do
    run_example
    cli('list').should match(/RUNNING/)
    cli('list -m').should match(/Forever:\s/)
  end

  it "should stop daemons" do
    run_example
    cli('list').should match(/RUNNING/)
    result = cli('stop -a -y')
    result.should match(/STOPPING/)
    result.should_not match(/ERROR/)
    cli('list').should match(/NOT RUNNING/)
  end
end