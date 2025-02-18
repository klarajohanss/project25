require 'sinatra'
require 'slim'
require 'sqlite3'
require 'sinatra/reloader'
require 'bcrypt'
enable :sessions
set :public_folder, "public"

get('/home') do
    slim(:index)
end

get('/show_login') do
    slim(:login)
end

post('/login') do
    username = params[:username]
    password = params[:password]
    db = SQLite3::Database.new("db/webbshop.db")
    db.results_as_hash = true
    result = db.execute("SELECT * FROM users WHERE username = ?",username).first
    pwdigest = result["pwdigest"]
    id = result["id"]
  
    if (BCrypt::Password.new(pwdigest)) == password
      session[:id] = id
      redirect('/index')
    else
      "Wrong password"
    end
end

post('/users/new') do
    username = params[:username]
    password = params[:password]
    password_confirm = params[:password_confirm]
  
    if (password == password_confirm)
      password_digest = BCrypt::Password.create(password)
      db = SQLite3::Database.new("db/webbshop.db")
      db.execute("INSERT INTO users (username,pwdigest) VALUES (?,?)",[username,password_digest])
      redirect('/')
    else
      "Passwords do not match..."
    end
end

get('/show_varukorg') do
    slim(:varukorg)
end

get('/show_produkter') do
    db = SQLite3::Database.new("db/webbshop.db")
    db.results_as_hash = true
    result = db.execute("SELECT * FROM produkt")

    slim(:produkter, locals:{produkt:result})
end

#skicka med vilken row (produkt) från show_products, ändra sql
get('/show_produkt') do
    db = SQLite3::Database.new("db/webbshop.db")
    db.results_as_hash = true
    result = db.execute("SELECT * FROM produkt")

    slim(:produkt, locals:{produkt:result})
end

get('/show_om_oss') do
    slim(:om_oss)
end

get('/show_kontakt') do
    slim(:kontakt)
end

#:id nedanför istället för namn
#post('#{produkt['namn']}/update_cart') do
 #   redirect('/show_produkt')
#end