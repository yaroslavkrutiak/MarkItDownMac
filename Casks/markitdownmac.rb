cask "markitdownmac" do
  version "1.2.1"
  sha256 "01ff4daf59ba928d71d0e685db949e61c934c020c1848bec3b614d4b1a748036"

  url "https://github.com/yaroslavkrutiak/MarkItDownMac/releases/download/v#{version}/MarkItDownMac.zip"
  name "MarkItDownMac"
  desc "Native macOS wrapper for the markitdown Python CLI"
  homepage "https://github.com/yaroslavkrutiak/MarkItDownMac"

  depends_on macos: ">= :ventura"

  app "MarkItDownMac.app"

  zap trash: [
    "~/Library/Logs/MarkItDownMac",
    "~/Library/Preferences/com.markitdownmac.app.plist",
  ]
end
