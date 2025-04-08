require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require_relative 'model'
enable :sessions

before do
  @user_logged_in = session[:user_id] != nil
end

get('/') do
  slim(:"home/index")
end

# AUTH
get('/register') do
  slim(:register)
end

post('/register') do
  register_user(params[:username], params[:password], params[:password_confirm])
end

get('/login') do
  slim(:login)
end

post('/login') do
  login_user(params[:username], params[:password])
end

get('/logout') do
  logout_user
end

# PROFILE
get('/profile') do
  protected!
  slim(:"profile/user_profile")
end

# PRODUCTS
get('/products') do
  @products = fetch_all_products
  slim(:"product/list")
end

get('/products/:id') do
  @product = fetch_product_by_id(params[:id])
  slim(:"product/product_page")
end

# CART & CHECKOUT
post('/cart/add/:id') do
  add_to_cart(params[:id].to_i)
end

get('/cart') do
  slim(:cart)
end

get('/checkout') do
  slim(:checkout)
end

# ORDER
post('/order/confirm') do
  create_order(session[:cart], session[:user_id])
end

get('/order/confirmation') do
  @order = fetch_latest_order(session[:user_id])
  slim(:"order/confirmation")
end

get('/order/:id') do
  @order = fetch_order_by_id(params[:id])
  slim(:"order/details")
end

# ADMIN
get('/admin/orders') do
  protected!
  admin_only!
  @orders = fetch_all_orders
  slim(:"admin/orders")
end

get('/admin/questions') do
  protected!
  admin_only!
  @questions = fetch_all_questions
  slim(:"admin/questions")
end

# QUESTIONS
get('/contact') do
  slim(:contact)
end

post('/questions') do
  create_question(params[:name], params[:email], params[:message])
end

get('/questions') do
  @questions = fetch_all_questions
  slim(:"contact/show_questions")
end

# ABOUT
get('/about') do
  slim(:"about/about_us")
end
