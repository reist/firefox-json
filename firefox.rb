require 'oj'

module Firefox
  class Base
    attr_accessor :path
    @@inherited = []

    def inspect
      to_s
    end

    def check_keys data
      key = self.class::REQUIRED_KEY
      unless data && data[key]
        raise ArgumentError, "Not a Firefox #{self.class.name.downcase} - missing #{key} key"
      end
      @data = data
    end

    def reload
      raise ArgumentError, 'Path not given' unless @path
      @data = Oj.load_file(@path, :mode => :strict)
    end

    def save path=nil
      path ||= @path
      raise ArgumentError, 'Path not given' unless path
      File.open(path, 'w') {|f| f.write Oj.dump(dump, :mode => :strict)}
    end

    def self.inherited klass
      @@inherited << klass
    end

    def self.children
      @@inherited
    end
  end

  class Session < Base
    attr_reader :windows, :closed_windows

    REQUIRED_KEY = 'windows'

    def initialize data
      check_keys data
      @windows = data['windows'].map {|wh| Window.new(wh)}
      @closed_windows = data['_closedWindows'].map {|wh| Window.new(wh, true)}
    end

    def dump
      @data['windows'] = @windows.map(&:dump)
      @data['_closedWindows'] = @closed_windows.map(&:dump)
      @data
    end

    def current_urls
      windows.map(&:current_urls)
    end

    def to_json
      Oj.dump dump, :mode => :strict
    end

    def to_s
      closed_text = ' closed='+closed_windows.size.to_s if closed_windows.size>0
      warning = File.basename(path) if File.basename(path).split('.')[0] == 'recovery'
      "#<Firefox::Session##{warning} windows=#{windows.size}#{closed_text}>"
    end
  end

  class Window < Base
    attr_reader :tabs, :closed_tabs, :selected_idx, :is_closed

    REQUIRED_KEY = 'tabs'

    def initialize data, is_closed = false
      check_keys data
      @is_closed = is_closed
      @tabs = data['tabs'].map {|wh| Tab.new(wh)}
      @closed_tabs = data['_closedTabs'].map {|wh| Tab.new(wh)}
      @selected_idx = data['selected']
    end

    def selected_idx= idx
      if @tabs.size > idx
        @data['selected'] = @selected_idx = idx
      else
        @selected_idx
      end
    end

    def reset_selected_idx
      selected_idx = @tabs.size - 1
    end

    def hash
      tabs.hash
    end

    def eql? _window
      _window.is_a?(Firefox::Window) && hash == _window.hash
    end

    def dump
      @data['tabs'] = @tabs.map(&:dump)
      @data['_closedTabs'] = @closed_tabs.map(&:dump)
      @data
    end

    def current_urls
      tabs.map(&:selected_url)
    end

    def selected
      tabs[selected_idx-1]
    end

    def selected_title
      selected.selected.title
    end

    def to_s
      "#<Firefox::Window#{' closed!' if is_closed} tabs=#{tabs.size}#{' closed='+closed_tabs.size.to_s if closed_tabs.size>0} selected=\"#{selected_title}\">"
    end
  end

  class Tab < Base
    attr_reader :entries, :selected_idx, :is_closed

    REQUIRED_KEY = 'entries'

    def initialize data
      if data['state']
        @is_closed = true
        @closed_data = data.reject {|k,_v| 'state' == k}
      else
        @is_closed = false
      end
      tab_state = is_closed ? data['state'] : data
      check_keys tab_state
      @entries = tab_state['entries'].map {|wh| Entry.new(wh)}
      @selected_idx = tab_state['index']
    end

    def hash
      selected_url.hash
    end

    def eql? _tab
      _tab.is_a?(Firefox::Tab) && selected_url == _tab.selected_url
    end

    def dump
      @data['entries'] = @entries.map(&:dump)
      is_closed ? @closed_data.merge('state' => @data) : @data
    end

    def selected
      entries[selected_idx-1]
    end

    def selected_title
      selected.title
    end

    def selected_url
      selected.url
    end

    def to_s
      "#<Firefox::Tab#{' closed!' if is_closed} entries=#{entries.size} selected=\"#{selected_title}\">"
    end
  end

  class Entry < Base
    attr_reader :url, :title, :referrer

    REQUIRED_KEY = 'url'

    def initialize data, is_closed = false
      check_keys data
      @is_closed = is_closed
      @url = data['url']
      @title = data['title']
      @referrer = data['referrer']
      @id = data['id']
      @docshell_id = data['docshellID']
      @doc_identifier = data['docIdentifier']
    end

    def hash
      url.hash
    end

    def eql? _entry
      _entry.is_a?(Firefox::Entry) && url == _entry.url
    end

    def dump
      @data
    end

    def to_s
      "#<Firefox::Entry #{url}>"
    end
  end

  BAD_ARG = 'Not Firefox session data'.freeze

  def self.load string, path=nil
    data = Oj.load(string, :mode => :strict)
    raise ArgumentError, BAD_ARG unless data.is_a?(Hash)
    klass = Base.children.find { |klass| data.key? klass::REQUIRED_KEY }
    raise RuntimeError, BAD_ARG unless klass
    o = klass.new data
    o.path = path
    o
  end

  def self.load_file js_path
    load IO.read(js_path), js_path
  end

  def self.load_profile name
    ff_path = File.expand_path('~/.mozilla/firefox')
    profile_dirs = Dir["#{ff_path}/*.#{name}/", "#{ff_path}/#{name}/"]
    case profile_dirs.size
    when 0
      false
    when 1
      js_path = File.join(profile_dirs[0], 'sessionstore.js')
      load IO.read(js_path), js_path
    else
      profiles = profile_dirs.map {|dir| File.basename(dir)}
      raise ArgumentError, "Multiple profiles matched: #{profiles.join(', ')}"
    end
  end
end
