def create_backlogs!
  errors = {}
  projects = Project.all.reverse
  projects = projects.select { |p| p.enabled_modules.map(&:name).include? "backlogs" }
  projects = projects.reject { |p| p.versions.where(name: "Product Backlog").exists? }

  projects.each do |p|
    begin
      Project.transaction do
        version = Version.create! project: p, name: "Product Backlog", status: "open", sharing: "none"
        version.version_settings.create project: version.project, display: "3" # display right
        backlogs = p.work_packages.select { |wp| wp.fixed_version.nil? }

        backlogs.each { |wp| wp.update fixed_version: version }
      end
    rescue => e
      errors[p.identifier] = e.message
    end
  end

  errors
end

def fix_queries!
  Query.find(261).tap do |query|
    query.update column_names: query.column_names.reject { |n| n.to_s == "description" }
  end

  migrate_list_filters!
end

def migrate_list_filters!
  invalid = []
  queries = Query.all.select { |q| q.inspect.include?("field_format: \"list\"") && !q.valid? }

  queries.each do |query|
    puts "Fixing query with list custom field: ##{query.id}"

    filters = query.filters.select { |f| f.class.name == "Queries::Filters::Shared::CustomFields::ListOptional" }

    filters.each do |filter|
      filter.values = filter.values.flat_map do |value|
        CustomOption.where(custom_field_id: filter.custom_field.id, value: value).take(1).map(&:id)
      end
    end

    if !query.save
      invalid << query
    end
  end

  invalid
end

def create_query_menu_items!
  queries = Query.all.select { |q| q.query_menu_item.nil? && !q.is_public }
  failed_count = 0

  queries.each do |query|
    item = query.create_query_menu_item name: query.name, title: query.name

    if item.id.nil?
      puts "Could not create menu item for '#{query.name}':\n  #{query.errors.full_messages.join("\n  ")}"
      failed_count = failed_count + 1
    end
  end

  { created: queries.size - failed_count, failed: failed_count }
end

def rename_types!
  support = Type.find(3)
  support.update name: "Support"

  fehler = Type.find_by(name: "Fehler")
  feature = Type.find_by(name: "Feature")

  [support, fehler, feature].each do |t|
    t.update is_default: true
  end
end

def fix_backlogs_settings!
  Setting.plugin_openproject_backlogs = Setting.plugin_openproject_backlogs.merge(
    "story_types" => ["1", "2", "4"],
    "task_type" => "5"
  )
end

def fix_links_in_wikis!
  WikiContent.all.each do |wc|
    new_content = wc.text.gsub(":/redmine/", ":/")

    wc.update text: new_content if wc.text != new_content
  end
end

def fix_done_statuses!
  projects = Project.all.select { |p| p.backlogs_enabled? }
  statuses = [Status.find(5), Status.find(6)] # erledigt, abgewiesen

  projects.each do |project|
    project.done_statuses = statuses
    project.save
  end
end

def set_default_work_package_types!
  type_ids = [1, 2, 3] # Fehler, Feature, Support
  types = type_ids.map { |id| Type.find id }

  Project.all.each do |project|
    (type_ids - project.type_ids).each do |id|
      type = types.find { |t| t.id == id }
      project.types << type
    end
  end
end

def add_view_members_permission!
  Role.where.not(name: "Anonymous").each do |r|
    r.add_permission! :view_members unless r.permissions.include? :view_members
  end

  Role.where(name: ["Manager"]).each do |r|
    r.add_permission! :copy_projects unless r.permissions.include? :copy_projects
    r.add_permission! :manage_types unless r.permissions.include? :manage_types
  end
end

def define_colors!
  colors = [
    {"name"=>"Blue (dark)", "hexcode"=>"#06799F"}, {"name"=>"Blue", "hexcode"=>"#3493B3"}, {"name"=>"Blue (light)", "hexcode"=>"#00B0F0"},
    {"name"=>"Green (light)", "hexcode"=>"#35C53F"}, {"name"=>"Green (dark)", "hexcode"=>"#339933"}, {"name"=>"Yellow", "hexcode"=>"#FFFF00"},
    {"name"=>"Orange", "hexcode"=>"#FFCC00"}, {"name"=>"Red", "hexcode"=>"#FF3300"}, {"name"=>"Magenta", "hexcode"=>"#E20074"},
    {"name"=>"White", "hexcode"=>"#FFFFFF"}, {"name"=>"Grey (light)", "hexcode"=>"#F8F8F8"}, {"name"=>"Grey", "hexcode"=>"#EAEAEA"},
    {"name"=>"Grey (dark)", "hexcode"=>"#878787"}, {"name"=>"Black", "hexcode"=>"#000000"}, {"name"=>"gray-0", "hexcode"=>"#F8F9FA"},
    {"name"=>"gray-1", "hexcode"=>"#F1F3F5"}, {"name"=>"gray-2", "hexcode"=>"#E9ECEF"}, {"name"=>"gray-3", "hexcode"=>"#DEE2E6"},
    {"name"=>"gray-4", "hexcode"=>"#CED4DA"}, {"name"=>"gray-5", "hexcode"=>"#ADB5BD"}, {"name"=>"gray-6", "hexcode"=>"#868E96"},
    {"name"=>"gray-7", "hexcode"=>"#495057"}, {"name"=>"gray-8", "hexcode"=>"#343A40"}, {"name"=>"gray-9", "hexcode"=>"#212529"},
    {"name"=>"red-0", "hexcode"=>"#FFF5F5"}, {"name"=>"red-1", "hexcode"=>"#FFE3E3"}, {"name"=>"red-2", "hexcode"=>"#FFC9C9"},
    {"name"=>"red-3", "hexcode"=>"#FFA8A8"}, {"name"=>"red-4", "hexcode"=>"#FF8787"}, {"name"=>"red-5", "hexcode"=>"#FF6B6B"},
    {"name"=>"red-6", "hexcode"=>"#FA5252"}, {"name"=>"red-7", "hexcode"=>"#F03E3E"}, {"name"=>"red-8", "hexcode"=>"#E03131"},
    {"name"=>"red-9", "hexcode"=>"#C92A2A"}, {"name"=>"pink-0", "hexcode"=>"#FFF0F6"}, {"name"=>"pink-1", "hexcode"=>"#FFDEEB"},
    {"name"=>"pink-2", "hexcode"=>"#FCC2D7"}, {"name"=>"pink-3", "hexcode"=>"#FAA2C1"}, {"name"=>"pink-4", "hexcode"=>"#F783AC"},
    {"name"=>"pink-5", "hexcode"=>"#F06595"}, {"name"=>"pink-6", "hexcode"=>"#E64980"}, {"name"=>"pink-7", "hexcode"=>"#D6336C"},
    {"name"=>"pink-8", "hexcode"=>"#C2255C"}, {"name"=>"pink-9", "hexcode"=>"#A61E4D"}, {"name"=>"grape-0", "hexcode"=>"#F8F0FC"},
    {"name"=>"grape-1", "hexcode"=>"#F3D9FA"}, {"name"=>"grape-2", "hexcode"=>"#EEBEFA"}, {"name"=>"grape-3", "hexcode"=>"#E599F7"},
    {"name"=>"grape-4", "hexcode"=>"#DA77F2"}, {"name"=>"grape-5", "hexcode"=>"#CC5DE8"}, {"name"=>"grape-6", "hexcode"=>"#BE4BDB"},
    {"name"=>"grape-7", "hexcode"=>"#AE3EC9"}, {"name"=>"grape-8", "hexcode"=>"#9C36B5"}, {"name"=>"grape-9", "hexcode"=>"#862E9C"},
    {"name"=>"violet-0", "hexcode"=>"#F3F0FF"}, {"name"=>"violet-1", "hexcode"=>"#E5DBFF"}, {"name"=>"violet-2", "hexcode"=>"#D0BFFF"},
    {"name"=>"violet-3", "hexcode"=>"#B197FC"}, {"name"=>"violet-4", "hexcode"=>"#9775FA"}, {"name"=>"violet-5", "hexcode"=>"#845EF7"},
    {"name"=>"violet-6", "hexcode"=>"#7950F2"}, {"name"=>"violet-7", "hexcode"=>"#7048E8"}, {"name"=>"violet-8", "hexcode"=>"#6741D9"},
    {"name"=>"violet-9", "hexcode"=>"#5F3DC4"}, {"name"=>"indigo-0", "hexcode"=>"#EDF2FF"}, {"name"=>"indigo-1", "hexcode"=>"#DBE4FF"},
    {"name"=>"indigo-2", "hexcode"=>"#BAC8FF"}, {"name"=>"indigo-3", "hexcode"=>"#91A7FF"}, {"name"=>"indigo-4", "hexcode"=>"#748FFC"},
    {"name"=>"indigo-5", "hexcode"=>"#5C7CFA"}, {"name"=>"indigo-6", "hexcode"=>"#4C6EF5"}, {"name"=>"indigo-7", "hexcode"=>"#4263EB"},
    {"name"=>"indigo-8", "hexcode"=>"#3B5BDB"}, {"name"=>"indigo-9", "hexcode"=>"#364FC7"}, {"name"=>"blue-0", "hexcode"=>"#E7F5FF"},
    {"name"=>"blue-1", "hexcode"=>"#D0EBFF"}, {"name"=>"blue-2", "hexcode"=>"#A5D8FF"}, {"name"=>"blue-3", "hexcode"=>"#74C0FC"},
    {"name"=>"blue-4", "hexcode"=>"#4DABF7"}, {"name"=>"blue-5", "hexcode"=>"#339AF0"}, {"name"=>"blue-6", "hexcode"=>"#228BE6"},
    {"name"=>"blue-7", "hexcode"=>"#1C7ED6"}, {"name"=>"blue-8", "hexcode"=>"#1971C2"}, {"name"=>"blue-9", "hexcode"=>"#1864AB"},
    {"name"=>"cyan-0", "hexcode"=>"#E3FAFC"}, {"name"=>"cyan-1", "hexcode"=>"#C5F6FA"}, {"name"=>"cyan-2", "hexcode"=>"#99E9F2"},
    {"name"=>"cyan-3", "hexcode"=>"#66D9E8"}, {"name"=>"cyan-4", "hexcode"=>"#3BC9DB"}, {"name"=>"cyan-5", "hexcode"=>"#22B8CF"},
    {"name"=>"cyan-6", "hexcode"=>"#15AABF"}, {"name"=>"cyan-7", "hexcode"=>"#1098AD"}, {"name"=>"cyan-8", "hexcode"=>"#0C8599"},
    {"name"=>"cyan-9", "hexcode"=>"#0B7285"}, {"name"=>"teal-0", "hexcode"=>"#E6FCF5"}, {"name"=>"teal-1", "hexcode"=>"#C3FAE8"},
    {"name"=>"teal-2", "hexcode"=>"#96F2D7"}, {"name"=>"teal-3", "hexcode"=>"#63E6BE"}, {"name"=>"teal-4", "hexcode"=>"#38D9A9"},
    {"name"=>"teal-5", "hexcode"=>"#20C997"}, {"name"=>"teal-6", "hexcode"=>"#12B886"}, {"name"=>"teal-7", "hexcode"=>"#0CA678"},
    {"name"=>"teal-8", "hexcode"=>"#099268"}, {"name"=>"teal-9", "hexcode"=>"#087F5B"}, {"name"=>"green-0", "hexcode"=>"#EBFBEE"},
    {"name"=>"green-1", "hexcode"=>"#D3F9D8"}, {"name"=>"green-2", "hexcode"=>"#B2F2BB"}, {"name"=>"green-3", "hexcode"=>"#8CE99A"},
    {"name"=>"green-4", "hexcode"=>"#69DB7C"}, {"name"=>"green-5", "hexcode"=>"#51CF66"}, {"name"=>"green-6", "hexcode"=>"#40C057"},
    {"name"=>"green-7", "hexcode"=>"#37B24D"}, {"name"=>"green-8", "hexcode"=>"#2F9E44"}, {"name"=>"green-9", "hexcode"=>"#2B8A3E"},
    {"name"=>"lime-0", "hexcode"=>"#F4FCE3"}, {"name"=>"lime-1", "hexcode"=>"#E9FAC8"}, {"name"=>"lime-2", "hexcode"=>"#D8F5A2"},
    {"name"=>"lime-3", "hexcode"=>"#C0EB75"}, {"name"=>"lime-4", "hexcode"=>"#A9E34B"}, {"name"=>"lime-5", "hexcode"=>"#94D82D"},
    {"name"=>"lime-6", "hexcode"=>"#82C91E"}, {"name"=>"lime-7", "hexcode"=>"#74B816"}, {"name"=>"lime-8", "hexcode"=>"#66A80F"},
    {"name"=>"lime-9", "hexcode"=>"#5C940D"}, {"name"=>"yellow-0", "hexcode"=>"#FFF9DB"}, {"name"=>"yellow-1", "hexcode"=>"#FFF3BF"},
    {"name"=>"yellow-2", "hexcode"=>"#FFEC99"}, {"name"=>"yellow-3", "hexcode"=>"#FFE066"}, {"name"=>"yellow-4", "hexcode"=>"#FFD43B"},
    {"name"=>"yellow-5", "hexcode"=>"#FCC419"}, {"name"=>"yellow-6", "hexcode"=>"#FAB005"}, {"name"=>"yellow-7", "hexcode"=>"#F59F00"},
    {"name"=>"yellow-8", "hexcode"=>"#F08C00"}, {"name"=>"yellow-9", "hexcode"=>"#E67700"}, {"name"=>"orange-0", "hexcode"=>"#FFF4E6"},
    {"name"=>"orange-1", "hexcode"=>"#FFE8CC"}, {"name"=>"orange-2", "hexcode"=>"#FFD8A8"}, {"name"=>"orange-3", "hexcode"=>"#FFC078"},
    {"name"=>"orange-4", "hexcode"=>"#FFA94D"}, {"name"=>"orange-5", "hexcode"=>"#FF922B"}, {"name"=>"orange-6", "hexcode"=>"#FD7E14"},
    {"name"=>"orange-7", "hexcode"=>"#F76707"}, {"name"=>"orange-8", "hexcode"=>"#E8590C"}, {"name"=>"orange-9", "hexcode"=>"#D9480F"}
  ]

  colors.each do |data|
    PlanningElementTypeColor.create name: data["name"], hexcode: data["hexcode"]
  end
end

def fix_version_start_dates!
  Version.all.each do |version|
    if version.start_date.nil? && version.sprint_start_date.present?
      version.update start_date: version.sprint_start_date
    end
  end
end

def apply_fixes!
  create_backlogs!
  fix_queries!
  create_query_menu_items!
  rename_types!
  fix_backlogs_settings!
  fix_links_in_wikis!
  fix_done_statuses!
  set_default_work_package_types!
  add_view_members_permission!
  define_colors!
  fix_version_start_dates!
end
