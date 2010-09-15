require 'sinatra'
require 'haml'
require 'sass'
require 'dm-core'
require 'dm-migrations'
require 'rdiscount'


## configuration

HOME_PAGE_NAME = 'home'
USERNAME = 'cvk'
PASSWORD = 'cvk'

# authentication (comment out to disable [will cause some tests to fail])
use Rack::Auth::Basic do |username, password|
  [username, password] == [USERNAME, PASSWORD]
end

# sinatra and datamapper
configure do
  set :bind, '127.0.0.1'
  DataMapper::Logger.new(STDOUT, :debug)
  DataMapper.setup :default, 'sqlite3:fwiki.sqlite3'
end


## models

class Page
  include DataMapper::Resource
  property :name, String, :key => true
  has n, :bodies
  def contents
    bodies.last.contents
  end
  def contents=(text)
    bodies << Body.new(:contents => text)
  end
end

class Body
  include DataMapper::Resource
  property :id, Serial
  property :contents, String
  property :created_at, DateTime, :default => lambda { Time.now }
  belongs_to :page
end


# intitialize database on first run
DataMapper.auto_upgrade! if $0 == __FILE__


## helpers

helpers do
  include Rack::Utils
  alias_method :h, :escape_html
  alias_method :e, :escape

  # render page contents as html
  #
  # for something besides markdown, process as you like
  def htmlify(text)
    RDiscount.new(text).to_html
  end

  # changes [[wiki_links]] into anchor elements in page contents
  def linkify(text)
    text.gsub(%r(\[\[(.*?)\]\])) { '<a href="%s">%s</a>' % [$1, $&] }
  end

  # sets the page title (called by views)
  def call_me(name)
    @page_title = name
  end

  def page_title; @page_title; end
end


## web app methods

get '/' do
  @pages = Page.all
  haml :index
end

get '/fwiki/style' do
  content_type 'text/css'
  sass :style
end

get '/:name' do
  @page = Page.get(params[:name])
  raise NoPage, 'not here' unless @page
  if params[:raw]
    content_type 'text/plain'
    @page.contents
  elsif params[:edit]
    haml :show_edit
  else
    haml :show
  end
end

put '/:name' do
  name = params[:name]
  @page = Page.get(name) || Page.new(:name => name)
  @page.contents = params[:contents] || ''
  @page.save
  haml :show
end


## exceptions

class NoPage < Sinatra::NotFound; end
error NoPage do
  @name = params[:name]
  haml :new_page
end


## views

__END__

@@ layout
- page_contents = yield
%html
  %head
    %title= page_title
    %link{:rel => 'stylesheet', :href => '/fwiki/style', :type => 'text/css'}
  %div#menu
    %ul
      %li
        %a{:href => '/' + h(e(HOME_PAGE_NAME))}= h(HOME_PAGE_NAME)
      %li
        %a{:href => '/'} all pages
  %div#page
    %h1= page_title
    = page_contents

@@ index
- call_me 'oh hai there'
%h2 you can haz pages
%ul#pages
  - @pages.each do |page|
    %li
      %a{:href => '/' + h(e(page.name))}=h page.name

@@ show
- call_me h(@page.name)
%div#actions
  %a{:href => '/' + h(e(@page.name)) + '?edit=gogogo', :class => 'primary'} edit
  %a{:href => '/' + h(e(@page.name)) + '?raw=chicken'} raw
= linkify(htmlify(h(@page.contents)))

@@ show_edit
- call_me 'editing ' + h(@page.name)
%form{:action => '/' + h(e(@page.name)), :method => 'post'}
  %input{:type => 'hidden', :name => '_method', :value => 'PUT'}
  %textarea{:rows => 20, :cols => 60, :name => 'contents'}=h @page.contents
  %input{:type => 'submit', :value => 'save'}

@@ new_page
- call_me 'you can create ' + h(@name)
%form{:action => '/' + h(e(@name)), :method => 'post'}
  %input{:type => 'hidden', :name => '_method', :value => 'PUT'}
  %textarea{:rows => 20, :cols => 60, :name => 'contents'}
  %input{:type => 'submit', :value => 'create'}

@@ style
// colors from http://www.colourlovers.com/palette/177020/Amsterdam_Acid
$green: #c7ff00
$blue: #0069ff
$red: #ff3b2f
$steel: #494e54
$fog: #adb39b

$layout_width: 60em

@mixin rounded-top
  $radius: 10px

  border-top-radius: $radius
  -moz-border-radius-topleft: $radius
  -moz-border-radius-topright: $radius
  -webkit-border-top-left-radius: $radius
  -webkit-border-top-right-radius: $radius

@mixin nopadding
  margin: 0
  padding: 0

@mixin center_in_parent
  margin-left: auto
  margin-right: auto

html, body
  @include nopadding
 
body
  padding-top: 1em
  background-color: $steel

a
  color: $blue
  text-decoration: none
  &:visited
    color: $blue
  &:hover
    color: $red

#menu, #page
  @include center_in_parent
#menu
  @include rounded-top
  background-color: $blue
  width: $layout_width
#page
  $side_padding: 3em
  padding: 1em $side_padding
  width: #{$layout_width - $side_padding * 2}
  background-color: white
  min-height: 80%
  background-image: url(http://cvk.qubes.org/fwiki_logo_small.png)
  background-repeat: no-repeat
  background-position: bottom right
#menu ul
  @include nopadding
  padding: 0.5em
  li
    display: inline
    padding: 0 0.5em
    a
      color: white
      font:
        size: small
        weight: bold
h1
  @include nopadding
  color: $red

#actions
  float: right
  padding-top: 1em
  a
    color: darken($green, 50%)
    text-decoration: underline
    padding: 0.25em 0.5em
    &:hover
      color: $red
  .primary
    color: $green
    font-weight: bold
    background-color: $steel
    text-decoration: none
    &:hover
      background-color: lighten($steel, 20%)
