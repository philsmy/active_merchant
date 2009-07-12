require File.dirname(__FILE__) + '/../../test_helper'

class RemoteIridiumTest < Test::Unit::TestCase
  

  def setup
    @gateway = IridiumGateway.new(fixtures(:iridium))
    
    @amount = rand(100)
    @credit_card = credit_card('4976000000003436', {:verification_value => '452'})
    @threed_credit_card = credit_card('4976350000006891', {:verification_value => '341'})
    @declined_card = credit_card('4221690000004963')
    
    our_address = address(:address1 => "32 Edward Street", 
                          :address2 => "Camborne",
                          :state => "Cornwall",
                          :zip => "TR14 8PA",
                          :country => "826")
    @options = { 
      :order_id => generate_unique_id,
      :billing_address => our_address,
      :description => 'Store Purchase'
    }
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.authorization, response.authorization 
    assert response.message[/AuthCode/], response.message
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Card declined', response.message
  end

  def test_authorize_and_capture
    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert auth.message[/AuthCode/], auth.message
    assert auth.authorization
    assert capture = @gateway.capture(amount, auth.authorization, @options)
    assert_success capture
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '', @options)
    assert_failure response
    assert_equal 'Input Variable Errors', response.message
  end
  
  def test_successful_authorization
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert response.message[/AuthCode/], response.message
    assert_success response
    assert response.test?
    assert !response.authorization.blank?
  end

  def test_unsuccessful_authorization
    assert response = @gateway.authorize(@amount, @declined_card, @options)
    assert response.test?
    assert_equal 'Card declined', response.message
    assert_equal false,  response.success?
  end
  
  def test_successful_authorization_and_failed_capture
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert auth.message[/AuthCode/], auth.message

    assert capture = @gateway.capture(@amount + 10, auth.authorization, @options)
    assert_failure capture
    assert capture.message[/Amount exceeds that available for collection/]
  end

  def test_failed_capture_bad_auth_info
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert capture = @gateway.capture(@amount, "a;b;c", @options)
    assert_failure capture
  end
  
  def test_store_credit_card
    assert response = @gateway.store(@credit_card, @options)
    assert_success response
    assert response.message[/AuthCode/], response.message
    assert !response.authorization.blank?
    assert_not_nil response.authorization
  end
  
  def test_store_and_charge
    assert response = @gateway.store(@credit_card, @options)
    assert_success response
    assert response.message[/AuthCode/], response.message
    assert (token = response.authorization)
    
    assert purchase = @gateway.purchase(@amount, token, {:order_id => "Order-#{rand(100)}"})
    assert purchase.message[/AuthCode/], purchase.message
    assert_success purchase
    assert_not_nil purchase.authorization
  end

  #  Covered in the ThreeDSecure test script
  # def test_3d_secure
  #   assert purchase = @gateway.purchase(@amount, @threed_credit_card, @options)
  #   assert_failure purchase
  #   assert !purchase.params["transaction_output_data"][:three_d_secure_output_data][:acsurl].blank?, purchase.inspect
  #   assert !purchase.params["transaction_output_data"][:three_d_secure_output_data][:pa_req].blank?, purchase.inspect
  # end
  

  def test_invalid_login
    gateway = IridiumGateway.new(
                :login => '',
                :password => ''
              )
    
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Input Variable Errors', response.message
  end
end
