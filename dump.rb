app = Growl.application do |a|
  a.name = "Testo"
  a.app_icon = "Mail"
  a.notification do |n|
    n.name = "Yo Mommma"
    n.title = "Some Things About Yo Momma"
    n.message = "Yo momma is so {adj}, when she {v}, {pl}!"
  end
end