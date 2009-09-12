#!/usr/bin/env ruby

require 'uri'
require 'cgi'
require 'net/https'
require 'active_support'

class Gixen
  class GixenError < RuntimeError
    def initialize(code, text)
      super(text)
      @code = code
      @message = text
    end

    attr_reader :code, :message

    def to_s
      "#{@code} - #{@message}"
    end
  end

  # :nodoc:
  CORE_GIXEN_URL='https://www.gixen.com/api.php'

  # Create a Gixen object for interacting with the user's Gixen
  # account, placing snipes, deleting snipes, and determining what
  # snipes have been set up.
  # 
  # * +user+ is the user's eBay username
  # * +pass+ is the user's eBay password
  # 
  # Gixen uses eBay authentication for its own authentication, so it
  # doesn't have to have a different user/pass for its users.
  def initialize(user, pass)
    @username = user
    @password = pass
  end

  private
  # :nodoc:
  def gixen_url
    "#{CORE_GIXEN_URL}?username=#{@username}&password=#{@password}&notags=1"
  end

  # :nodoc:
  def submit(params)
    url = "#{gixen_url}&#{params.to_param}"
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if uri.scheme == 'https' # enable SSL/TLS
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    http.ca_file = pem_file
    http.get("#{uri.path}?#{uri.query}")
  end

  def pem_file
    File.expand_path(File.dirname(__FILE__) + "/gixen.pem")
  end

  # :nodoc:
  def parse_response(resp)
    data = resp.body
    if data =~ /^ERROR \(([0-9]+)\): (.*)$/
      error_code = $1
      error_text = $2
      raise GixenError.new(error_code.to_i, error_text)
    end
  end

  public
  # Place a snipe on an +item+ (the auction item #) for +bid+ (string amount, for example "23.50", with no currency)
  #
  # Optional parameters include:
  # * <tt>snipegroup => {group number}</tt>, e.g. <tt>snipegroup => 1</tt> (default: 0, no groups used)
  # * <tt>quantity => {number}</tt> (default: 1, single item auction) <b>[_obsolete_]</b>
  # * <tt>bidoffset => {seconds before end}</tt> (3, 6, 8, 10 or 15. Default value is 6)
  # * <tt>bidoffsetmirror => {seconds before end}</tt> (same as above, just for mirror server)
  def snipe(item, bid, options = {})
    response = submit({:itemid => item, :maxbid => bid}.merge(options))
  end

  # Remove a snipe from an +item+ (the auction item #).
  def unsnipe(item)
    response = submit({:ditemid => item})
  end

  # Lists all snipes set on any Gixen server.
  def snipes
    response = main_snipes + mirror_snipes
  end

  # Lists all snipes currently set on Gixen's main server.
  def main_snipes
    response = submit({:listsnipesmain => 1})
    parse_response(response)
  end

  # List all snipes currently set on Gixen's mirror server.
  def mirror_snipes
    response = submit({:listsnipesmirror => 1})
  end

  # Normally the snipes that are completed are still listed when
  # retrieving snipes from the server; this method clears completed
  # listings, so the list of snipes is just active snipes.
  def purge
    response = submit({:purgecompleted => 1})
  end
end