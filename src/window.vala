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

using Json, Soup, Gee;
namespace Mingle {
    [GtkTemplate (ui = "/com/github/halfmexican/Mingle/window.ui")]
    public class Window : Adw.ApplicationWindow {

        [GtkChild] private unowned Gtk.FlowBox left_emojis_flow_box;
        [GtkChild] private unowned Gtk.FlowBox right_emojis_flow_box;
        [GtkChild] private unowned Gtk.FlowBox combined_emojis_flow_box;
        [GtkChild] private unowned Adw.ToastOverlay toast_overlay;
        private Json.Node root_node;
        private Json.Array known_supported_emojis;
        private Json.Array curr_emoji_combinations;
        private string curr_left_emoji;
        private string curr_right_emoji;

        public Window (Gtk.Application app) {
            GLib.Object (application: app);

            add_emojis_to_flowbox(left_emojis_flow_box);
            add_emojis_to_flowbox(right_emojis_flow_box);
        }

        private Json.Array get_emoji_data() {
            // JSON reading and parsing logic here
            // Return the known_supported_array
            string file_contents;
            size_t length;

            var input_stream = GLib.resources_open_stream("/com/github/halfmexican/Mingle/metadata.json", GLib.ResourceLookupFlags.NONE);
            var data_stream = new GLib.DataInputStream(input_stream);
            file_contents = data_stream.read_upto("", -1, out length);

            Json.Parser parser = new Json.Parser ();
            parser.load_from_data (file_contents, -1);

            input_stream.close(null);
            data_stream.close(null);

            root_node = parser.get_root();
            if (root_node.get_node_type() != Json.NodeType.OBJECT) {
                stderr.printf ("Root node is not a JSON object.\n");
            }

            // Navigate to known_supported_emoji
            Json.Object root_object = root_node.get_object ();
            Json.Node known_supported_node = root_object.get_member("knownSupportedEmoji");
            if (known_supported_node.get_node_type () != Json.NodeType.ARRAY) {
                stderr.printf ("known_supported_emoji is not a JSON array.\n");
            }

            Json.Array known_supported_array = known_supported_node.get_array();
            return known_supported_array;
        }

        private void add_emojis_to_flowbox(Gtk.FlowBox flowbox) {
            if(known_supported_emojis == null)
                known_supported_emojis = get_emoji_data();

            for (int i = 0; i < known_supported_emojis.get_length(); i++) {
                Json.Node emoji_node = known_supported_emojis.get_element(i);
                add_emoji_to_flowbox(emoji_node.get_string(), flowbox);
            }

            flowbox.child_activated.connect ((item) => {
                Mingle.EmojiLabel emoji_label = (Mingle.EmojiLabel) item.child;
                string emoji_code = emoji_label.code_point_str;
                string emoji = emoji_label.emoji;
                stdout.printf("Unicode: %s, Emoji: %s\n", emoji_code, emoji);
                curr_emoji_combinations = get_combinations_by_emoji_code(emoji_label.code_point_str);
                this.populate_center_flow_box.begin();
            });
        }

        private void add_emoji_to_flowbox(string emoji, Gtk.FlowBox flowbox) {
            var item = new Mingle.EmojiLabel (emoji) {};
            flowbox.append (item);
        }

        private Json.Array get_combinations_by_emoji_code(string emoji_code) {
            Json.Node data_node = root_node.get_object().get_member("data");
            if (data_node == null || data_node.get_node_type() != Json.NodeType.OBJECT) {
                stderr.printf("Data node is missing or not an object.");
            }

            Json.Object data_object = data_node.get_object();

            // Get the specific emoji data by code
             Json.Node emoji_node = data_object.get_member(emoji_code);
             if (emoji_node == null || emoji_node.get_node_type() != Json.NodeType.OBJECT) {
                stderr.printf("Emoji code not found or data is not an object.");
            }

            Json.Object emoji_object = emoji_node.get_object();

            // Get the combinations array
            Json.Node combinations_node = emoji_object.get_member("combinations");
            if (combinations_node == null || combinations_node.get_node_type() != Json.NodeType.ARRAY) {
                stderr.printf("Combinations not found or not an array.");
            }

            return combinations_node.get_array();
        }

        private async void populate_center_flow_box() {
            Json.Array current_processing_combinations = curr_emoji_combinations;
            Gee.HashSet<string> added_emojis = new HashSet<string>();

            if (curr_emoji_combinations == null) {
                stderr.printf("Current emoji combinations are not set.\n");
                return;
            }
            combined_emojis_flow_box.remove_all();

            for (int i = 0; i < current_processing_combinations.get_length(); i++) {
                Json.Node combination_node = current_processing_combinations.get_element(i);
                if (combination_node.get_node_type() != Json.NodeType.OBJECT) {
                    continue;
                }


                if (current_processing_combinations != this.curr_emoji_combinations) {
                    combined_emojis_flow_box.remove_all();
                    return;  // Stop the loop if the array has changed
                }


                Json.Object combination_object = combination_node.get_object();
                Json.Node alt_node = combination_object.get_member("alt");
                Json.Node gstatic_url_node = combination_object.get_member("gStaticUrl");

                if (gstatic_url_node == null || gstatic_url_node.get_node_type() != Json.NodeType.VALUE) {
                    stderr.printf("gStaticUrl is missing or not a value.\n");
                    continue;
                }

                string gstatic_url = gstatic_url_node.get_value().get_string();
                string alt_name = alt_node.get_value().get_string();
                  if (!added_emojis.add(alt_name)) {
                    // If the emoji was already in the set, 'add' returns false
                    continue;  // So skip this emoji, it's a duplicate
                 }

                Mingle.CombinedEmoji combined_emoji = yield new Mingle.CombinedEmoji(gstatic_url);

                combined_emoji.copied.connect(() => {
                    var toast = new Adw.Toast("Image copied to clipboard"){
                        timeout = 3,
                    };
                    toast_overlay.add_toast(toast);
                });

                combined_emojis_flow_box.append(combined_emoji);
                combined_emoji.revealer.reveal_child = true; //animate transition
            }
        }
    }
}


