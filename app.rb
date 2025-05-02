require 'sinatra'
require 'slim'
require 'sqlite3'
require 'sinatra/reloader'
require 'bcrypt'
require_relative './model.rb'
enable :sessions
set :public_folder, 'public'
include Model

before %r{/(profile|contact|questions|orders|checkout)} do
  redirect('/login') unless session[:logged_in]
end

before '/admin/*' do
  unless session[:logged_in] && session[:is_admin]
    redirect('/login')
  end
end

# HEM
get('/') do
  result = fetch_two_products  # Flyttad till model.rb
  slim(:"home/index", locals:{produkt:result})
end

get('/user/:id') do
  requested_id = params[:id].to_i
  owner_id = check_user_ownership(requested_id)  # Flyttad till model.rb

  if owner_id == session[:id]
    result = find_user_by_id(requested_id)  # Flyttad till model.rb
    slim(:"users/show", locals:{users: result})
  else
    return "Aja baja inte hacka!"
  end
end

# LOGIN / REGISTRERING
get('/login') do
  slim(:"users/login")
end

get('/users/new') do
  slim(:"users/register")
end

post('/login') do
  cooldown_seconds = 5

  if session[:last_login_attempt] && Time.now - session[:last_login_attempt] < cooldown_seconds
    return "För många försök. Vänta några sekunder innan du försöker igen."
  end

  session[:last_login_attempt] = Time.now

  username = params[:username]
  password = params[:password]
  result = find_user_by_username(username)  # Flyttad till model.rb

  if result.nil?
    return "Fel användarnamn"
  end

  if BCrypt::Password.new(result["pwdigest"]) != password
    return "Fel lösenord"
  else
    session[:id] = result["id"]
    session[:username] = result["username"]
    session[:logged_in] = true
    session[:is_admin] = result["is_admin"] == 1
    session.delete(:last_login_attempt)
    redirect("/user/#{result["id"]}")
  end
end

post('/logout') do
  session.clear
  redirect('/')
end

post('/users') do
  username = params[:username]
  password = params[:password]
  password_confirm = params[:password_confirm]
  email = params[:email]
  phone = params[:phone]

  if (password != password_confirm)
    "Lösenorden matchar inte..."
  elsif username.length <= 2
    "Ditt användarnamn måste innehålla minst 3 karaktärer"
  elsif !(email.include?("@"))
    "Din e-post måste innehålla @"
  else
    create_user(username, password, email, phone)  # Flyttad till model.rb
    redirect('/')
  end
end

# PRODUKTER
get('/products') do
  result = fetch_all_products  # Flyttad till model.rb
  slim(:"products/index", locals:{produkt:result})
end

get('/products/:id') do
  id = params[:id].to_i
  result = fetch_product_by_id(id)  # Flyttad till model.rb
  slim(:"products/show", locals:{produkt:result})
end

# STATISKA SIDOR
get('/about') do
  slim(:"about/about_us")
end

get('/contact') do
  slim(:contact)
end

# KONTAKTFRÅGOR
get('/questions') do
  questions = fetch_all_questions  # Flyttad till model.rb
  slim(:"questions/index", locals: { questions: questions })
end

post('/questions') do
  name = params[:name]
  question = params[:question]
  user_id = session[:id]
  created_at = Time.now.to_s
  add_question(user_id, name, question, created_at)  # Flyttad till model.rb
  redirect('/contact')
end

# ADMIN KONTAKTER
get('/admin/questions') do
  questions = fetch_all_questions  # Återanvänder
  slim(:"questions/admin_index", locals: { questions: questions })
end

get('/admin/questions/:id/answer') do
  question_id = params[:id]
  question = fetch_question_by_id(question_id)  # Flyttad till model.rb
  slim(:"questions/answer", locals: { question: question })
end

post('/admin/questions/:id/answer') do
  question_id = params[:id]
  answer = params[:answer]

  if answer.empty?
    return "Svaret får inte vara tomt!"
  end

  update_question_answer(question_id, answer)  # Flyttad till model.rb
  redirect('/admin/questions')
end

# VARUKORG
get('/cart') do
  session[:cart] ||= {}
  @cart = session[:cart].values
  slim(:cart)
end

post('/cart') do
  quantity = params[:quantity].empty? ? 1 : params[:quantity].to_i
  product_id = params[:product_id].to_i
  session[:cart] ||= {}

  product = fetch_product_by_id(product_id)  # Flyttad till model.rb

  if product
    if session[:cart].key?(product_id)
      session[:cart][product_id][:quantity] += quantity
    else
      session[:cart][product_id] = {
        name: product["namn"], 
        quantity: quantity, 
        price: product["pris"],
        image_url: product["img_url"]
      }
    end
  end

  redirect("/products/#{product_id}")
end

get('/cart/clear') do
  session[:cart] = {}
  redirect('/cart')
end

# CHECKOUT / ORDER
get('/checkout') do
  session[:cart] ||= {}
  @cart = session[:cart].values
  slim(:checkout)
end

post('/orders') do
  name = params[:name]
  address = params[:address]
  phone = params[:phone]
  cart = session[:cart]

  if cart.empty?
    redirect('/cart')
  end

  order_id = create_order(session[:id], name, address, phone)  # Flyttad till model.rb
  session[:last_order_id] = order_id

  cart.each do |id, item|
    add_order_item(order_id, id, item[:quantity], item[:price])  # Flyttad till model.rb
  end

  session[:cart] = {}
  redirect('/orders/confirmation')
end

get('/orders/confirmation') do
  order_id = session[:last_order_id]
  order = fetch_order_by_id(order_id)  # Flyttad till model.rb
  order_items = fetch_order_items(order_id)  # Flyttad till model.rb
  slim(:"orders/confirmation", locals: { order: order, order_items: order_items })
end

# ADMIN ORDERS
get('/admin/orders') do
  orders = fetch_all_orders  # Flyttad till model.rb
  slim(:"orders/admin_index", locals: { orders: orders })
end

get('/admin/orders/:id') do
  order_id = params[:id]
  order = fetch_order_by_id(order_id)  # Flyttad till model.rb
  order_items = fetch_order_items(order_id)  # Flyttad till model.rb
  slim(:"orders/show", locals: { order: order, order_items: order_items })
end
