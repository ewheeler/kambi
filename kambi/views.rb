#!ruby
module Kambi::Views

    module HTML
      include Kambi::Helpers
      include Kambi::Models
      include Kambi::Controllers
        
        # the markaby gem doesn't seem to provide
        # a way of switching to xhtml 1.1 strict,
        # so i've manually implemented it here.
        # TODO: is there a cleaner way to do this?
        def xhtml11(&block)
          self.tagset = Markaby::XHTMLStrict
          declare! :DOCTYPE, :html, :PUBLIC, "-//W3C//DTD XHTML 1.1//EN", "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd"
          tag! :html, :xmlns => "http://www.w3.org/1999/xhtml", 'xml:lang' => "en", &block
          self
        end
        
        # only execute the block if the current
        # user is logged in to the website
        def when_logged_in(&block)
          unless @state.user_id.blank?
            yield
          end
        end
        
        def layout
          xhtml11 do
            head do
              title "Kambi"
              link( :rel => "stylesheet", :type => "text/css", :href => "/static/css/base.css",    :media => "screen")
              link( :rel => "stylesheet", :type => "text/css", :href => "/static/css/anserai.css", :media => "screen")
            end
            
            body do
              div.wrapper! do
                div.header! do
                  h1 { a 'Kambi', :href => R(Posts) }
                  
                  when_logged_in do
                    div.logged_in_as! do
                        span "You are logged in as "
                        span.username(@state.user_name)
                    end
                  end
                  
                  ul.nav! do
                    # the small left nav
                    li.home  { a("Home",  :href => R(Posts) )}
                    li.about { a("About", :href => "TODO" )}
                  end
                  
                  for page in Page.find :all
                    a(page.title, :href => R(Pages, page.id))
                  end
                  
                  ul.places! do
                    # the top-right "places" nav
                    li { a("All Essays",    :href => R(Posts)   )}
                    li { a("All Resources", :href => R(Clips)   )}
                    li { a("All Tags",      :href => R(Tags)    )}
                    li { a("Authors",       :href => R(Authors) )}
                  end
                  
                  # the floaty admin navigation
                  # only appears when logged in
                  when_logged_in do
                    div.admin_toolbox! do
                      h3 "Admin Toolbox"
                      ul do
                        li { a("New Page",     :href => R(Pages,   "new")) }
                        li { a("New Essay",    :href => R(Posts,   "new")) }
                        li { a("New Resource", :href => R(Clips,   "new")) }
                        li { a("New Tag",      :href => R(Tags,    "new")) }
                        li { a("New Author",   :href => R(Authors, "new")) }
                        
                        # requires class for css hackery (ie<7 compat)
                        li.last { a(:href => "TODO") { "Log out &raquo;" } }
                      end
                    end
                  end
                  
                  div.clear_hack ""
                end
                div.content! do
                  self << yield
                end
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
                @authors = post.authors
                _post(post)
              end
                clips = post.clips
                for clip in clips
                  tag_names = clip.tags.collect{|t| t.name}
                  tag_names.to_s
                  if tag_names.include?('project')
                      div.project do
                        _clip(clip)
                      end
                  else
                    div.clip do
                      _clip(clip)
                    end
                  end
                end
              div.break do
                p ''
              end
            end
          end
          div.cloud do
            _cloud
          end
        end   
    
        def login
          p { b @login }
          p { a 'Continue', :href => R(Posts) }
        end
    
        def logout
          p "You have been logged out."
          p { a 'Continue', :href => R(Posts) }
        end
        
        def add_author
          if @user
            _author_form(@author, :action => R(Authors))
          else
            _login
          end
        end
        
        def add_page
          if @user
            _page_form(@page, :action => R(Pages))
          else
            _login
          end
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
        
        def add_tag
          if @user
            _tag_form(@tag, :action => R(Tags))
          else
            _login
          end
        end
        
        def edit_author
          if @user
            _author_form(@author, :action => R(@author), :method => :put)
          else
            _login
          end
        end
        
        def edit_page
          if @user
            _page_form(@page, :action => R(@page), :method => :put)
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
        
        # def edit_tag
        #   if @user
        #     _tag_form(@tag, :action => R(@tag), :method => :put)
        #   else
        #     _login
        #   end
        # end
        
        def view
          div.post do
            _post(@post)
          end
            for clip in @clips
              tag_names = clip.tags.collect{|t| t.name}
              tag_names.to_s
              if tag_names.include?('project')
                  div.project do
                    _clip(clip)
                  end
              else
                div.clip do
                  _clip(clip)
                end
              end
            end
            div.comments do
              p "Comments:"
              for c in @comments
                div.comment do
                  h1 c.username + ' says:'
                  p c.body
                  div.time do
                    p c.pretty_time
                  end
                  unless @state.user_id.blank?
                    a('Delete', :href => R(Comments, c.id, 'delete'))
                  end
                end
              end
              form :action => R(Comments), :method => 'post' do
                src = @captcha[:filename]
                hush = @captcha[:hushhush]
                img :src => "/static/" + src; br
                label 'Please enter the above number', :for => 'captcha'; br
                input :name => 'captcha', :type => 'text'; br
                
                label 'Name', :for => 'post_username'; br
                input :name => 'post_username', :type => 'text'; br
                label 'Comment', :for => 'post_body'; br
                textarea :name => 'post_body' do; end; br
                input :type => 'hidden', :name => 'post_id', :value => @post.id
                input :type => 'hidden', :name => 'hushhush', :value => hush
                input :type => 'submit', :value => 'Submit'
            end
          end
        end
        
        def view_authors
          div.author do
            for author in @authors
              _author(author)
            end
          end
        end
        
        def view_author
          div.author do
            _author(author)
          end
          p "Essays written by "+ author.name + ":"
          for post in @posts
            a(post.title, :href => R(Posts, post.id))
          end
        end
        
        def view_clip
          div.clip do
            _clip(@clip)
          end
          div.post do
            p "Essays referring to " + @clip.nickname + " :"
            for post in @posts
              a(post.title, :href => R(Posts, post.id))
            end
          end
          div.page do
            p "Pages referring to " + @clip.nickname + " :"
            for page in @pages
              a(page.title, :href => R(Pages, page.id))
            end
          end
        end
        
        def view_page
          div.page do
            _page(@page)
          end
          for clip in @clips
            tag_names = clip.tags.collect{|t| t.name}
            tag_names.to_s
            if tag_names.include?('project')
                div.project do
                  _clip(clip)
                end
            else
              div.clip do
                _clip(clip)
              end
            end
          end
        end
        
        def view_tags
          div.cloud do
            _cloud
          end
          if @tag
            h3 @tag.name
            unless @posts.nil? or @posts.empty?
              div.tags do
                p "Essays tagged with " + @tag.name + ":"
                for post in @posts
                  a(post.title, :href => R(Posts, post.id)) 
                end
              end
            end
            unless @clips.nil? or @clips.empty?
              div.tags do
                p "Resources tagged with " + @tag.name + ":"
                for clip in @clips
                  a(clip.nickname, :href => R(Clips, clip.id))   
                end
              end
            end
            unless @pages.nil? or @pages.empty?
              div.tags do
                p "Pages tagged with " + @tag.name + ":"
                for page in @pages
                  a(page.nickname, :href => R(Pages, page.id))   
                end
              end
            end
            unless @authors.nil? or @authors.empty?
              div.tags do
                p "Authors tagged with " + @tag.name + ":"
                for author in @authors
                  a(author.name, :href => R(Authors, author.id))   
                end
              end
            end
            unless @state.user_id.blank?
              _tag(@tag)
            end
          end
        end
        
        def view_clips
          h2 "Resources:"
          for clip in @clips
            div.clip do
              a(clip.nickname, :href => R(Clips, clip.id, 'edit'))
              tags = clip.tags unless clip.tags.nil?
              unless tags.empty?
                div.tags do
                  p "tagged with:"
                  for tag in tags
                    a(tag.name, :href => R(Tags, tag.id))
                  end
                end
              end
              p clip.body
              h3 "Referenced in:" unless clip.references.empty?
              for post in clip.posts
                a(post.title, :href => R(Posts, post.id))
              end
              for page in clip.pages
                a(page.title, :href => R(Pages, page.id))
              end
            end
          end
        end
    
        # partials
        def _login
          form :action => R(Sessions), :method => 'post' do
            label 'Username', :for => 'username'; br
            input :name => 'username', :type => 'text'; br
            label 'Password', :for => 'password'; br
            input :name => 'password', :type => 'password'; br
            input :type => 'submit', :name => 'login', :value => 'Login'
          end
        end
        
        def _cloud
          h2 "Tags:"
          all_tags = Kambi::Models::Tag.find(:all)
          all_tags_items = Array.new(all_tags)
          all_tags_taggables = all_tags_items.collect!{|t| t.taggables.compact}
          tags_counts = all_tags_taggables.collect!{|g| g.length}
          maxtc = 0; mintc = 3
          tags_counts.each{|c| maxtc = c if c > maxtc; mintc = c if c < mintc}
          for c in all_tags
            tag_index = all_tags.index(c)
            a( c.name, :href => R(Tags, c.id), :style => font_size_for_tag_cloud( tags_counts.fetch(tag_index), mintc, maxtc) )
          end
        end
        
        def _tag(tag)
          a('Delete ' + tag.name, :href => R(Tags, tag.id, 'delete')) 
        end
        
        def _page(page)
          h1 do
            a(page.title, :href => R(Pages, page.id))
          end
          tags = page.tags unless page.tags.nil?
          unless tags.empty?
            div.tags do
              p "tagged with:"
              for tag in tags
                a(tag.name, :href => R(Tags, tag.id))
              end
            end
          end
          p page.body
          unless @state.user_id.blank?
            p do
              a("Edit Page", :href => R(Pages, page.id, 'edit'))
            end
          end
        end
        
        def _post(post)
          h1 do
            a(post.title, :href => R(Posts, post.id))
          end
          tags = post.tags unless post.tags.nil?
          unless tags.empty?
            div.tags do
              span "Tags:"
              for tag in tags
                a(tag.name, :href => R(Tags, tag.id))
              end
            end
          end
          unless @authors.empty?
            step = 0
            p do h4 "by"
              for author in @authors
                  a(author.name, :href => R(Authors, author.id)) if step == 0
                  h4 "and " unless step == 0
                  a(author.name, :href => R(Authors, author.id)) unless step == 0
                  step = step.next
              end
            end
          end
          p post.body
          div.time do
            p post.pretty_time
          end
          unless @state.user_id.blank?
            p do
              a("Edit Essay", :href => R(Posts, post.id, 'edit'))
            end
          end
        end
        
        def _clip(clip)
          a(clip.nickname, :href => clip.url)
          p clip.source
          tags = clip.tags unless clip.tags.nil?
          unless tags.empty?
            div.tags do
              p "tagged with:"
              for tag in tags
                a(tag.name, :href => R(Tags, tag.id))
              end
            end
          end
          p clip.body
          unless @state.user_id.blank?
            p do
              a("Edit Resource", :href => R(Clips, clip.id, 'edit'))
            end
          end
        end
        
        def _author(author)
          a(author.name, :href => author.url)
          tags = author.tags unless author.tags.nil?
          unless tags.empty?
            div.tags do
              p "tagged with:"
              for tag in tags
                a(tag.name, :href => R(Tags, tag.id))
              end
            end
          end
          a(author.photo_url, :href => author.photo_url)
          p "Organization:"
          a(author.org, :href => author.org_url)
          p "Bio:"
          p author.bio
          unless @state.user_id.blank?
            p do
              a("Edit Author", :href => R(Authors, author.id, 'edit'))
            end
          end
        end
        
        
        def _page_form(page, opts)
          a('Delete Page', :href => R(Pages, page.id, 'delete')) unless @these_tags.nil?
          form({:method => 'post'}.merge(opts)) do
            label 'Title', :for => 'page_title'; br
            input :name => 'page_title', :type => 'text', 
                  :value => page.title; br
            label 'Nickname', :for => 'page_nickname'; br
            input :name => 'page_nickname', :type => 'text',
                  :value => page.nickname; br
            label 'Body', :for => 'page_body'; br
            textarea page.body, :name => 'page_body'; br
             
            if @all_tags
              p "Tagged with:"  
              _tag_checks(@all_tags, @these_tags)
            end
            if @all_clips
              p "References:"
              _clip_checks(@all_clips, @these_clips)
            end
            input :type => 'hidden', :name => 'page_id', :value => page.id
            input :type => 'submit', :value => 'Submit'
          end 
        end
      
    
        def _post_form(post, opts)
          form(:action => R(Sessions), :method => 'delete') do
          p do 
            span "You are logged in as #{@user.username}"
            span " | "
            button(:type => 'submit') {'Logout'}
          end
          a('Delete Essay', :href => R(Posts, post.id, 'delete')) unless @these_tags.nil?
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
            
            if @all_authors
              p "Author(s):"        
              _author_checks(@all_authors, @these_authors)
            end
             
            if @all_tags
              p "Tagged with:"        
             _tag_checks(@all_tags, @these_tags)
            end
            if @all_clips
              p "References:"
              _clip_checks(@all_clips, @these_clips)
            end
            input :type => 'hidden', :name => 'post_id', :value => post.id
            input :type => 'submit', :value => 'Submit'
          end 
        end
        
        
        def _clip_form(clip, opts)
          form(:action => R(Sessions), :method => 'delete') do
          p do 
            span "You are logged in as #{@user.username}"
            span " | "
            button(:type => 'submit') {'Logout'}
          end
          a('Delete Resource', :href => R(Clips, clip.id, 'delete')) unless @these_tags.nil?
          end
          form({:method => 'post'}.merge(opts)) do
            label 'Nickname', :for => 'clip_nickname'; br
            input :name => 'clip_nickname', :type => 'text', 
                  :value => clip.nickname; br
            label 'Url', :for => 'clip_url'; br
            input :name => 'clip_url', :type => 'text', 
                  :value => clip.url; br   
            label 'Source', :for => 'clip_source'; br
            input :name => 'clip_source', :type => 'text', 
                  :value => clip.source; br
            label 'Body', :for => 'clip_body'; br
            textarea clip.body, :name => 'clip_body'; br
            
            if @all_tags
              p "Tagged with:"
              _tag_checks(@all_tags, @these_tags)
            end
            if @all_posts
              p "Referenced in:"
                _post_checks(@all_posts, @these_posts)
                _page_checks(@all_pages, @these_pages)
            end
            input :type => 'hidden', :name => 'clip_id', :value => clip.id
            input :type => 'submit', :value => 'Submit'
          end
        end 
        
        def _author_form(author, opts)
           form(:action => R(Sessions), :method => 'delete') do
           p do 
             span "You are logged in as #{@user.username}"
             span " | "
             button(:type => 'submit') {'Logout'}
           end
           a('Delete Author', :href => R(Authors, author.id, 'delete')) unless @these_tags.nil?
           end
           form({:method => 'post'}.merge(opts)) do
             label 'First Name', :for => 'author_first'; br
             input :name => 'author_first', :type => 'text', 
                   :value => author.first; br
             label 'Last Name', :for => 'author_last'; br
             input :name => 'author_last', :type => 'text', 
                   :value => author.last; br
             label 'Url', :for => 'author_url'; br
             input :name => 'author_url', :type => 'text', 
                   :value => author.url; br
             label 'Photo Url', :for => 'author_photo_url'; br
             input :name => 'author_photo_url', :type => 'text', 
                   :value => author.photo_url; br
             label 'Organization', :for => 'author_org'; br
             input :name => 'author_org', :type => 'text', 
                   :value => author.org; br
             label 'Organization Url', :for => 'author_org_url'; br
             input :name => 'author_org_url', :type => 'text', 
                   :value => author.org_url; br
             label 'Bio', :for => 'author_bio'; br
             textarea author.bio, :name => 'author_bio'; br
             
             if @all_tags
               p "Tagged with:"
               _tag_checks(@all_tags, @these_tags)
             end
             
             if @all_posts
               p "Authorships:"
               _post_checks(@all_posts, @these_posts)
             end
             input :type => 'hidden', :name => 'author_id', :value => author.id
             input :type => 'submit', :value => 'Submit'
           end
        end
        
        def _tag_form(tag, opts)
          form(:action => R(Sessions), :method => 'delete') do          
            p do 
              span "You are logged in as #{@user.username}"
              span " | "
              button(:type => 'submit') {'Logout'}
            end
          end
          form({:method => 'post'}.merge(opts)) do
            label 'Tag Name', :for => 'tag_name'; br
            input :name => 'tag_name', :type => 'text', :value => tag.name; br
            input :type => 'submit', :value => 'Submit'
          end
        end
        
        def _post_checks(all_posts, these_posts)
          for post in all_posts
            if !these_posts.nil? and these_posts.include?(post)
              input :type => 'checkbox', :name => 'post-' + post.id.to_s, :value => post, :checked => 'true'
              label post.title, :for => 'post-' + post.id.to_s; br
            else
              input :type => 'checkbox', :name => 'post-' + post.id.to_s, :value => post
              label post.title, :for => 'post-' + post.id.to_s; br
            end
          end
        end
        
        def _tag_checks(all_tags, these_tags)
          for tag in all_tags
            if !these_tags.nil? and these_tags.include?(tag)
              input :type => 'checkbox', :name => 'tag-' + tag.id.to_s, :value => tag, :checked => 'true'
              label tag.name, :for => tag.name.to_s; br
            else
              input :type => 'checkbox', :name => 'tag-' + tag.id.to_s, :value => tag
              label tag.name, :for => 'tag-' + tag.id.to_s; br
            end
          end
        end
        
        def _clip_checks(all_clips, these_clips)
          for clip in all_clips
            if !these_clips.nil? and these_clips.include?(clip)
              input :type => 'checkbox', :name => 'clip-' + clip.id.to_s, :value => clip, :checked => 'true'
              label clip.nickname, :for => 'clip-' + clip.id.to_s; br
            else
              input :type => 'checkbox', :name => 'clip-' + clip.id.to_s, :value => clip
              label clip.nickname, :for => 'clip-' + clip.id.to_s; br
            end
          end
        end
        
        def _author_checks(all_authors, these_authors)
          for author in all_authors
            if !these_authors.nil? and these_authors.include?(author)
              input :type => 'checkbox', :name => 'author-' + author.id.to_s, :value => author, :checked => 'true'
              label author.name, :for => 'author-' + author.id.to_s; br
            else
              input :type => 'checkbox', :name => 'author-' + author.id.to_s, :value => author
              label author.name, :for => 'author-' + author.id.to_s; br
            end
          end
        end
        
        def _page_checks(all_pages, these_pages)
          for page in all_pages
            if !these_pages.nil? and these_pages.include?(page)
              input :type => 'checkbox', :name => 'page-' + page.id.to_s, :value => page, :checked => 'true'
              label page.title, :for => 'page-' + page.id.to_s; br
            else
              input :type => 'checkbox', :name => 'page-' + page.id.to_s, :value => page
              label page.title, :for => 'page-' + page.id.to_s; br
            end
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

