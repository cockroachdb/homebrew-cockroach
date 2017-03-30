class Cockroach < Formula
  desc "Distributed SQL database"
  homepage "https://www.cockroachlabs.com"
  url "https://github.com/cockroachdb/cockroach.git",
      :tag => "beta-20170330"
  head "https://github.com/cockroachdb/cockroach.git"

  depends_on "go" => :build

  def install
    # Move everything in the current directory (i.e. the cockroach
    # repo), except for .brew_home, to where it would reside in a
    # normal Go source layout.
    files = Dir.glob("*") + Dir.glob(".[a-z]*")
    files.delete(".brew_home")
    mkdir_p buildpath/"src/github.com/cockroachdb/cockroach"
    mv files, buildpath/"src/github.com/cockroachdb/cockroach"

    # The only go binary we need to install is glock.
    ENV["GOBIN"] = buildpath/"bin"
    ENV["GOPATH"] = buildpath
    ENV["GOHOME"] = buildpath

    # We use `xcrun make` instead of `make` to avoid homebrew mucking
    # with the HOMEBREW_CCCFG variable which in turn causes the C
    # compiler to behave in a way that is not supported by cgo.
    system "xcrun", "make", "GOFLAGS=-v", "-C",
           "src/github.com/cockroachdb/cockroach", "build"
    bin.install "src/github.com/cockroachdb/cockroach/cockroach" => "cockroach"
  end

  plist_options :manual => "cockroach start"

  def plist; <<-EOS.undent
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>Label</key>
      <string>#{plist_name}</string>
      <key>ProgramArguments</key>
      <array>
        <string>#{opt_bin}/cockroach</string>
        <string>start</string>
        <string>--store=#{var}/cockroach/</string>
      </array>
      <key>WorkingDirectory</key>
      <string>#{var}</string>
      <key>RunAtLoad</key>
      <true/>
      <key>KeepAlive</key>
      <true/>
    </dict>
    </plist>
    EOS
  end

  test do
    begin
      system "#{bin}/cockroach", "start", "--background"
      pipe_output("#{bin}/cockroach sql", <<-EOS.undent)
        CREATE DATABASE bank;
        CREATE TABLE bank.accounts (id INT PRIMARY KEY, balance DECIMAL);
        INSERT INTO bank.accounts VALUES (1, 1000.50);
      EOS
      output = pipe_output("#{bin}/cockroach sql --format=csv",
        "SELECT * FROM bank.accounts;")
      assert_equal <<-EOS.undent, output
        1 row
        id,balance
        1,1000.50
      EOS
    ensure
      system "#{bin}/cockroach", "quit"
    end
  end
end
