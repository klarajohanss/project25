require 'sqlite3'

DB_PATH = "db/webbshop.db"

def db_connection
    db = SQLite3::Database.new(DB_PATH)
    db.results_as_hash = true
    db
end

def fetch_two_products
    db_connection.execute("SELECT * FROM products LIMIT 2")
end