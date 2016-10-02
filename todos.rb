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
  
  def h(content)
    Rack::Utils.escape_html(content)
  end
  
  def list_class(list)
    "complete" if list_completed?(list)
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
  
  def list_completed?(list)
    todos_count(list) > 0 && todos_remaining_count(list) == 0
  end
  
  def todos_remaining_count(list)
    #binding.pry
    list[:todos].select {|todo| !todo[:completed] }
    .size
  end
  
  def todos_count(list) 
    list[:todos].size
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
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb  :new_list, layout: :layout
  else
    session[:lists] << {name: list_name, todos: []}
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

# edit a list 
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
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb  :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = 'Congratulations - you list name has been updated'
    redirect "/list/#{@list_id}"
  end
end

# mark all todos 
post "/list/:list_id/update_status_of_all_todos" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id) 
  @list[:todos].each_with_index do |todo, index|
    todo[:completed] = true
  end
  session[:success] = 'All todos have been marked completed'
  redirect "/list/#{@list_id}"
end

# destroy a list
post "/list/:id/destroy" do
  @list_id = params[:id].to_i
  session[:lists].delete_at(@list_id)
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = 'List Destroyed'
    redirect to "/lists"
  end
end

#add a new todo to the list
post "/list/:list_id/create_todo" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id) #was @list = session[:lists][@list_id]
  text = params[:todo].strip
  error = error_for_todo(text)
  if error
    session[:error] = error
    erb  :show_list, layout: :layout
  else
    @list[:todos] << {name: text, completed: false}
    session[:success] = "A todo has been added to the list"
    redirect to "/list/#{@list_id}"
  end
end

#delete todo
post '/list/:list_id/todos/:todo_id/destroy' do
   @list_id = params[:list_id].to_i
   @todo_id = params[:todo_id].to_i
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
post '/list/:list_id/todo/:todo_id/completed' do
  @list_id = params[:list_id].to_i
  @todo_id = params[:todo_id].to_i
  @list = load_list(@list_id) #@list = session[:lists][@list_id]
  @todo = @list[:todos][@todo_id]
  if params[:completed] == 'true'
    @todo[:completed] = true
  else
    @todo[:completed] = false
  end
  session[:success] = "The todo status has been updated"
  redirect to "/list/#{@list_id}"
end

# validate list name
def error_for_list_name(name)
  if !(1..100).cover? name.size 
    "List name must be between 1 and 100 characters long"
  elsif session[:lists].any? {|list| list[:name] == name }
    "You already have a list with that name"  
  end  
end

# validate todo
def error_for_todo(text)
  if !(1..100).cover? text.size 
    "To do text must be between 1 and 100 characters long"
  end  
end

def load_list(index)
  list = session[:lists][index] if index
  return list if list

  session[:error] = "The specified list was not found."
  redirect "/lists"
end