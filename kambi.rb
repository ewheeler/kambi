#!/usr/bin/env ruby

#
# This is a RESTful version of the Camping-based Blokk application.
#
# The original version can be found here: 
# http://code.whytheluckystiff.net/camping/browser/trunk/examples/blog.rb
#

require 'rubygems'

gem 'camping', '~> 1.5'
gem 'reststop', '~> 0.2'

require 'camping'
#require 'yaml'
require 'camping/db'
require 'camping/session'


begin
  # try to use local copy of library
  require '../lib/reststop'
rescue LoadError
  # ... otherwise default to rubygem
  require 'reststop'
end
  
Camping.goes :Kambi

module Kambi
    include Camping::Session
end

module Kambi::Models
    class Post < Base
      has_many :comments, :order => 'created_at ASC'
      has_many :clipposts
      has_many :posttags
      has_many :clips, :through => :clipposts
      has_many :tags, :through => :posttags
      validates_presence_of :title, :nickname
      validates_uniqueness_of :nickname
    end
  
    class Clip < Base
      has_many :clipposts
      has_many :cliptags
      has_many :posts, :through => :clipposts
      has_many :tags, :through => :cliptags
      validates_presence_of :url, :nickname
      validates_uniqueness_of :nickname
    end
    
    class Clippost < Base
      has_many :clips
      has_many :posts
    end
  
    class Comment < Base
      validates_presence_of :username
      validates_length_of :body, :within => 1..3000
      #validates_inclusion_of :bot, :in => %w(K)
      #validates_associated :post
      belongs_to :post
      #attr_accessor :bot
    end
    
    class Tag < Base
      validates_presence_of :name
      belongs_to :posts
      belongs_to :clips
    end
    
    class Posttag < Base
      has_many :tags
      has_many :posts
    end
    
    class Cliptag < Base
      has_many :tags
      has_many :clips
    end
    
    class User < Base; end

    class CreateTheBasics < V 1.2
      def self.up
        create_table :kambi_users, :force => true do |table|
          table.string :username, :password
        end
        User.create :username => 'camper', :password => 'mepemepe'
        
        create_table :kambi_posts, :force => true do |table|
          table.integer :user_id
          table.string :title, :nickname
          table.text :body
          table.timestamps
        end
        
        create_table :kambi_clips, :force => true do |table|
          table.string :url, :nickname
          table.text :body
          table.timestamps
        end
        
        create_table :kambi_clipposts, :force => true do |table|
          table.integer :clip_id
          table.integer :post_id
        end
        
        create_table :kambi_comments, :force => true do |table|
          table.integer :post_id
          table.string :username
          table.text :body
          table.datetime :created_at
        end
        
        create_table :kambi_tags, :force => true do |table|
          table.string :name
        end
        
        create_table :kambi_posttags, :force => true do |table|
          table.integer :tag_id
          table.integer :post_id
        end
        
        create_table :kambi_cliptags, :force => true do |table|
          table.integer :tag_id
          table.integer :clip_id
        end
        
      end
    end
end

def Kambi.create
    Camping::Models::Session.create_schema
    Kambi::Models.create_schema
end

module Kambi::Helpers
  
  # menu bar
  def menu target = nil
    if target
      args = target.is_a?(Symbol) ? [] : [target]
      for role, submenu in menu[target].sort_by { |k, v| [:visitor, :user].index k }
        ul.menu.send(role) do
          submenu.each do |x|
            li { x[/\A\w+\z/] ? a(x, :href => R(Controllers.const_get(x), *args)) : x }
          end
        end unless submenu.empty?
      end
    else
      @menu ||= Hash.new { |h, k| h[k] = { :visitor => [], :user => [] } }
    end
  end
  
  # shortcut for error-aware labels
  def label_for name, record = nil, attr = name, options = {}
    errors = record && !record.body.blank? && !record.valid? && record.errors.on(attr)
    label name.to_s, { :for => name }, options.merge(errors ? { :class => :error } : {})
  end
  
end

# beautiful XHTML 11
class Mab
  def initialize(assigns = {}, helpers = nil, &block)
    super(assigns.merge({:indent => 2}), helpers, &block)
  end
  def xhtml11(&block)
    self.tagset = Markaby::XHTMLStrict
    declare! :DOCTYPE, :html, :PUBLIC, '-//W3C//DTD XHTML 1.1//EN', 'http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd'
    tag!(:html, :xmlns => 'http://www.w3.org/1999/xhtml', 'xml:lang' => 'en', &block)
    self
  end
end

module Kambi::Controllers
    class Posts < REST 'posts'      

        # POST /posts
        def create
            unless @state.user_id.blank?
                post = Post.create :title => input.post_title, :body => input.post_body,
                                   :user_id => @state.user_id, :nickname => input.post_nickname
                redirect R(Posts)
            else
              _error("Unauthorized", 401)
            end
        end

        # GET /posts/1
        # GET /posts/1.xml
        def read(post_id) 
            @post = Post.find post_id
            @comments = @post.comments
            @clips = @post.clipposts.collect{|c| c.clips}.flatten
            render :view
        end

        # PUT /posts/1
        def update(post_id)
            unless @state.user_id.blank?
                @post = Post.find post_id
                all_tags = Models::Tag.find :all
                these_tags_ids = @post.posttags.collect{|p| p.tag_id}.flatten
                these_tags = these_tags_ids.collect{|i| Kambi::Models::Tag.find i}
                these_tags.each{|d| unless input.include?(d.name); @post.posttags.delete(d); end; }
                not_these_tags = all_tags - these_tags
                not_these_tags.each{|a| if input.include?(a.name); pt = Posttag.new; @post.posttags.build(pt.create :post_id => @post.id, :tag_id => a.id).save; end; }
                @post.update_attributes :title => input.post_title, :body => input.post_body, :nickname => input.post_nickname
                redirect R(@post)
            else
              _error("Unauthorized", 401)
            end
        end

        # DELETE /posts/1
        def delete(post_id)
            unless @state.user_id.blank?
                @post = Post.find post_id
                
                if @post.destroy
                  redirect R(Posts)
                else
                  _error("Unable to delete post #{@post.id}", 500)
                end
            else
              _error("Unauthorized", 401)
            end
        end

        # GET /posts
        # GET /posts.xml
        def list
            @posts = Post.find :all
            render :index
        end
        
        
        # GET /posts/new
        def new
            unless @state.user_id.blank?
                @user = User.find @state.user_id
                @post = Post.new
            end
            render :add_post
        end

        # GET /posts/1/edit
        def edit(post_id) 
            unless @state.user_id.blank?
                @user = User.find @state.user_id
            end
            @post = Post.find post_id
            @all_posts_tags = Models::Tag.find :all
            these_posts_tags_ids = @post.posttags.collect{|p| p.tag_id}.flatten
            @these_posts_tags = these_posts_tags_ids.collect{|i| Kambi::Models::Tag.find i}
            render :edit_post
        end
        
        # GET /posts/info
        def info
            div do
                code args.inspect; br; br
                code @env.inspect; br
                code "Link: #{R(Info, 1, 2)}"
            end
        end
    end
    
    class Clips < REST 'clips'
        # POST /clips
        def create
            clip = Models::Clip.create(:nickname => input.clip_nickname,
                        :url => input.clip_url,
                       :body => input.clip_body)
            all_posts = Models::Post.find :all
            #these_clips_posts = clip.posts
            #not_these_clips_posts = all_posts - these_clips_posts
            #these_clips_posts.each{|d| unless input.include?(d.title); clip.posts.delete(d); end; }
            all_posts.each{|a| if input.include?(a.title); clip.clipposts.create(a.id); end; }
            redirect R(Posts)
        end
        
        # GET /clips
        # GET /clips.xml
        def list
            @clips = Clip.find :all
            render :view_clips
        end
        
        # GET /clips/new
        def new
            unless @state.user_id.blank?
                @user = User.find @state.user_id
                @all_posts = Models::Post.find :all
                @these_clips_posts = nil
                @clip = Clip.new
            end
            render :add_clip
        end
        
        # GET /clips/1/edit
        def edit(clip_id) 
            unless @state.user_id.blank?
                @user = User.find @state.user_id
            end
            @clip = Models::Clip.find clip_id
            @all_posts = Models::Post.find :all
            @these_clips_posts = @clip.clipposts.collect{|t| t.posts}.flatten
            @all_clips_tags = Models::Tag.find :all
            @these_clips_tags = @clip.cliptags.collect{|c| c.tags}.flatten
            render :edit_clip
        end
        
        # PUT /clips/1
        def update(clip_id)
            unless @state.user_id.blank?
                clip = Clip.find clip_id
                all_tags = Models::Tag.find :all
                these_tags = clip.cliptags.collect{|c| c.tags}.flatten
                not_these_tags = all_tags - these_tags
                these_tags.each{|d| unless input.include?(d.name); clip.cliptags.delete(d); end; }
                not_these_tags.each{|a| if input.include?(a.name); clip.cliptags.build(a); end; }
                clip.update_attributes :url => input.clip_url, :body => input.clip_body, :nickname => input.clip_nickname
                all_posts = Models::Post.find :all
                these_clips_posts = clip.clipposts.collect{|t| t.posts}.flatten
                not_these_clips_posts = all_posts - these_clips_posts
                these_clips_posts.each{|d| unless input.include?(d.title); clip.clipposts.delete(d); end; }
                not_these_clips_posts.each{|a| if input.include?(a.title); clip.clipposts.build(a); end; }
                #@post = Post.find clip.post_id
                redirect R(Posts)
            else
              _error("Unauthorized", 401)
            end
        end
    end
     
    class Tags < REST 'tags'
        # POST /tags
        def create
            Models::Tag.create(:name => input.tag_name)
            redirect R(Tags)
        end
        
        # GET /tags
        # GET /tags.xml
        def list
            @tags = Tag.find :all
            render :view_tags
        end
        
        # GET /tags/1
        # GET /tags/1.xml
        def read(tag_id) 
            @tag = Tag.find tag_id
            @tags = Models::Tag.find :all
            @posts = @tag.posts
            @clips = @tag.clips
            render :view_tags
        end
        
        # GET /tags/new
        def new
            unless @state.user_id.blank?
                @tag = Tag.new
            end
            render :add_tag
        end
        
        # GET /tag/1/edit
        def edit(tag_id) 
            unless @state.user_id.blank?
                @user = User.find @state.user_id
            end
            @tag = Tag.find tag_id
            render :edit_tag
        end
        
        # PUT /tags/1
        def update(tag_id)
            unless @state.user_id.blank?
                @tag = Tag.find tag_id
                @tag.update_attributes :name => input.tag_name
                render :view_tags
            else
              _error("Unauthorized", 401)
            end
        end
    end 
     
    class Comments < REST 'comments'
        # POST /comments
        def create
            Models::Comment.create(:username => input.post_username,
                       :body => input.post_body, :post_id => input.post_id)
            redirect R(Posts, input.post_id)
        end
    end
    
    class Sessions < REST 'sessions'
        # POST /sessions
        def create
            @user = User.find :first, :conditions => ['username = ? AND password = ?', input.username, input.password]
     
            if @user
                @login = 'login success !'
                @state.user_id = @user.id
            else
                @login = 'wrong user name or password'
            end
            render :login
        end   

        # DELETE /sessions
        def delete
            @state.user_id = nil
            render :logout
        end
    end
    
    # You can use old-fashioned Camping controllers too!
    class Style < R '/styles.css'
        def get
            @headers["Content-Type"] = "text/css; charset=utf-8"
            @body = %{
                body {
                    font-family: Utopia, Georga, serif;
                }
                h1.header {
                    background-color: #fef;
                    margin: 0; padding: 10px;
                }
                div.content {
                    padding: 10px;
                }
                div.post {
                    padding: 1em;
                    border: 1px solid black;
                    width: 50%;
                }
                div.clip{
                    padding: 1em;
                    border: 1px dotted black;
                    margin-right: 4em;
                }
                div.comments{
                  padding: 1em;
                  border: 1px solid black;
                }
                div.comment{
                  padding: 1em;
                  margin-right: 4em;
                  border: 1px dotted black;
                }
            }
        end
    end
end


Markaby::Builder.set(:indent, 2)

module Kambi::Views
    module HTML
        include Kambi::Controllers 
      
        def layout
          html do
            head do
              title 'Kambi'
              link :rel => 'stylesheet', :type => 'text/css', 
                   :href => self/'/styles.css', :media => 'screen'
            end
            body do
              h1.header { a 'Kambi', :href => R(Posts) }
              div.content do
                self << yield
              end
            end
          end
        end
    
        def index
          if @posts.empty?
            p 'No posts found.'
          else
            for post in @posts
              div.post do
                _post(post)
                pclips = post.clipposts.collect{|p| p.clips}.flatten
                for clip in pclips
                  div.clip do
                    _clip(clip)
                  end
                end
              end
            end
          
          end
          p { a 'New Post', :href => R(Posts, 'new') }
          
        end
    
        def login
          p { b @login }
          p { a 'Continue', :href => R(Posts, 'new') }
        end
    
        def logout
          p "You have been logged out."
          p { a 'Continue', :href => R(Posts) }
        end
    
        def add_post
          if @user
            _post_form(@post, :action => R(Posts))
          else
            _login
          end
        end
        
        def add_clip
          if @user
            _clip_form(@clip, :action => R(Clips))
          else
            _login
          end
        end
    
        def edit_post
          if @user
            _post_form(@post, :action => R(@post), :method => :put)
          else
            _login
          end
        end
        
        def edit_clip
          if @user
            _clip_form(@clip, :action => R(@clip), :method => :put)
          else
            _login
          end
        end
        
        def view
            div.post do
              _post(@post)
              pclips = @post.clipposts.collect{|p| p.clips}.flatten
              for clip in pclips
                div.clip do
                  _clip(clip)
                end
              end
              div.comments do
                p "Comments:"
                for c in @comments
                  div.comment do
                    h1 c.username + ' says:'
                    p c.body
                    p c.created_at
                  end
                end
                form :action => R(Comments), :method => 'post' do
                  label 'Name', :for => 'post_username'; br
                  input :name => 'post_username', :type => 'text'; br
                  label 'Comment', :for => 'post_body'; br
                  textarea :name => 'post_body' do; end; br
                  input :type => 'hidden', :name => 'post_id', :value => @post.id
                  input :type => 'submit'
              end
            end
          end
        end
        
        def view_tags
          if @tag
            unless @posts.empty?
              p "Posts tagged with " + @tag.name + ":"
              for post in @posts
                a(post.title, :href => R(Posts, post.post_id)) 
              end
            end
            unless @clips.empty?
              for clip in @clips
                p "Clips tagged with " + @tag.name + ":"
                a(clip.nickname, :href => R(Clips, clip.clip_id))   
              end
            end
          end
          p "All tags:"
          for tag in @tags
            p tag.name
          end
          form :action => R(Tags), :method => 'post' do
            label 'New tag', :for => 'tag_name'; br
            input :name => 'tag_name', :type => 'text'; br
            
            input :type => 'submit'
          end
        end
        
        def view_clips
          for clip in @clips
            p do
              a(clip.nickname, :href => R(Clips, clip.id, 'edit'))
            end
          end
        end
    
        # partials
        def _login
          form :action => R(Sessions), :method => 'post' do
            label 'Username', :for => 'username'; br
            input :name => 'username', :type => 'text'; br
    
            label 'Password', :for => 'password'; br
            input :name => 'password', :type => 'text'; br
    
            input :type => 'submit', :name => 'login', :value => 'Login'
          end
        end
    
        def _post(post)
          h1 do
            a(post.title, :href => R(Posts, post.id))
          end
          ptagids = post.posttags.collect{|p| p.tag_id}.flatten
          ptags = ptagids.collect{|i| Kambi::Models::Tag.find i }
          unless ptags.empty?
            div.posts_tags do
              p "tagged with :"
              for tag in ptags
                a(tag.name, :href => R(Tags, tag.id))
              end
            end
          end
          p post.body
          p do
            a("Edit Post", :href => R(Posts, post.id, 'edit'))
          end
          p { a 'Add Clip', :href => R(Clips, 'new')}
        end
        
        def _clip(clip)
          a(clip.nickname, :href => clip.url)
          ctagids = clip.cliptags.collect{|c| c.tag_id}.flatten
          ctags = ctagids.collect{|i| Kambi::Models::Tag.find i }
          unless ctags.nil?
                      div.clips_tags do
                        p "tagged with :"
                        for tag in ctags
                          p do
                            a(tag.name, :href => R(Tags, tag.tag_id))
                          end
                        end
                      end
                    end
          p clip.body
          p do
            a("Edit Clip", :href => R(Clips, clip.clip_id, 'edit'))
          end
        end
      
    
        def _post_form(post, opts)
          form(:action => R(Sessions), :method => 'delete') do
          p do 
            span "You are logged in as #{@user.username}"
            span " | "
            button(:type => 'submit') {'Logout'}
          end
          end
          form({:method => 'post'}.merge(opts)) do
            label 'Title', :for => 'post_title'; br
            input :name => 'post_title', :type => 'text', 
                  :value => post.title; br
                  
            label 'Nickname', :for => 'post_nickname'; br
            input :name => 'post_nickname', :type => 'text',
                  :value => post.nickname; br
    
            label 'Body', :for => 'post_body'; br
            textarea post.body, :name => 'post_body'; br
             
            if @all_posts_tags            
              for tag in @all_posts_tags
                if @these_posts_tags.include?(tag)
                  input :type => 'checkbox', :name => tag.name, :value => tag.id, :checked => 'true'
                  label tag.name, :for => tag.name; br
                else
                  input :type => 'checkbox', :name => tag.name, :value => tag.id
                  label tag.name, :for => tag.name; br
                end
              end
            end
    
            input :type => 'hidden', :name => 'post_id', :value => post.id
            input :type => 'submit'
          end
          
          
        end
        
        def _clip_form(clip, opts)
          form(:action => R(Sessions), :method => 'delete') do
          p do 
            span "You are logged in as #{@user.username}"
            span " | "
            button(:type => 'submit') {'Logout'}
          end
          end
          form({:method => 'post'}.merge(opts)) do
            label 'Nickname', :for => 'clip_nickname'; br
            input :name => 'clip_nickname', :type => 'text', 
                  :value => clip.nickname; br
                  
            label 'Url', :for => 'clip_url'; br
            input :name => 'clip_url', :type => 'text', 
                  :value => clip.url; br
                  
            label 'Body', :for => 'clip_body'; br
            textarea clip.body, :name => 'clip_body'; br
            
            if @all_clips_tags
              for tag in @all_clips_tags
                if !@these_clips_tags.nil? && @these_clips_tags.include?(tag)
                  input :type => 'checkbox', :name => tag.name, :value => tag, :checked => 'true'
                  label tag.name, :for => tag.name; br
                else
                  input :type => 'checkbox', :name => tag.name, :value => tag
                  label tag.name, :for => tag.name; br
                end
              end
            end
           
            if @all_posts
              for post in @all_posts
                if !@these_clips_posts.nil? && @these_clips_posts.include?(post)
                  input :type => 'checkbox', :name => post.title, :value => post, :checked => 'true'
                  label post.title, :for => post.title; br
                else
                  input :type => 'checkbox', :name => post.title, :value => post
                  label post.title, :for => post.title; br
                end
              end
            end
            
            input :type => 'submit'
          end
        end 
    end
    default_format :HTML

    module XML
      def layout
        yield
      end
      
      def index
        @posts.to_xml(:root => 'kambi')
      end
      
      def view
        @post.to_xml(:root => 'post')
      end
    end
end
 

# 
# if __FILE__ == $0
#   require 'mongrel/camping'
# 
#   Kambi::Models::Base.establish_connection :adapter => 'mysql', 
#     :database => 'kambi_dev', 
#     :username => 'root', 
#     :password => 'root'
#   Kambi::Models::Base.logger = Logger.new('kambi.log')
#   #Kambi::Models::Base.threaded_connections = false
#   Kambi.create # only if you have a .create method 
#                  # for loading the schema
# 
#   server = Mongrel::Camping::start("0.0.0.0",80,"/", Kambi)
#   puts "Kambi is running at http://localhost:80/"
#   server.run.join
# end