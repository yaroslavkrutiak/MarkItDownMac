cask "markitdownmac" do
  version "1.0.0"
  sha256 :no_check

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
