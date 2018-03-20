require "firefox-json/version"
require "firefox-json/profiles"

module FirefoxJson
  def self.available_profiles
    Profiles.new.list
  end

  def self.load_profile(name)
    profiles = Profiles.new
    profiles[name]
  end
end
