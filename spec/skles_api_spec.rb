require 'spec_helper'

describe StrongKeyLite::API do
  before :each do
    @client = mock('Savon::Client', request: nil, wsdl: mock('Savon::WSDL', soap_actions: [ :ping ]))
    Savon::Client.stub!(:new).and_return(@client)
    @response = mock('Soap::Response', :soap_fault? => false, :http_error? => false, soap_fault: nil, http_error: nil, to_hash: {})
    @skles = StrongKeyLite.new('http://test.host', 1, login: 'login', password: 'password')
  end

  describe "#ping" do
    before :each do
      @time = mock('Time')
      Time.stub!(:parse).and_return(@time)
      @client.should_receive(:request).once.with(:wsdl, :ping).and_return(@response)
    end

    it "should parse the ping response" do
      ping_response = <<-EOF
SKLES 1.0 (Build 40)
Hostname: demo.strongauth.com
Current time: Sat Nov 13 12:44:03 PST 2010
Up since: Mon Sep 27 20:58:05 PDT 2010
Well-known PAN: 1235711131719230
ENC: 8/19
DEC: 10/21
DEL: 1/1
SRC: 11/13
BAT: 0/0
SKLES Domain 21 is alive!
      EOF

      @response.stub(:to_hash).and_return(ping_response: { return: ping_response })
      @skles.ping.should eql({ version: "1.0", build: 40, hostname: "demo.strongauth.com",
                               current_time: @time, up_since: @time,
                               well_known_pan: 1235711131719230,
                               encryptions_since_startup: 8, encryptions_total: 19,
                               decryptions_since_startup: 10, decryptions_total: 21,
                               deletions_since_startup: 1, deletions_total: 1,
                               searches_since_startup: 11, searches_total: 13,
                               batch_operations_since_startup: 0, batch_operations_total: 0,
                               domain_id: 21 })
    end

    it "should not error if the response is malformed" do
      ping_response = <<-EOF
SKLES 1.0 (Build 40)
Hostname: demo.strongauth.com
Current time: Sat Nov 13 12:44:03 PST 2010
Up since: Mon Sep 27 20:58:05 PDT 2010
Well-known PAN: 1235711131719230
ENC: 8/19
DEL: 1/1
SRC: 11/13
BAT: 0/0
SKLES Domain 21 is alive!
      EOF

      @response.stub(:to_hash).and_return(ping_response: { return: ping_response })
      @skles.ping.should eql({ version: "1.0", build: 40, hostname: "demo.strongauth.com",
                               current_time: @time, up_since: @time,
                               well_known_pan: 1235711131719230,
                               encryptions_since_startup: 8, encryptions_total: 19,
                               deletions_since_startup: 1, deletions_total: 1,
                               searches_since_startup: 11, searches_total: 13,
                               batch_operations_since_startup: 0, batch_operations_total: 0,
                               domain_id: 21 })
    end
  end

  describe "#encrypt" do
    it "should make the appropriate API call" do
      @skles.stub!(:actions).and_return([ :encrypt ])
      @skles.add_user('login', 'password', :encrypt)

      @response.stub(:to_hash).and_return(encrypt_response: { return: '123456' })
      soap = mock('Savon::SOAP')
      soap.should_receive(:body=).once.with(hash_including(plaintext: 'plaintext'))
      
      @client.should_receive(:request).once.with(:wsdl, :encrypt).and_yield(soap).and_return(@response)

      @skles.encrypt('plaintext').should eql('123456')
    end
  end

  describe "#decrypt" do
    it "should make the appropriate API call" do
      @skles.stub!(:actions).and_return([ :decrypt ])
      @skles.add_user('login', 'password', :decrypt)

      @response.stub(:to_hash).and_return(decrypt_response: { return: 'plaintext' })
      soap = mock('Savon::SOAP')
      soap.should_receive(:body=).once.with(hash_including(token: '123456'))

      @client.should_receive(:request).once.with(:wsdl, :decrypt).and_yield(soap).and_return(@response)

      @skles.decrypt('123456').should eql('plaintext')
    end
  end

  describe "#delete" do
    it "should make the appropriate API call" do
      @skles.stub!(:actions).and_return([ :delete ])
      @skles.add_user('login', 'password', :delete)

      @response.stub(:to_hash).and_return(delete_response: { return: true })
      soap = mock('Savon::SOAP')
      soap.should_receive(:body=).once.with(hash_including(token: '123456'))

      @client.should_receive(:request).once.with(:wsdl, :delete).and_yield(soap).and_return(@response)

      @skles.delete('123456').should be_true
    end
  end

  describe "#search" do
    it "should make the appropriate API call" do
      @skles.stub!(:actions).and_return([ :search ])
      @skles.add_user('login', 'password', :search)

      @response.stub(:to_hash).and_return(search_response: { return: '123456' })
      soap = mock('Savon::SOAP')
      soap.should_receive(:body=).once.with(hash_including(plaintext: 'plaintext'))

      @client.should_receive(:request).once.with(:wsdl, :search).and_yield(soap).and_return(@response)

      @skles.search('plaintext').should eql('123456')
    end
  end
end
