$ = require "jquery"
require "./../css/style.css";
require "./../less/animale.less";


#### Adds plugin object to jQuery
$.fn.extend

    docScreenBuilder: (options) ->
# Default settings
        settings =
            option1: true
            option2: false
            debug: false

        # Merge default settings with options.
        settings = $.extend settings, options

        userWarn = (msg) ->
            $.MEAlert msg, "MECEAP ScreenBuilder Plugin"

        # Bomb when no elements matched
        unless @length > 0
            userWarn "Error, could not find any elements to work with selector #{@selector}"

        # Instantiate our main class for each object, passing options.
        builder = null
        @each (idx, divObj) =>
            builder = $(divObj).data('screenBuilder')
            if (!builder)
                console.log "Creating builder since its not in data" if settings.debug
                builder = new ScreenBuilder($(divObj), options)
                $(divObj).data('screenBuilder', builder)
            else
                console.log("Returning existing screenbuilder", builder) if settings.debug

        return builder


#### The main ScreenBuilder class.
class ScreenBuilder

    # Log to the console if options allow it (debug)
    log: (msg...) ->
        console?.log msg... if @options.debug

# Open a console group (debugging)
    logGroup: (msg...) ->
        console?.group(msg...) if @options.debug

# Close a console group (debugging)
    logGroupEnd: () ->
        console?.groupEnd() if @options.debug

    isDebugging: () ->
        return true if @options.debug
        false

# Show a warning to the end-user.
    warn: (msg) ->
        $.MEAlert msg, "MECEAP ScreenBuilder Class" if !@options.quiet

# The constructor, called by the jQuery plugin above.
    constructor: (@mainDiv, @options) ->
        @initDone = false
        @docType = null
        @dtDefs = null
        @screenDefs = null
        @validationModel = null
        @currentShowRepeaters = {}
        @enableSectionFieldFiltering = @options.enableSectionFieldFiltering
        @readOnlyMode = options.readOnly
        @forceReadOnlyPrivateShare = @options.readOnlyPrivateShare
        @readyOnlyFollowers = @options.readOnlyFollowers
        @fieldRendererFactory = new FieldRendererFactory(@)
        @disableActionButtons = (@options.disableActionButtons == true)
        @screenActions = @options.screenActions
        @isDirty = @options.dirty

        @log "Init doc load, ", @options.documentId?, " and ", (!(@options.documentObj?)), " doc is ", @options.documentObj
        if @options.documentId? and (!(@options.documentObj?))
            @isRenderingDoc = true
            if @options.documentVersionId?
                @getDocumentVersionMetaObjectDataAjax @options.documentVersionId
            else
                @getDocumentMetaObjectDataAjax @options.documentId
        else
            if @options.documentObj?
                @isRenderingDoc = true
                @metaObject = @options.documentObj

        @getValidationModel @options.documentTypeId
        @getDocumentTypeDefs @options.documentTypeId
        @getScreenDefsAjax @options.screenId
        @log "****** constructor SB done ", @mainDiv.prop('id')


    initIfReady: (origin) ->
        @log "Initting if ready... with origin", origin
        if (!@docType)
            @log "Not ready, missing docType defs"
            return

        if (!@screenDefs)
            @log "Not ready, missing ScreenDefs"
            return

        if (!@validationModel)
            @log "Not ready, missing validationModel"
            return

        if @isRenderingDoc and (!@metaObject)
            @log "Not ready, missing metaObject"
            return

        if @initDone
            @warn "SB is initializing twice."

        @setReadOnlyMode()
        @getScreenActionsMacro @options.screenId

        @initDone = true
        @logGroup "*****>>> calling findMainSection origin", origin
        @findMainSection()
        @paintSections()

        unless @isInAdminMode() or @readOnlyMode == "never"
            @bindDataChangeEvents()

        @logGroupEnd "****** Init SB, ready! ", @mainDiv.prop('id'), " origin ", origin

        @mainDiv.trigger "sbInitDone", [ @metaObject, @ ]

    showMessageChangedBySomeoneElse: (warning) ->
        message = Catalog.getMessage "screen.changedBySomeoneElse"
        title = Catalog.getMessage "screen.documentUpdated"
        if (warning)
            $.MEFloatingWarning message, title
        else
            $.MEFloatingInfo message, title

    bindDataChangeEvents: () ->
        @mainDiv.off 'sbInternalChange'
        # listen to the data events
        @mainDiv.on 'sbInternalChange', () =>
            unless @isDirty
                @checkVersion @metaObject.internalId, (version) =>
                    unless @metaObject.version is version
                        @showMessageChangedBySomeoneElse true
                        @reload()
                    else
                        @showAlertPanel()

            @isDirty = true

        @mainDiv.on "sbRepaint", () =>
            @showAlertPanel() if @isDirty


        @mainDiv.off 'sbExternalChange'
        @mainDiv.on 'sbExternalChange', (e, data) =>
# avoid send message to same user who trigger the event
            unless PrincipalInfo.principalHumanBeing.id == parseInt data.humanBeingId
                @showMessageChangedBySomeoneElse @isDirty

            # avoid reloading same documentversion again
            unless @metaObject.version == data.metaDocumentVersion
                @reload()

        $(window).bind 'beforeunload ', () =>
            if @isDirty then Catalog.getMessage("screen.allPendingChangesWillBeLost") else undefined

        @subscribeToChannel @mainDiv.attr('data-channel')


    subscribeToChannel: (channelId) ->
        return if not channelId
        unless @channel
            pusher = PusherFactory.get PrincipalInfo.pusherKey
            @log "subscribing on", channelId
            @channel = pusher.subscribe channelId
            @channel.unbind "documentSaved"
            @channel.bind "documentSaved", (data) =>
                $(@mainDiv).trigger "sbExternalChange", data
            @channel.bind "subDocumentAdded", (data) =>
                $(@mainDiv).trigger "sbSubDocumentAdded", data

    showAlertPanel: ->
        @$alertPanel.show('fade')

    renderAlertPanel: ->
        $panel = $ "<div />", class: "screenBuilderDialog"
        $panel.appendTo @mainDiv

        $btnSave = $ "<button />", type: "button", class: "btn btn-primary", text: Catalog.getMessage("label.save")
        $btnSave.appendTo $panel
        $btnSave.click =>
            unless not @validateFormScreen()
                $btnSave.text(Catalog.getMessage("label.saving"))
                $btnSave.attr("disabled", "disabled")

                $(@mainDiv).trigger "sbSaveClick",
                    documentObject: @getDocumentObject()
                    button: $btnSave

        $panel.append $ "<span />", style: "padding-left:10px", html: Catalog.getMessage('label.or')

        $btnRevert = $ "<button/>", type: 'button', class: 'btn btn-link', html: Catalog.getMessage('screen.revertChanges')
        $btnRevert.appendTo $panel
        $btnRevert.click =>
            @reload()

        $panel

    parseDocumentType: () ->
        @docType = new DocumentType(@dtDefs)

# Helper, uses jQuery Ajax to *synchronously* POST data and handle response. Auto-JSON the obj data.
    postObjectAsJSONandWait: (url, obj, success) ->
        @ajaxPostObject url, obj, success, false

    postObjectAsJSONAsync: (url, obj, success) ->
        @postObjectAndVariablesAndWait url, obj, success, true

    postObjectAndVariablesAndWait: (url, obj, success, async) ->
        dataPost =
            docJSON: JSON.stringify(obj)
        @ajaxPostObject url, dataPost, success, async || false

    ajaxPostObject: (url, obj, success, async) ->
        $.ajax
            dataType: 'json'
            contentType: 'application/json; charset=utf-8'
            type: 'POST'
            url: url
            success: success
            async: async
            data: JSON.stringify(obj)

    ajaxGetAsync: (url, success) ->
        $.ajax
            type: 'GET'
            url: url
            success: (data) =>
                @log "** Returning data with", url, "invoking callback"
                success(data)


    getDocumentMetaObjectDataAjax: (documentId) ->
        @log "Get document metaobject data #{documentId}"
        @ajaxGetAsync "/#{@options.customRootName}/document/getDocumentJSON/#{documentId}", @setDocumentObject

    getDocumentVersionMetaObjectDataAjax: (documentVersionId) ->
        @log "Get document version metaobject data #{documentVersionId}"
        @ajaxGetAsync "/#{@options.customRootName}/document/getDocumentVersionJSON/#{documentVersionId}", (data) =>
            @log "Got document version metaobject", data
            @metaObject = data
            @initIfReady('metaObject version')

    setReadOnlyMode: () ->
        @readOnlyMode = @screenDefs.readOnlyMode unless @readOnlyMode?
        @readOnlyMode = "toggle" unless @readOnlyMode?

    getScreenDefsAjax: (screenId) ->
        if @options.screenDefsObj?
            @screenDefs = @options.screenDefsObj
            @initIfReady('screenDefs serialized')
            return

        @log "get screen definitions via ajax #{screenId}"

        if (@enableSectionFieldFiltering)
            if @metaObject.internalId? && !@isDirty
                @ajaxGetAsync "/#{@options.customRootName}/document/getScreenJSON/#{screenId}/#{@metaObject.internalId}", (data) =>
                    @log "Got screen data via GET Filtered", data
                    @screenDefs = data
                    @initIfReady('screenDefs GET Filtered')
            else
                @postObjectAsJSONAsync "/#{@options.customRootName}/document/filterScreenJSON/#{screenId}", @metaObject, (data) =>
                    @log "Got screen data via POST", data
                    @screenDefs = data
                    @initIfReady('screenDefs POST')

        else
            @ajaxGetAsync "/#{@options.customRootName}/document/getScreenJSON/#{screenId}", (data) =>
                @log "Got screen data via GET", data
                @screenDefs = data
                @initIfReady('screenDefs GET')

    getScreenActionsMacro: (screenId) ->
        hasMacro = false
        if  @screenDefs?.actionList?
            hasMacro = true for action in @screenDefs.actionList when action.macroId? && action.macroId

        return unless hasMacro
        @ajaxGetAsync "/#{@options.customRootName}/document/getMacrosJSON/#{screenId}", (data) =>
            action.macro = data[action.name] for action in @screenDefs.actionList when data[action.name]? && data[action.name]

    getDocumentTypeDefs: (documentTypeId) ->
        if @options.docTypeObj?
            @dtDefs = @options.docTypeObj
            @parseDocumentType()
            @initIfReady('documentTypeDefs serialized')
            return

        @log "get doctype definitions via ajax #{documentTypeId}"
        @ajaxGetAsync "/#{@options.customRootName}/document/getDocumentTypeJSON/#{documentTypeId}", (data) =>
            @log "Got documentType data", data
            @dtDefs = data
            @parseDocumentType()
            @initIfReady('documentTypeDefs')


    getValidationModel: (documentTypeId) ->
        if @options.validationModel
            @validationModel = @options.validationModel
            return

        @ajaxGetAsync "/#{@options.customRootName}/document/getValidationModel/#{documentTypeId}", (@validationModel) =>
            @log "Got validationModel", @validationModel
            @initIfReady('validationModel')


# Returns true if we're allowed to edit the screen definitions themselves (eg, adminMode)
    isInAdminMode: () ->
        return (!!@options.adminMode)

# Returns true if we're forced to only 'show' a document, not edit in any way
    isForcingReadOnly: () ->
        return @readOnlyMode == "always"

    isForcingReadOnlyPrivateShare: () ->
        return !!@forceReadOnlyPrivateShare

# Finds the 'main' section, which is the parent of all other sections and has no parent
    findMainSection: () ->
        @log "finding main section with metaObject ", @metaObject
        for childSection in @screenDefs.childSections
            factory = new ScreenSectionFactory()
            obj = new factory.createScreenSection(@, childSection, null, @metaObject)
            obj.parseData()
            @mainSection = obj

    hasDocumentId:() ->
        @metaObject?.internalId?

# Paint sections to the screen.
    paintSections: () ->
        @form = $('<form/>').addClass("formular").addClass("sbForm")
        @mainSection.paintToDOM 0, @form

        @mainDiv.empty()
        @mainDiv.addClass "screenBuilder"

        @renderDocumentFeaturesPanel() if @hasDocumentId() and @isRenderingDoc
        @buildShareSection() if @screenDefs.showPrivacyPanel and @isRenderingDoc
        @mainDiv.append @form

        @form.form()
        @initToolTips()

        if !@disableActionButtons
            @mainDiv.append $('<hr/>')

        if @isInAdminMode()
            @dialogButton = $("<input type='button' class='btn btn-primary' value='#{Catalog.getMessage('screen.options')}' />")
            @dialogButton.button()
            @dialogButton.click () =>
                @showConfigDialog()
            @dialogButton.appendTo @mainDiv
            @mainDiv.safeDisableSelection()

        @$alertPanel = @renderAlertPanel()

        if @hasDocumentId()
            @renderAttachmentSection() if @screenDefs.showAttachment and @isRenderingDoc
            @renderCheckListSection() if @screenDefs.showCheckList and @isRenderingDoc

        if @isRenderingDoc and !@disableActionButtons
            actionList = if @screenActions? then @screenActions else @screenDefs.actionList
            for action in actionList
                @renderActionButton action

        if @hasDocumentId() and @screenDefs.showActivity
            $activityPanel = $ "<div/>"
            $activityPanel.appendTo @mainDiv
            $activityPanel.activity
                documentId: @metaObject.internalId

    renderDocumentFeaturesPanel: ->
        return unless @screenDefs.showTag or @screenDefs.showFollow or @screenDefs.showStar or @screenDefs.showMacro or @screenDefs.showBoard

        $btnGroup = $ "<div />", class: "btn-group pull-right"
        @buildTag $btnGroup, @metaObject if @screenDefs.showTag
        @buildFollow $btnGroup, @metaObject if @screenDefs.showFollow
        @buildStar $btnGroup, @metaObject if @screenDefs.showStar
        @buildMacro $btnGroup, @metaObject if @screenDefs.showMacro
        @buildBoard $btnGroup, @metaObject if @screenDefs.showBoard

        $featurePanel = $ "<div />", class: "sb-featurePanel"
        $featurePanel.append $btnGroup
        $featurePanel.appendTo @mainDiv

    renderAttachmentSection:() ->
        inputAttachment = $("<input />", type: "hidden")
        inputAttachment.appendTo @mainDiv

        readOnly = @isForcingReadOnly()
        $.get "/#{PrincipalInfo.principalCustomRoot.name}/document/attachments/#{@metaObject.internalId}", (data) =>
            inputAttachment.upload
                attachment: true
                objectId: @metaObject.internalId
                canUpload: !readOnly
                canDelete: !readOnly
                canEdit: !readOnly
                files: data
                type: "Document"
                urlUpload : "/#{PrincipalInfo.principalCustomRoot.name}/attachment/upload"
                urlDownload : "/#{PrincipalInfo.principalCustomRoot.name}/attachment/download/"
                urlSaveAttachment : "/#{PrincipalInfo.principalCustomRoot.name}/attachment/save"
                delete:
                    url: "/#{PrincipalInfo.principalCustomRoot.name}/attachment/remove/"
                    type: "Document"

    renderCheckListSection:() ->
        div = $("<div />", class: "me-checklist").appendTo @mainDiv

        readOnly = @isForcingReadOnly()
        div.checkList
            type: "document"
            objectId: @metaObject.internalId
            templateTypeId: @metaObject.documentTypeId
            canDeleteCheckList: !readOnly
            canSaveTemplate: !readOnly
            canCreateCheckList: !readOnly
            canLoadTemplate: !readOnly
            readOnly: readOnly

# Renders one action button.
    renderActionButton: (action) ->
        @log "Creating button for action", action
        button = $("<button class='btn btn-default'>#{action.title}</button>")
        button.prop 'title', Catalog.getMessage action.description
        button.data "action", action
        button.button()
        button.metooltip()

        button.click (evt) =>
            if @validateFormScreen()
                @handleActionClicked action
        button.appendTo @mainDiv


# Handles the click on the button for an action
    handleActionClicked: (action) ->
        @postActionPerformed action


# Shows the configuration dialog for the screen
    showConfigDialog: () ->
        if (!@configDialog?)
            @configDialog = new ScreenConfigDialog(@)

        @configDialog.show()


    repaint: ->
        @destroyValidation()
        @paintSections()
        @updateConfigDialog()
        @mainDiv.trigger "sbRepaint", [ @metaObject, @ ]

# Updates the configuration dialog after repaiting the screen
    updateConfigDialog: () ->
        return null unless (@configDialog?)
        @configDialog.updateAfterRepaint()

    buildStar: (container, data) ->
        button = $("<button />").addClass "btn btn-sm btn-default"
        button.appendTo container

        star = $("<input type='checkbox'>").addClass "sb-star"
        star.appendTo button
        star.favorite
            document: data.internalId

    buildFollow: (container, data) ->
        button = $("<button />").addClass "btn btn-sm btn-default"
        button.appendTo container

        star = $("<input type='checkbox'>").addClass "sb-follow"
        star.appendTo button
        star.follow
            document: data.internalId

    buildTag: (container, data) ->
        tag = $("<span />").addClass "sb-tag"

        $("<div />", class: "btn-group").append(tag).appendTo(container)

        tag.tag
            buttonClass: "btn btn-sm btn-default"
            editable: !@isForcingReadOnly()
            document: data.internalId

    buildMacro: (container, data) ->
        buttonGroup = $("<div />").addClass "btn-group sb-macro"
        button = $("<button />").addClass "dropdown-toggle btn btn-sm btn-default"
        button.attr "data-toggle", "dropdown"
        button.attr "type", "button"

        button.append $("<li />").addClass "fa fa-play"
        button.append $("<span />").text " "
        button.append $("<li />").addClass "fa fa-caret-down"

        buttonGroup.append button

        macro = $("<ul />").addClass "me-macro dropdown-menu dropdown-menu-right"
        macro.attr "role", "menu"
        buttonGroup.append macro

        macro.macroMenu
            documentId: data.internalId
            documentTypeId: data.documentTypeId

        buttonGroup.appendTo container


    buildBoard: (container, data) ->
        buttonGroup = $("<div />").addClass "btn-group sb-board"
        button = $("<button />").addClass "dropdown-toggle btn btn-sm btn-default"
        button.attr "data-toggle", "dropdown"
        button.attr "type", "button"

        button.append $("<li />").addClass "fa fa-table"
        button.append $("<span />").text " "
        button.append $("<li />").addClass "fa fa-caret-down"

        buttonGroup.append button

        board = $("<ul />").addClass "me-boardmenu dropdown-menu dropdown-menu-right"
        board.attr "role", "menu"
        buttonGroup.append board

        board.boardMenu
            documentId: data.internalId

        buttonGroup.appendTo container

    buildShareSection: () ->
        @log ">>>>>> Building share section."

        form = $ '<div/>', { class: "share form-horizontal" }
        form.appendTo @mainDiv

        formGroup = $ "<div />", class: "form-group"
        formGroup.appendTo form

        unless @readyOnlyFollowers and @metaObject.followers?.length is 0
            @buildSharing formGroup, 4
            @buildFollowers formGroup
        else
            @buildSharing formGroup, 10

    buildFollowers: (formGroup) ->
        $label = $ "<label />", class: "control-label col-sm-2", html: Catalog.getMessage('label.following')
        $label.appendTo formGroup

        $col = $ "<div />", class: "col-sm-4"
        $col.appendTo formGroup

        if @readyOnlyFollowers || @isForcingReadOnly()
            if @metaObject.followers?
                for follower in @metaObject.followers
                    $avatar = Avatar.getImg(follower.email, 30)
                    $avatar.appendTo $col
                    $avatar.mepopover
                        url: "/users/card/#{follower.email}"
                        placement: "bottom"
        else
            $select = $ "<input type='hidden' />"
            $select.appendTo $col
            $select.on "change", (e) =>
                @metaObject.followers = [] unless @metaObject.followers?
                if (e.added?)
                    @metaObject.followers.push e.added
                else if (e.removed?)
                    for follower, i in @metaObject.followers when follower.id is e.removed.id
                        @metaObject.followers.splice i, 1
                        break
                $(@mainDiv).trigger "sbInternalChange", e.val

            $select.val @metaObject.followers if @metaObject.followers?
            $select.meselect
                multiple: true
                minimumInputLength: 2
                placeholder: Catalog.getMessage("document.followers.placeholder")
                ajax:
                    url: "/users/getListByName"
                    dataType: 'json'
                    data: (term, page) =>
                        name: term
                    results: (data, page) =>
                        results: data
                initSelection: (element, callback) =>
                    callback(@metaObject.followers)
                formatResult: (user) =>
                    "#{Avatar.getHtml(user.email, 30)} #{user.name}"
                formatSelection: (user) =>
                    "#{Avatar.getHtml(user.email, 20)} #{user.name}"

    buildSharing: (formGroup, size) ->
        label = $('<label />', { class: "control-label col-sm-2"}).text(Catalog.getMessage('label.sharedWith'))
        label.appendTo formGroup

        shareGroupsCol = $('<div />', { class: "col-sm-#{size}"})
        shareGroupsCol.appendTo formGroup

        hidePublicOption = @dtDefs.properties["ALLOW_PUBLIC_DOCUMENTS"] == "0"

        @sharing = $ "<input/>", type: "hidden"
        @sharing.appendTo shareGroupsCol

        @sharing.on "save.meceap.sharing.dialog", (e, data) =>
            $(@mainDiv).trigger "sbInternalChange", data
            @metaObject.privateShare = not data.public
            @metaObject.privateGroups = data.sharedWith

        @sharing.sharingDialog
            editable: not @isForcingReadOnlyPrivateShare() or not @isForcingReadOnly()
            enableAcl: true
            allowNewHumanBeing: true
            public: not @metaObject.privateShare
            sharedWith: @metaObject.privateGroups
            aclUrlPermission: "/#{PrincipalInfo.principalCustomRoot.name}/document/getPermissions/#{@metaObject.documentTypeId}"

# Init tooltips for labels.
    initToolTips: () ->
        $("label[title]", @mainDiv).metooltip()

# Gather definition data and POST it to server that saves it.
    saveScreenDefsToServer: (screenId) ->
        @log "Going to save to server", @screenDefs
        @screenDefs.childSections = [ @mainSection.gatherDefsData() ]
        @log "After gathering", @screenDefs
        # Use ´MEFloatingWaiting´ to display a spinner.
        @divWaiting = $.MEFloatingWaiting "Saving Screen '#{@screenDefs.name}'"

        @postObjectAsJSONandWait "/#{@options.customRootName}/document/saveScreenJSON/#{screenId}", @screenDefs, (data) =>
            @log "Saved screen Data!", data
            @screenDefs = data
            @findMainSection()
            @repaint()
            # When done, flash a sucess message, then remove the spinner
            $.MEFlash "Saved screen data sucessfully"
            setTimeout((() =>
                @divWaiting.close())
            , 1000)

    executeMacro: (action, callback) ->
        if action.macro?
            macroExecution = new Macro
                documentTypeId: @options.documentTypeId
                documentId: @options.documentId
                confirmation: false

            macroExecution.execute action.macro, =>
                callback()
        else
            callback()

    postActionPerformed: (action) ->
        @log "Going to POST the doc back with an action...", action.name
        @divWaiting = $.MEFloatingWaiting "Doing action #{action.name}..."

        @postObjectAndVariablesAndWait "/#{@options.customRootName}/document/saveDocumentFromScreen/#{@options.documentId}/#{@options.screenId}/#{action.name}",
                @metaObject,
            (data) =>
                @log "Got stuff back", data
                setTimeout (() =>
                    @divWaiting.close())
                , 500

                if data.ok
                    @executeMacro action, =>
#console.log "Saved document!", data, @options

# When done, flash a success message, then remove the spinner
                        $.MEFlash "Actioned successfully!"

                        if @options.callBackPostURL?
                            theURL = @options.callBackPostURL.replace "actionName", action.name
                            @log "Final URL callback", theURL

                            # We use a 'fake form' to POST; we don't want people going back here without a refresh.
                            fakeForm = $('<form method="post"/>')
                            fakeForm.prop 'action', theURL
                            # Even though the form is fake, we need to append it to the document, or it wont work
                            @mainDiv.append fakeForm
                            fakeForm.submit()
                        else if data.redirectUrl?
                            window.location.href = data.redirectUrl
                    return
                if data.result == "validation"
                    allErrs = ""
                    for error in data.validationErrors.errorMessages
# TODO.... highlight document etc
                        $.MEFlash "Error: " + error, 'error', 'slow'
                        allErrs = allErrs + error + '<br/>'
                    @warn "There were validation errors: <br/>" + allErrs
                    return

                console.error "Error in response to save...", data
                $.MEFlash "Generic error: " + data.exception.message, 'error', 'slow'

# Returns the current document object
    getDocumentObject: () ->
        @log "Returning the current metaObject", @metaObject
        @metaObject

    setDocumentObject: (data) =>
        return if @metaObject?.version is data.version and not @isDirty

        @log "Got document metaobject", data
        @initDone = false
        @metaObject = data
        @initIfReady('metaObject')
        @isDirty = false
        $(@mainDiv).trigger "sbDataLoaded"

    destroyValidation: ->
        @form.form('destroyValidation')

    validateFormScreen: ->
        @form.form('isValid')

    resetValidation: ->
        @form.form('resetValidation')

    reload: ->
        @getDocumentMetaObjectDataAjax(@getDocumentObject().internalId)

    checkVersion: (documentId, callback)->
        @log "Check document version ##{documentId}"
        @ajaxGetAsync "/#{@options.customRootName}/document/version/#{documentId}", (version) =>
            callback?(version)