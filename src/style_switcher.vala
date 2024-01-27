using Adw;

namespace Mingle {
    [GtkTemplate (ui = "/com/github/halfmexican/Mingle/gtk/style-switcher.ui")]
    public class StyleSwitcher : Gtk.Widget {

        [GtkChild] unowned Gtk.CheckButton system_selector;
        [GtkChild] unowned Gtk.CheckButton light_selector;
        [GtkChild] unowned Gtk.CheckButton dark_selector;

        private Adw.StyleManager style_manager;
        private GLib.Settings settings = new GLib.Settings ("com.github.halfmexican.Mingle");
        public bool show_system { get; set; default = true; }

        public StyleSwitcher () {
            this.style_manager = Adw.StyleManager.get_default ();
            switch (this.settings.get_int ("color-scheme") ) {
                case 0:
                    style_manager.set_color_scheme (Adw.ColorScheme.DEFAULT);
                    system_selector.activate ();
                    break;
                case 1:
                    style_manager.set_color_scheme (Adw.ColorScheme.FORCE_LIGHT);
                    light_selector.activate ();
                    break;
                case 2:
                    style_manager.set_color_scheme (Adw.ColorScheme.FORCE_DARK);
                    dark_selector.activate ();
                    break;
            }
        }

        static construct {
            set_layout_manager_type (typeof (Gtk.BinLayout));
        }

        [GtkCallback]
        private void theme_check_active_changed () {
            if (this.system_selector.active) {
                style_manager.set_color_scheme (Adw.ColorScheme.DEFAULT);
                settings.set_int ("color-scheme", 0);
            } else if (this.light_selector.active) {
                style_manager.set_color_scheme (Adw.ColorScheme.FORCE_LIGHT);
                settings.set_int ("color-scheme", 1);
            } else if (this.dark_selector.active) {
                style_manager.set_color_scheme (Adw.ColorScheme.FORCE_DARK);
                settings.set_int ("color-scheme", 2);
            }
        }
    }
}

