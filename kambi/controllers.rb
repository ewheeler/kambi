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
                all_clips.each{|c| if input.include?('clip-' + c.id.to_s); 
                    @page.references<<(Reference.create :page_id => @page.id, :clip_id => c.id); end; }
                
                all_tags = Models::Tag.find :all
                these_taggings = Array.new(@page.taggings)
                these_taggings.each{|d| @page.taggings.delete(d) }
                
                all_tags.each{|a| if input.include?('tag-' + a.id.to_s); 
                    @page.taggings<<(Tagging.create( :taggable_id => @page.id, :taggable_type => 'Page', :tag_id => a.id)); end; }
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
                @page = Page.new; 
                @all_clips = Models::Clip.find :all;      @these_clips = nil
                @all_tags = Models::Tag.find :all;  @these_tags = nil
            end
            render :add_page
        end

        # GET /pages/1/edit
        def edit(page_id) 
            unless @state.user_id.blank?
                @user = User.find @state.user_id
            end
            @page = Page.find page_id
            @all_clips = Models::Clip.find :all;      @these_clips = @page.clips
            @all_tags = Models::Tag.find :all;  @these_tags = @page.tags
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
            @captcha = turing_image
            render :view
        end

        # PUT /posts/1
        def update(post_id)
            unless @state.user_id.blank?
                @post = Post.find post_id
                
                all_authors = Models::Author.find :all
                @post.authors.each{|d| @post.authorships.delete(Authorship.find(:all, :conditions => ["author_id = #{d.id} AND  post_id = #{@post.id}"] )) }
                all_authors.each{|a| if input.include?('author-' + a.id.to_s); 
                    @post.authorships<<(Authorship.create( :post_id => @post.id, :author_id => a.id)); end; }
                    
                all_clips = Models::Clip.find :all
                @post.clips.each{|d| @post.references.delete(Reference.find(:all, :conditions => ["clip_id = #{d.id}"] )) }
                all_clips.each{|c| if input.include?('clip-' + c.id.to_s); 
                    @post.references<<(Reference.create :post_id => @post.id, :clip_id => c.id); end; }
                
                all_tags = Models::Tag.find :all                
                these_taggings = Array.new(@post.taggings)
                these_taggings.each{|d| @post.taggings.delete(d) }
                
                all_tags.each{|a| if input.include?('tag-' + a.id.to_s); 
                    @post.taggings<<(Tagging.create( :taggable_id => @post.id, :taggable_type => 'Post', :tag_id => a.id)); end; }
                    
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
                @post = Post.new;
                @all_clips = Models::Clip.find :all;      @these_clips = nil
                @all_tags = Models::Tag.find :all;  @these_tags = nil
                @all_authors = Models::Author.find :all;  @these_authors = nil
            end
            render :add_post
        end

        # GET /posts/1/edit
        def edit(post_id) 
            unless @state.user_id.blank?
                @user = User.find @state.user_id
            end
            @post = Post.find post_id
            @all_clips = Models::Clip.find :all;      @these_clips = @post.clips
            @all_tags = Models::Tag.find :all;  @these_tags = @post.tags
            @all_authors = Models::Author.find :all;  @these_authors = @post.authors
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
            all_posts.each{|p| if input.include?('post-' + p.id.to_s); 
                clip.references<<(Reference.create :post_id => p.id, :clip_id => clip.id); end; }
            redirect R(Posts)
        end
        
        # GET /clips/1
        # GET /clips/1.xml
        def read(clip_id) 
            @clip = Clip.find clip_id;
            @posts = @clip.posts
            @pages = @clip.pages
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
                @all_posts = Models::Post.find :all; @these_posts = nil
                @all_tags = Models::Tag.find :all;  @these_tags = nil
                @all_pages = Models::Page.find :all; @these_pages = nil
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
            @all_posts = Models::Post.find :all;      @these_posts = @clip.posts
            @all_tags = Models::Tag.find :all;  @these_tags = @clip.tags
            @all_pages = Models::Page.find :all; @these_pages = @clip.pages
            render :edit_clip
        end
        
        # PUT /clips/1
        def update(clip_id)
            unless @state.user_id.blank?
                clip = Clip.find clip_id
                all_tags = Models::Tag.find :all
                clip.update_attributes :url => input.clip_url, :body => input.clip_body, :nickname => input.clip_nickname
                
                these_taggings = Array.new(clip.taggings)
                these_taggings.each{|d| clip.taggings.delete(d) }
                
                all_tags.each{|a| if input.include?('tag-' + a.id.to_s); 
                    clip.taggings<<(Tagging.create(:taggable_id => clip.id, :taggable_type => 'Clip', :tag_id => a.id)); end; }
                
                all_posts = Models::Post.find :all
                these_clips_posts = clip.posts
                these_clips_posts.each{|d|  clip.references.delete(Reference.find(:all, :conditions => ['post_id =?', d.id])) }
                all_posts.each{|p| if input.include?('post-' + p.id.to_s); 
                    clip.references<<(Reference.create :post_id => p.id, :clip_id => clip.id); end; }
                    
                all_pages = Models::Page.find :all
                these_clips_pages = clip.pages
                these_clips_pages.each{|d|  clip.references.delete(Reference.find(:all, :conditions => ['page_id =?', d.id])) }
                all_pages.each{|p| if input.include?('page-' + p.id.to_s); 
                    clip.references<<(Reference.create :page_id => p.id, :clip_id => clip.id); end; }
            
                # all_pages = Models::Page.find :all
                # these_references = Array.new(clip.references)
                # these_references.each{|r| clip.references.delete(r)}
                # 
                # all_referables = all_posts + all_pages
                # all_referables.each{|r| 
                #     if input.include?('post-' + r.id.to_s);
                #       puts r.title;
                #       clip.references<<(Reference.create :post_id => r.id, :clip_id => clip.id); 
                #     end;
                #     if input.include?('page-' + r.id.to_s);
                #       puts r.title;
                #       clip.references<<(Reference.create :page_id => r.id, :clip_id => clip.id); 
                #     end;}
                
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
                @user = User.find @state.user_id
            end
            @tag = Tag.new
            render :add_tag
        end
        
        # # GET /tag/1/edit
        # def edit(tag_id) 
        #     unless @state.user_id.blank?
        #         @user = User.find @state.user_id
        #     end
        #     @tag = Tag.find tag_id
        #     render :edit_tag
        # end
        # 
        # # PUT /tags/1
        # def update(tag_id)
        #     unless @state.user_id.blank?
        #         @tag = Tag.find tag_id
        #         @tag.update_attributes :name => input.tag_name
        #         @taggables = @tag.taggables
        #         @posts = Array.new; @clips = Array.new; @pages = Array.new; @authors = Array.new;
        #         @taggables.each{|t|  if t.instance_of?(Kambi::Models::Post); @posts<<t; 
        #             elsif t.instance_of?(Kambi::Models::Clip);  @clips<<t;
        #             elsif t.instance_of?(Kambi::Models::Page); @pages<<t;  
        #             elsif t.instance_of?(Kambi::Models::Author); @authors<<t; end; }
        #         render :view_tags
        #     else
        #       _error("Unauthorized", 401)
        #     end
        # end
    end 
     
    class Comments < REST 'comments'
        # POST /comments
        def create

          if input.captcha == input.hushhush
              Models::Comment.create(:username => input.post_username,
                         :body => input.post_body, :post_id => input.post_id)
          
          end
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
              @author = Models::Author.new; 
              @all_posts = Models::Post.find :all;  @these_posts = nil
              @all_tags = Models::Tag.find :all;    @these_tags = nil
          end
          render :add_author
      end
      
      # GET /authors/1/edit
      def edit(author_id) 
          unless @state.user_id.blank?
              @user = User.find @state.user_id
          end
          @author = Models::Author.find author_id
          @all_posts = Models::Post.find :all;  @these_posts = @author.posts
          @all_tags = Models::Tag.find :all;    @these_tags = @author.tags
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
              
              these_taggings = Array.new(author.taggings)
              these_taggings.each{|d| author.taggings.delete(d) }
              
              all_tags.each{|a| if input.include?('tag-' + a.id.to_s); 
                  author.taggings<<(Tagging.create(:taggable_id => author.id, :taggable_type => 'Author', :tag_id => a.id)); end; }
              all_posts = Models::Post.find :all
              these_authors_posts = author.posts
              these_authors_posts.each{|d|  author.authorships.delete(Authorship.find(:all, :conditions => ['post_id =?', d.id])) }
              all_posts.each{|p| if input.include?('post-' + p.id.to_s); 
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
    
    class Static < R '/static/(.+)'         
      MIME_TYPES = {'.css' => 'text/css', '.js' => 'text/javascript', 
                    '.jpg' => 'image/jpeg'}
      PATH = File.expand_path("../" + File.dirname(__FILE__))

      def get(path)
        @headers['Content-Type'] = MIME_TYPES[path[/\.\w+$/, 0]] || "text/plain"
        unless path.include? ".." # prevent directory traversal attacks
          @headers['X-Sendfile'] = "#{PATH}/static/#{path}"
        else
          @status = "403"
          "403 - Invalid path"
        end
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
                div.header{
                    background-color: #433C2A;
                    color:  #e5e5e5;
                    min-height:180px;
                    padding: 0pt;
                    margin: 0pt;
                    border-top: 8px solid #990000;
                }
                div.header h1 a{
                    font-family: Georgia, Utopia, serif;
                    color:  #e5e5e5;
                    font-size:150%;
                    margin-left: 20%;
                    border-bottom: 1px solid #433C2A;
                }
                div.header a{
                    font-family: Georgia, Utopia, serif;
                    color:  #A59E8F;
                    font-size:120%;
                    margin-left:5%;
                    border-bottom: 1px solid #433C2A;
                }
                h1, h2, h3{
                  color: #433C2A;
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
                    border-top: 4px solid #433C2A;
                    width:20%;
                    text-align:justify;
                    float:right;
                    clear:right;
                    margin-right:20%;
                    line-height:1.3em;
                    word-spacing:0.25em;
                    font-size:90%;
                }
                div.project{
                    padding: 1em;
                    border-top: 4px solid #433C2A;
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
                    font-size: 90%;
                    color: #990000;
                    border-left: 1px solid #433C2A;
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
                    color:#433C2A;
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
                    border-left: 4px solid #433C2A;
                    font-family:"Helvetica Neue",Helvetica,Arial,sans-serif;
                    float:left;
                    clear:both;
                }
                div.comment{
                    padding: 1em;
                    margin-right: 4em;
                    border-left: 1px solid #433C2A;
                }
                div.time{
                    font-size:70%;
                    color: #990000;
                    border-left: 1px solid #433C2A;
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