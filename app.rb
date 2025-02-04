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

get('/show_varukorg') do
    slim(:varukorg)
end

get('/show_produkter') do
    db = SQLite3::Database.new("db/webbshop.db")
    db.results_as_hash = true
    result = db.execute("SELECT * FROM produkt")

    slim(:produkter, locals:{produkt:result})
end

get('/show_produkt') do
    slim(:produkt)
end

get('/show_om_oss') do
    slim(:om_oss)
end

get('/show_kontakt') do
    slim(:kontakt)
end
