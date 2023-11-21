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

        private Gee.HashMap<string, Json.Node> combinations_map;
        private Json.Node root_node;
        private Json.Array known_supported_emojis;
        private Json.Array curr_emoji_combinations;
        private Gee.HashSet<string> added_emojis = new HashSet<string>();
        string curr_left_emoji;
        string curr_right_emoji;

        private delegate void EmojiActionDelegate(Mingle.EmojiLabel emoji_label);

        public Window (Gtk.Application app) {
            var window_timer = new GLib.Timer();
            window_timer.start();
            GLib.Object (application: app);
            setup_emoji_flow_boxes();
            initialize_hashmap();
            right_emojis_flow_box.sensitive = false;
            window_timer.stop();
            stdout.printf("\nWindow opened in %2f seconds\n\n", window_timer.elapsed());
        }

        private void initialize_hashmap() {
            // MutiThreaded Hashmap implementation
            if (!Thread.supported()) {
                stderr.printf("Threads are not supported!\n");
            }

            try {
                Thread<Gee.HashMap<string, Json.Node>> thread = new Thread<Gee.HashMap<string, Json.Node>>.try (
                        "combinations_map_thread", () => {
                        return populate_combinations_map();
                    });
                combinations_map = thread.join();
            } catch (Error e) {
                stderr.printf("Error: %s\n", e.message);
            }
        }

        private void setup_emoji_flow_boxes() {
            connect_flow_box_signals(left_emojis_flow_box, handle_left_emoji_activation);
            connect_flow_box_signals(right_emojis_flow_box, handle_right_emoji_activation);

            add_emojis_to_flowbox(left_emojis_flow_box);
            add_emojis_to_flowbox(right_emojis_flow_box);
        }

        private void connect_flow_box_signals(Gtk.FlowBox flowBox, EmojiActionDelegate handler) {
            flowBox.child_activated.connect ((item) => {
                Mingle.EmojiLabel emoji_label = (Mingle.EmojiLabel) item.child;
                handler(emoji_label);
            });
        }

        private void handle_left_emoji_activation(Mingle.EmojiLabel emoji_label) {
            string emoji = emoji_label.emoji;
            curr_left_emoji = emoji_label.code_point_str;
            stdout.printf("Left Unicode: %s, Emoji: %s\n", curr_left_emoji, emoji);
            curr_emoji_combinations = get_combinations_by_emoji_code(emoji_label.code_point_str);
            added_emojis = new HashSet<string>();
            this.populate_center_flow_box.begin();
            this.get_emoji_combination(curr_left_emoji, curr_right_emoji);
            right_emojis_flow_box.sensitive = true;
        }

        private void handle_right_emoji_activation(Mingle.EmojiLabel emoji_label) {
            string emoji = emoji_label.emoji;
            curr_right_emoji = emoji_label.code_point_str;
            stdout.printf("Right Unicode: %s, Emoji: %s\n", curr_right_emoji, emoji);
            added_emojis = new HashSet<string>();
            curr_emoji_combinations = get_combinations_by_emoji_code(curr_left_emoji);
            this.populate_center_flow_box.begin();
            this.get_emoji_combination(curr_left_emoji, curr_right_emoji);
        }

        private async void get_emoji_combination(string left_codepoint, string right_codepoint) {
            string combinationKey1 = left_codepoint + "_" + right_codepoint;
            string combinationKey2 = right_codepoint + "_" + left_codepoint;

            Json.Node combinationNode1 = combinations_map.get(combinationKey1);
            Json.Node combinationNode2 = combinations_map.get(combinationKey2);

            if (combinationNode1 != null) {
                yield process_combination(combinationNode1);
            } else if (combinationNode2 != null) {
                yield process_combination(combinationNode2);
            } else {
                stderr.printf("Combination not found for the provided codepoints.\n");
            }
        }

        private async void process_combination(Json.Node combinationNode) {
            // Extract the data from the combinationNode
            Json.Object combination_object = combinationNode.get_object();
            Json.Node gstatic_url_node = combination_object.get_member("gStaticUrl");
            Json.Node alt_node = combination_object.get_member("alt");
            string alt_name = alt_node.get_value().get_string();
            stdout.printf("\n%s\n",alt_name);
            added_emojis.add(alt_name);

            if (gstatic_url_node != null && gstatic_url_node.get_node_type() == Json.NodeType.VALUE) {
                string gstatic_url = gstatic_url_node.get_value().get_string();

                Mingle.CombinedEmoji combined_emoji = yield new Mingle.CombinedEmoji(gstatic_url, true);
                combined_emojis_flow_box.insert(combined_emoji, 0);
                combined_emoji.revealer.reveal_child = true;
                combined_emoji.copied.connect(() => {
                    create_and_show_toast("Image copied to clipboard");
                });
            } else {
                stderr.printf("gStaticUrl is missing or not a value.\n");
            }
        }

        private Gee.HashMap<string, Json.Node> populate_combinations_map() {
            stdout.printf("populate_combinations_map thread started\n");
            Json.Array emoji_data = get_emoji_data();
            Gee.HashMap<string, Json.Node> combinations_map = new Gee.HashMap<string, Json.Node>();

            for (int i = 0; i < emoji_data.get_length(); i++) {
                Json.Node emoji_node = emoji_data.get_element(i);
                string emoji_code = emoji_node.get_string();
                Json.Array combinations = get_combinations_by_emoji_code(emoji_code);

                for (int j = 0; j < combinations.get_length(); j++) {
                    Json.Node combination_node = combinations.get_element(j);
                    Json.Object combination_object = combination_node.get_object();

                    string leftEmojiCode = combination_object.get_member("leftEmojiCodepoint").get_value().get_string();
                    string rightEmojiCode = combination_object.get_member("rightEmojiCodepoint").get_value().get_string();

                    string combinationKey = leftEmojiCode + "_" + rightEmojiCode;
                    combinations_map.set(combinationKey, combination_node);
                }
            }
            stdout.printf("populate_combinations_map thread finishes\n");
            return combinations_map;
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

        private void create_and_show_toast(string message) {
            var toast = new Adw.Toast(message) {timeout = 3};
            toast_overlay.add_toast(toast);
        }

       private async void populate_center_flow_box() {
    // Early exit if no combinations are set
    if (curr_emoji_combinations.get_length() == 0) {
        stderr.printf("No emoji combinations to process.\n");
        return;
    }

    // Clearing the existing emojis in the flow box
    combined_emojis_flow_box.remove_all();

    foreach (Json.Node combination_node in curr_emoji_combinations.get_elements()) {
        // Check if the node is a valid JSON object
        if (combination_node.get_node_type() != Json.NodeType.OBJECT) {
            continue;
        }

        Json.Object combination_object = combination_node.get_object();
        string alt_name = combination_object.get_member("alt").get_value().get_string();

        // Skip duplicates
        if (!added_emojis.add(alt_name)) {
            continue;
        }

        string gstatic_url = combination_object.get_member("gStaticUrl").get_value().get_string();

        // Asynchronously create and append the emoji
        Mingle.CombinedEmoji combined_emoji = yield new Mingle.CombinedEmoji(gstatic_url, false);
        combined_emoji.copied.connect(() => {
            weak Window self = this;
            self.create_and_show_toast("Image copied to clipboard");
        });

        combined_emojis_flow_box.append(combined_emoji);
        combined_emoji.revealer.reveal_child = true;
    }
}
    }
}



