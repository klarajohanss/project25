require 'sinatra'
require 'slim'
require 'sqlite3'
require 'sinatra/reloader'
require 'bcrypt'
require_relative './model.rb'
enable :sessions
set :public_folder, 'public'
include Model

# Redirects users to the login page if they try to access protected routes without being logged in
before %r{/(profile|contact|questions|orders|checkout)} do
  redirect('/login') unless session[:logged_in]
end

# Redirects non-admin users to the login page if they try to access admin routes
before '/admin/*' do
  unless session[:logged_in] && session[:is_admin]
    redirect('/login')
  end
end

# Displays the landing page with products
#
# @return [String] The Slim view template for the home page with product details
get('/') do
  result = fetch_two_products  # Fetches two products from the database
  slim(:"home/index", locals:{produkt:result})
end

# Displays a user's profile page
#
# @param [Integer] id, The ID of the user
# @return [String] The Slim view template for the user's profile
get('/user/:id') do
  requested_id = params[:id].to_i
  owner_id = check_user_ownership(requested_id)  # Checks if the user owns the profile

  if owner_id == session[:id]
    result = find_user_by_id(requested_id)  # Fetches the user's details
    slim(:"users/show", locals:{users: result})
  else
    return "Aja baja inte hacka!"  # Displays a warning if the user is trying to hack
  end
end

# Displays the login page
#
# @return [String] The Slim view template for the login form
get('/login') do
  slim(:"users/login")
end

# Displays the user registration page
#
# @return [String] The Slim view template for the registration form
get('/users/new') do
  slim(:"users/register")
end

# Attempts to log a user in
#
# @param [String] username, The username for login
# @param [String] password, The password for login
# @return [String] A message indicating the result of the login attempt
post('/login') do
  cooldown_seconds = 5

  if session[:last_login_attempt] && Time.now - session[:last_login_attempt] < cooldown_seconds
    return "För många försök. Vänta några sekunder innan du försöker igen."  # Message for too many login attempts
  end

  session[:last_login_attempt] = Time.now

  username = params[:username]
  password = params[:password]
  result = find_user_by_username(username)  # Fetches the user by username

  if result.nil?
    return "Fel användarnamn"  # Error message for invalid username
  end

  if BCrypt::Password.new(result["pwdigest"]) != password
    return "Fel lösenord"  # Error message for invalid password
  else
    session[:id] = result["id"]
    session[:username] = result["username"]
    session[:logged_in] = true
    session[:is_admin] = result["is_admin"] == 1
    session.delete(:last_login_attempt)
    redirect("/user/#{result["id"]}")  # Redirects to the user's profile page
  end
end

# Logs out the user by clearing the session
#
# @return [String] Redirects to the home page after logging out
post('/logout') do
  session.clear
  redirect('/')
end

# Registers a new user
#
# @param [String] username, The username for the new user
# @param [String] password, The password for the new user
# @param [String] password_confirm, The confirmation of the password
# @param [String] email, The email address of the new user
# @param [String] phone, The phone number of the new user
# @return [String] A message indicating the result of the registration attempt
post('/users') do
  username = params[:username]
  password = params[:password]
  password_confirm = params[:password_confirm]
  email = params[:email]
  phone = params[:phone]

  if (password != password_confirm)
    "Lösenorden matchar inte..."  # Message for password mismatch
  elsif username.length <= 2
    "Ditt användarnamn måste innehålla minst 3 karaktärer"  # Error message for short username
  elsif !(email.include?("@"))
    "Din e-post måste innehålla @"  # Error message for invalid email format
  else
    create_user(username, password, email, phone)  # Creates the user in the database
    redirect('/')
  end
end

# Displays a list of all products
#
# @return [String] The Slim view template for the product listing page
get('/products') do
  result = fetch_all_products  # Fetches all products from the database
  slim(:"products/index", locals:{produkt:result})
end

# Displays a single product page
#
# @param [Integer] id, The ID of the product
# @return [String] The Slim view template for the product's details
get('/products/:id') do
  id = params[:id].to_i
  result = fetch_product_by_id(id)  # Fetches the product by ID
  slim(:"products/show", locals:{produkt:result})
end

# Displays the About Us page
#
# @return [String] The Slim view template for the about us page
get('/about') do
  slim(:"about/about_us")
end

# Displays the Contact page
#
# @return [String] The Slim view template for the contact page
get('/contact') do
  slim(:contact)
end

# Displays all contact questions
#
# @return [String] The Slim view template for the list of questions
get('/questions') do
  questions = fetch_all_questions  # Fetches all questions from the database
  slim(:"questions/index", locals: { questions: questions })
end

# Submits a new contact question
#
# @param [String] name, The name of the person asking the question
# @param [String] question, The question being asked
# @param [String] created_at, The timestamp when the question was created
# @return [String] Redirects to the contact page after submitting the question
post('/questions') do
  name = params[:name]
  question = params[:question]
  user_id = session[:id]
  created_at = Time.now.to_s
  add_question(user_id, name, question, created_at)  # Adds the question to the database
  redirect('/contact')
end

# Displays a list of all questions in the admin panel
#
# @return [String] The Slim view template for the admin panel's questions list
get('/admin/questions') do
  questions = fetch_all_questions  # Fetches all questions for the admin panel
  slim(:"questions/admin_index", locals: { questions: questions })
end

# Displays the answer form for a specific question in the admin panel
#
# @param [Integer] id, The ID of the question
# @return [String] The Slim view template for answering the question
get('/admin/questions/:id/answer') do
  question_id = params[:id]
  question = fetch_question_by_id(question_id)  # Fetches the question by ID
  slim(:"questions/answer", locals: { question: question })
end

# Submits an answer to a question in the admin panel
#
# @param [Integer] id, The ID of the question
# @param [String] answer, The answer to the question
# @return [String] Redirects to the admin questions list after submitting the answer
post('/admin/questions/:id/answer') do
  question_id = params[:id]
  answer = params[:answer]

  if answer.empty?
    return "Svaret får inte vara tomt!"  # Message for empty answer
  end

  update_question_answer(question_id, answer)  # Updates the question's answer in the database
  redirect('/admin/questions')
end

# Displays the shopping cart
#
# @return [String] The Slim view template for the shopping cart page
get('/cart') do
  session[:cart] ||= {}
  @cart = session[:cart].values
  slim(:cart)
end

# Adds a product to the shopping cart
#
# @param [Integer] quantity, The quantity of the product
# @param [Integer] product_id, The ID of the product
# @return [String] Redirects to the product page after adding to the cart
post('/cart') do
  quantity = params[:quantity].empty? ? 1 : params[:quantity].to_i
  product_id = params[:product_id].to_i
  session[:cart] ||= {}

  product = fetch_product_by_id(product_id)  # Fetches the product by ID

  if product
    if session[:cart].key?(product_id)
      session[:cart][product_id][:quantity] += quantity  # Increases quantity if the product is already in the cart
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

# Clears the shopping cart
#
# @return [String] Redirects to the cart page after clearing the cart
get('/cart/clear') do
  session[:cart] = {}
  redirect('/cart')
end

# Displays the checkout page
#
# @return [String] The Slim view template for the checkout page
get('/checkout') do
  session[:cart] ||= {}
  @cart = session[:cart].values
  slim(:checkout)
end

# Places an order and processes the checkout
#
# @param [String] name, The name of the customer
# @param [String] address, The shipping address of the customer
# @param [String] phone, The phone number of the customer
# @param [Hash] cart, The customer's cart containing products and quantities
# @return [String] Redirects to the order confirmation page after placing the order
post('/orders') do
  name = params[:name]
  address = params[:address]
  phone = params[:phone]
  cart = session[:cart]

  if cart.empty?
    redirect('/cart')  # Redirects to the cart if it's empty
  end

  order_id = create_order(session[:id], name, address, phone)  # Creates the order in the database
  session[:last_order_id] = order_id

  cart.each do |id, item|
    add_order_item(order_id, id, item[:quantity], item[:price])  # Adds each item to the order
  end

  session[:cart] = {}
  redirect('/orders/confirmation')
end

# Displays the order confirmation page
#
# @return [String] The Slim view template for the order confirmation page
get('/orders/confirmation') do
  order_id = session[:last_order_id]
  order = fetch_order_by_id(order_id)  # Fetches the order by ID
  order_items = fetch_order_items(order_id)  # Fetches the items for the order
  slim(:"orders/confirmation", locals: { order: order, order_items: order_items })
end

# Displays a list of all orders in the admin panel
#
# @return [String] The Slim view template for the admin panel's orders list
get('/admin/orders') do
  orders = fetch_all_orders  # Fetches all orders for the admin panel
  slim(:"orders/admin_index", locals: { orders: orders })
end

# Displays the details of a single order in the admin panel
#
# @param [Integer] id, The ID of the order
# @return [String] The Slim view template for the order's details in the admin panel
get('/admin/orders/:id') do
  order_id = params[:id]
  order = fetch_order_by_id(order_id)  # Fetches the order by ID
  order_items = fetch_order_items(order_id)  # Fetches the items for the order
  slim(:"orders/show", locals: { order: order, order_items: order_items })
end
