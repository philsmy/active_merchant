module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class ChronopayGateway < Gateway
      TEST_URL = "https://secure.chronopay.com/gateway.cgi"
      LIVE_URL = "https://secure.chronopay.com/gateway.cgi"
      
      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['ES']
      
      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      
      # The homepage URL of the gateway
      self.homepage_url = 'http://www.chronopay.com/'
      
      # The name of the gateway
      self.display_name = 'Chronopay'
      
      APPROVED = 'Y'

      OPCODES = {
        :purchase => "1",
        :refund => "2",
        :initiate_recurring => "3",
        :initiate_pre_auth => "4",
        :void_pre_auth => "5",
        :confirm_pre_auth => "6",
        :cancel_future_recurring => "7",
        :customer_fund_transfer => "8"
      }

      def initialize(options = {})
        #requires!(options, :login, :password)
        @options = options
        super
      end  
      
      def authorize(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)        
        add_address(post, creditcard, options)        
        add_customer_data(post, options)
        
        commit('authonly', money, post)
      end
      
      def purchase(money, creditcard, options = {})
        requires!(options, :ip)

        post = {}
        add_amount(post, money, options)
        add_creditcard(post, creditcard)        
        add_address(post, creditcard, options)        
        add_customer_data(post, options)
             
        commit(:purchase, money, post)
      end                       
    
      def capture(money, authorization, options = {})
        commit('capture', money, post)
      end
    
      private                       
      
      def add_amount(post, money, options)
        add_pair(post, :amount, amount(money), :required => true)
        add_pair(post, :currency, options[:currency] || currency(money), :required => true)
      end

      def add_customer_data(post, options)
        add_pair(post, :email, options[:email][0,255]) unless options[:email].blank?
        add_pair(post, :ip, options[:ip]) unless options[:ip].blank?

        add_pair(post, :user_agent, options[:user_agent]) unless options[:user_agent].blank?
        add_pair(post, :screen_resolution, options[:screen_resolution]) unless options[:screen_resolution].blank?
        add_pair(post, :javascript_timedate, Time.now)
      end

      def add_address(post, creditcard, options)      
        address = options[:billing_address] || options[:address]
        shipping_address = options[:shipping_address] || ''
        
        return if address.blank?

        add_pair(post, :street, address[:address1])
        add_pair(post, :city, address[:city])
        add_pair(post, :country, address[:country])
      end

      def add_invoice(post, options)
      end
      
      def add_creditcard(post, creditcard)      
        c_name = creditcard.name.split
        f_name = c_name.shift
        l_name = c_name.join(" ")

        add_pair(post, :fname, f_name, :required => true)
        add_pair(post, :lname, l_name, :required => true)
        add_pair(post, :card_no, creditcard.number, :required => true)
         
        add_pair(post, :expirem, sprintf("%02d", creditcard.month), :required => true)
        add_pair(post, :expirey, sprintf("%04d", creditcard.year), :required => true)
         
        add_pair(post, :cvv, creditcard.verification_value)
      end
      
      def add_pair(post, key, value, options = {})
        post[key] = value if !value.blank? || options[:required]
      end

      # I believe that chronpay will only return a single line. (well, a blank line first, but stripped)
      # It will either be:
      # "N|Reason Things Didn't Work"
      # or
      # "Y|ID1|ID2<optional>"
      def parse(body)
        result = {}

        response = body.to_a
        response.shift
        unless response.blank?
          values = response[0].split("|")
          puts values.inspect
          result[:status] = values[0]
          if result[:status] == APPROVED
            result[:id1] = values[1] if values[1]
            result[:id2] = values[2] if values[2]
          else
            result[:error] = values[1] if values[1]
          end
          puts result.inspect
        end
        result
      end
      
      def commit(action, money, parameters)
        response = parse( ssl_post(TEST_URL, post_data(action, parameters)) )
          
        Response.new(response[:status] == APPROVED, message_from(response), response,
          :test => test?,
          :authorization => authorization_from(response)
        )
      end

      def message_from(response)
        response[:status] == APPROVED ? 'Success' : (response[:error] || 'Unspecified error')    # simonr 20080207 can't actually get non-nil blanks, so this is shorter
      end
      
      def authorization_from(response)
        response[:status] == APPROVED ? response[:id1] : nil
      end

      def post_data(action, parameters = {})
        parameters.update(
          :hash => compute_checksum(action, parameters),
          :opcode => OPCODES[action],
          :product_id => @options[:product_id]
        )
        
        parameters.collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
      end

      def compute_checksum(action, parameters = {})
        s = ""

        case action
        when :purchase
          s << @options[:shared_secret]
          s << OPCODES[action]
          s << @options[:product_id]
          s << parameters[:fname]
          s << parameters[:lname]
          s << parameters[:street]
          s << parameters[:ip]
          s << parameters[:card_no]
          s << parameters[:amount]
        end

        md5 = Digest::MD5.new
        md5 << s

        checksum = md5.hexdigest
      end
    end
  end
end

