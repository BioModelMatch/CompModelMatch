module TavernaPlayer
  class RunsController < TavernaPlayer::ApplicationController
    include TavernaPlayer::Concerns::Controllers::RunsController

    skip_before_filter :project_membership_required
    skip_before_filter :restrict_guest_user, :only => :new

    before_filter :check_project_membership_unless_embedded, :only => [:create, :new]
    before_filter :auth, :except => [ :index, :new, :create ]
    before_filter :add_sweeps, :only => :index
    before_filter :filter_users_runs_and_sweeps, :only => :index
    before_filter :find_workflow_and_version, :only => :new

    def update
      @run.update_attributes(params[:run])

      if params[:sharing]
        @run.policy_or_default
        @run.policy.set_attributes_with_sharing params[:sharing], @run.projects
        @run.save
      end

      respond_with(@run)
    end

    # POST /runs
    def create
      @run = Run.new(params[:run])
      # Manually add projects of current user, as they aren't prompted for this information in the form
      @run.projects = @run.contributor.person.projects
      @run.policy.set_attributes_with_sharing params[:sharing], @run.projects

      if @run.save
        flash[:notice] = "Run was successfully created."
      end

      respond_with(@run, :status => :created, :location => @run)
    end

    # DELETE /runs/1
    def destroy
      if @run.destroy
        flash[:notice] = "Run was deleted."
        respond_with(@run) do |format|
          format.html { redirect_to params[:redirect_to].blank? ? :back : params[:redirect_to]}
        end
      else
        flash[:error] = "Run must be cancelled before deletion."
        respond_with(@run, :nothing => true, :status => :forbidden) do |format|
          format.html { redirect_to :back}
        end
      end
    end

    private

    def find_workflow_and_version
      @workflow = @run.workflow || TavernaPlayer.workflow_proxy.class_name.find(params[:workflow_id])
      @workflow_version = params[:version].blank? ? @workflow.latest_version : @workflow.find_version(params[:version])
    end

    def choose_layout
      if (action_name == "new" || action_name == "show") && @run.embedded?
       "taverna_player/embedded"
      else
        ApplicationController.new.send(:_layout)
      end
    end

    def find_runs
      select = params[:workflow_id] ? { :workflow_id => params[:workflow_id] } : {}
      @runs = Run.where(select).where(:embedded => :false).includes(:sweep).includes(:workflow).all
      @runs = @runs & Run.all_authorized_for('view', current_user)
    end

    # Overrides the method from TavernaPlayer::Concerns::Controllers::RunsController
    # to check for non-existing runs and failing gracefully instead of throwing 404 Not found.
    def find_run
      if Run.where(:id => params[:id]).blank?
        respond_to do |format|
          flash[:error] = 'The run you are looking for does not exist.'
          format.html { redirect_to runs_path }
          format.json { render :nothing => true, :status => "404" }
        end
      else
        @run = Run.find(params[:id])
      end
    end

    # Returns a list of simple Run objects and Sweep objects. We do not want
    # to group sweeps when serving json, though. There may be a better way...
    def add_sweeps
      return if request.format.to_s.include?("json")
      @runs = @runs.group_by { |run| run.sweep }
      @runs = (@runs[nil] || []) + @runs.keys
      @runs.compact! # to ignore 'nil' key
    end

    def filter_users_runs_and_sweeps
      @user_runs = @runs.select do |run|
        run.contributor == current_user
      end

      @extra_runs = @runs - @user_runs
    end

    def auth
      # Skip certain auth if run is embedded
      if @run.embedded
        if ['cancel','read_interaction','write_interaction'].include?(action_name)
          return true
        end
      end

      action = translate_action(action_name)
      unless is_auth?(@run, action)
        if User.current_user.nil?
          flash[:error] = "You are not authorized to #{action} this Workflow Run, you may need to login first."
        else
          flash[:error] = "You are not authorized to #{action} this Workflow Run."
        end
        respond_with(@run, :nothing => true, :status => :unauthorized) do |format|
          format.html do
            case action
              when 'manage','edit','download','delete'
                redirect_to @run
              else
                redirect_to taverna_player.runs_path
            end
          end
        end
      end
    end

    def check_project_membership_unless_embedded
      unless (params[:run] && params[:run][:embedded] == 'true') || (params[:embedded] && params[:embedded] == 'true')
        project_membership_required
      end
    end

  end
end
