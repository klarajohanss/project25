require 'sqlite3'

module Model

    DB_PATH = "db/webbshop.db"

    # Opens a database connection
    #
    # @return [SQLite3::Database] the database connection
    def db_connection
        db = SQLite3::Database.new(DB_PATH)
        db.results_as_hash = true
        db
    end

    # Fetches two products from the database
    #
    # @return [Array<Hash>] two product rows
    def fetch_two_products
        db_connection.execute("SELECT * FROM products LIMIT 2")
    end

    # Finds a user by ID
    #
    # @param [Integer] id the user's ID
    # @return [Array<Hash>] the user row(s)
    def find_user_by_id(id)
        db_connection.execute("SELECT * FROM users WHERE id = ?", id)
    end

    # Checks if a user with the given ID exists
    #
    # @param [Integer] requested_id the user ID to check
    # @return [Integer, nil] the user ID if found, otherwise nil
    def check_user_ownership(requested_id)
        owner = db_connection.execute("SELECT id FROM users WHERE id = ?", requested_id).first
        owner && owner["id"]
    end

    # Finds a user by username
    #
    # @param [String] username the username to search for
    # @return [Hash, nil] the user row if found, otherwise nil
    def find_user_by_username(username)
        db_connection.execute("SELECT * FROM users WHERE username = ?", username).first
    end

    # Creates a new user
    #
    # @param [String] username the username
    # @param [String] password_digest the hashed password
    # @param [String] email the user's email
    # @param [String] phone the user's phone number
    # @return [void]
    def create_user(username, password_digest, email, phone)
        db_connection.execute("INSERT INTO users (username, pwdigest, mail, telefon_nr) VALUES (?, ?, ?, ?)",
                              [username, password_digest, email, phone])
    end

    # Fetches all products
    #
    # @return [Array<Hash>] all product rows
    def fetch_all_products
        db_connection.execute("SELECT * FROM products")
    end

    # Fetches a single product by ID
    #
    # @param [Integer] id the product ID
    # @return [Hash, nil] the product row if found, otherwise nil
    def fetch_product_by_id(id)
        db_connection.execute("SELECT * FROM products WHERE id = ?", id).first
    end

    # Fetches all questions ordered by creation time descending
    #
    # @return [Array<Hash>] all question rows
    def fetch_all_questions
        db_connection.execute("SELECT * FROM questions ORDER BY created_at DESC")
    end

    # Adds a new question
    #
    # @param [Integer] user_id the ID of the user asking the question
    # @param [String] name the name of the asker
    # @param [String] question the question content
    # @param [String] created_at the timestamp when the question was asked
    # @return [void]
    def add_question(user_id, name, question, created_at)
        db_connection.execute("INSERT INTO questions (user_id, name, question, created_at) VALUES (?, ?, ?, ?)",
                              [user_id, name, question, created_at])
    end

    # Fetches a question by ID
    #
    # @param [Integer] id the question ID
    # @return [Hash, nil] the question row if found, otherwise nil
    def fetch_question_by_id(id)
        db_connection.execute("SELECT * FROM questions WHERE id = ?", id).first
    end

    # Updates the answer to a question
    #
    # @param [Integer] id the question ID
    # @param [String] answer the answer content
    # @return [void]
    def update_question_answer(id, answer)
        db_connection.execute("UPDATE questions SET answer = ? WHERE id = ?", [answer, id])
    end

    # Creates a new order
    #
    # @param [Integer] user_id the ID of the user placing the order
    # @param [String] name the name of the customer
    # @param [String] address the shipping address
    # @param [String] phone the phone number
    # @return [Integer] the ID of the newly created order
    def create_order(user_id, name, address, phone)
        db = db_connection
        db.execute("INSERT INTO orders (user_id, namn, adress, tel_nr) VALUES (?, ?, ?, ?)",
                   [user_id, name, address, phone])
        db.last_insert_row_id
    end

    # Adds an item to an order
    #
    # @param [Integer] order_id the ID of the order
    # @param [Integer] product_id the ID of the product
    # @param [Integer] quantity the quantity ordered
    # @param [Integer] price the price of the item
    # @return [void]
    def add_order_item(order_id, product_id, quantity, price)
        db_connection.execute("INSERT INTO order_items (order_id, produkt_id, kvantitet, pris) VALUES (?, ?, ?, ?)",
                              [order_id, product_id, quantity, price])
    end

    # Fetches an order by ID
    #
    # @param [Integer] order_id the ID of the order
    # @return [Hash, nil] the order row if found, otherwise nil
    def fetch_order_by_id(order_id)
        db_connection.execute("SELECT * FROM orders WHERE id = ?", [order_id]).first
    end

    # Fetches the items of a specific order, including product names
    #
    # @param [Integer] order_id the ID of the order
    # @return [Array<Hash>] the items in the order
    def fetch_order_items(order_id)
        db_connection.execute("SELECT order_items.*, products.namn AS produkt_namn
                               FROM order_items
                               JOIN products ON order_items.produkt_id = products.id
                               WHERE order_items.order_id = ?", [order_id])
    end

    # Fetches all orders
    #
    # @return [Array<Hash>] all order rows
    def fetch_all_orders
        db_connection.execute("SELECT * FROM orders")
    end

    # Fetches raw order items without joins
    #
    # @param [Integer] order_id the ID of the order
    # @return [Array<Hash>] the order items
    def fetch_order_items_raw(order_id)
        db_connection.execute("SELECT * FROM order_items WHERE order_id = ?", order_id)
    end

    # Finds a product to be used in a cart
    #
    # @param [Integer] id the product ID
    # @return [Hash, nil] the product row if found, otherwise nil
    def find_product_for_cart(id)
        db_connection.execute("SELECT * FROM products WHERE id = ?", id).first
    end
end
