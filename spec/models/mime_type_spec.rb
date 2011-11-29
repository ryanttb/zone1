require 'spec_helper'

describe MimeType do
  it { should have_many(:stored_files) }
  it { should belong_to(:mime_type_category) }

  it { should validate_presence_of(:name) }
  it { should validate_presence_of(:mime_type) }
  it { should validate_presence_of(:extension) }

  it { should allow_mass_assignment_of(:name) }
  it { should allow_mass_assignment_of(:mime_type) }
  it { should allow_mass_assignment_of(:extension) }
  it { should allow_mass_assignment_of(:blacklist) }

  describe "after initialize" do
    describe "set default category" do
      it "sets the MimeTypeCategorty to 'Uncategorized'" do
        subject { Factory(:mime_type) }
        subject.mime_type_category.should == MimeTypeCategory.find_by_name("Uncategorized")
      end
    end
  end

  describe ".blacklisted_extensions" do
    it "should return an array of extensions marked as blacklisted" do
      Factory(:mime_type, :blacklist => true, :extension => ".exe")
      Factory(:mime_type, :blacklist => false, :extension => ".jpg")
      MimeType.blacklisted_extensions.should == [".exe"]
    end
  end
end