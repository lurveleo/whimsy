#
# Post or edit a report or resolution
#
# For new resolutions, allow entry of title, but not commit message
# For everything else, allow modification of commit message, but not title

class Post < Vue
  def initialize
    @button = @@button.text
    @disabled = false
    @alerted = false
    @edited = false
  end

  # default attributes for the button associated with this form
  def self.button
    {
      text: 'post report',
      class: 'btn_primary',
      disabled: Server.offline,
      data_toggle: 'modal',
      data_target: '#post-report-form'
    }
  end

  def render
    _ModalDialog.wide_form.post_report_form! color: 'commented' do
      if @button == 'add item'
        _h4 'Select Item Type'
  
        _ul.new_item_type do
          _li do
            _button.btn.btn_primary 'Change Chair', onClick: selectItem
            _ '- change chair for an existing PMC'
          end
  
          _li do
            _button.btn.btn_primary 'Establish Project', disabled: true
          end
  
          _li do
            _button.btn.btn_primary 'Terminate Project', onClick: selectItem
            _ '- move a project to the attic'
          end
  
          _li do
            _button.btn.btn_primary 'Out of Cycle Report', onClick: selectItem
            _ '- report from a PMC not currently on the agenda for this month'
          end
  
          _li do
            _button.btn.btn_primary 'New Resolution', onClick: selectItem
            _ '- free form entry of a new resolution'
          end
        end
  
        _button.btn_default 'Cancel', data_dismiss: 'modal'

      elsif @button == 'Change Chair'
        _h4 'Change Chair Resolution'

        _div.form_group do
          _label 'PMC', for: 'change-chair-pmc'
          _select.form_control.change_chair_pmc!(
            onChange: ->(event) {chair_pmc_change(event.target.value)}
          ) do
            @pmcs.each {|pmc| _option pmc}
          end
        end

        _div.form_group do
          _label 'Outgoing Chair', for: 'outgoing-chair'
          _input.form_control.outgoing_chair! value: @outgoing_chair, 
            disabled: true
        end

        _div.form_group do
          _label 'Incoming Chair', for: 'incoming-chair'
          _select.form_control.incoming_chair! do
            @pmc_members.each do |person|
              _option person.name, value: person.id,
                selected: person.id == User.id
            end
          end
        end

        _button.btn_default 'Cancel', data_dismiss: 'modal', disabled: @disabled
        _button.btn_primary 'Draft', disabled: @disabled,
          onClick: draft_chair_change_resolution

      elsif @button == 'Terminate Project'
        _h4 'Terminate Project Resolution'

        _div.form_group do
          _label 'PMC', for: 'terminate-pmc'
          _select.form_control.terminate_pmc! do
            @pmcs.each {|pmc| _option pmc}
          end
        end

        _p 'Reason for termination:'

        _div.form_check do
          _input.form_check_input.termvote! type: 'radio', name: 'termreason', 
            onClick: -> {@termreason = 'vote'}
          _label.form_check_label 'by vote of the PMC', for: 'termvote'
        end

        _div.form_check do
          _input.form_check_input.termconsensus! type: 'radio', 
            name: 'termreason', onClick: -> {@termreason = 'consensus'}
          _label.form_check_label 'by consensus of the PMC', 
            for: 'termconsensus'
        end

        _div.form_check do
          _input.form_check_input.termboard! type: 'radio', 
            name: 'termreason', onClick: -> {@termreason = 'board'}
          _label.form_check_label 'by the board for inactivity', 
            for: 'termboard'
        end

        _button.btn_default 'Cancel', data_dismiss: 'modal', disabled: @disabled
        _button.btn_primary 'Draft', onClick: draft_terminate_project,
          disabled: (@pmcs.empty? or not @termreason)


      elsif @button == 'Out of Cycle Report'
        _h4 'Out of Cycle PMC Report'

        _div.form_group do
          _label 'PMC', for: 'out-of-cycle-pmc'
          _select.form_control.out_of_cycle_pmc! do
            @pmcs.each {|pmc| _option pmc}
          end
        end

        _button.btn_default 'Cancel', data_dismiss: 'modal', disabled: @disabled
        _button.btn_primary 'Draft', disabled: @pmcs.empty?,
          onClick: draft_out_of_cycle_report

      else

        _h4 @header

        #input field: title
        if @header == 'Add Resolution' or @header == 'Add Discussion Item'
          _input.post_report_title! label: 'title', disabled: @disabled,
            placeholder: 'title', value: @title, onFocus: self.default_title
        end

        #input field: report text
        _textarea.post_report_text! label: @label, value: @report,
          placeholder: @label, rows: 17, disabled: @disabled, 
          onInput: self.change_text

        # upload of spreadsheet from virtual
        if @@item.title == 'Treasurer'
          _form do
            _div.form_group do
              _label 'financial spreadsheet from virtual', for: 'upload'
              _input.upload! type: 'file', value: @upload
              _button.btn.btn_primary 'Upload', onClick: upload_spreadsheet,
                disabled: @disabled || !@upload
            end
          end
        end

        #input field: commit_message
        if @header != 'Add Resolution' and @header != 'Add Discussion Item'
          _input.post_report_message! label: 'commit message', 
            disabled: @disabled, value: @message
        end

        # footer buttons
        _button.btn_default 'Cancel', data_dismiss: 'modal', disabled: @disabled
        _button 'Reflow', class: self.reflow_color(), onClick: self.reflow
        _button.btn_primary 'Submit', onClick: self.submit, 
          disabled: (not self.ready())
      end
    end
  end

  # add item menu support
  def selectItem(event)
    @button = event.target.textContent

    if @button == 'Change Chair'
      initialize_chair_change()
    elsif @button == 'Terminate Project'
      initialize_terminate_project()
    elsif @button == 'Out of Cycle Report'
      initialize_out_of_cycle()
    end

    retitle()
  end

  # autofocus on report/resolution title/text
  def mounted()
    jQuery('#post-report-form').on 'show.bs.modal' do
      # update contents when modal is about to be shown
      @button = @@button.text
      self.retitle()
    end

    jQuery('#post-report-form').on 'shown.bs.modal' do
      reposition()
    end
  end

  # reposition after update if header changed
  def updated()
    reposition() if Post.header != @header
  end

  # set focus, scroll
  def reposition()
    # set focus once modal is shown
    title = document.getElementById("post-report-title")
    text = document.getElementById("post-report-text")

    if title || text
      (title || text).focus()

      # scroll to the top
      setTimeout 0 do
        text.scrollTop = 0 if text
      end
    end

    Post.header = @header
  end

  # initialize form title, etc.
  def created()
    self.retitle()
  end

  # match form title, input label, and commit message with button text
  def retitle()
    case @button
    when 'post report'
      @header = 'Post Report'
      @label = 'report'
      @message = "Post #{@@item.title} Report"

    when 'edit report'
      @header = 'Edit Report'
      @label = 'report'
      @message = "Edit #{@@item.title} Report"

    when 'add resolution', 'New Resolution'
      @header = 'Add Resolution'
      @label = 'resolution'
      @title = ''

    when 'edit resolution'
      @header = 'Edit Resolution'
      @label = 'resolution'
      @title = ''

    when 'post item'
      @header = 'Add Discussion Item'
      @label = 'discussion item'
      @message = "Add Discussion Item"

    when 'post items'
      @header = 'Post Discussion Items'
      @label = 'items'
      @message = "Post Discussion Items"

    when 'edit items'
      @header = 'Edit Discussion Items'
      @label = 'items'
      @message = "Edit Discussion Items"
    end

    if not @edited
      text = @@item.text || '' 
      if @@item.title == 'President'
        text.sub! /\s*Additionally, please see Attachments \d through \d\./, ''
      end

      @report = text
      @digest = @@item.digest
      @alerted = false
      @edited = false
      @base = @report
    elsif not @alerted and @edited and @digest != @@item.digest
      alert 'edit conflict'
      @alerted = true
    else
      @report = @base
    end

    if @header == 'Add Resolution' or @@item.attach =~ /^[47]/
      @indent = '        '
    elsif @header == 'Add Disussion Item' 
      @indent = '        '
    elsif @@item.attach == '8.'
      @indent = '    '
    else
      @indent = ''
    end
  end

  # default title based on common resolution patterns
  def default_title(event)
    return if @title
    match = nil

    if (match = @report.match(/appointed\s+to\s+the\s+office\s+of\s+Vice\s+President,\s+Apache\s+(.*?),/))
      @title = "Change the Apache #{match[1]} Project Chair"
    elsif (match = @report.match(/to\s+be\s+known\s+as\s+the\s+"Apache\s+(.*?)\s+Project",\s+be\s+and\s+hereby\s+is\s+established/))
      @title = "Establish the Apache #{match[1]} Project"
    elsif (match = @report.match(/the\s+Apache\s+(.*?)\s+project\s+is\s+hereby\s+terminated/))
      @title = "Terminate the Apache #{match[1]} Project"
    end
  end

  # track changes to text value
  def change_text(event)
    @report = event.target.value
    self.change_message()
  end

  # update default message to reflect whether only whitespace changes were
  # made or if there is something more that was done
  def change_message()
    @edited = (@base != @report)

    if @message =~ /(Edit|Reflow) #{@@item.title} Report/
      if @edited and @base.gsub(/[ \t\n]+/, '') == @report.gsub(/[ \t\n]+/, '')
         @message = "Reflow #{@@item.title} Report"
      else
         @message = "Edit #{@@item.title} Report"
      end
    end
  end

  # determine if reflow button should be default or danger color
  def reflow_color()
    width = 80 - @indent.length

    if @report.split("\n").all? {|line| line.length <= width}
      return 'btn-default'
    else
      return'btn-danger'
    end
  end

  # perform a reflow of report text
  def reflow()
    report = @report
    textarea = document.getElementById('post-report-text')
    indent = start = finish = 0

    # extract selection (if any)
    if textarea and textarea.selectionEnd > textarea.selectionStart
      start = textarea.selectionStart
      start -= 1  while start > 0 and report[start-1] != "\n"
      finish = textarea.selectionEnd
      finish += 1 while report[finish] != '\n' and finish < report.length-1
    end

    # remove indentation
    unless report =~ /^\S/
      regex = RegExp.new('^( +)', 'gm')
      indents = []
      while (result = regex.exec(report))
        indents.push result[1].length
      end
      unless indents.empty?
        indent = Math.min(*indents)
        report.gsub!(RegExp.new('^' + ' ' * indent, 'gm'), '')
      end
    end

    # enable special punctuation rules for the incubator
    puncrules = (@@item.title == 'Incubator')

    # reflow selection or entire report
    if finish > start
      report = Flow.text(report[start..finish], @indent+indent, puncrules)
      report.gsub(/^/, ' ' * indent) if indent > 0
      @report = @report[0...start] + report + @report[finish+1..-1]
    else
      @report = Flow.text(report, @indent, puncrules)
    end

    self.change_message()
  end

  # determine if the form is ready to be submitted
  def ready()
    return false if @disabled

    if @header == 'Add Resolution'
      return @report != '' && @title != ''
    else
      return @report != @@item.text && @message != ''
    end
  end

  # when save button is pushed, post comment and dismiss modal when complete
  def submit(event)
    @edited = false

    if @header == 'Add Resolution' or @header == 'Add Discussion Item'
      data = {
        agenda: Agenda.file,
        attach: (@header == 'Add Resolution') ? '7?' : '8?',
        title: @title,
        report: @report
      }
    else
      data = {
        agenda: Agenda.file,
        attach: @attach || @@item.attach,
        digest: @digest,
        message: @message,
        report: @report
      }
    end

    @disabled = true
    post 'post', data do |response|
      jQuery('#post-report-form').modal(:hide)
      document.body.classList.remove('modal-open')
      @attach = nil
      @disabled = false
      Agenda.load response.agenda, response.digest
    end
  end

  #########################################################################
  #                                Treasurer                              #
  #########################################################################

  # upload contents of spreadsheet in base64; append extracted table to report
  def upload_spreadsheet(event)
    @disabled = true
    event.preventDefault()

    reader = FileReader.new
    def reader.onload(event)
      result = event.target.result
      base64 = btoa(String.fromCharCode(*Uint8Array.new(result)))
      post 'financials', spreadsheet: base64 do |response|
        report = @report
        report += "\n" if report and not report.end_with? "\n"
        report += "\n" if report
        report += response.table

        self.change_text target: {value: report}

        @upload = nil
        @disabled = false
      end
    end
    reader.readAsArrayBuffer(document.getElementById('upload').files[0])
  end

  #########################################################################
  #                            Terminate Project                          #
  #########################################################################

  def initialize_terminate_project()
    # get a list of PMCs
    @pmcs = []
    post 'post-data', request: 'committee-list' do |response|
      @pmcs = response
    end

    @terreason = nil
  end

  def draft_terminate_project()
    @disabled = true
    options = {
      request: 'terminate', 
      pmc: document.getElementById('terminate-pmc').value, 
      reason: @termreason
    }

    post 'post-data', options do |response|
      @button = @header = 'Add Resolution'
      @title = response.title
      @report = response.draft
      @label = 'resolution'
      @disabled = false
    end
  end

  #########################################################################
  #                           Out of Cycle report                         #
  #########################################################################

  def initialize_out_of_cycle()
    @disabled = true

    # gather a list of reports already on the agenda
    scheduled = {}
    Agenda.index.each do |item|
      if item.attach =~ /^[A-Z]/
        scheduled[item.title.downcase] = true
      end
    end

    # get a list of PMCs and select ones that aren't on the agenda
    @pmcs = []
    post 'post-data', request: 'committee-list' do |response|
      response.each do |pmc|
        @pmcs << pmc unless scheduled[pmc]
      end
    end
  end

  def draft_out_of_cycle_report()
    pmc =  document.getElementById('out-of-cycle-pmc').value.
      gsub(/\b[a-z]/) {|s| s.upcase()}
    @button = 'post report'
    @disabled = true
    @report = ''
    @header = 'Post Report'
    @label = 'report'
    @message = "Post Out of Cycle #{pmc} Report"
    @attach = '+' + pmc 
    @disabled = false
  end

  #########################################################################
  #                         Change Project Chair                          #
  #########################################################################

  def initialize_chair_change()
    @disabled = true
    @pmcs = []
    chair_pmc_change(nil)
    post 'post-data', request: 'committee-list' do |response|
      @pmcs = response
      chair_pmc_change(@pmcs.first)
    end
  end

  def chair_pmc_change(pmc)
    @disabled = true
    @outgoing_chair = nil
    @pmc_members = []
    return unless pmc
    post 'post-data', request: 'committee-members', pmc: pmc do |response|
      @outgoing_chair = response.chair.name
      @pmc_members = response.members
      @disabled = false
    end
  end

  def draft_chair_change_resolution()
    @disabled = true
    options = {
      request: 'change-chair', 
      pmc: document.getElementById('change-chair-pmc').value, 
      chair: document.getElementById('incoming-chair').value
    }

    post 'post-data', options do |response|
      @button = @header = 'Add Resolution'
      @title = response.title
      @report = response.draft
      @label = 'resolution'
      @disabled = false
    end
  end

end
