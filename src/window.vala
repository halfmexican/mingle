/* window.vala
 *
 * Copyright 2023 José Hunter
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
    [GtkTemplate (ui = "/com/github/halfmexican/Mingle/window.ui")]
    public class Window : Adw.ApplicationWindow {

        [GtkChild] private unowned Gtk.FlowBox left_emojis_flow_box;
        [GtkChild] private unowned Gtk.FlowBox right_emojis_flow_box;

        public Window (Gtk.Application app) {
            Object (application: app);

            // Populate the left flow box
            add_emojis_to_flowbox(left_emojis_flow_box);

            // Populate the right flow box
            add_emojis_to_flowbox(right_emojis_flow_box);

        }

        private void add_emojis_to_flowbox(Gtk.FlowBox flowbox) {
            // Read the metadata.json file
            string file_contents;
            size_t length;
            var input_stream = GLib.resources_open_stream("/com/github/halfmexican/Mingle/metadata.json", GLib.ResourceLookupFlags.NONE);
            var data_stream = new GLib.DataInputStream(input_stream);
            file_contents = data_stream.read_upto("", -1, out length);

            // Parse the JSON data
            Json.Parser parser = new Json.Parser ();
            parser.load_from_data (file_contents, -1);

            // Access the root node
            Json.Node root = parser.get_root ();
            if (root.get_node_type () != Json.NodeType.OBJECT) {
                stderr.printf ("Root is not a JSON object.\n");
                return;
            }

            // Navigate to known_supported_emoji
            Json.Object root_object = root.get_object ();
            Json.Node known_supported_node = root_object.get_member("knownSupportedEmoji");
            if (known_supported_node.get_node_type () != Json.NodeType.ARRAY) {
                stderr.printf ("known_supported_emoji is not a JSON array.\n");
                return;
            }

           // Populate the flow box
            Json.Array known_supported_array = known_supported_node.get_array();
            for (int i = 0; i < known_supported_array.get_length(); i++) {
                Json.Node emoji_node = known_supported_array.get_element(i);
                string code_point_str = emoji_node.get_string();

                // Check if the code_point_str contains "-"
                if (code_point_str.contains("-")) {
                    // Handle sequence of Unicode characters
                    string[] parts = code_point_str.split("-");
                    string emoji = "";
                    foreach (string part in parts) {
                        int64 code_point_64 = int64.parse("0x" + part);
                        unichar emoji_char = (unichar) code_point_64;
                        emoji += @"$(emoji_char)";
                    }

                    add_emoji_to_flowbox(emoji, flowbox);
                } else {
                    // Handle single Unicode character
                    int64 code_point_64 = int64.parse("0x" + code_point_str);
                    unichar emoji_char = (unichar) code_point_64;
                    string emoji = @"$(emoji_char)";
                    add_emoji_to_flowbox(emoji, flowbox);
                }
            }

            // TODO: Fix
            flowbox.child_activated.connect ((item) => {
                Gtk.Label emoji_label = (Gtk.Label) item.child;
                unichar emoji_code = emoji_label.label.get_char (0);
                print ("\nUnicode: %x", emoji_code);
            });
        }


        private void add_emoji_to_flowbox(string emoji, Gtk.FlowBox flowbox) {
            var item = new Gtk.Label (emoji) {
                vexpand = true,
                hexpand = true,
                width_request = 50,
                height_request = 50,
                css_classes = { "emoji", "card", "title-1" }
            };

            flowbox.append (item);
        }
    }
}

