require 'rspec/mocks'
require 'imperator'
require 'imperator/test_background_processor'
describe Imperator::Command do

  describe "actions" do
    class CommandTestException < Exception; end
    context "using DSL " do
      class DSLTestCommand < Imperator::Command
        action do
          raise CommandTestException.new
        end
      end

      let(:command){DSLTestCommand.new}
      it "runs the action block when #perform is called" do
        expect{command.perform}.to raise_exception(CommandTestException)
      end
    end

    context "using method definition" do
      class MethodTestCommand < Imperator::Command
        def action
          raise CommandTestException.new
        end
      end
      let(:command){MethodTestCommand.new}
      it "runs the action method when #perform is called" do
        expect{command.perform}.to raise_exception(CommandTestException)
      end
    end
  end

  describe "performing" do
    context "bang version" do
      class PerformBangValidCommand < Imperator::Command
        attribute :foo, String
        def action
          "this is fine"
        end
      end

      it "bang version doesn't raise exception if validations not enabled" do
        expect{PerformBangValidCommand.new.perform!}.not_to raise_exception(Imperator::InvalidCommandError)
        expect{PerformBangValidCommand.new.commit!}.not_to raise_exception(Imperator::InvalidCommandError)
      end

      it "raises an exception if the command is invalid" do
        command = PerformBangValidCommand.new
        command.stub(:valid?).and_return(false)
        expect{command.perform!}.to raise_exception(Imperator::InvalidCommandError)
        expect{command.commit!}.to  raise_exception(Imperator::InvalidCommandError)

      end
    end
  end

  describe "attributes" do
    class AttributeCommand < Imperator::Command
      attribute :gets_default, String, :default => "foo"
      attribute :declared_attr, String
    end

    it "throws away undeclared attributes in mass assignment" do
      command = AttributeCommand.new(:undeclared_attr => "foo")
      expect{command.undeclared_attr}.to raise_exception(NoMethodError)
    end

    it "accepts declared attributes in mass assignment" do
      command = AttributeCommand.new(:declared_attr => "bar")
      command.declared_attr.should == "bar"
    end

    it "allows default values to be used on commands" do
      command = AttributeCommand.new
      command.gets_default.should == "foo"
    end
    it "overrides default when supplied in constructor args" do
      command = AttributeCommand.new :gets_default => "bar"
      command.gets_default.should == "bar"
    end
  end

  describe "#commit" do
    before do
      Imperator::Command.background_processor = Imperator::TestBackgroundProcessor
    end

    after do
      Imperator::Command.background_processor = Imperator::NullBackgroundProcessor
    end

    class TestCommand < Imperator::Command
      attribute :foo, String
      def action
      end
    end

    context "in subclassed commands" do
      class SubTestCommand < TestCommand
        background :any_option => :foo
      end
      it "commits like the parent class" do
        command = SubTestCommand.new(:foo => "bar")
        command.commit
        Imperator::TestBackgroundProcessor.commits.should include(command)
      end

      context "with background options" do
        it "receives background options" do
          command = SubTestCommand.new(:foo => "bar")
          Imperator::TestBackgroundProcessor.should_receive(:commit).with(command, :any_option => :foo)
          command.commit
        end

        it "receives options supplied on the command instance" do
          command = SubTestCommand.new(:foo => "bar")
          Imperator::TestBackgroundProcessor.should_receive(:commit).with(command, :any_option => :bar)
          command.commit(:any_option => :bar)

        end
      end
    end

    it "sends the command into the configured background processor" do
      command = TestCommand.new(:foo => "bar")
      command.commit
      Imperator::TestBackgroundProcessor.commits.should include(command)
    end
  end

end

