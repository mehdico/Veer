cask "veer" do
  version "1.6.0"
  sha256 "e63ddc2f6b5844e6f362ac2a37632831e5423cf084297e22f09eb5a7477c2d12"

  url "https://github.com/mehdico/Veer/releases/download/v#{version}/Veer.app.zip",
      verified: "github.com/mehdico/Veer"
  name "Veer"
  desc "Menu-bar clipboard history manager with fuzzy search"
  homepage "https://github.com/mehdico/Veer"

  depends_on macos: :sequoia

  app "Veer.app"

  uninstall quit: "com.mahdimoosavi.veer"

  zap trash: [
    "~/Library/Application Support/com.mahdimoosavi.veer",
    "~/Library/Preferences/com.mahdimoosavi.veer.plist",
  ]

  caveats <<~EOS
    Veer needs Accessibility permission to paste into other apps.
    Grant it in System Settings → Privacy & Security → Accessibility.
  EOS
end
