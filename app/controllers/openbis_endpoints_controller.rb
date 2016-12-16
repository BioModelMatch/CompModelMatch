class OpenbisEndpointsController < ApplicationController
  respond_to :html

  before_filter :get_project
  before_filter :project_required
  before_filter :project_can_admin?
  before_filter :get_endpoints,only:[:index, :browse]


  def index
    respond_with(@project,@openbis_endpoints)
  end

  def new
    @openbis_endpoint=OpenbisEndpoint.new
    @openbis_endpoint.project=@project
    respond_with(@openbis_endpoint)
  end

  def edit
    @openbis_endpoint=OpenbisEndpoint.find(params[:id])
    respond_with(@openbis_endpoint)
  end

  def update
    @openbis_endpoint=OpenbisEndpoint.find(params[:id])
    respond_with(@project,@openbis_endpoint) do |format|
      if @openbis_endpoint.update_attributes(params[:openbis_endpoint])
        flash[:notice] = 'The space was successfully updated.'
        format.html {redirect_to project_openbis_endpoints_path(@project)}
      end
    end
  end

  def browse
    respond_with(@project,@openbis_endpoints)
  end

  def create
    @openbis_endpoint=@project.openbis_endpoints.build(params[:openbis_endpoint])
    respond_with(@project,@openbis_endpoint) do |format|
      if @openbis_endpoint.save
        flash[:notice] = 'The space was successfully associated with the project.'
        format.html {redirect_to project_openbis_endpoints_path(@project)}
      end
    end
  end

  def show_item_count
    endpoint = OpenbisEndpoint.find(params[:id])
    respond_to do |format|
      format.html {render(text:"#{endpoint.space.dataset_count} datasets found")}
    end
  end

  def show_items
    endpoint = OpenbisEndpoint.find(params[:id])
    respond_to do |format|
      format.html {render(partial:'show_items_for_space',locals:{space:endpoint.space})}
    end
  end

  def test_endpoint
    endpoint = OpenbisEndpoint.new(params[:openbis_endpoint])
    result = endpoint.test_authentication

    respond_to do |format|
      format.json {render(json:{result:result})}
    end
  end

  def fetch_spaces
    endpoint = OpenbisEndpoint.new(params[:openbis_endpoint])
    respond_to do |format|
      format.html {render partial:'available_spaces',locals:{endpoint:endpoint}}
    end
  end

  ### Filters

  def project_required
    return false unless @project
  end

  def get_endpoints
    @openbis_endpoints=@project.openbis_endpoints
  end

  def get_project
    @project=Project.find(params[:project_id])
  end

  def project_can_admin?
    unless @project.can_be_administered_by?(current_user)
      error("Insufficient privileges", "is invalid (insufficient_privileges)")
      return false
    end
  end

end