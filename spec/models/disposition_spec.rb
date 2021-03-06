require 'spec_helper'

describe Disposition do
  it { should belong_to :disposition_action }
  it { should belong_to :stored_file }

  it { should validate_presence_of :disposition_action_id }
  it { should validate_presence_of :stored_file_id }

  it { should allow_mass_assignment_of :stored_file_id }
  it { should allow_mass_assignment_of :disposition_action_id }
  it { should allow_mass_assignment_of :location }
  it { should allow_mass_assignment_of :note }
  
end
