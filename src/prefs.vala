/* prefs.vala
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

using Gtk, Adw, GLib;
namespace Mingle {
    [GtkTemplate (ui = "/com/github/halfmexican/Mingle/gtk/prefs.ui")]
    public class PrefsWindow : Adw.PreferencesWindow {
    [GtkChild] private unowned Adw.ComboRow headerbar_row;
    [GtkChild] private unowned Adw.ComboRow transition_row;
    private GLib.Settings settings;

        public PrefsWindow (Mingle.Application app) {
            this.settings = app.settings;
            headerbar_row.notify["selected"].connect (update_headerbar_style);
            headerbar_row.set_selected (this.settings.get_int ("headerbar-style"));
            transition_row.notify["selected"].connect (update_revealer_transition);
            transition_row.set_selected (this.settings.get_int ("transition-type"));
        }

        private void update_headerbar_style () {
            int selected = (int) headerbar_row.get_selected ();
            this.settings.set_int ("headerbar-style", selected);
        }

        private void update_revealer_transition () {
            int selected = (int) transition_row.get_selected ();
            this.settings.set_int ("transition-type", selected);
        }
    }
}
