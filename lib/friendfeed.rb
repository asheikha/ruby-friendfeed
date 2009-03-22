#!/usr/bin/env ruby
#--
# friendfeed.rb - provides access to FriendFeed API's
#++
# Copyright (c) 2009 Akinori MUSHA <knu@iDaemons.org>
#
# All rights reserved.  You can redistribute and/or modify it under the same
# terms as Ruby.
#

require 'rubygems'
require 'json'
require 'mechanize'
require 'uri'

module FriendFeed
  ROOT_URI      = URI.parse("https://friendfeed.com/")

  # Client library for FriendFeed API.
  class Client
    attr_reader :nickname

    #
    # Official API
    #

    API_URI = ROOT_URI + "/api/"

    private

    def get_api_agent
      @api_agent ||= WWW::Mechanize.new
    end

    def validate
      call_api('validate')
    end

    def require_api_login
      @nickname or raise 'not logged in'
    end

    public

    # Performs a login with a +nickname+ and +remote key+ and returns
    # self.  This enables call of any official API that requires
    # authentication[6~.  It is not needed to call this method if you
    # have called login(), which internally obtains a remote key and
    # calls this method.  An exception is raised if authentication
    # fails.
    def api_login(nickname, remote_key)
      @nickname = nickname
      @remote_key = remote_key
      @api_agent = get_api_agent()
      @api_agent.auth(@nickname, @remote_key)
      validate

      self
    end

    # Calls an official API specified by a +path+ with optional
    # parameters, and returns an object parsed from a JSON response.
    def call_api(path, parameters = nil)
      api_agent = get_api_agent()

      uri = API_URI + path
      if parameters
        uri.query = parameters.map { |key, value|
          if array = Array.try_convert(value)
            value = array.join(',')
          end
          URI.encode(key) + "=" + URI.encode(value)
        }.join('&')
      end
      JSON.parse(api_agent.get_file(uri))
    end

    # Gets profile information of a user of a given +nickname+,
    # defaulted to the authenticated user, in hash.
    def get_profile(nickname = @nickname)
      nickname or require_api_login
      call_api('user/%s/profile' % URI.encode(nickname))
    end

    # Gets an array of profile information of users of given
    # +nicknames+.
    def get_profiles(nicknames)
      call_api('profiles', 'nickname' => nicknames)['profiles']
    end

    # Gets an array of profile information of friends of a user of a
    # given +nickname+ (defaulted to the authenticated user) is
    # subscribing to.
    def get_real_friends(nickname = @nickname)
      nickname or require_api_login
      get_profiles(get_profile(@nickname)['subscriptions'].map { |subscription|
          subscription['nickname']
        })
    end

    # Gets an array of the most recent public entries.
    def get_public_entries()
      call_api('feed/public')['entries']
    end

    # Gets an array of the entries the authenticated user would see on
    # their home page.
    def get_home_entries()
      call_api('feed/home')['entries']
    end

    # Gets an array of the entries for the authenticated user's list
    # of a given +nickname+
    def get_list_entries(nickname)
      call_api('feed/list/%s' % URI.encode(nickname))['entries']
    end

    # Gets an array of the most recent entries from a user of a given
    # +nickname+ (defaulted to the authenticated user).
    def get_user_entries(nickname = @nickname)
      nickname or require_api_login
      call_api('feed/user/%s' % URI.encode(nickname))['entries']
    end

    # Gets an array of the most recent entries from users of given
    # +nicknames+.
    def get_multi_user_entries(nicknames)
      call_api('feed/user', 'nickname' => nicknames)['entries']
    end

    # Gets an array of the most recent entries a user of a given
    # +nickname+ (defaulted to the authenticated user) has commented
    # on.
    def get_user_commented_entries(nickname = @nickname)
      nickname or require_api_login
      call_api('feed/user/%s/comments' % URI.encode(nickname))['entries']
    end

    # Gets an array of the most recent entries a user of a given
    # +nickname+ (defaulted to the authenticated user) has like'd.
    def get_user_liked_entries(nickname = @nickname)
      nickname or require_api_login
      call_api('feed/user/%s/likes' % URI.encode(nickname))['entries']
    end

    # Gets an array of the most recent entries a user of a given
    # +nickname+ (defaulted to the authenticated user) has commented
    # on or like'd.
    def get_user_discussed_entries(nickname = @nickname)
      nickname or require_api_login
      call_api('feed/user/%s/discussion' % URI.encode(nickname))['entries']
    end

    # Gets an array of the most recent entries from friends of a user
    # of a given +nickname+ (defaulted to the authenticated user).
    def get_user_friend_entries(nickname = @nickname)
      nickname or require_api_login
      call_api('feed/user/%s/friends' % URI.encode(nickname))['entries']
    end

    # Gets an array of the most recent entries in a room of a given
    # +nickname+.
    def get_room_entries(nickname)
      call_api('feed/room/%s' % URI.encode(nickname))['entries']
    end

    # Gets an array of the entries the authenticated user would see on
    # their rooms page.
    def get_rooms_entries()
      call_api('feed/rooms')['entries']
    end

    # Gets an entry of a given +entryid+.  An exception is raised when
    # it fails.
    def get_entry(entryid)
      call_api('feed/entry/%s' % URI.encode(entryid))['entries'].first
    end

    # Gets an array of entries of given +entryids+.  An exception is
    # raised when it fails.
    def get_entries(entryids)
      call_api('feed/entry', 'entry_id' => entryids)['entries']
    end

    # Gets an array of entries that match a given +query+.
    def search(query)
      call_api('feed/search', 'q' => query)['entries']
    end

    # Gets an array of entries that link to a given +url+.
    def search_for_url(url, options = nil)
      new_options = { 'url' => url }
      new_options.merge!(options) if options
      call_api('feed/url', new_options)['entries']
    end

    # Gets an array of entries that link to a given +domain+.
    def search_for_domain(url, options = nil)
      new_options = { 'url' => url }
      new_options.merge!(options) if options
      call_api('feed/domain', new_options)['entries']
    end

    #
    # Unofficial API
    #

    LOGIN_URI     = ROOT_URI + "/account/login"
    IMAGINARY_URI = ROOT_URI + "/settings/imaginary?num=9999"

    private

    def get_login_agent
      @login_agent or raise 'login() must be called first to use this feature'
    end

    public

    # Performs a login with a +nickname+ and +password+ and returns
    # self.  This enables call of any API, including both official API
    # and unofficial API.
    def login(nickname, password)
      @nickname = nickname
      @password = password
      @login_agent = WWW::Mechanize.new

      page = @login_agent.get(LOGIN_URI)

      login_form = page.forms.find { |form|
        LOGIN_URI + form.action == LOGIN_URI
      } or raise 'Cannot locate a login form'

      login_form.set_fields(:email => @nickname, :password => @password)

      page = @login_agent.submit(login_form)

      login_form = page.forms.find { |form|
        LOGIN_URI + form.action == LOGIN_URI
      } and raise 'Login failed'

      page = @login_agent.get(ROOT_URI + "/account/api")
      remote_key = page.parser.xpath("//td[text()='FriendFeed remote key:']/following-sibling::td[1]/text()").to_s

      api_login(nickname, remote_key)
    end

    # Gets an array of profile information of the authenticated user's
    # imaginary friends, in a format similar to
    # get_real_friends(). [unofficial]
    def get_imaginary_friends
      agent = get_login_agent()

      page = agent.get(IMAGINARY_URI)
      page.parser.xpath("//div[@class='name']//a[@class='l_person']").map { |person_a|
        profile_uri = IMAGINARY_URI + person_a['href']
        profile_page = agent.get(profile_uri)
        {
          'id' => person_a['uid'], 
          'nickname' => person_a.text,
          'profileUrl' => profile_uri.to_s,
          'services' => profile_page.parser.xpath("//div[@class='servicefilter']//a[@class='l_filterservice']").map { |service_a|
            {
              'name' => service_a['servicename'],
              'profileUrl' => (profile_uri + service_a['href']).to_s
            }
          },
        }
      }
    end

    # Posts a request to an internal API of FriendFeed and returns
    # either a parser object for an HTML response or an object parsed
    # from a JSON response).  [unofficial]
    def post(uri, query = {})
      agent = get_login_agent()

      page = agent.post(uri, {
          'at' => agent.cookies.find { |cookie|
            cookie.domain == 'friendfeed.com' && cookie.name == 'AT'
          }.value
        }.merge(query))
      if page.respond_to?(:parser)
        parser = page.parser
        messages = parser.xpath("//div[@id='errormessage']/text()")
        messages.empty? or
          raise messages.map { |message| message.to_s }.join(" ")
        parser
      else
        json = JSON.parse(page.body)
        message = json['error'] and
          raise message
        json
      end
    end

    # Creates an imaginary friend of a given +nickname+ and returns a
    # unique ID string on success.  Like other methods in general, an
    # exception is raised on failure. [unofficial]
    def create_imaginary_friend(nickname)
      post(ROOT_URI + '/a/createimaginary', 'name' => nickname).xpath("//a[@class='l_userunsubscribe']/@uid").to_s
    end

    # Renames an imaginary friend specified by a unique ID to a given
    # +nickname+. [unofficial]
    def rename_imaginary_friend(id, nickname)
      post(ROOT_URI + '/a/imaginaryname', 'user' => id, 'name' => nickname)
    end

    # Adds a Twitter service to an imaginary friend specified by a
    # unique ID. [unofficial]
    def add_twitter_to_imaginary_friend(id, twitter_name)
      post(ROOT_URI + '/a/configureservice', 'stream' => id,
        'service' => 'twitter','username' => twitter_name)
    end

    # Unsubscribe from a user specified by a unique ID. [unofficial]
    def unsubscribe_from_user(id)
      post(ROOT_URI + '/a/userunsubscribe', 'user' => id)
    end
  end
end

class Array
  def self.try_convert(obj)
    return obj if obj.instance_of?(self)
    return nil if !obj.respond_to?(:to_ary)
    nobj = obj.to_ary 
    return nobj if nobj.instance_of?(self)
    raise TypeError, format("can't convert %s to %s (%s#to_ary gives %s)", obj.class, self.class, obj.class, nobj.class)
  end unless self.respond_to?(:try_convert)
end
