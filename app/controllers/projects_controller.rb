# frozen_string_literal: true

# EXAMPLE CONTROLLER.
#
# Read `scoped_projects` first: every action in this controller starts from
# `current_team.projects`, never from `Project`. That single habit is what makes
# cross-tenant access impossible rather than merely forbidden — a project
# belonging to another team is not found, so Rails renders 404.
class ProjectsController < ApplicationController
  before_action :set_project, only: %i[show edit update destroy]

  def index
    @projects = policy_scope(scoped_projects.search(params[:q]).recent)
    @page = paginate(@projects)
  end

  def show
    authorize @project
  end

  def new
    @project = scoped_projects.new
    authorize @project
  end

  def create
    @project = scoped_projects.new(project_params)
    @project.created_by = Current.user
    authorize @project

    if @project.save
      redirect_to @project, notice: "Project created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    authorize @project
  end

  def update
    authorize @project

    if @project.update(project_params)
      redirect_to @project, notice: "Project updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize @project
    @project.destroy!

    redirect_to projects_path, notice: "Project deleted.", status: :see_other
  end

  private

  # The one line that matters.
  def scoped_projects = current_team.projects

  def set_project
    @project = scoped_projects.find(params[:id])
  end

  def project_params
    params.expect(project: %i[name description])
  end
end
