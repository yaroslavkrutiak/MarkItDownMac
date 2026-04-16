cask "markitdownmac" do
  version "1.2.4"
  sha256 "9f6e21872ea868f006d49a6c53d44ecbe2ef543c1bf7f48dc700d556aef86247"

  url "https://github.com/yaroslavkrutiak/MarkItDownMac/releases/download/v#{version}/MarkItDownMac.zip"
  name "MarkItDownMac"
  desc "Native macOS wrapper for the markitdown Python CLI"
  homepage "https://github.com/yaroslavkrutiak/MarkItDownMac"

  depends_on macos: ">= :ventura"

  app "MarkItDownMac.app"

  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-cr", "#{appdir}/MarkItDownMac.app"],
                   sudo: false
  end

  zap trash: [
    "~/Library/Logs/MarkItDownMac",
    "~/Library/Preferences/com.markitdownmac.app.plist",
  ]
end
