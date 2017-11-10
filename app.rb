require 'sinatra'
require 'sinatra/multi_route'
require 'rest-client'
require 'byebug'
require 'pry'
require 'nokogiri'
require 'awesome_print'
require 'forwardable'

get '/', '/order' do
  order_form
end

def order_form
  <<~HTML
    <form method=\"POST\", action=\"/order\">
      name: <br>
      <input type=\"text\" name=\"name\" value=\"Joel\"><br>
      drink:<br>
      <input type=\"text\" name=\"drink\" value=\"Latte\"><br>
      milk:<br>
      <input type=\"text\" name=\"milk\" value=\"Whole\"><br>
      size:<br>
      <input type=\"text\" name=\"size\" value=\"Large\"><br>
      <br>
      <input type=\"submit\" value=\"Submit\">
    </form>
  HTML
end

def payment_form cost, payment_url
  <<~HTML
    <form method=\"POST\", action=\"/payment\">
      cost: <br>
      £<input type=\"text\" name=\"amount\" value=\"#{cost}\" placeholder=\"£\"><br>
      <br>
      <input type="hidden" name="payment_url" value=\"#{payment_url}\">
      <input type=\"submit\" value=\"Pay\">
    </form>
  HTML
end

# testing
post '/xml' do
  content_type 'text/xml'
  order_xml(params)
end

post '/order' do
  response = RestClient::Request.execute(
    method: :post,
    url: order_url,
    payload: order_xml(params),
    headers: { content_type: 'application/vnd.restbucks+xml' }
  )
  order = XMLParser.new(response.body)
  payment_form(order.cost, order.payment_url)
end

post '/payment' do
  response = RestClient::Request.execute(
    method: :put,
    url: params[:payment_url],
    payload: payment_xml(params),
    headers: { content_type: 'application/vnd.restbucks+xml' }
  )
  @receipt = XMLParser.new(response.body)
  show_and_delete_receipt @receipt
end

def order_xml options
  <<~XML
    <order xmlns=\"http://schemas.restbucks.com\">
      <name>#{options[:name]}</name>
      <item>
        <milk>#{options[:milk]}</milk>
        <size>#{options[:size]}</size>
        <drink>#{options[:drink]}</drink>
      </item>
      <location>takeaway</location>
    </order>
  XML
end

def payment_xml options
  <<~XML
    <payment xmlns="http://schemas.restbucks.com">
      <amount>#{options[:amount]}</amount>
      <cardholderName>#{options[:card_holder]}</cardholderName>
      <cardNumber>#{options[:card_number]}</cardNumber>
      <expiryMonth>#{options[:expiry_month]}</expiryMonth>
      <expiryYear>#{options[:expiry_year]}</expiryYear>
    </payment>
  XML
end

def show_and_delete_receipt receipt
  order = Order.new(receipt.url)
  wait_til_ready(order)

  response = RestClient::Request.execute(
    method: :delete,
    url: receipt.url,
    headers: { content_type: 'application/vnd.restbucks+xml' }
  )

  <<~HTML
    Received: £#{receipt.amount}<br>
    Date: #{receipt.paid}<br>
  HTML
end

  def receipt receipt_url
    response = RestClient::Request.execute(
      method: :get,
      url: receipt_url,
      headers: { content_type: 'application/vnd.restbucks+xml' }
    )
    XMLParser.new(response.body)
  end

  def wait_til_ready order
    if order.status == 'ready'
      true
    else
      sleep 1
      wait_til_ready(order)
    end
  end

def coffee_shop_ip
  ENV.fetch('COFFEE_SHOP_IP') || 'coffee_shop.com'
end

def order_url
  "http://#{coffee_shop_ip}:8080/order"
end

class Order
  extend Forwardable
  def_delegators :@order, :name, :location, :cost, :status

  attr_reader :order

  def initialize url
    @order = get(url)
  end

  def get(url)
    response = RestClient::Request.execute(
      method: :get,
      url: url,
      headers: { content_type: 'application/vnd.restbucks+xml' }
    )
    XMLParser.new(response.body)
  end

  def update
    response = RestClient::Request.execute(
      method: :post, # yes a post, not put...for now
      url: url,
      payload: order_update_xml,
      headers: { content_type: 'application/vnd.restbucks+xml' }
    )
    XMLParser.new(response.body)
  end

  def items
    # TODO: enumerate one or more <item> entries
  end

  def url
    @order.url('order')
  end

  private

  def order_update_xml
    # TODO: yet to be implemented
  end
end

class Receipt
  extend Forwardable
  def_delegators :@receipt, :paid, :amount

  attr_reader :receipt

  def initialize url
    @receipt = get(url)
  end

  def get url
    response = RestClient::Request.execute(
      method: :get,
      url: url,
      headers: { content_type: 'application/vnd.restbucks+xml' }
    )
    XMLParser.new(response.body)
  end

  def delete
    response = RestClient::Request.execute(
      method: :delete,
      url: url,
      headers: { content_type: 'application/vnd.restbucks+xml' }
    )
    XMLParser.new(response.body)
  end

  def url
    @receipt.url('receipt')
  end
end

class XMLParser
  attr_reader :xml

  def initialize(xml)
    @xml = Nokogiri::HTML::parse xml
  end

  def links
    xml.xpath('//link').map { |link| link }
  end

  def actions
    xml.xpath('//link').each_with_object({}) { |link, memo| memo.merge!(link['rel'] => link['uri']) }
  end

  def url name = nil
    actions.map { |k,v| v if k.match?("/#{name}/") }.compact.first unless name.nil?
  end

  def method_missing(method, *args, &block)
    result = xml.xpath("//#{method}").text
    result.nil? ? super : result
  end
end

# Possible response stubs
#

# POST order
# <?xml version="1.0" encoding="UTF-8" standalone="yes"?><ns2:order xmlns:ns2="http://schemas.restbucks.com" xmlns:ns3="http://schemas.restbucks.com/dap"><ns3:link rel="http://relations.restbucks.com/cancel" uri="http://$COFFEE_SHOP_IP:8080/order/658b0cae-e9d7-4712-a7a4-a5432593be65" mediaType="application/vnd.restbucks+xml"/><ns3:link rel="http://relations.restbucks.com/payment" uri="http://$COFFEE_SHOP_IP:8080/payment/658b0cae-e9d7-4712-a7a4-a5432593be65" mediaType="application/vnd.restbucks+xml"/><ns3:link rel="http://relations.restbucks.com/update" uri="http://$COFFEE_SHOP_IP:8080/order/658b0cae-e9d7-4712-a7a4-a5432593be65" mediaType="application/vnd.restbucks+xml"/><ns3:link rel="self" uri="http://$COFFEE_SHOP_IP:8080/order/658b0cae-e9d7-4712-a7a4-a5432593be65" mediaType="application/vnd.restbucks+xml"/><ns2:name>Joel</ns2:name><ns2:item><ns2:milk>whole</ns2:milk><ns2:size>small</ns2:size><ns2:drink>espresso</ns2:drink></ns2:item><ns2:location>takeaway</ns2:location><ns2:cost>1.50</ns2:cost><ns2:status>unpaid</ns2:status></ns2:order>

# PUT payment
# <?xml version="1.0" encoding="UTF-8" standalone="yes"?><ns2:payment xmlns="http://schemas.restbucks.com/dap" xmlns:ns2="http://schemas.restbucks.com"><link rel="http://relations.restbucks.com/order" uri="http://$COFFEE_SHOP_IP:8080/order/658b0cae-e9d7-4712-a7a4-a5432593be65" mediaType="application/vnd.restbucks+xml"/><link rel="http://relations.restbucks.com/receipt" uri="http://$COFFEE_SHOP_IP:8080/receipt/658b0cae-e9d7-4712-a7a4-a5432593be65" mediaType="application/vnd.restbucks+xml"/><ns2:amount>1.51</ns2:amount><ns2:cardholderName>Joel</ns2:cardholderName><ns2:cardNumber>whichever</ns2:cardNumber><ns2:expiryMonth>5</ns2:expiryMonth><ns2:expiryYear>19</ns2:expiryYear></ns2:payment>

# GET order
# <?xml version="1.0" encoding="UTF-8" standalone="yes"?><ns2:order xmlns:ns2="http://schemas.restbucks.com" xmlns:ns3="http://schemas.restbucks.com/dap"><ns3:link rel="self" uri="http://$COFFEE_SHOP_IP:8080/order/658b0cae-e9d7-4712-a7a4-a5432593be65" mediaType="application/vnd.restbucks+xml"/><ns2:name>Joel</ns2:name><ns2:item><ns2:milk>whole</ns2:milk><ns2:size>small</ns2:size><ns2:drink>espresso</ns2:drink></ns2:item><ns2:location>takeaway</ns2:location><ns2:cost>1.50</ns2:cost><ns2:status>preparing</ns2:status></ns2:order>

# DELETE order
# <?xml version="1.0" encoding="UTF-8" standalone="yes"?><ns2:order xmlns:ns2="http://schemas.restbucks.com" xmlns:ns3="http://schemas.restbucks.com/dap"><ns2:name>Joel</ns2:name><ns2:item><ns2:milk>whole</ns2:milk><ns2:size>small</ns2:size><ns2:drink>espresso</ns2:drink></ns2:item><ns2:location>takeaway</ns2:location><ns2:cost>1.50</ns2:cost><ns2:status>taken</ns2:status></ns2:order>

# GET receipt
# <?xml version="1.0" encoding="UTF-8" standalone="yes"?><ns2:receipt xmlns="http://schemas.restbucks.com/dap" xmlns:ns2="http://schemas.restbucks.com"><link rel="http://relations.restbucks.com/order" uri="http://$COFFEE_SHOP_IP:8080/order/658b0cae-e9d7-4712-a7a4-a5432593be65" mediaType="application/vnd.restbucks+xml"/><ns2:amount>1.51</ns2:amount><ns2:paid>2017-11-09T14:08:26.892Z</ns2:paid></ns2:receipt>
