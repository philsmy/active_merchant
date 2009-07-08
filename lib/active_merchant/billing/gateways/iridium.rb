module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class IridiumGateway < Gateway
      TEST_URL = 'https://gw1.iridiumcorp.net/'
      LIVE_URL = 'https://gw1.iridiumcorp.net/'
      
      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['GB']
      self.default_currency = 'EUR'
      
      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      
      # The homepage URL of the gateway
      self.homepage_url = 'http://www.iridiumcorp.net/'
      
      # The name of the gateway
      self.display_name = 'Iridium'
      
      def initialize(options = {})
        #requires!(options, :login, :password)
        @options = options
        super
      end  
      
      def authorize(money, creditcard, options = {})
        post = {}
        
        options = options.merge(:transaction_type => "PREAUTH")
        options = options.merge(:xml_transaction_wrapper => 'CardDetailsTransaction')
        options = options.merge(:soap_action => "https://www.thepaymentgateway.net/CardDetailsTransaction")

        commit(build_purchase_request(money, creditcard, options), options)
      end
      
      def purchase(money, payment_source, options = {})
        setup_address_hash(options)
        
        options = options.merge(:transaction_type => "SALE")
        options = options.merge(:xml_transaction_wrapper => 'CardDetailsTransaction')
        options = options.merge(:soap_action => "https://www.thepaymentgateway.net/CardDetailsTransaction")

        # post = {}
        # add_invoice(post, options)
        # add_creditcard(post, creditcard)        
        # add_address(post, creditcard, options)   
        # add_customer_data(post, options)
        
        if payment_source.is_a?(CreditCard)
          commit(build_purchase_request(money, payment_source, options), options)
        else
          options = options.merge(:xml_transaction_wrapper => 'CrossReferenceTransaction')
          options = options.merge(:soap_action => "https://www.thepaymentgateway.net/CrossReferenceTransaction")

          commit(build_capture_request(money, payment_source, options), options)
        end
      end                       
    
      # NOTE: you only usually have about 7 days to do this before the token expires
      #  if you want a 'never ending' capture, use the purchase method, passing in the authorization
      def capture(money, authorization, options = {})
        options = options.merge(:transaction_type => "COLLECTION")
        options = options.merge(:xml_transaction_wrapper => 'CrossReferenceTransaction')
        options = options.merge(:soap_action => "https://www.thepaymentgateway.net/CrossReferenceTransaction")

        commit(build_capture_request(money, authorization, options), options)
      end
      
      # This is a kind of mock store.
      # It does a preauth (which is never settled) and you will get a cross reference in return
      # that can be passed to 'capture' for any amount at any time (within 380 days of initial storage)
      def store(creditcard, options = {})
        requires!(options, :order_id, :billing_address)
        money = 101
        options = options.merge(:order_id => "STORE-#{creditcard.last_digits}-#{Time.now.to_i}")
        options = options.merge(:transaction_type => "PREAUTH")
        options = options.merge(:xml_transaction_wrapper => 'CardDetailsTransaction')
        options = options.merge(:soap_action => "https://www.thepaymentgateway.net/CardDetailsTransaction")

        commit(build_purchase_request(money, creditcard, options), options)
      end
    
      private                       

      def setup_address_hash(options)
        options[:billing_address] = options[:billing_address] || options[:address] || {}
        options[:shipping_address] = options[:shipping_address] || {}
      end
      
      def add_customer_data(post, options)
      end

      def add_purchase_data(xml, money = 0, include_grand_total = false, options={})
        requires!(options, :transaction_type, :order_id)
        xml.tag! 'TransactionDetails', {'Amount' => money, 'CurrencyCode' => '978'} do
          xml.tag! 'MessageDetails', {'TransactionType' => options[:transaction_type]}
          xml.tag! 'OrderID', options[:order_id]
          xml.tag! 'TransactionControl' do
            xml.tag! 'ThreeDSecureOverridePolicy', 'False'
          end
          # xml.tag! 'currency', options[:currency] || currency(money)
          # xml.tag!('grandTotalAmount', amount(money))  if include_grand_total 
        end
      end

      def add_repurchase_data(xml, authorization, money = 0, include_grand_total = false, options={})
        requires!(options, :transaction_type, :order_id)
        xml.tag! 'TransactionDetails', {'Amount' => money, 'CurrencyCode' => '978'} do
          xml.tag! 'MessageDetails', {'TransactionType' => options[:transaction_type], 'CrossReference' => authorization}
          xml.tag! 'OrderID', options[:order_id]
          # xml.tag! 'currency', options[:currency] || currency(money)
          # xml.tag!('grandTotalAmount', amount(money))  if include_grand_total 
        end
      end

      def add_customerdetails(xml, creditcard, address, options, shipTo = false)
        
        country_code = CountryCodes.find_by_a2[address[:country]][:numeric] rescue 724 # rescue'd to Spain
        xml.tag! 'CustomerDetails' do
          xml.tag! 'BillingAddress' do
            xml.tag! 'Address1', address[:address1]
            xml.tag! 'Address2', address[:address2]
            # xml.tag! 'Address3', ""
            # xml.tag! 'Address4', ""
            xml.tag! 'City', address[:city]
            xml.tag! 'State', address[:state]
            xml.tag! 'PostCode', address[:zip]
            xml.tag! 'CountryCode', country_code
          end
          
          # xml.tag! 'EmailAddress', options[:email]
          # xml.tag! 'PhoneNumber', options[:telephone]
          # xml.tag! 'CustomerIPAddress', options[:ip]
        end   
      end

      def add_invoice(post, options)
      end
      
      def add_creditcard(xml, creditcard)      
        xml.tag! 'CardDetails' do
          xml.tag! 'CardName', creditcard.name
          xml.tag! 'CV2', creditcard.verification_value
          xml.tag! 'CardNumber', creditcard.number
          xml.tag! 'ExpiryDate', { 'Month' => creditcard.expiry_date.month.to_s.rjust(2, "0"), 'Year' => creditcard.expiry_date.year.to_s[/\d\d$/] }
        end
      end
      
      def add_merchant_data(xml, options)
        xml.tag! 'MerchantAuthentication', {"MerchantID" => @options[:login], "Password" => @options[:password]}
      end

      # Where we actually build the full SOAP request using builder
      def build_request(body, options)
        requires!(options, :xml_transaction_wrapper)
        xml = Builder::XmlMarkup.new :indent => 2
          xml.instruct!(:xml, :version => '1.0', :encoding => 'utf-8')
          xml.tag! 'soap:Envelope', { 'xmlns:soap' => 'http://schemas.xmlsoap.org/soap/envelope/', 
                                      'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance', 
                                      'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema'} do
            xml.tag! 'soap:Body' do
              xml.tag! options[:xml_transaction_wrapper], {'xmlns' => "https://www.thepaymentgateway.net/"} do
                xml.tag! 'PaymentMessage' do
                  add_merchant_data(xml, options)
                  xml << body
                end
              end
            end
          end
        xml.target! 
      end

      # Contact Iridium, make the SOAP request, and parse the reply into a Response object
      def commit(request, options)
        requires!(options, :soap_action)
        
        xml_str = build_request(request, options)
        RAILS_DEFAULT_LOGGER.debug "Sending: #{xml_str}"
	      response = parse(ssl_post(test? ? TEST_URL : LIVE_URL, build_request(request, options),
	                            {"SOAPAction" => options[:soap_action],
	                              "Content-Type" => "text/xml; charset=utf-8" }))
  
        RAILS_DEFAULT_LOGGER.debug "Response: #{response.inspect rescue ''}"
        
	      success = response[:transaction_result][:status_code] == "0"
	      message = response[:transaction_result][:message]
        authorization = success ? [ options[:order_id], response[:transaction_output_data][:cross_reference], response[:transaction_output_data][:auth_code] ].compact.join(";") : nil
        
        Response.new(success, message, response, 
          :test => test?, 
          :authorization => authorization,
          :avs_result => { :code => response[:avsCode] },
          :cvv_result => response[:cvCode]
        )
      end

      def message_from(response)
      end
      
      def post_data(action, parameters = {})
      end
      
      def build_purchase_request(money, creditcard, options)
        xml = Builder::XmlMarkup.new :indent => 2
        add_purchase_data(xml, money, true, options)
        add_creditcard(xml, creditcard)
        add_customerdetails(xml, creditcard, options[:billing_address], options)
        # add_purchase_service(xml, options)
        # add_business_rules_data(xml)
        xml.target!
      end
      
      def build_capture_request(money, authorization, options)
        order_id, cross_reference, auth_id = authorization.split(";")
        xml = Builder::XmlMarkup.new :indent => 2
        add_repurchase_data(xml, cross_reference, money, true, options)
        xml.target!
      end
      
      # Parse the SOAP response
      # Technique inspired by the Paypal Gateway
      def parse(xml)
        # puts "response:\n#{xml}"
        reply = {}
        xml = REXML::Document.new(xml)
        if (root = REXML::XPath.first(xml, "//CardDetailsTransactionResponse")) or
              (root = REXML::XPath.first(xml, "//CrossReferenceTransactionResponse"))
          root.elements.to_a.each do |node|
            case node.name  
            when 'Message'
              reply[:message] = reply(node.text)
            else
              parse_element(reply, node)
            end
          end
        elsif root = REXML::XPath.first(xml, "//soap:Fault") 
          parse_element(reply, root)
          reply[:message] = "#{reply[:faultcode]}: #{reply[:faultstring]}"
        end
        return reply
      end     

      def parse_element(reply, node)
        case node.name
        when "CrossReferenceTransactionResult"
          reply[:transaction_result] = {}
          node.attributes.each do |a,b|
            reply[:transaction_result][a.underscore.to_sym] = b
          end
          node.elements.each{|e| parse_element(reply[:transaction_result], e) } if node.has_elements?

        when "CardDetailsTransactionResult"
          reply[:transaction_result] = {}
          node.attributes.each do |a,b|
            reply[:transaction_result][a.underscore.to_sym] = b
          end
          node.elements.each{|e| parse_element(reply[:transaction_result], e) } if node.has_elements?
        when "TransactionOutputData"
          reply[:transaction_output_data] = {}
          node.attributes.each{|a,b| reply[:transaction_output_data][a.underscore.to_sym] = b }
          node.elements.each{|e| parse_element(reply[:transaction_output_data], e) } if node.has_elements?
        when "CustomVariables"
          reply[:custom_variables] = {}
          node.attributes.each{|a,b| reply[:custom_variables][a.underscore.to_sym] = b }
          node.elements.each{|e| parse_element(reply[:custom_variables], e) } if node.has_elements?
        when "GatewayEntryPoints"
          reply[:gateway_entry_points] = {}
          node.attributes.each{|a,b| reply[:gateway_entry_points][a.underscore.to_sym] = b }
          node.elements.each{|e| parse_element(reply[:gateway_entry_points], e) } if node.has_elements?
        else
          k = node.name.underscore.to_sym
          if node.has_elements?
            reply[k] = {}
            node.elements.each{|e| parse_element(reply[k], e) } 
          else
            if node.has_attributes?
              reply[k] = {}
              node.attributes.each{|a,b| reply[k][a.underscore.to_sym] = b }
            else
              reply[k] = node.text
            end
          end
        end
        return reply
      end
    end

    
  end
end

