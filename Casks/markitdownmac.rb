cask "markitdownmac" do
  version "1.2.3"
  sha256 "c1a7485f32dfeb39ecb78b43dad4fb9dfca0be468b621580a847e1172572ac79"

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
