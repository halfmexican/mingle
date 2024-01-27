using Adw;

namespace Mingle {
    [GtkTemplate (ui = "/com/github/halfmexican/Mingle/gtk/style-switcher.ui")]
    public class StyleSwitcher : Gtk.Widget {

        [GtkChild] unowned Gtk.CheckButton system_selector;
        [GtkChild] unowned Gtk.CheckButton light_selector;
        [GtkChild] unowned Gtk.CheckButton dark_selector;

        private Adw.StyleManager style_manager;

        public bool show_system { get; set; default = true; }

        public StyleSwitcher () {
            style_manager = Adw.StyleManager.get_default ();
        }

        static construct {
            set_layout_manager_type (typeof (Gtk.BinLayout));
        }

        [GtkCallback]
        private void theme_check_active_changed () {
            if (this.system_selector.active) {
                style_manager.set_color_scheme (Adw.ColorScheme.DEFAULT);
            } else if (this.light_selector.active) {
                style_manager.set_color_scheme (Adw.ColorScheme.FORCE_LIGHT);
            } else if (this.dark_selector.active) {
                style_manager.set_color_scheme (Adw.ColorScheme.FORCE_DARK);
            }
        }
    }
}

