$ ->
  RECONNECT_TIMEOUT = 1000
  PING_TIMEOUT = 100

  DebugModel = Backbone.Model.extend(
    defaults:
      id: undefined
      toolbar: undefined
      response: undefined
      status_code: undefined
      date: undefined
      url: undefined
      method: undefined
  )

  DebugCollection = Backbone.Collection.extend(
    model: DebugModel
    comparator: (model)->
      -model.get('id')
  )

  profile_collection = new DebugCollection()

  DebugView = Backbone.View.extend(

    initialize: ->
      source = $('#buttons_template').html()
      @template = Handlebars.compile(source)

    render: ->
      profile_collection.sort({silent:true})
      context =
        profile_collection: profile_collection.toJSON()
      html = @template(context)
      @$el.html(html)
      @

    events:
      'click .show_debug_toolbar': 'activate_debug_toolbar'

    activate_debug_toolbar: (event) ->
      dom = $(event.currentTarget)
      id = dom.data('id')
      clear_djdt_handlers()
      $('#toolbar').html(profile_collection.get(id).get('toolbar'))
      window.djdt.init()
      $('.response_tr').removeClass('success')
      $('.response_tr[data-id='+ id + ']').addClass('success')
  )

  ajax_view = new DebugView(
    el: $('#content')
  )

  conn = undefined

  connect = ->
    tornado_url = "http://localhost:8080/broadcast"
    console.log tornado_url
    conn = new SockJS(tornado_url)
    conn.onopen = onopen
    conn.onclose = onclose
    conn.onmessage = onmessage
    console.log "connected!"

  timer = undefined

  onopen = ->
    sendPing = ->
      conn.send "msg"
      timer = setTimeout(sendPing, PING_TIMEOUT)
    timer = setTimeout(sendPing, PING_TIMEOUT)

  clear_djdt_handlers = ->
    window?.djdt?.jQuery(document).unbind()
    window?.djdt?.jQuery('#djDebugPanelList li a').die()
    window?.djdt?.jQuery('#djDebug a.djDebugClose').die()
    window?.djdt?.jQuery('#djDebug .remoteCall').die()
    window?.djdt?.jQuery('#djDebugWindow a.djDebugBack').die()
    window?.djdt?.jQuery('#djDebugTemplatePanel a.djTemplateShowContext').die()
    window?.djdt?.jQuery('#djDebug a.djDebugToggle').die()
    window?.djdt?.jQuery('#djDebug a.djToggleSwitch').die()
    window?.djdt?.jQuery('.djDebugProfileRow .djDebugProfileToggle').die()

  onmessage = (e) ->
    if e.data?
      console.log e.data
      new_model = new DebugModel(
        id: profile_collection.length + 1
        toolbar: e.data.toolbar
        response: e.data.response
        status_code: e.data.status_code
        time: e.data.time
        url: e.data.url
        method: e.data.method
      )
      profile_collection.push(new_model)
      ajax_view.render()
      $('.show_debug_toolbar:first').click()

  onclose = ->
    console.log "onclose"
    clearTimeout timer
    timer = undefined
    setTimeout connect, RECONNECT_TIMEOUT

  connect()