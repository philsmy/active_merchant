require File.dirname(__FILE__) + '/../../test_helper'

class ChronopayTest < Test::Unit::TestCase
  def setup
    @gateway = ChronopayGateway.new(
                 :login => 'login',
                 :password => 'password',
                 :shared_secret => "qwertyuiop123456",
                 :product_id => "004704-0001-0001"
               )

    @credit_card = credit_card
    @amount = 100
    
    @options = { 
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase',
      :ip => "212.22.228.23"
    }
  end
  
  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    # assert_instance_of 
    assert_success response
    
    # Replace with authorization number from the successful response
    assert_equal '', response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  private
  
  # Place raw successful response from gateway here
  def successful_purchase_response
    "Y|1234"
  end
  
  # Place raw failed response from gateway here
  def failed_purchase_response
    "N|Big Error"
  end
end
