dashboard -layout source assembly stack variables expressions !registers !history !memory !threads !breakpoints
dashboard -style compact_values False
dashboard -style max_value_length 0

dashboard source -style height 20
dashboard source -style highlight-line True

dashboard assembly -style height 15
dashboard assembly -style opcodes True
dashboard assembly -style highlight-line True

dashboard variables -style compact False

dashboard expressions -style align True
