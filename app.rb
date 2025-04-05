require 'sinatra'
require 'slim'
require 'sqlite3'
require 'sinatra/reloader'
require 'bcrypt'
enable :sessions
set :public_folder, 'public'

get('/home') do
    db = SQLite3::Database.new("db/webbshop.db")
    db.results_as_hash = true
    result = db.execute("SELECT * FROM produkt LIMIT 2") 

    slim(:index, locals:{produkt:result})
end

get('/home/logged_in') do
    id = session[:id].to_i
    db = SQLite3::Database.new("db/webbshop.db")
    db.results_as_hash = true
    result = db.execute("SELECT * FROM users WHERE id = ?",id)
    p "användarnamn: #{result}"
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
        session[:logged_in] = true
        redirect('/home/logged_in')
      
    end
end

post('/logout') do
    session.clear
    redirect('/home')
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

#get('/show_varukorg') do
#    @cart = session[:cart] || {}
#    slim(:varukorg)
#end



get('/show_varukorg') do
    session[:cart] ||= {}  # Se till att session[:cart] alltid finns
    @cart = session[:cart].values  # Hämta alla produkter från sessionen direkt

    slim(:varukorg)  # Skicka till Slim för rendering
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

post('/update_cart') do
    if params[:quantity].empty?
        quantity = 1
    else
        quantity = params[:quantity].to_i
    end
    product_id = params[:product_id].to_i

    session[:cart] ||= {}

    # Hämta produktens namn och pris från databasen och spara i sessionen
    db = SQLite3::Database.new("db/webbshop.db")
    db.results_as_hash = true
    product = db.execute("SELECT * FROM produkt WHERE id = ?",product_id).first

    if product
        # Uppdatera kvantiteten om produkten finns i varukorgen, annars lägg till den
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

    # Redirect tillbaka till produktens sida
    redirect "/show_produkt/#{product_id}"
end


get('/clear_cart') do
    session[:cart] = {}  # Nollställ varukorgen
    redirect '/show_varukorg'
end


get('/checkout') do
    redirect('/show_login') unless session[:logged_in]  
    
    session[:cart] ||= {}  # Se till att varukorgen alltid finns
    @cart = session[:cart].values  # Hämta varukorgen för att visa i formuläret

    slim(:checkout)  # Visa checkout-sidan
end

post('/place_order') do
    redirect('/show_login') unless session[:logged_in]  # Säkerställ att användaren är inloggad

    name = params[:name]
    address = params[:address]
    phone = params[:phone]
    cart = session[:cart]  # Hämta beställningsdata från sessionen

    if cart.empty?
        redirect('/show_varukorg')  # Om varukorgen är tom, skicka tillbaka
    end

    db = SQLite3::Database.new("db/webbshop.db")
    db.execute("INSERT INTO orders (user_id, namn, adress, tel_nr) VALUES (?,?,?,?)", [session[:id], name, address, phone])
    
    order_id = db.last_insert_row_id  # Hämta senaste order-ID
    session[:last_order_id] = order_id

    cart.each do |id, item|
        db.execute("INSERT INTO order_items (order_id, produkt_id, kvantitet, pris) VALUES (?,?,?,?)",[order_id,id,item[:quantity],item[:price]])
        #db.execute("INSERT INTO users (username,pwdigest,mail,telefon_nr) VALUES (?,?,?,?)",[username,password_digest,email,phone])
    end

    #puts "Inserting into beställning: #{name}, #{address}, #{phone}"
    #puts "Order ID after insert: #{order_id}"
    #puts "Cart contents: #{cart}"

    session[:cart] = {}  # Töm varukorgen efter beställning
    redirect('/order_confirmation')  # Skicka till bekräftelsesida
end


get('/order_confirmation') do
    # Kontrollera om användaren är inloggad
    redirect('/show_login') unless session[:logged_in]

    db = SQLite3::Database.new("db/webbshop.db")
    db.results_as_hash = true

    order_id = session[:last_order_id]
    order = db.execute("SELECT * FROM orders WHERE id = ?", [order_id]).first
    order_items = db.execute(
        "SELECT order_items.*, produkt.namn AS produkt_namn
        FROM order_items
        JOIN produkt ON order_items.produkt_id = produkt.id
        WHERE order_items.order_id = ?", [order_id]
    )


    slim(:order_confirmation, locals: { order: order, order_items: order_items })

end
