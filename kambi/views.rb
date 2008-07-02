#!/usr/bin/env ruby
# vim:tabstop=2:expandtab

module Kambi::Views
  module HTML
    include Kambi::Helpers
    include Kambi::Models
    include Kambi::Controllers
    include Ambethia::ReCaptcha::Helper
    include Ambethia::ReCaptcha::Controller

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

    
    # a clearer way of checking if the current
    # user is logged in to the website as admin
    def logged_in?
      return @state.user_id ? true : false
    end
    
    # only execute the block if the current
    # user is logged in to the website
    def when_logged_in(&block)
      if logged_in?
        yield
      else
				disaster("Please log in")
			end
    end

    def render_text(text, format=:lite)
      # lite formatting escapes html entities
      # and breaks the text into paragraphs
      if format==:lite
        enc = HTMLEntities.new
        unless text.nil? or text.empty?
          text.gsub("\r","").each("") do |chunk|
            p do
              enc.encode(chunk.trim, :named)
            end
          end
        end
      
      # html formatting does NOTHING to the
      # text. watch out for XSS vulnerabilities :O
      elsif format==:html
        div do
          text
        end
      
      # textile + markdown via redcloth
      elsif format==:red
        r = RedCloth.new text
        div do
          r.to_html
        end
      
      # what
      else
        raise(
          ArgumentError,
          "Unsupported format: #{format}")
      end
    end
    
    def help_text
      div.hint do
        "You may format your text using HTML, Textile, or Markdown." + a("Help", :href=> "/pages/help")
      end
    end
    
    def disaster(msg)
      p.disaster msg
    end

    def layout
      xhtml11 do
        head do
          #title "unisay"
					title "kambi"
          script(:type=>"text/javascript",:src=>"/static/admin.js") if logged_in?
          link :rel => "stylesheet", :type => "text/css", :href => "/static/css/base.css",    :media => "screen"
          link :rel => "stylesheet", :type => "text/css", :href => "/static/css/forms.css",   :media => "screen"
          link :rel => "stylesheet", :type => "text/css", :href => "/static/css/anserai.css", :media => "screen"
#          link :rel => "stylesheet", :type => "text/css", :href => "/static/css/unisay.css", :media => "screen"
          link :rel => "shortcut icon", :href => "/static/favicon.ico"
        end

        body do
          div.wrapper! do
            div.header! do
              h1 do
                a(:href => R(Posts)) do
                  span "unisay"
                end
              end

              ul.pages! do
                # the nav bar is hard-coded for now
                li(:class=>"n0 first") { a("Home",  :href=> "/"            )}
                li(:class=>"n1 last")  { a("About", :href=> "/pages/about" )}

#                Page.find(:all).each_with_css do |page,klass|
#                  li(:class=>klass) { a(page.title, :href => R(Pages, page.id)) }
#                end
              end

              ul.places! do
                # the top-right "places" nav
                li.p1 { a("All Essays",    :href => R(Posts))}
                li.p2 { a("All Resources", :href => R(Clips))}
                li.p3 { a("All Tags",      :href => R(Tags) )}
              end

              div.clear_hack ""
            end

            # wrapped multiple times
            # for css hackery
            div.content_wrap1! do
              div.content_wrap2! do
                div.content! do
                  self << yield
                end
              end
            end
      
            # tag cloud
            div.cloud do
              _cloud
            end

            div.footer! do
              div do
                p.links do
                  #a( "Privacy",  :href=> "/pages/privacy" ); span { "&bull;" }
                  a( "About",    :href=> "/pages/about"   ); span { "&bull;" }
                  #a( "Legal",    :href=> "/pages/legal"   ); span { "&bull;" }
                  a( "Login",    :href=>R(Sessions, :new) )
                end
                #p.rights "Copyright United Nations 2008. All Rights Reserved."
              end
            end

            # the floaty admin navigation
            # only appears when logged in
            when_logged_in do
              div.admin_toolbox! do
                h3("Admin Toolbox", :onclick=>"window.toggle_toolbox()")
                
                ul do
                  li { a("New Page",     :href => R(Pages,   "new")) }
                  li { a("New Essay",    :href => R(Posts,   "new")) }
                  li { a("New Resource", :href => R(Clips,   "new")) }
                  li { a("New Tag",      :href => R(Tags,    "new")) }
									li { a("New Bundle",   :href => R(Bundles, "new")) }
                  li { a("New Author",   :href => R(Authors, "new")) }

                  # requires class for css hackery (ie<7 compat)
                  li.last { a( "Log out", :href => R(Sessions, :delete)) }
                end
              end
            end
          end
          
          # logged in as banner at the bottom of
          # the html output (despite being at the
          # top of the rendered output) for IE6
          when_logged_in do
            div.logged_in_as! do
              span { "You are logged in as" }
              span.username(@state.user_name)
            end
          end
        end
      end
    end

    def view_posts
      # need to refactor
      # warning: default `to_a' will be obsolete
			p = @posts.to_a.compact
      unless p.empty?
        
        # render all posts passed to us (might
        # only be one, if this is the index page)
        p.each_with_css("post") do |post,klass|
          div(:class=>klass) do
            _post(post)
          end
        end
      else
        disaster "No posts found"
      end
    end

    # show a generic message (this
    # used to be the "logged in" page
    def msg
      h1(@h1) if @h1
      p(@msg) if @msg

      # show a link to continue to
      # the next page, or back home
      p do
        a(:href=>(@redir || "/")) do
          "Continue &raquo;"
        end
      end
    end

    # display the login form
    # (no longer a partial)
    def login
      form(:action=>R(Sessions), :method=>"post") do
        fieldset do
          div do
            label "Username", :for=>"fm-username"
            input :id=>"fm-username", :name=>"username", :class=>"text", :type=>"text"
          end
          div do
            label "Password", :for=>"fm-password"
            input :id=>"fm-password", :name=>"password", :class=>"text", :type=>"password"
          end

          div do
            input :type=>"submit", :class=>"submit button", :value=> "Login"
          end
        end
      end
    end

    def add_author
      when_logged_in do
        _author_form(@author, :action => R(Authors))
      end
    end

    def add_page
      when_logged_in do
        _page_form(@page, :action => R(Pages))
      end
    end

    def add_post
      when_logged_in do
        _post_form(@post, :action => R(Posts))
      end
    end

    def add_clip
      when_logged_in do
        _clip_form(@clip, :action => R(Clips))
      end
    end

    def add_tag
      when_logged_in do
        _tag_form(@tag, :action => R(Tags))
      end
    end
    
    def add_bundle
      when_logged_in do
        _bundle_form(@bundle, :action => R(Bundles))
      end
    end

		def edit_bundle
			when_logged_in do
				_bundle_form(@bundle, :action => R(@bundle), :method => :put)
			end
		end

    def edit_author
      when_logged_in do
        _author_form(@author, :action => R(@author), :method => :put)
      end
    end

    def edit_page
      when_logged_in do
        _page_form(@page, :action => R(@page), :method => :put)
      end
    end

    def edit_post
      when_logged_in do
        _post_form(@post, :action => R(@post), :method => :put)
      end
    end

    def edit_clip
      when_logged_in do
        _clip_form(@clip, :action => R(@clip), :method => :put)
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
      # only one on page, both first and last
      # add classes to recycle css styles
      div( :class=>"post n1 first last" ) do
        _post(@post)
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
          

#          form(:action=>R(Comments), :method=>"post") do
#            fieldset do
#              div do
#                label "Username", :for=>"fm-username"
#                input :id=>"fm-username", :name=>"username", :type=>"text"
#              end
#              div do
#                label "Password", :for=>"fm-password"
#                input :id=>"fm-password", :name=>"password", :type=>"password"
#              end

#              div do
#                button "Login"
#              end
#            end
#          end
      
          form :action => R(Comments), :method => 'post' do
            # src = @captcha[:filename]
            # hush = @captcha[:hushhush]
            # img :src => "/static/" + src; br
            # label 'Please enter the above number', :for => 'captcha'; br
            # input :name => 'captcha',  :class=>"text", :type => 'text'; br
            recaptcha_tags
            label 'Name', :for => 'post_username'; br
            input :name => 'post_username',  :class=>"text", :type => 'text'; br
            label 'Comment', :for => 'post_body'; br
            textarea :name => 'post_body' do; end; br
            input :type => 'hidden', :class=>"hidden", :name => 'post_id', :value => @post.id
            # input :type => 'hidden', :class=>"hidden",:name => 'hushhush', :value => hush
            input :type => 'submit', :class=>"submit button", :value => 'Submit'
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
                 #this was causing all of them to be nil
    def view_page#(page=nil)
      unless page.nil?
        div(:class=>"page page-1 first last") do
          _page(page)
        end
      else
        disaster "Page not found"
      end
    end

    def view_tags
      if @bundles
        div.bundles do
          _bundles
        end
      end
      
      if @tag
        thing_map = {
          "Essays"    => @posts,
          "Resources" => @clips,
          "Pages"     => @pages,
          "Authors"   => @authors
        }
        
        # do the same thing for all three taggables
        thing_map.keys.each_with_css("tagged") do |type,klass|
          things = thing_map[type]
          
          unless things.nil? or things.empty?
            div(:class=>klass) do
              h1 do
                text "#{type} tagged with "
                span @tag.name
              end
              ul do
                things.each do |thing|
                  li do
                    a thing.to_s, :href=>R(thing.restful_root, thing.id)
                  end
                end
              end
            end
          end
        end
      end

    end

    def view_clips
      h2 "Resources:"
      for clip in @clips
        div.clip do
          #a(clip.nickname, :href => R(Clips, clip.id, 'edit'))
          a(clip.nickname, :href => clip.url)
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
    
    def _bundles
      @bundles.each do |bundle|
				# this should be a nice red hovering edit link if logged in
				# and just a title otherwise
        h1 { a bundle.name, :href => R(Bundles, bundle.id, 'edit') }
         bundle.bundlings.each do |b|
           a b.tag.name, :href => R(Tags, b.tag.id)
     		end
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
        
        # never show the magic "project" tag
        unless c.name.downcase == "project"
          tag_index = all_tags.index(c)
          a( c.name, :href => R(Tags, c.id), :style => font_size_for_tag_cloud( tags_counts.fetch(tag_index), mintc, maxtc) )
        end
      end
    end

    def _tag(tag)
      a('Delete ' + tag.name, :href => R(Tags, tag.id, 'delete'))
    end

    def _tagged_with(tags)
      p.tags do
        span "Tags:"
        
        # ignore invalid arguments... or lists of tags that only contain "project" -- WTF
        unless(tags.nil? or tags.empty? or (tags.length == 1 and tags[0].name.downcase == "project"))
          tags.each do |tag|
            
            # never show the magic "project" tag
            unless tag.name.downcase == "project"
              a(tag.name, :href => R(Tags, tag.id))
            end
          end
        
        # oops: the dodgy layout
        # breaks the tag paragraph
        else; a "None"; end
      end
    end
    
    # render the right-hand-side bar, containing
    # the clips (projects and non) related to
    # a page or a post
    def _clips(clips)
      sorted = {
        :projects   => [],
        :references => [] }
      
      # section headers
      titles = {
        :projects   => "Related Projects",
        :references => "References" }
      
      # iterate all of this post/pages's clips,
      # sort them into "project" and "not
      # project" (reference) arrays
      clips.each do |clip|
        type = clip.has_tag?("project") ? (:projects) : (:references)
        sorted[type].push clip
      end
      
      # iterate each 'type' of clip, and create
      # div + h3 + (all clips of type)
      div.clips_box do
        [:projects, :references].each do |type|
          unless sorted[type].empty?
            div.clips do
              h3 titles[type]
              
              # all clips of this type,
              # via the _clip partial
              sorted[type].each_with_css("clip") do |clip,klass|
                div(:class=>klass) do
                  _clip clip
                end
              end
            end
          end
        end
      end
    end

    def _page(page)
      h1 { a(page.title, :href => R(Pages, page.id)) }
      
      when_logged_in do
        a( "Edit this Page",
           :class => "edit ed-page",
           :href  => R(Pages, page.id, 'edit'))
      end

      _tagged_with(page.tags)
      div.body { render_text(page.body, :red) }
      _clips(page.clips)
      
      # css hack for ie < 7
      div.clear_hack ""
    end

    def _post( post,summary=false )
      full = R(Posts, post.id)
      h1 { a(post.title, :href => full) }

      when_logged_in do
        a( "Edit this Essay",
           :class => "edit ed-post",
           :href  => R(Posts, post.id, 'edit'))
      end

      # the date in human readable
      # format: March 11th 2008
      p.date do
        day = post.created_at.mday
        ord = (day < 10 or day > 20)\
            ? %w{th st nd rd th th th th th th}[day % 10]\
            : "th" # all the teens are "th"

        # display the day including the ordinal
        span post.created_at.strftime("%B #{day}#{ord} %Y")
      end

      # the authors that produced this
      # post: Tom, Dick and Harry
      pa = post.authors
      p.authors do
        span "By"
        unless pa.empty?
          pa.each_with_index do |author,i|

            # capture the link as text, and add a join (COMMA or AND)
            link = capture { a(author.name, :href => R(Authors, author.id)) }
            join = (i < (pa.length-1)) ? (i < (pa.length-2) ? "," : " and ") : ""
            text link.trim + join + "\n"
          end
          
        else
          # no authors! (don't omit the paragraph
          # though, which breaks the layout)
          text "<a>???</a>"
        end
      end

      _tagged_with(post.tags)

      div.body do
        # abridge the essay (first paragraph only)
        post.body.gsub!(%r|\n+.*|, "") if summary
        
        # posts are supplied as raw html, for now
        render_text(post.body, :red)
        
        # link to the full essay, if this is not it
        p { a.complete("View Complete Essay", :href=>full) } if summary
      end
      
      _clips(post.clips) unless summary

      # css hack for ie < 7
      div.clear_hack ""
    end

    def _clip(clip)
      blockquote do
        render_text(clip.body, :red)
      end

      div.source do
        a(clip.nickname, :href => clip.url)
        cite clip.source
      end
      
      _tagged_with(clip.tags)

      when_logged_in do
        a( "Edit this Clip",
           :class => "edit ed-clip",
           :href  => R(Clips, clip.id, 'edit'))
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
      img(:alt => author.name, :src => author.photo_url)
      a(author.org, :href => author.org_url)
      p do 
				render_text(author.bio, :red)
      end
      unless @state.user_id.blank?
        p do
          a("Edit Author", :href => R(Authors, author.id, 'edit'))
        end
      end
    end


    def _page_form(page, opts)
      form({:method => 'post'}.merge(opts)) do
        
        # this partial serves new
        # pages and existing pages
        if page.title.nil?
          h1 "Creating a New Page"
        else
          h1 "Editing: " + page.title.to_s
          a("Delete", :class=>"edit del", :href=>R(Pages, page.id, "delete"))
        end
        
        # form fields
        fieldset do
          div.first do
            label "Title", :for=>"page_title"
            input :name=>"page_title", :class=>"text", :type=>"text", :value=>page.title
          end

          div do
            label "Nickname", :for=>"page_nickname"
            input :name=>"page_nickname", :class=>"text", :type=>"text", :value=>page.nickname
          end

          div do
            label "Body", :for=>"page_body"
            help_text
            textarea page.body, :name=>"page_body"
          end
        end
        
        # relationships as check boxes
        _checks(@all_tags,    @these_tags,    "Tags:")
        _checks(@all_clips,   @these_clips,   "References:")
        
        input :type=>"hidden", :class=>"hidden", :name=>"post_id", :value=>post.id
        button "Submit"
      end
    end


    def _post_form(post, opts)
      form({:method => 'post'}.merge(opts)) do
        
        # this partial serves new
        # posts and existing posts
        if post.title.nil?
          h1 "Creating a New Essay"
        else
          h1 "Editing: " + post.title.to_s
          a("Delete", :class=>"edit del", :href=>R(Posts, post.id, "delete"))
        end
        
        # form fields
        fieldset do
          div.first do
            label "Title", :for=>"post_title"
            input :name=>"post_title", :class=>"text", :type=>"text", :value=>post.title
          end

          div do
            label "Nickname", :for=>"post_nickname"
            input :name=>"post_nickname", :class=>"text", :type=>"text", :value=>post.nickname
          end

          div do
            label "Body", :for=>"post_body"
            help_text
            textarea post.body, :name=>"post_body"
          end
        end
        
        # relationships as check boxes
        _checks(@all_authors, @these_authors, "Authors:")
        _checks(@all_tags,    @these_tags,    "Tags:")
        _checks(@all_clips,   @these_clips,   "References:")
        
        input :type=>"hidden", :class=>"hidden", :name=>"post_id", :value=>post.id
        button "Submit"
      end
    end


    def _clip_form(clip, opts)
      form({:method=>"post"}.merge(opts)) do
        
        # this partial serves new
        # clips and existing clips
        if clip.nickname.nil?
          h1 "Creating a New Clip"
        else
          h1 "Editing: " + clip.nickname.to_s
          a("Delete", :class=>"edit del", :href=>R(Clips, clip.id, "delete"))
        end

        # form fields
        fieldset do
          div.first do
            label "Nickname", :for=>"fm-clip-nickname"
            input :id=>"fm-clip-nickname", :name=>"clip_nickname", :class=>"text", :type=>"text", :value=>clip.nickname
          end
          
          div do
            label "URL", :for=>"fm-clip-url"
            input :id=>"fm-clip-url", :name=>"clip_url", :class=>"text", :type=>"text", :value=>clip.url
          end
          
          div do
            label "Source", :for=>"fm-clip-source"
            input :id=>"fm-clip-source", :name=>"clip_source", :class=>"text", :type=>"text", :value=>clip.source
          end
          
          div do
            label "Body", :for=>"fm-clip-body"
            help_text
            textarea clip.body, :id=>"fm-clip-body", :name=>"clip_body"
          end
        end
        
        # relationships as check boxes
        _checks(@all_tags,  @these_tags,  "Tagged with:")
        _checks(@all_posts, @these_posts, "Referenced by Posts:")
        _checks(@all_pages, @these_pages, "Referenced by Pages:")
        
        input :type=>"hidden", :class=>"hidden", :name=>"clip_id", :value=>clip.id
        button "Submit"
      end
    end

    def _author_form(author, opts)
      form({:method=>"post"}.merge(opts)) do
        
        # this partial serves new
        # authors and existing authors
        if author.name.nil?
          h1 "Creating a New Author"
        else
          h1 "Editing: " + author.name.to_s
          a("Delete", :class=>"edit del", :href=>R(Authors, author.id, "delete"))
        end

        # form fields (this should be made
        # into a generic form builder)
        fieldset do
          div.first do
            label "First Name", :for=>"fm-author-first"
            input :id=>"fm-author-first", :type=>"text", :class=>"text", :name=>"author_first", :value=>author.first
          end
          
          div do
            label "Last Name", :for=>"fm-author-last"
            input :id=>"fm-author-last", :type=>"text", :class=>"text", :name=>"author_last", :value=>author.last
          end
          
          div do
            label "URL", :for=>"fm-author-url"
            input :id=>"fm-author-url", :type=>"text", :class=>"text", :name=>"author_url", :value=>author.url
          end
          
          div do
            label "Photo URL", :for=>"fm-author-photo"
            input :id=>"fm-author-photo", :type=>"text", :class=>"text", :name=>"author_photo_url", :value=>author.photo_url
          end
          
          div do
            label "Organization", :for=>"fm-author-org"
            input :id=>"fm-author-org", :type=>"text", :class=>"text", :name=>"author_org", :value=>author.org
          end
          
          div do
            label "Organization URL", :for=>"fm-author-org-url"
            input :id=>"fm-author-org-url", :type=>"text", :class=>"text", :name=>"author_org_url", :value=>author.org_url
          end
          
          div do
            label "Bio", :for=>"fm-author-bio"
            help_text
            textarea author.bio, :id=>"fm-author-bio", :name=>"author_bio"
          end
        end
        
        # relationships as check boxes
        _checks(@all_tags,  @these_tags,  "Tagged with:")
        _checks(@all_posts, @these_posts, "Credited by Posts:")
        
        input :type=>"hidden", :name=>"author_id", :value=>author.id
        button "Submit"
       end
    end

    def _tag_form(tag, opts)
      form({:method => 'post'}.merge(opts)) do
        
        # this partial is wired up to edit tags,
        # but currently, there is no controller
        # route to it. todo?
        if tag.name.nil?
          h1 "Creating a New Tag"
        else
          h1 "Editing: " + tag.name.to_s
          a("Delete", :class=>"edit del", :href=>R(Tags, tag.id, "delete"))
        end
        
        # form fields
        fieldset do
          div.first do
            label "Name", :for=>"tag_name"
            input :name=>"tag_name", :class=>"text", :type=>"text", :value=>tag.name
          end
        end
        
        # no check boxes to link this tag to pages, essays, etc
        
        input :type=>"hidden", :class=>"hidden", :name=>"tag_id", :value=>tag.id
        button "Submit"
      end
    end
    
    def _bundle_form(bundle,opts)
      form({:method => 'post'}.merge(opts))do

				if bundle.name.nil?
          h1 "Creating a New Bundle"
        else
          h1 "Editing: " + bundle.name.to_s
          a("Delete", :class=>"edit del", :href=>R(Bundles, bundle.id, "delete"))
        end

        # form fields
        fieldset do
          div.first do
            label "Name", :for=>"bundle_name"
            input :name=>"bundle_name", :class=>"text", :type=>"text", :value=>bundle.name
          end
          _checks(@all_tags,  @these_tags,  "Include:")
          input :type=>"hidden", :class=>"hidden", :name=>"bundle_id", :value=>bundle.id
          button "Submit"
        end
      end
    end

    def _checks(all_things, these_things, caption=nil)
      if all_things
        
        # optionally, label these check boxes
        h3.checks(caption)\
          unless caption.nil?
        
        # iterate all "things"
        fieldset.checks do
          all_things.each_with_index do |thing,n|

            # auto figure-out what sort of things we are
            # checking off. "Kambi::Models::Post" becomes "post"
            name = thing.class.to_s.gsub("Kambi::Models::", "").downcase
            checked = (!these_things.nil? && these_things.include?(thing))
            chk_hash = checked ? { :checked=>"checked" } : {}

            div(:class=>( n==0 ? "first" : "")) do
              # the [x] label pair
              # (inlined via css)
              
              input(chk_hash.merge({:type=>"checkbox", :class=>"checkbox", :id=>"fm-#{name}-#{thing.id}", :name=>"#{name}-#{thing.id}"}))
              label thing.to_s, :for => "fm-#{name}-#{thing.id}"
            end
          end
        end
      end
    end
  end
  
  # TODO: what is this?
  default_format :HTML
end

