# templates, event handlers, and subscriptions for the site-wide
# header bar, including the login modals and general Handlebars helpers

# link various types of objects
Handlebars.registerHelper 'link', (args) ->
  args = if typeof(args) is 'string' then {id:args} else args.hash
  n = Names.findOne(args.id)
  return args.id unless n
  extraclasses = if args.class then (' '+args.class) else ''
  title = if args.title then " title='#{args.title}'" else ''
  link = "<a href='/#{n.type}/#{n._id}' class='#{n.type}-link#{extraclasses}' #{title}>"
  link += Handlebars._escape(n.name)
  link += '</a>'
  return new Handlebars.SafeString(link)

$('a.puzzles-link, a.rounds-link, a.chat-link').live 'click', (event) ->
  return unless event.button is 0 # check right-click
  event.preventDefault()
  Router.navigate $(this).attr('href'), {trigger:true}

############## log in/protect/mute panel ####################
Template.header_loginmute.volumeIcon = ->
  Template.nickAndRoom.volumeIcon()
Template.header_loginmute.sessionNick = -> Session.get 'nick'
Template.header_loginmute.rendered = ->
  # 'canEdit' radio buttons
  setCanEdit (Session.get('canEdit') and Session.get('nick'))
Template.header_loginmute.events
  "click .canEdit-true": (event, template) ->
    event.preventDefault()
    setCanEdit true
  "click .canEdit-false": (event, template) ->
    event.preventDefault()
    setCanEdit false
  "click .bb-login": (event, template) ->
    event.preventDefault()
    ensureNick()
  "click .bb-logout": (event, template) ->
    event.preventDefault()
    setCanEdit false
    Session.set 'nick', null
    $.removeCookie 'nick'

setCanEdit = (canEdit) ->
  Session.set 'canEdit', if canEdit then true else null
  $('.bb-buttonbar input:radio[name=editable]').val([
        if canEdit then 'true' else 'false'
  ])

############## nick selection ####################
Template.header_nickmodal.nickModalVisible = -> Session.get 'nickModalVisible'
Template.header_nickmodal_contents.currentPage = -> Session.get "currentPage"
Template.header_nickmodal_contents.nick = -> Session.get "nick" or ''
Template.header_nickmodal_contents.created = ->
  this.afterFirstRender = ->
    $('#nickPickModal').one 'hide', ->
      Session.set 'nickModalVisible', false
    $('#nickPickModal').modal keyboard: false, backdrop:"static"
    $('#nickInput').select()
  this.sub = Meteor.subscribe 'all-nicks'
Template.header_nickmodal_contents.rendered = ->
  this.afterFirstRender?()
  this.afterFirstRender = null
Template.header_nickmodal_contents.destroyed = ->
  this.sub.stop()

$("#nickPick").live "submit", ->
  $warning = $(this).find ".warning"
  nick = $("#nickInput").val().replace(/^\s+|\s+$/g,"") #trim
  $warning.html ""
  if not nick || nick.length > 20
    $warning.html("Your nickname must be between 1 and 20 characters long!");
  else
    $.cookie "nick", nick, {expires: 365}
    Session.set "nick", nick
    $('#nickPickModal').modal 'hide'
    joinRoom Session.get('type'), Session.get('id')

  hideMessageAlert()
  return false

changeNick = (cb=(->)) ->
  $('#nickPickModal').one 'hide', -> cb
  Session.set 'nickModalVisible',true

ensureNick = (cb=(->)) ->
  if Session.get 'nick'
    cb()
  else if $.cookie('nick')
    Session.set 'nick', $.cookie('nick')
    cb()
  else
    changeNick cb


############## operation log in header ####################
Template.header_lastupdates.lastupdates = ->
  LIMIT = 10
  ologs = OpLogs.find {}, \
        {sort: [["timestamp","desc"]], limit_BUG: LIMIT}
  # Meteor doesn't support the limit option yet.  So in a hacky workaround,
  # limit the collection client-side
  ologs = ologs.fetch().slice(0, LIMIT)
  # now look through the entries and collect similar logs
  # this way we can say "New puzzles: X, Y, and Z" instead of just "New Puzzle: Z"
  return '' unless ologs && ologs.length
  message = [ ologs[0] ]
  for ol in ologs[1..]
    if ol.message is message[0].message and ol.type is message[0].type
      message.push ol
    else
      break
  type = ''
  if message[0].id
    type = ' ' + pretty_collection(message[0].type) + \
      (if message.length > 1 then 's ' else ' ')
  return {
    timestamp: message[0].timestamp
    message: message[0].message + type
    nick: message[0].nick
    objects: ({type:m.type,id:m.id} for m in message)
  }

# subscribe when this template is in use/unsubscribe when it is destroyed
Template.header_lastupdates.created = ->
  this.sub = Meteor.subscribe 'recent-oplogs'
Template.header_lastupdates.destroyed = ->
  this.sub.stop()

############## chat log in header ####################
Template.header_lastchats.lastchats = ->
  LIMIT = 2
  m = Messages.find {room_name: "general/0", system: false}, \
        {sort: [["timestamp","desc"]], limit_BUG: LIMIT}
  # Meteor doesn't support the limit option yet.  So in a hacky workaround,
  # limit the collection client-side
  m = m.fetch().slice(0, LIMIT)
  m.reverse()
  return m
Template.header_lastchats.pretty_ts = (ts) -> Template.messages.pretty_ts ts

# subscribe when this template is in use/unsubscribe when it is destroyed
Template.header_lastchats.created = ->
  this.sub = Meteor.subscribe 'recent-messages', 'general/0'
Template.header_lastchats.destroyed = ->
  this.sub.stop()