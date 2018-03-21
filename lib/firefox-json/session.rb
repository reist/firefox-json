require 'firefox-json/js_file'

module FirefoxJson
  module Session
    class Base
      attr_accessor :path
      @@inherited = []

      def initialize data, path: nil
        setup data
        @path = path
      end

      def inspect
        to_s
      end

      def eql? object
        object.is_a?(self.class) && hash == object.hash
      end

      def setup data
        unless data && data[required_key]
          raise ArgumentError, "Not a Firefox #{self.class.name.downcase} - missing #{required_key} key"
        end
        @data = data
      end
      protected :setup

      def reload
        raise ArgumentError, 'Path not given' unless @path
        @data = JsFile.load_file(@path)
      end

      def dump
        @data
      end

      def save path=nil
        path ||= @path
        raise ArgumentError, 'Path not given' unless path
        JsFile.save(path, dump)
      end

      def self.inherited klass
        @@inherited << klass
      end

      def self.children
        @@inherited
      end

      def self.choose_for data
        children.find { |klass| data.key? klass.required_key }
      end

      def self.mattr_accessor name
        class_eval <<-CODE, __FILE__, __LINE__ + 1
          def self.#{name}
            @#{name}
          end
          def #{name}
            self.class.#{name}
          end
        CODE
      end

      def self.required_key= key
        @required_key = key.freeze
      end
      mattr_accessor :required_key

      def self.set_collection item_class, index_key, with_closed = false
        include Collection
        @index_key = index_key
        @item_class = item_class
        base_key_name = item_class.name.split('::')[-1].sub(/y$/, 'ie') + 's'
        self.required_key = base_key_name.downcase
        define_method @required_key do
          @collection
        end
        if with_closed
          @closed_key = "_closed#{base_key_name}"
          define_method "closed_#{required_key}" do
            @closed_collection
          end
        end
      end
    end

    # Management of collections, closed items and the item in focus
    module Collection
      def self.included target
        target.send(:attr_reader, :selected_idx)
        [:item_class, :closed_key, :index_key].each do |accessor|
          target.mattr_accessor accessor
        end
      end

      def setup data
        super
        @collection = convert required_key, false
        if closed_key
          @closed_collection = convert closed_key, true
        end
        @selected_idx = @data[index_key]
        sanify_selected_idx
      end

      def convert key, is_closed
        @data[key].map {|hash| item_class.new(hash, is_closed)}
      end

      def selected_idx= idx
        if send(required_key).size >= idx
          @selected_idx = idx
        else
          @selected_idx
        end
      end

      def sanify_selected_idx
        if !@selected_idx || @selected_idx > send(required_key).size
          reset_selected_idx
        else
          @selected_idx
        end
      end

      def reset_selected_idx
        @selected_idx = send(required_key).size
      end

      def selected
        send(required_key)[@selected_idx-1]
      end

      def dump
        @data[index_key] = sanify_selected_idx
        @data[required_key] = @collection.map(&:dump)
        if closed_key
          @data[closed_key] = @closed_collection.map(&:dump)
        end
        super
      end
    end

    # The base of the session - a specific viewed site
    class Entry < Base
      attr_reader :url, :title, :referrer
      self.required_key = 'url'

      def initialize data, _closed
        setup data
        @url = data['url']
        @title = data['title']
        @referrer = data['referrer']
        @id = data['id']
        @docshell_id = data['docshellID']
        @doc_identifier = data['docIdentifier']
      end

      def domain
        url.split('/')[2]
      end

      def hash
        url.hash
      end

      def to_s
        "#<FirefoxJson::Entry #{url}>"
      end
    end

    # A tab collects all its history and knows whether it's closed or not
    class Tab < Base
      attr_reader :is_closed
      set_collection Entry, 'index'

      # is_closed passed from Window and means the real data is inside the 'state' key
      def initialize data, is_closed
        @is_closed = is_closed
        if is_closed
          @closed_data = data.reject {|key,_v| 'state' == key}
        end
        tab_state = is_closed ? data['state'] : data
        setup tab_state
      end

      def hash
        selected_url.hash
      end

      def dump
        is_closed ? @closed_data.merge('state' => super) : super
      end

      def selected_title
        selected&.title
      end

      def selected_url
        selected&.url
      end

      def selected_domain
        selected&.domain
      end

      def to_s
        "#<FirefoxJson::Tab#{' closed!' if is_closed} entries=#{entries.size} selected=\"#{selected_title}\">"
      end
    end

    # A collection of tabs, both current and previous
    class Window < Base
      attr_reader :is_closed
      set_collection Tab, 'selected', true

      def initialize data, is_closed = false
        @is_closed = is_closed
        setup data
      end

      def hash
        tabs.hash
      end

      def current_urls
        tabs.map(&:selected_url)
      end

      def selected_title
        selected.selected.title
      end

      def by_domain
        tabs.map(&:selected_domain).reduce(Hash.new(0)) {|h,host| h[host]+=1; h}.sort_by {|_,v| -v}
      end

      def to_s
        "#<FirefoxJson::Window#{' closed!' if is_closed} tabs=#{tabs.size}#{' closed='+closed_tabs.size.to_s if closed_tabs.size>0} selected=\"#{selected_title}\">"
      end
    end

    # A collection of windows, both current and previous
    class Session < Base
      set_collection Window, 'selectedWindow', true

      def current_urls
        windows.map(&:current_urls)
      end

      def to_s
        closed_text = ' closed='+closed_windows.size.to_s if closed_windows.size>0
        fname = File.basename(path).split('.')[0..-2].join('.')
        warning = fname if fname != 'sessionstore'
        "#<FirefoxJson::Session##{warning} windows=#{windows.size}#{closed_text}>"
      end

      def self.default_file(path)
        Dir["#{path}/sessionstore.jsonlz4",
            "#{path}/sessionstore.js"][0]
      end

      def self.recovery_file(path)
        Dir["#{path}/sessionstore-backups/recovery.jsonlz4",
            "#{path}/sessionstore-backups/recovery.js"][0]
      end

      def self.file(path)
        default_file(path) || recovery_file(path)
      end
    end

    BAD_ARG = 'Not Firefox session data'.freeze

    def self.load string, path=nil
      data = JsFile.load(string)
      raise ArgumentError, BAD_ARG unless data.is_a?(Hash)
      klass = Base.choose_for(data)
      raise RuntimeError, BAD_ARG unless klass
      klass.new(data, path: path)
    end

    def self.load_file(path)
      load IO.read(path), path
    end

    def self.default(path)
      load_file Session.file(path)
    rescue
      load_file session.recovery_file(path)
    end

    def self.recovery(path)
      load_file session.recovery_file(path)
    end
  end
end
