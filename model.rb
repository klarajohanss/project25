require 'sqlite3'

def connect_to_db
    db = SQLite3::Database.new("db/webbshop.db")
    db.results_as_hash = true
    db
end

def fetch_two_products
    db = SQLite3::Database.new("db/webbshop.db")
    db.results_as_hash = true
    db.execute("SELECT * FROM products LIMIT 2")
end