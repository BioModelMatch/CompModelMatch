# To change this template, choose Tools | Templates
# and open the template in the editor.

class BioportalConcept < ActiveRecord::Base
  include BioPortal::RestAPI

  belongs_to :conceptable,:polymorphic=>true

  def concept_details options={}    
    options[:refresh]||=false

    refresh=options.delete(:refresh)

    #TODO: handle caching of concept
    concept = get_concept(self.ontology_version_id,self.concept_uri,options)
    update_attribute(:cached_concept_yaml, concept.to_yaml)
    
    return concept
  end

  #the base url is defined by the associated class - this overrides the method in the RestAPI mixin
  def bioportal_base_rest_url
    conceptable.bioportal_base_rest_url
  end

end
