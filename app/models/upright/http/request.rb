class Upright::HTTP::Request
  attr_reader :url, :options

  def initialize(url, **options)
    @url = url
    @options = options
  end

  def get
    response = Typhoeus.get(url, request_options)
    Upright::HTTP::Response.new(response, build_log(response))
  end

  private
    def request_options
      current_site = Upright.current_site

      {
        timeout: current_site.default_timeout,
        connecttimeout: current_site.default_timeout,
        headers: request_headers,
        userpwd: userpwd,
        proxy: proxy_url,
        proxyuserpwd: proxy_userpwd,
        verbose: true,
        forbid_reuse: proxy_url.nil?
      }.compact
    end

    def request_headers
      { "User-Agent" => Upright.configuration.user_agent }
    end

    def userpwd
      if options[:username] && options[:password]
        "#{options[:username]}:#{options[:password]}"
      end
    end

    def proxy_url
      options[:proxy]
    end

    def proxy_userpwd
      if options[:proxy_username] && options[:proxy_password]
        "#{options[:proxy_username]}:#{options[:proxy_password]}"
      end
    end

    def build_log(response)
      StringIO.new.tap do |log|
        if response.debug_info
          response.debug_info.text.each { |msg| log.puts "* #{msg.chomp}" }
          response.debug_info.header_out.each { |msg| log.puts "> #{msg.chomp}" }
          response.debug_info.header_in.each { |msg| log.puts "< #{msg.chomp}" }
        end
      end
    end
end
