require File.dirname(__FILE__) + '/../../test_helper'

class RemoteChronopayTest < Test::Unit::TestCase
  def setup
    @gateway = ChronopayGateway.new(fixtures(:chronopay))
    
    @good_card = CreditCard.new(
      :number => '4111111111111111',
      :month => Time.now.advance(:months => 1).month,
      :year => Time.now.advance(:months => 1).year,
      :verification_value => 123,
      :first_name => 'Longbob',
      :last_name => 'Longsen',
      :type => :mastercard
    )
    
    @bad_card = CreditCard.new(
      :number => '4000000000000002',
      :month => Time.now.advance(:months => 1).month,
      :year => Time.now.advance(:months => 1).year,
      :verification_value => 123,
      :first_name => 'Longbob',
      :last_name => 'Longsen',
      :type => :mastercard
    )
    
    @purchase_options = { 
      :billing_address => { 
        :address1 => 'Santa Maria 23',
        :city => "La Linea",
        :state => "Cadiz",
        :country => "ES",
        :zip => '11300'
      },
      :email => "test@funnydomain.com",
      :ip => "222.244.15.13",
      :order_id => generate_unique_id,
      :description => 'Store purchase'
    }
    
    @amount = 100
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @good_card, @purchase_options)
    assert_success response
    assert response.test?
    assert !response.authorization.blank?
  end
  
end