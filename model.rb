require 'sqlite3'

def connect_to_db
    db = SQLite3::Database.new("db/webbshop.db")
    db.results_as_hash = true
    db
end

def get_featured_products
    db = connect_to_db
    db.execute("SELECT * FROM produkt LIMIT 2")
end

def find_user_by_id(id)
    db = connect_to_db
    db.execute("SELECT * FROM users WHERE id = ?", id).first
end

def register_user(username, password_digest, email, phone)
    db = connect_to_db
    db.execute("INSERT INTO users (username, pwdigest, mail, telefon_nr) VALUES (?,?,?,?)", [username, password_digest, email, phone])
end

def find_user_by_username(username)
    db = connect_to_db
    db.execute("SELECT * FROM users WHERE username = ?", username).first
end

def get_all_products
    db = connect_to_db
    db.execute("SELECT * FROM produkt")
end

def get_product_by_id(id)
    db = connect_to_db
    db.execute("SELECT * FROM produkt WHERE id = ?", id).first
end

def get_questions
    db = connect_to_db
    db.execute("SELECT * FROM questions ORDER BY created_at DESC")
end

def save_question(user_id, name, question, created_at)
    db = connect_to_db
    db.execute("INSERT INTO questions (user_id, name, question, created_at) VALUES (?, ?, ?, ?)", [user_id, name, question, created_at])
end

def get_question_by_id(id)
    db = connect_to_db
    db.execute("SELECT * FROM questions WHERE id = ?", [id]).first
end

def answer_question(id, answer)
    db = connect_to_db
    db.execute("UPDATE questions SET answer = ? WHERE id = ?", [answer, id])
end

def create_order(user_id, name, address, phone)
    db = connect_to_db
    db.execute("INSERT INTO orders (user_id, namn, adress, tel_nr) VALUES (?,?,?,?)", [user_id, name, address, phone])
    db.last_insert_row_id
end

def add_order_item(order_id, produkt_id, quantity, price)
    db = connect_to_db
    db.execute("INSERT INTO order_items (order_id, produkt_id, kvantitet, pris) VALUES (?,?,?,?)", [order_id, produkt_id, quantity, price])
end

def get_order_by_id(order_id)
    db = connect_to_db
    db.execute("SELECT * FROM orders WHERE id = ?", [order_id]).first
end

def get_order_items(order_id)
    db = connect_to_db
    db.execute(
        "SELECT order_items.*, produkt.namn AS produkt_namn
        FROM order_items
        JOIN produkt ON order_items.produkt_id = produkt.id
        WHERE order_items.order_id = ?", [order_id]
    )
end

def get_all_orders
    db = connect_to_db
    db.execute("SELECT * FROM orders")
end

def get_order_items_raw(order_id)
    db = connect_to_db
    db.execute("SELECT * FROM order_items WHERE order_id = ?", [order_id])
end
