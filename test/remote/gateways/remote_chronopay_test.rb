require File.dirname(__FILE__) + '/../../test_helper'

class RemoteChronopayTest < Test::Unit::TestCase
  

  def setup
    ActiveMerchant::Billing::Base.gateway_mode = :test

    @gateway = ChronopayGateway.new(fixtures(:chronopay))
    
    
    @amount = 100
    @credit_card = CreditCard.new(
      :number => '4111111111111111',
      :month => Time.now.advance(:months => 1).month,
      :year => Time.now.advance(:months => 1).year,
      :verification_value => 123,
      :first_name => 'Longbob',
      :last_name => 'Longsen',
      :type => :mastercard)

    @declined_card =   CreditCard.new(
        :number => '4000000000000002',
        :month => Time.now.advance(:months => 1).month,
        :year => Time.now.advance(:months => 1).year,
        :verification_value => 123,
        :first_name => 'Longbob',
        :last_name => 'Longsen',
        :type => :mastercard
      )
    
    address = { 
      :address1 => 'Santa Maria 23',
      :city => "La Linea",
      :state => "Cadiz",
      :country => "ES",
      :zip => '11300'
    }
    
    @options = { 
      :order_id => generate_unique_id,
      :billing_address => address,
      :description => 'Store Purchase',
      :ip => "222.244.15.13",
      :email => "test@funnydomain.com"
    }
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Declined by processing', response.message
  end

  def test_successful_purchase_and_recur
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Success', response.message
    assert response.authorization
    assert recur = @gateway.recurring(@amount, response.authorization)
    assert_success recur
    assert_equal 'Success', recur.message
  end

  def test_failed_recur
    assert response = @gateway.recurring(@amount, "12343234")
    assert_failure response
    assert_equal 'Incorrect input information', response.message
  end

  def test_authorize_and_capture
    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Success', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(amount, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, "12343234")
    assert_failure response
    assert_equal 'Unable to confirm preauthorisation', response.message.chomp
  end

  def test_authorize_and_capture
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Success', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_equal 'Success', capture.message
    assert_success capture
  end
  
  def test_authorize_and_void
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Success', auth.message
    assert auth.authorization
    assert void = @gateway.void(auth.authorization)
    assert_equal 'Success', void.message
    assert_success void
  end

  def xtest_invalid_login
    gateway = ChronopayGateway.new(
                :login => '',
                :password => ''
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'REPLACE WITH FAILURE MESSAGE', response.message
  end
end
