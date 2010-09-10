require 'test/helper'

class CommandLineTest < Test::Unit::TestCase
  def setup
    Paperclip::CommandLine.path = nil
    File.stubs(:exist?).with("/dev/null").returns(true)
  end

  should "take a command and parameters and produce a shell command for bash" do
    cmd = Paperclip::CommandLine.new("convert", "a.jpg b.png")
    assert_equal "convert a.jpg b.png", cmd.command
  end

  should "be able to set a path and produce commands with that path" do
    Paperclip::CommandLine.path = "/opt/bin"
    cmd = Paperclip::CommandLine.new("convert", "a.jpg b.png")
    assert_equal "/opt/bin/convert a.jpg b.png", cmd.command
  end

  should "be able to interpolate quoted variables into the parameters" do
    cmd = Paperclip::CommandLine.new("convert",
                                     ":one :{two}",
                                     :one => "a.jpg",
                                     :two => "b.png")
    assert_equal "convert 'a.jpg' 'b.png'", cmd.command
  end

  should "quote command line options differently if we're on windows" do
    File.stubs(:exist?).with("/dev/null").returns(false)
    cmd = Paperclip::CommandLine.new("convert",
                                     ":one :{two}",
                                     :one => "a.jpg",
                                     :two => "b.png")
    assert_equal 'convert "a.jpg" "b.png"', cmd.command
  end

  should "be able to quote and interpolate dangerous variables" do
    cmd = Paperclip::CommandLine.new("convert",
                                     ":one :two",
                                     :one => "`rm -rf`.jpg",
                                     :two => "ha'ha.png")
    assert_equal "convert '`rm -rf`.jpg' 'ha'\\''ha.png'", cmd.command
  end

  should "be able to quote and interpolate dangerous variables even on windows" do
    File.stubs(:exist?).with("/dev/null").returns(false)
    cmd = Paperclip::CommandLine.new("convert",
                                     ":one :two",
                                     :one => "`rm -rf`.jpg",
                                     :two => "ha'ha.png")
    assert_equal %{convert "`rm -rf`.jpg" "ha'ha.png"}, cmd.command
  end

  should "add redirection to get rid of stderr in bash" do
    File.stubs(:exist?).with("/dev/null").returns(true)
    cmd = Paperclip::CommandLine.new("convert",
                                     "a.jpg b.png",
                                     :swallow_stderr => true)

    assert_equal "convert a.jpg b.png 2>/dev/null", cmd.command
  end

  should "add redirection to get rid of stderr in cmd.exe" do
    File.stubs(:exist?).with("/dev/null").returns(false)
    cmd = Paperclip::CommandLine.new("convert",
                                     "a.jpg b.png",
                                     :swallow_stderr => true)

    assert_equal "convert a.jpg b.png 2>NUL", cmd.command
  end

  should "raise if trying to interpolate :swallow_stderr or :expected_outcodes" do
    cmd = Paperclip::CommandLine.new("convert",
                                     ":swallow_stderr :expected_outcodes",
                                     :swallow_stderr => false,
                                     :expected_outcodes => [0, 1])
    assert_raise(Paperclip::PaperclipCommandLineError) do
      cmd.command
    end
  end

  should "run the #command it's given and return the output" do
    cmd = Paperclip::CommandLine.new("convert", "a.jpg b.png")
    cmd.class.stubs(:"`").with("convert a.jpg b.png").returns(:correct_value)
    with_exitstatus_returning(0) do
      assert_equal :correct_value, cmd.run
    end
  end

  should "raise a PaperclipCommandLineError if the result code isn't expected" do
    cmd = Paperclip::CommandLine.new("convert", "a.jpg b.png")
    cmd.class.stubs(:"`").with("convert a.jpg b.png").returns(:correct_value)
    with_exitstatus_returning(1) do
      assert_raises(Paperclip::PaperclipCommandLineError) do
        cmd.run
      end
    end
  end

  should "not raise a PaperclipCommandLineError if the result code is expected" do
    cmd = Paperclip::CommandLine.new("convert",
                                     "a.jpg b.png",
                                     :expected_outcodes => [0, 1])
    cmd.class.stubs(:"`").with("convert a.jpg b.png").returns(:correct_value)
    with_exitstatus_returning(1) do
      assert_nothing_raised do
        cmd.run
      end
    end
  end

  should "log the command" do
    cmd = Paperclip::CommandLine.new("convert", "a.jpg b.png")
    cmd.class.stubs(:'`')
    Paperclip.expects(:log).with("convert a.jpg b.png")
    cmd.run
  end

  should "detect that the system is unix or windows based on presence of /dev/null" do
    File.stubs(:exist?).returns(true)
    assert Paperclip::CommandLine.unix?
  end

  should "detect that the system is not unix or windows based on absence of /dev/null" do
    File.stubs(:exist?).returns(false)
    assert ! Paperclip::CommandLine.unix?
  end
end
