require 'spec_helper'

describe StrongKeyLite do
  before :each do
    @client = mock('Savon::Client', request: nil)
    Savon::Client.stub!(:new).and_return(@client)
  end

  describe "#initialize" do
    it "should accept a host for the WSDL" do
      Savon::Client.should_receive(:new).once.with("http://test.host/strongkeyliteWAR/EncryptionService?wsdl").and_return(@client)
      StrongKeyLite.new('http://test.host', 1)
    end

    it "should set the domain ID" do
      StrongKeyLite.new('http://test.host', 15).domain_id.should eql(15)
    end

    it "should accept and apply HTTP options" do
      http = mock('Net::HTTP')
      request = mock('Savon::Request', http: http)
      @client.stub!(:request).and_return(request)

      http.should_receive(:timeout=).once.with(60)
      StrongKeyLite.new('http://test.host', 1, http: { timeout: 60 })
    end

    it "should optionally accept a login and password" do
      pending "Need a good way to test this"
    end
  end

  describe "#call" do
    before :each do
      @client = mock('Savon::Client', request: nil, wsdl: mock('Savon::WSDL', soap_actions: [ :ping ]))
      Savon::Client.stub!(:new).and_return(@client)
      @skles = StrongKeyLite.new('http://test.host', 1)

      @response = mock('Soap::Response', :soap_fault? => false, :http_error? => false, soap_fault: nil, http_error: nil, to_hash: {})
      @response.stub(:to_hash).and_return(ping_response: { return: '' })
    end

    it "should raise an error if no user has been assigned to the action" do
      -> { @skles.ping }.should raise_error(/No user/)
    end

    it "should invoke the proper action on the Savon client and use the appropriate user" do
      @skles.add_user('login', 'password', :ping)
      
      soap = mock('Savon::Request')
      soap.should_receive(:body=).once.with({ did: 1, username: 'login', password: 'password' })
      @client.should_receive(:ping).once.and_yield(soap).and_return(@response)
      @skles.ping
    end

    it "should assign a user to all actions when given :all" do
      @skles.add_user('all', 'password', :all)

      soap = mock('Savon::Request')
      soap.should_receive(:body=).once.with({ did: 1, username: 'all', password: 'password' })
      @client.should_receive(:ping).once.and_yield(soap).and_return(@response)
      @skles.ping
    end

    it "should replace an older user assigned to an action" do
      @skles.add_user('all', 'password', :all)
      @skles.add_user('ping', 'password', :ping)

      soap = mock('Savon::Request')
      soap.should_receive(:body=).once.with({ did: 1, username: 'ping', password: 'password' })
      @client.should_receive(:ping).once.and_yield(soap).and_return(@response)
      @skles.ping
    end
  end

  describe "#actions" do
    before :each do
      @wsdl = mock('Savon::WSDL')
      @client = mock('Savon::Client', request: nil, wsdl: @wsdl)
      Savon::Client.stub!(:new).and_return(@client)
      @skles = StrongKeyLite.new('http://test.host', 1)
    end

    it "should return a list of SOAP actions" do
      @wsdl.should_receive(:soap_actions).once.and_return([ :one, :two, :three ])
      @skles.actions.should eql([ :one, :two, :three ])
    end

    it "should cache the list" do
      @wsdl.should_receive(:soap_actions).once.and_return([ :one, :two, :three ])
      @skles.actions.should eql([ :one, :two, :three ])

      @wsdl.should_not_receive(:soap_actions)
      @skles.actions.should eql([ :one, :two, :three ])
    end
  end
end
