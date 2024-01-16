mingle_sources = [
  'main.vala',
  'application.vala',
  'window.vala',
  'utils.vala',
  'emoji_label.vala',
  'combined_emoji.vala',
  'emoji_data_manager.vala'
]

mingle_deps = [
  dependency('gtk4'),
  dependency('gio-2.0'),
  dependency('libadwaita-1'),
  dependency('json-glib-1.0'),
  dependency('libsoup-3.0'),
  dependency('gee-0.8')
]

mingle_sources += gnome.compile_resources('mingle-resources',
  'mingle.gresource.xml',
  c_name: 'mingle'
)

executable('mingle', mingle_sources,
  dependencies: mingle_deps,
       install: true,
)
