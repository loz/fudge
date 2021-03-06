RSpec::Matchers.define :be_registered_as do |key|
  match do |task|
    Fudge::Tasks.discover(key) == task.class
  end
end

# Collection of matchers for use in a test environment
module FudgeMatchers
  # Run matcher
  class Run
    attr_reader :args, :expected, :task

    def initialize(expected, args={})
      @expected = expected
      @args = args
      @args[:output] ||= $stdout
    end

    def matches?(task)
      @task = task
      ran = []

      to_stub =
        if task.is_a?(Fudge::Tasks::Shell)
          task
        else
          Fudge::Tasks::Shell.any_instance
        end

      to_stub.stub(:run_command) do |cmd, outputio|
        raise "Run Command requires an output IOStream" unless outputio
        ran.push(cmd)
        ['dummy output', true]
      end

      task.run(args)

      @actual = ran
      run_matches?(ran, expected)
    end

    # Failure message
    def failure_message_for_should
      message = ""
      message << "Expected task :#{@task.class.name} "
      message << "to run:\n  #{@expected}\n"
      message << "but it ran:\n  #{@actual}"
    end

    private
    def run_matches?(ran, expected)
      if expected.is_a? Regexp
        ran.any? {|cmd| cmd =~ expected}
      else
        ran.include? expected
      end
    end
  end
end

# Matcher to test a command has been run by the task
def run_command(cmd, options={})
  FudgeMatchers::Run.new cmd, options
end

RSpec::Matchers.define :succeed_with_output do |output|
  match do |subject|
    subject.stub(:run_command).and_return([output, true])

    subject.run
  end
end

shared_examples_for 'bundle aware' do
  before :each do
    @normal_cmd = subject.send(:cmd)
  end

  it "should prefix the command with bundle exec when bundler is set" do
    subject.should run_command("bundle exec #{@normal_cmd}", :bundler => true)
  end

  it "should not prefix the command with bundle exec when bundler is not set" do
    subject.should run_command(@normal_cmd, :bundler => false)
  end
end
