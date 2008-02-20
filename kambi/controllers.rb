#!ruby

module Kambi::Controllers
  # include Kambi::Helpers
  # include Kambi::Models
  # include Kambi::Views
    class Index < R '/', '/index', '/all()()', '/(rss)', '/(rss)/([-\w]+)'
      def get format = 'html'
        redirect R(Posts)
      end
    end
    
    class Pages < REST 'pages'      

        # POST /pages
        def create
            unless @state.user_id.blank?
                page = Page.create :title => input.page_title, :body => input.page_body, :nickname => input.page_nickname
                redirect R(Pages)
            else
              _error("Unauthorized", 401)
            end
        end
        
        # GET /pages/1
        # GET /pages/1.xml
        def read(page_id) 
            @page = Page.find page_id
            @clips = @page.clips
            render :view_page
        end
        
        # PUT /pages/1
        def update(page_id)
            unless @state.user_id.blank?
                @page = Page.find page_id
                all_clips = Models::Clip.find :all
                @page.clips.each{|d| @page.references.delete(Reference.find(:all, :conditions => ["clip_id = #{d.id}"] )) }
                all_clips.each{|c| if input.include?(c.nickname); 
                    @page.references<<(Reference.create :page_id => @page.id, :clip_id => c.id); end; }
                
                all_tags = Models::Tag.find :all
                @page.tags.each{|d| @page.taggings.delete(Tagging.find(:all, :conditions => ["tag_id = #{d.id} AND  taggable_id = #{@page.id}"] )) }
                all_tags.each{|a| if input.include?(a.name); 
                    @page.taggings<<(Tagging.create( :taggable_id => @page.id, :taggable_type => "Page", :tag_id => a.id)); end; }
                @page.update_attributes :title => input.page_title, :body => input.page_body, :nickname => input.page_nickname
                redirect R(@page)
            else
              _error("Unauthorized", 401)
            end
        end
        
        # GET /pages
        # GET /pages.xml
        def list
            @pages = Page.find :all; @posts = Post.find :all
            render :index
        end
        
        # GET /pages/new
        def new
            unless @state.user_id.blank?
                @user = User.find @state.user_id
                @page = Page.new; @these_pages_tags = nil;
            end
            render :add_page
        end

        # GET /pages/1/edit
        def edit(page_id) 
            unless @state.user_id.blank?
                @user = User.find @state.user_id
            end
            @page = Page.find page_id
            @all_clips = Models::Clip.find :all;      @these_pages_clips = @page.clips
            @all_pages_tags = Models::Tag.find :all;  @these_pages_tags = @page.tags
            render :edit_page
        end
        
    end
    
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
            @post = Post.find post_id;  @comments = @post.comments
            @clips = @post.clips;       @authors = @post.authors
            render :view
        end

        # PUT /posts/1
        def update(post_id)
            unless @state.user_id.blank?
                @post = Post.find post_id
                
                all_authors = Models::Author.find :all
                @post.authors.each{|d| @post.authorships.delete(Authorship.find(:all, :conditions => ["author_id = #{d.id} AND  post_id = #{@post.id}"] )) }
                all_authors.each{|a| name = a.first + " " + a.last; if input.include?(name); 
                    @post.authorships<<(Authorship.create( :post_id => @post.id, :author_id => a.id)); end; }
                    
                all_clips = Models::Clip.find :all
                @post.clips.each{|d| @post.references.delete(Reference.find(:all, :conditions => ["clip_id = #{d.id}"] )) }
                all_clips.each{|c| if input.include?(c.nickname); 
                    @post.references<<(Reference.create :post_id => @post.id, :clip_id => c.id); end; }
                
                all_tags = Models::Tag.find :all
                @post.tags.each{|d| @post.taggings.delete(Tagging.find(:all, :conditions => ["tag_id = #{d.id} AND  taggable_id = #{@post.id}"] )) }
                all_tags.each{|a| if input.include?(a.name); 
                    @post.taggings<<(Tagging.create( :taggable_id => @post.id, :taggable_type => "Post", :tag_id => a.id)); end; }
                    
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
            @posts = Post.find :all; @pages = Page.find :all
            render :index
        end
              
        # GET /posts/new
        def new
            unless @state.user_id.blank?
                @user = User.find @state.user_id
                @post = Post.new; @these_posts_tags = nil;
            end
            render :add_post
        end

        # GET /posts/1/edit
        def edit(post_id) 
            unless @state.user_id.blank?
                @user = User.find @state.user_id
            end
            @post = Post.find post_id
            @all_clips = Models::Clip.find :all;      @these_posts_clips = @post.clips
            @all_posts_tags = Models::Tag.find :all;  @these_posts_tags = @post.tags
            @all_authors = Models::Author.find :all;  @these_posts_authors = @post.authors
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
            clip = Clip.create(:nickname => input.clip_nickname, :url => input.clip_url, :body => input.clip_body)
            all_posts = Models::Post.find :all
            all_posts.each{|p| if input.include?(p.title); 
                clip.references<<(Reference.create :post_id => p.id, :clip_id => clip.id); end; }
            redirect R(Posts)
        end
        
        # GET /clips/1
        # GET /clips/1.xml
        def read(clip_id) 
            @clip = Clip.find clip_id;
            @posts = @clip.posts
            render :view_clip
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
                @all_posts = Models::Post.find :all; @these_clips_posts = nil
                @clip = Clip.new
            end
            render :add_clip
        end     
        
        # DELETE /clips/1
        def delete(clip_id)
            unless @state.user_id.blank?
                @clip = Clip.find clip_id
                if @clip.destroy
                  redirect R(Posts)
                else
                  _error("Unable to delete clip #{@clip.id}", 500)
                end
            else
              _error("Unauthorized", 401)
            end
        end
                
        # GET /clips/1/edit
        def edit(clip_id) 
            unless @state.user_id.blank?
                @user = User.find @state.user_id
            end
            @clip = Models::Clip.find clip_id
            @all_posts = Models::Post.find :all;      @these_clips_posts = @clip.posts
            @all_clips_tags = Models::Tag.find :all;  @these_clips_tags = @clip.tags
            render :edit_clip
        end
        
        # PUT /clips/1
        def update(clip_id)
            unless @state.user_id.blank?
                clip = Clip.find clip_id
                all_tags = Models::Tag.find :all
                clip.update_attributes :url => input.clip_url, :body => input.clip_body, :nickname => input.clip_nickname
                these_tags = clip.tags
                these_tags.each{|d| unless input.include?(d.name); 
                    clip.taggings.delete(Tagging.find(:all, :conditions => ["tag_id = #{d.id} AND  taggable_id = #{clip.id}"] )); end; }
                not_these_tags = all_tags - these_tags
                not_these_tags.each{|a| if input.include?(a.name); 
                    clip.taggings.push(Tagging.create(:taggable_id => clip.id, :taggable_type => "Clip", :tag_id => a.id)); end; }
                all_posts = Models::Post.find :all
                these_clips_posts = clip.posts
                these_clips_posts.each{|d|  clip.references.delete(Reference.find(:all, :conditions => ['post_id =?', d.id])) }
                all_posts.each{|p| if input.include?(p.title); 
                    clip.references<<(Reference.create :post_id => p.id, :clip_id => clip.id); end; }
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
            @taggables = @tags.collect{|t| t.taggables}.flatten
            render :view_tags
        end
        
        # GET /tags/1
        # GET /tags/1.xml
        def read(tag_id) 
            @tag = Tag.find tag_id
            @tags = Tag.find :all
            @taggables = @tag.taggables
            @posts = Array.new; @clips = Array.new; @pages = Array.new; @authors = Array.new;
            @taggables.each{|t|  if t.instance_of?(Kambi::Models::Post); @posts<<t; 
                elsif t.instance_of?(Kambi::Models::Clip);  @clips<<t;
                elsif t.instance_of?(Kambi::Models::Page); @pages<<t;  
                elsif t.instance_of?(Kambi::Models::Author); @authors<<t; end; }
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
        
        # DELETE /comments/1
        def delete(comment_id)
            unless @state.user_id.blank?
                @comment = Comment.find comment_id
                if @comment.destroy
                  redirect R(Posts)
                else
                  _error("Unable to delete comment #{@comment.id}", 500)
                end
            else
              _error("Unauthorized", 401)
            end
        end     
    end
    
    class Authors < REST 'authors'
      # POST /authors
      def create
        Models::Author.create(:first => input.author_first, :last => input.author_last,
                    :url => input.author_url, :photo_url => input.author_photo_url,
                    :org => input.author_org, :org_url => input.author_org_url,
                    :bio => input.author_bio)
        redirect R(Authors, input.author_id)
      end
      
      # GET /authors
      # GET /authors.xml
      def list
          @authors = Author.find :all
          render :view_authors
      end
      
      # GET /authors/1
      # GET /authors/1.xml
      def read(author_id) 
          @author = Author.find author_id
          @posts = @author.posts
          render :view_author
      end
      
      # DELETE /authors/1
      def delete(author_id)
          unless @state.user_id.blank?
              @author = Models::Author.find author_id
              if @author.destroy
                redirect R(Posts)
              else
                _error("Unable to delete author #{@author.id}", 500)
              end
          else
            _error("Unauthorized", 401)
          end
      end
      
      # GET /authors/new
      def new
          unless @state.user_id.blank?
              @user = User.find @state.user_id
              @author = Models::Author.new; @these_authors_tags = nil;
          end
          render :add_author
      end
      
      # GET /authors/1/edit
      def edit(author_id) 
          unless @state.user_id.blank?
              @user = User.find @state.user_id
          end
          @author = Models::Author.find author_id
          @all_posts = Models::Post.find :all;  @these_authors_posts = @author.posts
          @all_tags = Models::Tag.find :all;    @these_authors_tags = @author.tags
          render :edit_author
      end
      
      # PUT /authors/1
      def update(author_id)
          unless @state.user_id.blank?
              author = Author.find author_id
              all_tags = Models::Tag.find :all
              author.update_attributes :first => input.author_first, :last => input.author_last,
                          :url => input.author_url, :photo_url => input.author_photo_url,
                          :org => input.author_org, :org_url => input.author_org_url,
                          :bio => input.author_bio
              these_tags = author.tags
              these_tags.each{|d| unless input.include?(d.name); 
                  author.taggings.delete(Tagging.find(:all, :conditions => ["tag_id = #{d.id} AND  taggable_id = #{author.id}"] )); end; }
              not_these_tags = all_tags - these_tags
              not_these_tags.each{|a| if input.include?(a.name); 
                  author.taggings.push(Tagging.create(:taggable_id => author.id, :taggable_type => "Author", :tag_id => a.id)); end; }
              all_posts = Models::Post.find :all
              these_authors_posts = author.posts
              these_authors_posts.each{|d|  author.authorships.delete(Authorship.find(:all, :conditions => ['post_id =?', d.id])) }
              all_posts.each{|p| if input.include?(p.title); 
                  author.authorships<<(Authorship.create :post_id => p.id, :author_id => author.id); end; }
              redirect R(Authors)
          else
            _error("Unauthorized", 401)
          end
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
        
        # GET /sessions/new
        def new
            render :edit_post
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
                    font-family: Georga, Utopia, serif;
                }
                h1.header {
                    background-color: #e5e5e5;
                    margin: 0; padding: 10px;
                    border-top: 8px solid #990000;
                }
                div.content {
                    padding: 10px;
                }
                div.break{
                    clear:both;
                }
                div.page{
                    font-family:georgia,"lucida bright","times new roman",serif;
                    width:50%;
                    float:left;
                    text-align:justify;
                    word-spacing:0.25em;
                    border-bottom: 8px solid #990000;
                    line-height:1.3em;
                }
                div.post {
                    font-family:georgia,"lucida bright","times new roman",serif;
                    width: 50%;
                    text-align:justify;
                    word-spacing:0.25em;
                    float:left;
                    border-bottom: 8px solid #990000;
                    line-height:1.3em;
                }
                div.clip{
                    padding: 1em;
                    border-top: 4px solid #444;
                    width:20%;
                    text-align:justify;
                    float:right;
                    clear:right;
                    margin-right:20%;
                    line-height:1.3em;
                    word-spacing:0.25em;
                    font-size:90%;
                }
                div.author{
                    border-bottom: 8px solid #990000;
                }
                div.tags {
                    font-size: 80%;
                    color: #990000;
                    border-left: 1px solid #444;
                    padding-left:1em;
                }
                div.tags a:hover{
                    background:yellow;
                    border-bottom: 1px solid yellow;
                    color:black;
                }
                a{
                    font-family:"Helvetica Neue",Helvetica,Arial,sans-serif;
                }
                a:link,a:visited {
                    color:black;
                    border-bottom: 1px dotted #990000;
                    text-decoration:none;
                }
                a:hover {
                    color:white;
                    background:#990000;
                    text-decoration:none;
                }
                div.comments{
                    padding: 1em;
                    margin-top: 1em;
                    border-left: 4px solid #444;
                    font-family:"Helvetica Neue",Helvetica,Arial,sans-serif;
                    float:left;
                    clear:both;
                }
                div.comment{
                    padding: 1em;
                    margin-right: 4em;
                    border-left: 1px solid #444;
                }
                div.time{
                    font-size:70%;
                    color: #990000;
                    border-left: 1px solid #444;
                    padding-left:1em;
                    font-family:georgia,"lucida bright","times new roman",serif;   
                }
                div.cloud{
                    padding-left:10%;
                }
                div.cloud a:hover{
                    background:yellow;
                    border-bottom: 1px solid yellow;
                }
            }
        end
    end
end