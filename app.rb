require 'sinatra'
require 'slim'
require 'sqlite3'
require 'sinatra/reloader'
require 'bcrypt'
enable :sessions
set :public_folder, "public"
@logged_in = false

get('/home') do
    slim(:index)
end

get('/home/logged_in') do
    id = session[:id].to_i
    db = SQLite3::Database.new("db/webbshop.db")
    db.results_as_hash = true
    result = db.execute("SELECT * FROM users WHERE id = ?",id)
    p "användarnamn: #{result}"
    @logged_in = true
    slim(:mina_sidor, locals:{users:result})
end

get('/show_login') do
    slim(:login)
end

get('/register') do
    slim(:register)
end

post('/login') do
    username = params[:username]
    password = params[:password]
    db = SQLite3::Database.new("db/webbshop.db")
    db.results_as_hash = true
    result = db.execute("SELECT * FROM users WHERE username = ?",username).first
    pwdigest = result["pwdigest"]
    id = result["id"]
    username = result["username"]
  
    if (BCrypt::Password.new(pwdigest)) != password
        "Fel lösenord"
    #elsif username... (validera om username finns)
    else
        session[:id] = id
        session[:username] = username
        redirect('/home/logged_in')
      
    end
end

post('/users/new') do
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
        password_digest = BCrypt::Password.create(password)
      db = SQLite3::Database.new("db/webbshop.db")
      db.execute("INSERT INTO users (username,pwdigest,mail,telefon_nr) VALUES (?,?,?,?)",[username,password_digest,email,phone])
      redirect('/home')
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
get('/show_produkt/:id') do
    id = params[:id].to_i
    db = SQLite3::Database.new("db/webbshop.db")
    db.results_as_hash = true
    result = db.execute("SELECT * FROM produkt WHERE id = ?",id).first

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