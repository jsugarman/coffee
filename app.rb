require 'sinatra'
require 'sinatra/multi_route'
require 'rest-client'

set :sessions, :coffee_shop_ip => ENV.fetch('COFFEE_SHOP_IP') { 'coffee_shop.com'}

get '/', '/order' do
  order_form
end

def order_form
  <<~HTML
    <form method=\"POST\", action=\"/order\">
      name: <br>
      <input type=\"text\" name=\"name\"><br>
      drink:<br>
      <input type=\"text\" name=\"drink\"><br>
      milk:<br>
      <input type=\"text\" name=\"milk\"><br>
      size:<br>
      <input type=\"text\" name=\"size\"><br>
      <br>
      <input type=\"submit\" value=\"Submit\">
    </form>
  HTML
end

def payment_form amount
  <<~HTML
    <form method=\"POST\", action=\"/payment\">
      cost: <br>
      £<input type=\"text\" name=\"amount\" value=\"#{amount}\" placeholder=\"£\"><br>
      <br>
      <input type=\"submit\" value=\"Pay\">
    </form>
  HTML
end

post '/payment' do
  # response = RestClient.post(
  #   payment_url,
  #   payment_xml(params),
  #   headers
  # )

  receipt = { paid: 1.50, date: Date.today }# TODO: response.receipt
  show_receipt receipt
end

# testing
post '/xml' do
  content_type 'text/xml'
  order_xml(params)
end

post '/order' do
  # curl -X POST http://172.16.7.209:8080/order -d @restbucks.xml -H "Content-Type: application/vnd.restbucks+xml" 
  # response = RestClient.post(
  #   order_url,
  #   order_xml(params),
  #   headers
  # )

  amount = 1.50 # TODO: response.amount
  payment_form(amount)
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
      <amount>#{options[:amout]}</amount>
      <cardholderName>#{options[:card_holder]}</cardholderName>
      <cardNumber>#{options[:card_number]}</cardNumber>
      <expiryMonth>#{options[:expiry_month]}</expiryMonth>
      <expiryYear>#{options[:expiry_year]}</expiryYear>
    </payment>
  XML
end

def show_receipt receipt
  <<~HTML
    TODO: Your receipt
    <br>
    Paid: £#{receipt[:paid]}
    <br>
    Date: #{receipt[:date]}
  HTML
end

def order_url
  'http://#{coffee_shop_ip}:8080/order'
end

def payment_url
  'http://#{coffee_shop_ip}:8080/payment'
end

def headers
  {
    content_type: 'application/vnd.restbucks+xml'
  }
end
