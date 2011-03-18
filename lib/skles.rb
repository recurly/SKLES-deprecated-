require 'savon'
require File.dirname(__FILE__) + '/skles_extensions'
require File.dirname(__FILE__) + '/skles_api'

Savon.configure do |config|
  config.log = false # can't have plaintext CC #s being logged
  config.raise_errors = false # We have our own error raising
end

# Client for the StrongKey Lite Encryption System (SKLES) SOAP-based API. An
# instance of this API interfaces with your StrongKey Lite box to encrypt and
# decrypt credit card numbers into the vault.
#
# Since many StrongKey Lite setups use different logins to perform different
# tasks (e.g., a more secure login/password is used to decrypt credit cards than
# to encrypt them), this class supports storing multiple sets of credentials,
# choosing them depending on the operation being performed.
#
# @example Single-user SKLES interface for the test domain
#   skles = StrongKeyLite.new("https://demo.strongauth.com:8181",               # the URL to the demo StrongKey Lite service
#                             1,                                                # your domain ID
#                             login: 'mylogin', password: 'mypassword'          # your API user login and password for the demo box
#                             http: { verify_mode: OpenSSL::SSL::VERIFY_NONE }, # the demo service has an invalid cert, so we override cert verification
#
# @example Multi-user SKLES interface for a production domain
#   skles = StrongKeyLite.new("https://strongauth.company.com:8181", 15)
#   skles.add_user 'encrypt_only', 'thepassword', :encrypt, :batch_encrypt
#   skles.add_user 'decrypt', 'anotherpassword', :decrypt, :batch_decrypt

class StrongKeyLite
  include API

  # The domain ID of the StrongKey service.
  attr_accessor :domain_id

  # Creates a new client interface.
  #
  # @param [String] service_url The protocol, host, and port for your StrongKey
  #   Lite service; _e.g._, "http://demo.strongauth.com:8181"
  # @param [Fixnum] domain_id The domain ID.
  # @param [Hash] options Additional options.
  # @option options [String] :login You can provide the login of a user who will
  #   be used for all actions.
  # @option options [String] :password The password for this user.
  # @yield [http] HTTP configuration block.
  # @yieldparam [HTTPI::Request] http The HTTP request object, for configuring.
  #   See the HTTPI gem documentation for more information.
  #
  # @example Setting a custom timeout
  #   StrongKeyLite.new(url, domain) { |http| http.read_timeout = 60 }

  def initialize(service_url, domain_id, options={})
    @client = Savon::Client.new do |wsdl, http, wsse|
      wsdl.document = "#{service_url}/strongkeyliteWAR/EncryptionService?wsdl"
      yield http if block_given?
    end
    options[:http].each { |key, val| @client.request.http.send :"#{key}=", val } if options[:http].kind_of?(Hash)

    self.domain_id = domain_id

    @users = {}
    @users_for_action = {}

    add_user(options[:login], options[:password], :all) if options[:login] and options[:password]
  end

  # Adds a user by login and password. These users are used to perform API
  # actions.
  #
  # @overload add_user(login, password)
  #   Adds a user. You can tell the client to use this user for certain actions
  #   by calling {#set_user_for_actions}.
  # @overload add_user(login, password, action, ...)
  #   Adds a user and tells the client to use this user for the given list of
  #   actions.
  #   @param [Symbol] action An API action (such as @:ping@) that this user
  #     should be used to perform. Replaces the previous user assigned to this
  #     action.
  #   @raise [ArgumentError] If an unknown action is provided.
  # @overload add_user(login, password, :all)
  #   Adds a user and tells the client to use this user for all API actions.
  # @param [String] login The user's login.
  # @param [String] password The user's password.

  def add_user(login, password, *actions_for_user)
    @users[login] = password
    if actions_for_user == [ :all ] then
      actions.each { |action| set_user_for_action(login, action) }
    else
      actions_for_user.each { |action| set_user_for_action(login, action) }
    end
  end

  # @overload set_user_for_actions(login, action, ...)
  #   Tells the client to use this user for a list of actions. Calls made via
  #   the API of one of these actions will use this user. Replaces the previous
  #   user assigned to these actions.
  #   @param [String] login The user's login.
  #   @param [Symbol] the API action (such as @:ping@).
  # @raise [ArgumentError] If an unknown action is provided.

  def set_user_for_actions(login, *actions_for_user)
    actions.flatten!
    raise ArgumentError, "Unknown action(s): #{(actions_for_user - actions).join(',' )}" unless (actions_for_user - actions).empty?
    actions_for_user.each { |action| @users_for_action[action] = login }
  end
  alias_method :set_user_for_action, :set_user_for_actions

  # @return [Array<Symbol>] A list of actions that the API can perform.

  def actions
    @actions ||= @client.wsdl.soap_actions
  end

  # Makes an API call and returns the result as a hash. This method is the basis
  # of all the more high-level API methods.
  #
  # @param [Symbol] meth The API method.
  # @param [Hash] options The arguments for the API method. The @:did@,
  #   @:login@, and @:password@ arguments are set for you automatically.
  # @return [Hash] The response fields.
  # @raise [SOAPError] If a SOAP fault occurs.
  # @raise [HTTPError] If an HTTP error occurs.

  def call(meth, options={})
    raise ArgumentError, "Unknown action #{meth.inspect}" unless actions.include?(meth)

    login = @users_for_action[meth]
    raise "No user has been assigned to action #{meth.inspect}" unless login
    password = @users[login]
    
    response = @client.request(:wsdl, meth) { |soap| soap.body = { did: domain_id, username: login, password: password }.merge(options) }
    raise SOAPError.new(response.soap_fault, response) if response.soap_fault?
    raise HTTPError.new(response.http_error, response) if response.http_error?

    return response.to_hash
  end
  
  # Sets the HTTPI adapter to use for Savon. By default it's @:net_http@.
  #
  # @param [Symbol] adapter The HTTPI adapter to use.
  
  def self.http_adapter=(adapter)
    Savon.http_adapter = adapter
  end

  # Superclass of all {StrongKeyLite} exceptions.

  class ResponseError < StandardError

    # The @Savon::Response@ object resulting from the API call.
    attr_reader :response

    # @private
    def initialize(error, response)
      super error.to_s
      @response = response
    end
  end

  # Raised when SOAP responses indicate errors.

  class SOAPError < ResponseError
    attr_reader :code
    
    # @private
    def initialize(fault, response)
      super
      if code_match = fault.to_s.match(/SKL-ERR-(\d+)/) then
        @code = code_match[1].try(:to_i)
      end
    end
  end

  # Raised when @Net::HTTP@ returns a response other than 200 OK, or there is a
  # socket error.

  class HTTPError < ResponseError; end
end
