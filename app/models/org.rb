class Org < ActiveRecord::Base
  has_many :projects   
  has_many :commits   
  has_many :coders, :through => :commits   
  
  validates_uniqueness_of :login, :on => :create, :message => "must be unique"

  # given an organization name, goto github and grab the organization details and create a new org
  #
  # @param name The url of the repo, i.e. "codeforamerica"
  # @return Organization or Error
  # @example Organization.new.get_details("codeforamerica")
  
  def get_details(name)
    begin
      org = Octokit.organization(name) 
    rescue
      return false, "We had a problem finding that organization"
    else
      col = Org.columns.map(&:name)
      org.delete_if { |key| !col.include?(key)}
      Org.create!(org)
    end
  end

  # goto github and grab the organization projects
  #
  # @return projects or Error
  # @example Organization.first.get_projects
  
  def get_projects
    begin
      repos = Octokit.organization_repositories(self.login)
    rescue
      self.update_attributes(:flag => true, :error_message => "We had a problem finding that organization")
      return false, "We had a problem finding that organization"
    else
      repos.each do |repo|
        col = Project.columns.map(&:name)
        repo.delete_if { |key| !col.include?(key)}        
        self.projects.create(repo)        
      end
      self.projects
    end
  end
  
  # goto github, grab the organization projects and add any new projects
  #
  # @return projects or Error
  # @example Organization.first.new_projects
  
  def get_new_projects
    project_list = self.get_projects
    project_list.each do |project|
      if Project.where(:name => project.name).blank?
        self.projects.create!(project)
        Project.last.delay.get_commit_history(1)
      end
    end
  end
  
  
  
  # given a org name, find and return it or goto github and grab the org details and return a new coder
  #
  # @param name The username of the coder i.e. sferik
  # @return Github user object or error
  # @example Org.new.find_or_create("codeforamerica")
  
  def find_or_create(name)
    org = Org.where(:login => name).first
    !org.blank? ? org : self.get_details(name)
  end

end
