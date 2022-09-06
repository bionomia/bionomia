class InstitutionCodeSerialize < ActiveRecord::Migration[7.0]
  def up
    unless column_exists? :organizations, :institution_codes_json
      add_column :organizations, :institution_codes_json, :text, after: :institution_codes
    end

    Organization.where.not(institution_codes: nil).find_each do |o|
      o.institution_codes_json = o.institution_codes
      o.save
    end

    remove_column :organizations, :institution_codes
    rename_column :organizations, :institution_codes_json, :institution_codes
  end

  def down
  end
end
