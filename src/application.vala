/* application.vala
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

namespace Mingle {
    public class Application : Adw.Application {
        public GLib.Settings settings = new GLib.Settings ("io.github.halfmexican.Mingle");
        public Application () {
            Object (application_id: "io.github.halfmexican.Mingle", flags: ApplicationFlags.DEFAULT_FLAGS);
        }

        construct {
            ActionEntry[] action_entries = {
                { "select_random", this.select_random },
                { "load_batch", this.load_batch },
                { "about", this.on_about_action },
                { "preferences", this.on_preferences_action },
                { "quit", this.quit }
            };
            this.add_action_entries (action_entries, this);
            this.set_accels_for_action ("app.quit", { "<primary>q" });
            this.set_accels_for_action ("app.select_random", { "<Ctrl>R"});
            this.set_accels_for_action ("app.load_batch", {"<Ctrl>L"});
        }

        public override void activate () {
            base.activate ();
            var win = this.active_window;
            if (win == null) {
                win = new Mingle.Window (this);
            }
            win.present ();
        }

        private void select_random () {
            var win = (Mingle.Window) this.active_window;
            win.select_random ();
        }

        private void load_batch () {
            var win = (Mingle.Window) this.active_window;
            win.populate_center_flow_box_lazy.begin ();
        }

        private void on_about_action () {
            string[] developers = {
                "José Hunter https://github.com/halfmexican",
                "kramo https://kramo.page",
                "QuazarOmega https://github.com/quazar-omega"
            };
            var about = new Adw.AboutDialog () {
                application_name = "mingle",
                application_icon = "io.github.halfmexican.Mingle",
                website = "https://github.com/halfmexican/mingle",
                issue_url = "https://github.com/halfmexican/mingle/issues",
                developer_name = "José Hunter",
                version = "0.15",
                developers = developers,
                copyright = "© 2024 José Hunter",
                license_type = Gtk.License.GPL_3_0,
            };
            about.present (this.active_window);
        }

        private void on_preferences_action () {
            message ("app.preferences action activated");
            var prefs = new Mingle.PrefsDialog ();
            prefs.present (this.active_window);
        }
    }
}
