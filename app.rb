require 'sinatra'
require 'slim'
require 'sqlite3'
require 'sinatra/reloader'
require 'bcrypt'
enable :sessions
set :public_folder, 'public'

before %r{/(profile|contact|questions|orders|checkout)} do
    redirect('/login') unless session[:logged_in]
end

before '/admin/*' do
    unless session[:logged_in] && session[:is_admin]
      redirect('/login')
    end
end
  
#HEM
get('/') do
    db = SQLite3::Database.new("db/webbshop.db")
    db.results_as_hash = true
    result = db.execute("SELECT * FROM products LIMIT 2") 

    slim(:"home/index", locals:{produkt:result})
end

get('/user/:id') do
    id = session[:id].to_i
    db = SQLite3::Database.new("db/webbshop.db")
    db.results_as_hash = true
    result = db.execute("SELECT * FROM users WHERE id = ?",id)
    p "användarnamn: #{result}"
    slim(:"profile/user_profile", locals:{users:result})
end

#LOGIN / REGISTRERING
get('/login') do
    slim(:login)
end

get('/users/new') do
    slim(:register)
end


post('/login') do
    username = params[:username]
    password = params[:password]
    db = SQLite3::Database.new("db/webbshop.db")
    db.results_as_hash = true
    result = db.execute("SELECT * FROM users WHERE username = ?", username).first

    if result.nil?
        return "Fel användarnamn"
    end

    pwdigest = result["pwdigest"]
    id = result["id"]
    username = result["username"]
    is_admin = result["is_admin"] == 1

    if BCrypt::Password.new(pwdigest) != password
        "Fel lösenord"
    else
        session[:id] = id
        session[:username] = username
        session[:logged_in] = true
        session[:is_admin] = is_admin  # ← Lägg till den här raden

        redirect("/user/#{id}")
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
        password_digest = BCrypt::Password.create(password)
      db = SQLite3::Database.new("db/webbshop.db")
      db.execute("INSERT INTO users (username,pwdigest,mail,telefon_nr) VALUES (?,?,?,?)",[username,password_digest,email,phone])
      redirect('/')
    end
end




#PRODUKTER

get('/products') do
    db = SQLite3::Database.new("db/webbshop.db")
    db.results_as_hash = true
    result = db.execute("SELECT * FROM products")

    slim(:"product/list", locals:{produkt:result})
end

#skicka med vilken row (produkt) från show_products, ändra sql
get('/products/:id') do
    id = params[:id].to_i
    db = SQLite3::Database.new("db/webbshop.db")
    db.results_as_hash = true
    result = db.execute("SELECT * FROM products WHERE id = ?",id).first

    slim(:"product/product_page", locals:{produkt:result})
end

#STATISKA SIDOR

get('/about') do
    slim(:"about/about_us")
end

get('/contact') do
    slim(:contact)
end

#KONTAKTFRÅGOR

get('/questions') do
    db = SQLite3::Database.new("db/webbshop.db")
    db.results_as_hash = true

    # Hämta alla frågor och svar (om de finns)
    questions = db.execute("SELECT * FROM questions ORDER BY created_at DESC")

    slim(:"questions/index.slim", locals: { questions: questions })
end

post('/questions') do
    name = params[:name]
    question = params[:question]
    user_id = session[:id]  # Hämta användarens id från sessionen
    created_at = Time.now.strftime('%Y-%m-%d %H:%M:%S')  # Skapa en tidsstämpel i korrekt format

    if name.empty? || question.empty?
        return "Namnet eller frågan får inte vara tomma!"
    end

    db = SQLite3::Database.new("db/webbshop.db")
    db.execute("INSERT INTO questions (user_id, name, question, created_at) VALUES (?, ?, ?, ?)", 
        [session[:id], name, question, created_at])
    redirect('/contact')  # Bekräftelse att frågan är skickad eller visa en tack-sida
end

#ADMIN KONTAKTER

get('/admin/questions') do

    db = SQLite3::Database.new("db/webbshop.db")
    db.results_as_hash = true

    # Hämta alla frågor som användare har skickat
    questions = db.execute("SELECT * FROM questions ORDER BY created_at DESC")

    slim(:"admin/questions", locals: { questions: questions })
end

get('/admin/questions/:id/answer') do

    question_id = params[:id] #ändrat från chatgpt !!!
    db = SQLite3::Database.new("db/webbshop.db")
    db.results_as_hash = true

    # Hämta frågan från databasen
    question = db.execute("SELECT * FROM questions WHERE id = ?", [question_id]).first

    slim(:answer_question, locals: { question: question })
end



post('/admin/questions/:id/answer') do

    question_id = params[:id]#ändrat från chatgpt !!!
    answer = params[:answer]

    # Om svaret är tomt, ge ett felmeddelande
    if answer.empty?
        return "Svaret får inte vara tomt!"
    end

    db = SQLite3::Database.new("db/webbshop.db")
    
    # Uppdatera frågan med svaret
    db.execute("UPDATE questions SET answer = ? WHERE id = ?", [answer, question_id])

    redirect('/admin/questions')  # Tillbaka till admin-sidan där alla frågor visas
end





#VARUKORG

get('/cart') do
    session[:cart] ||= {}  # Se till att session[:cart] alltid finns
    @cart = session[:cart].values  # Hämta alla produkter från sessionen direkt

    slim(:cart)  # byta namn till cart !!!!
end

post('/cart') do
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
    product = db.execute("SELECT * FROM products WHERE id = ?",product_id).first

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
    redirect("/products/#{product_id}")
end


get('/cart/clear') do
    session[:cart] = {}  # Nollställ varukorgen
    redirect('/cart')
end

#CHECKOUT / ORDER

get('/checkout') do
    
    session[:cart] ||= {}  # Se till att varukorgen alltid finns
    @cart = session[:cart].values  # Hämta varukorgen för att visa i formuläret

    slim(:checkout)  # Visa checkout-sidan
end

post('/orders') do

    name = params[:name]
    address = params[:address]
    phone = params[:phone]
    cart = session[:cart]  # Hämta beställningsdata från sessionen

    if cart.empty?
        redirect('/cart')  # Om varukorgen är tom, skicka tillbaka
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
    redirect('/orders/confirmation')  # Skicka till bekräftelsesida
end


get('/orders/confirmation') do
    # Kontrollera om användaren är inloggad

    db = SQLite3::Database.new("db/webbshop.db")
    db.results_as_hash = true

    order_id = session[:last_order_id]
    order = db.execute("SELECT * FROM orders WHERE id = ?", [order_id]).first
    order_items = db.execute(
        "SELECT order_items.*, products.namn AS produkt_namn
        FROM order_items
        JOIN products ON order_items.produkt_id = products.id
        WHERE order_items.order_id = ?", [order_id]
    )


    slim(:"order/confirmation", locals: { order: order, order_items: order_items })

end

#ADMIN ORDERS

get('/admin/orders') do
    # Kontrollera om användaren är inloggad och är admin

    db = SQLite3::Database.new("db/webbshop.db")
    db.results_as_hash = true

    # Hämta alla beställningar från databasen
    orders = db.execute("SELECT * FROM orders")

    slim(:"admin/orders", locals: { orders: orders })
end

get('/admin/orders/:id') do
    # Kontrollera om användaren är inloggad och är admin

    order_id = params[:id]
    db = SQLite3::Database.new("db/webbshop.db")
    db.results_as_hash = true

    # Hämta beställningen från databasen
    order = db.execute("SELECT * FROM orders WHERE id = ?", order_id).first

    # Hämta alla order_items för den beställningen
    order_items = db.execute("SELECT * FROM order_items WHERE order_id = ?", order_id)

    slim(:"order/details", locals: { order: order, order_items: order_items })
end
