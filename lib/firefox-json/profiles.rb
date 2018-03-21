require 'inifile'
require 'firefox-json/session'

module FirefoxJson
  # Access to the profiles.ini file that links to all defined profiles and their locations
  class Profiles
    # Collects methods to access a single profile's session file
    class Profile
      def initialize(data, ff_path)
        @data = data
        @ff_path = ff_path
      end

      def path
        @path ||= @data['IsRelative'] == 1 ? File.join(@ff_path, @data['Path']) : @data['Path']
      end

      def session
        Session.default(path)
      end

      def recovery_session
        Session.recovery(path)
      end
    end

    def initialize(path = File.join(Dir.home, '.mozilla/firefox'))
      @ff_path = path
      data = IniFile.load(File.join(@ff_path, 'profiles.ini'))
      p_sections = data.sections.select {|section| section.start_with?('Profile')}
      @profile_map = p_sections.reduce({}) do |hash, section|
        profile = data[section]
        hash[profile['Name'].freeze] = profile.freeze
        hash
      end
    end

    def list
      @profile_map.keys.dup
    end

    def [](name)
      if @profile_map.key?(name)
        Profile.new(@profile_map[name], @ff_path)
      end
    end
  end
end
