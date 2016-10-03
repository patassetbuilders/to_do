require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"
require "pry"


configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

before do
  session[:lists] ||= []
end

helpers do
  
  def next_todo_id(todos)
    max = todos.map { |todo| todo[:id]}.max || 0 
    max + 1
  end
  
  def next_list_id
    max = session[:lists].map { |list| list[:id]}.max || 0 
    max + 1
  end
  
  def h(content)
    Rack::Utils.escape_html(content)
  end
  
  def list_completed?(list)
    todos_count(list) > 0 && todos_remaining_count(list) == 0
  end
  
  def list_class(list)
    "complete" if list_completed?(list)
  end
  
  def todos_count(list) 
    list[:todos].size
  end 
  
  def todos_remaining_count(list)
    list[:todos].select {|todo| !todo[:completed] } #note could use .count instead of .select
    .size
  end
  
  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition { |list| list_completed?(list) }
    
    incomplete_lists.each { |list| yield list, lists.index(list) }
    complete_lists.each { |list| yield list, lists.index(list) }
  end
  
  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed] }
    
    incomplete_todos.each { |todo| yield todo, todos.index(todo) }
    complete_todos.each { |todo| yield todo, todos.index(todo) }
  end  
end

def load_list(id)
  list = session[:lists].find{ |list| list[:id] == id}
  return list if list

  session[:error] = "The specified list was not found."
  redirect "/lists"
end

# validate list name
def validate_list_name(name)
  if !(4..100).cover? name.size 
    "List name must be between 4 and 100 characters long"
  elsif session[:lists].any? {|list| list[:name] == name }
    "You already have a list with that name"  
  end  
end

# validate todo
def error_for_todo(text)
  if !(4..100).cover? text.size 
    "To do text must be between 4 and 100 characters long"
  end  
end

get "/" do
  redirect "/lists"
end

# show all lists
get "/lists" do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# new list form
get "/lists/new" do
  erb  :new_list, layout: :layout
end

# create a new list
post "/list" do
  list_name = params[:list_name].strip
  error = validate_list_name(list_name)
  if error
    session[:error] = error
    erb  :new_list, layout: :layout
  else
    id = next_list_id
    session[:lists] << {id: id, name: list_name, todos: []}
    session[:success] = 'Congratulations - you new list has been created'
    redirect "/lists"
  end
end

# show a list
get "/list/:list_id" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  erb :show_list, layout: :layout
end

# edit an existing todo list 
get "/list/:list_id/edit" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id) #replaces below @list = session[:lists][@list_id] 
  erb :edit_list, layout: :layout
end

# update a list
post "/list/:list_id" do
  @list_id = params[:list_id].to_i
  list_name = params[:list_name].strip
  @list = load_list(@list_id) 
  
  error = validate_list_name(list_name)
  if error
    session[:error] = error
    erb  :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = 'Congratulations - you list name has been updated'
    redirect "/list/#{@list_id}"
  end
end

# destroy a list
post "/list/:id/destroy" do
  id = params[:id].to_i
  session[:lists].reject! { |list| list[:id] == id }
  session[:success] = "The list has been deleted."
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = 'List Destroyed'
    redirect to "/lists"
  end
end

#add a new item to the todo list
post "/list/:list_id/create_todo" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id) #was @list = session[:lists][@list_id]
  text = params[:todo].strip
  error = error_for_todo(text)
  if error
    session[:error] = error
    erb  :show_list, layout: :layout
  else
    id = next_todo_id(@list[:todos])
    @list[:todos] << {id: id, name: text, completed: false}
    session[:success] = "A todo has been added to the list"
    redirect to "/list/#{@list_id}"
  end
end

#delete an item from a todo list
post '/list/:list_id/todos/:todo_id/destroy' do
   @list_id = params[:list_id].to_i
   @todo_id = params[:id].to_i
   @list = load_list(@list_id) #@list = session[:lists][@list_id]
   @todos = @list[:todos]
   @todos.delete_at(@todo_id)
   if env["HTTP_X_REQUESTED_WITH"] =="XMLHttpRequest"
     status 204
   else
     session[:success] = "The todo has been deleted"
     redirect to "/list/#{@list_id}"
   end
end

#update todo status
post '/list/:list_id/todo/:id/completed' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id) #@list = session[:lists][@list_id]
  @todo = @list[:todos].find { |todo| todo[:id] == params[:id].to_i }
  if params[:completed] == 'true'
    @todo[:completed] = true
  else
    @todo[:completed] = false
  end
  session[:success] = "The todo status has been updated"
  redirect to "/list/#{@list_id}"
end

# mark all todos in a list as complete
post "/list/:list_id/update_status_of_all_todos" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id) 
  
  @list[:todos].each_with_index do |todo, index|
    todo[:completed] = true
  end
  
  session[:success] = 'All todos have been marked completed'
  redirect "/list/#{@list_id}"
end


