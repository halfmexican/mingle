/* style_switcher.vala
 *
 * Copyright 2023-2024 José Hunter
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
using Adw;

namespace Mingle {
    [GtkTemplate (ui = "/io/github/halfmexican/Mingle/gtk/style-switcher.ui")]
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

