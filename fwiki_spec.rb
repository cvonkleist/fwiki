require 'fwiki'
require 'rack/test'
require 'base64'

configure do
  DataMapper::Logger.new(STDOUT, :debug)
  DataMapper.setup :default, 'sqlite3::memory:'
end

describe Page do
  it 'should create a body when contents are specified' do
    p = Page.new(:name => 'foo', :contents => 'bar')
    p.contents.should == 'bar'
  end

  it 'should search the body and title' do
    p = Page.new(:name => 'foo page', :contents => 'now is the time for all good foo to come to the aid of their bar')
    p.scan(%r(the)).length.should == 3
  end
end

def authorized_get(path)
  get path, {}, {'HTTP_AUTHORIZATION' => encode_credentials(USERNAME, PASSWORD)}
end

def encode_credentials(username, password)
  'Basic ' + Base64.encode64(username + ':' + password)
end

describe "fwiki" do
  include Rack::Test::Methods

  def app
    @app ||= Sinatra::Application
  end

  it 'should require authorization' do
    get '/'
    last_response.status.should == 401
  end

  it 'should not allow bad authorization' do
    get '/', {}, {'HTTP_AUTHORIZATION' => encode_credentials('foo', 'asdf')}
    last_response.status.should == 401
  end

  it 'should respond to /' do
    page = mock('page object')
    page.should_receive(:name).twice
    Page.should_receive(:all).and_return [page]
    authorized_get '/'
    last_response.should be_ok
  end

  it 'should get a page' do
    page = mock('page object')
    page.should_receive(:name).exactly(3).times.and_return 'foo'
    page.should_receive(:contents).and_return 'bar'
    Page.should_receive(:get).with('home').and_return page
    authorized_get '/home'
    last_response.should be_ok
    last_response.body.should include('foo')
    last_response.body.should include('bar')
  end

  it "should show a page's edit form" do
    page = mock('page object')
    page.stub!(:name)
    page.stub!(:contents)
    Page.should_receive(:get).with('foo').and_return page
    authorized_get '/foo?edit=1'
    last_response.should be_ok
  end

  it 'should 404 on a bad page' do
    page = nil
    Page.should_receive(:get).with('foo<bar').and_return nil
    authorized_get '/foo%3cbar'
    last_response.status.should == 404
    last_response.body.should include('you can create')
    last_response.body.should include('foo&lt;bar')
  end
end

describe 'fwiki searching' do
  include Rack::Test::Methods

  def app
    @app ||= Sinatra::Application
  end

  def mock_page_result(name, search_result)
    p = mock('page')
    p.stub!(:name).and_return name
    p.stub!(:scan).and_return search_result
    p
  end

  it 'should search pages' do
    page1 = mock_page_result('foo page', ['foo is foo', 'foo foo foo'])
    page2 = mock_page_result('bar page', [])
    Page.stub!(:all).and_return [page1, page2]
    authorized_get '/search/foo'
    last_response.should be_ok
    last_response.body.should include('foo page')
    last_response.body.should include('foo is foo')
    last_response.body.should include('foo foo foo')
    last_response.body.should_not include('bar page')
  end

  it 'should say when there are no results' do
    page = mock_page_result('bar page', [])
    Page.stub!(:all).and_return [page]
    authorized_get '/search/baz'
    last_response.should be_ok
    last_response.body.should include('no baz :(')
  end
end
