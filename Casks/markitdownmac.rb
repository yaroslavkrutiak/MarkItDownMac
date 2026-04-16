cask "markitdownmac" do
  version "1.0.1"
  sha256 "751f6184a4ff28aee0afbb5bf7ba0684143cdcc31e3c151b5987dc9c7102394d"

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
