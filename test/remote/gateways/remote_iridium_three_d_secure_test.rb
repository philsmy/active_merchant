require File.dirname(__FILE__) + '/../../test_helper'
require 'mechanize'

class RemoteIridiumThreeDSecureTest < Test::Unit::TestCase
  TEST_3D_PASSWORD = 'password'

  def setup
    @gateway = IridiumGateway.new(fixtures(:iridium).merge(:enable_3d_secure => true))

    @amex = CreditCard.new(
      :number => '374200000000004',
      :month => 12,
      :year => next_year,
      :verification_value => 4887,
      :first_name => 'Tekin',
      :last_name => 'Suleyman',
      :type => 'american_express'
    )
    
    @visa = CreditCard.new(
      :number => '4976350000006891',
      :month => 12,
      :year => 2012,
      :verification_value => 341,
      :first_name => 'Geoff',
      :last_name => 'Wayne',
      :type => 'visa'
    )
    
    @maestro = CreditCard.new(
      :number => '300000000000000004',
      :month => 12,
      :year => next_year,
      :start_month => 12,
      :start_year => next_year - 2,
      :verification_value => 123,
      :first_name => 'Tekin',
      :last_name => 'Suleyman',
      :type => 'maestro'
    )

    @solo = CreditCard.new(
      :number => '6334900000000005',
      :month => 6,
      :year => next_year,
      :issue_number => 1,
      :start_month => 12,
      :start_year => next_year - 2,
      :verification_value => 227,
      :first_name => 'Tekin',
      :last_name => 'Suleyman',
      :type => 'solo'
    )

    @mastercard = CreditCard.new(
      :number => '5100000000001907',
      :month => 12,
      :year => 2012,
      :verification_value => 654,
      :first_name => 'Jon',
      :last_name => 'Robb',
      :type => 'mastercard'
    )
    
    @electron = CreditCard.new(
      :number => '4508750000001908',
      :month => 12,
      :year => 2012,
      :verification_value => 159,
      :first_name => 'Timothy',
      :last_name => 'Taylor',
      :type => 'electron'
    )

    @declined_card = CreditCard.new(
      :number => '4111111111111111',
      :month => 9,
      :year => next_year,
      :first_name => 'Tekin',
      :last_name => 'Suleyman',
      :type => 'visa'
    )
  
    @options = { 
      :billing_address => { 
        :name => 'Jon Robb',
        :address1 => '9 Mount Orchard',
        :address2 => '',
        :city => "Tenbury Wells",
        :county => 'Worcestershire',
        :country => 'GB',
        :zip => 'WR15 8DW'
      },
      :shipping_address => { 
        :name => 'Tekin Suleyman',
        :address1 => '120 Grosvenor St',
        :city => "Manchester",
        :county => 'Greater Manchester',
        :country => 'GB',
        :zip => 'M1 7QW'
      },
      :order_id => generate_unique_id,
      :description => 'Store purchase',
      :ip => '86.150.65.37',
      :email => 'phil.smy@filmamora.com',
      :phone => '34679930870'
    }
    
    @amount = 100
  end

  def test_successful_three_d_secure_mastercard_purchase
    response = @gateway.purchase(@amount, @mastercard, @options)

    assert_failure response
    assert_3d_secure response
    
    pa_res, md = retrieve_and_submit_three_d_secure_form(response, TEST_3D_PASSWORD)
    three_d_secure_response = @gateway.three_d_complete(pa_res,md)
    
    assert_success three_d_secure_response
  end
  
  def test_successful_purchase_with_3d_secure_override
    @options = @options.merge(:skip_3d_secure => true)
    response = @gateway.purchase(@amount, @mastercard, @options)
    
    assert_success response
    assert !response.authorization.blank?
  end

  def test_successful_authorization_with_3d_secure_override
    @options = @options.merge(:skip_3d_secure => true)
    response = @gateway.authorize(@amount, @mastercard, @options)
    
    assert_success response
    assert !response.authorization.blank?
  end

  def test_successful_three_d_secure_mastercard_authorization
    response = @gateway.authorize(@amount, @mastercard, @options)

    assert_failure response
    assert_3d_secure response
    
    pa_res, md = retrieve_and_submit_three_d_secure_form(response, TEST_3D_PASSWORD)
    three_d_secure_response = @gateway.three_d_complete(pa_res,md)
    
    assert_success three_d_secure_response
  end

  # def test_successful_three_d_secure_visa_purchase
  #   response = @gateway.purchase(@amount, @visa, @options)
  # 
  #   assert_failure response
  #   assert_3d_secure response
  #   
  #   pa_res, md = retrieve_and_submit_three_d_secure_form(response, TEST_3D_PASSWORD)
  #   three_d_secure_response = @gateway.three_d_complete(pa_res,md)
  #   
  #   assert_success three_d_secure_response
  # end
  # 
  # def test_successful_three_d_secure_maestro_purchase
  #   response = @gateway.purchase(@amount, @maestro, @options)
  # 
  #   assert_failure response
  #   assert_3d_secure response
  #   
  #   pa_res, md = retrieve_and_submit_three_d_secure_form(response, TEST_3D_PASSWORD)
  #   three_d_secure_response = @gateway.three_d_complete(pa_res,md)
  #   
  #   assert_success three_d_secure_response
  # end
  # 
  # def test_successful_three_d_secure_amex_purchase
  #   response = @gateway.purchase(@amount, @amex, @options)
  # 
  #   assert_failure response
  #   assert_3d_secure response
  #   
  #   pa_res, md = retrieve_and_submit_three_d_secure_form(response, TEST_3D_PASSWORD)
  #   three_d_secure_response = @gateway.three_d_complete(pa_res,md)
  #   
  #   assert_success three_d_secure_response
  # end
  # 
  # def test_successful_three_d_secure_solo_purchase
  #   response = @gateway.purchase(@amount, @solo, @options)
  # 
  #   assert_failure response
  #   assert_3d_secure response
  #   
  #   pa_res, md = retrieve_and_submit_three_d_secure_form(response, TEST_3D_PASSWORD)
  #   three_d_secure_response = @gateway.three_d_complete(pa_res,md)
  #   
  #   assert_success three_d_secure_response
  # end
  # 
  # 
  # def test_successful_three_d_secure_electron_purchase
  #   response = @gateway.purchase(@amount, @electron, @options)
  # 
  #   assert_failure response
  #   assert_3d_secure response
  #   
  #   pa_res, md = retrieve_and_submit_three_d_secure_form(response, TEST_3D_PASSWORD)
  #   three_d_secure_response = @gateway.three_d_complete(pa_res,md)
  #   
  #   assert_success three_d_secure_response
  # end


  # def test_failed_three_d_secure_purchase
  #   response = @gateway.purchase(@amount, @mastercard, @options)
  # 
  #   assert_instance_of IridiumResponse, response
  # 
  #   assert_failure response
  #   assert_3d_secure response
  #   
  #   pa_res, md = retrieve_and_submit_three_d_secure_form(response, 'wrong password')
  #   three_d_secure_response = @gateway.three_d_complete(pa_res,md)
  #   
  #   assert_failure three_d_secure_response
  # end

  private
  
  def assert_3d_secure(response)
    assert response.three_d_secure?, "Response not 3D secure: #{response.inspect}"
  end
  
  # Uses mechanize to retrieve 3D secure page, fill in password, submit and retrieve the pa_res and md
  def retrieve_and_submit_three_d_secure_form(response, password)
    agent = WWW::Mechanize.new
    page = agent.post(response.acs_url, :MD => response.md, :PaReq => response.pa_req, :TermUrl => 'http://localhost')
    
    # puts page.inspect
    
    # page.forms[0].password = password
    # result = agent.submit(page.forms[1])
    
    # puts result.inspect
    
    [page.forms[1].PaRes,page.forms[1].MD]
  end
  
  def next_year
    Date.today.year + 1
  end
end
